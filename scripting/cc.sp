#pragma semicolon 1
#pragma newdecls required

#include <sdktools_stringtables>
#include <smartdm>
#include <materialadmin>
#include <sdktools_sound>
#include <adminmenu>

TopMenu hTop;

TopMenuObject hCat;

Menu hMenu[MAXPLAYERS+1];

Database hDatabase;

int
    iStepSQLite,
    iStepMySQL;

ConVar
	cvBanTime,
	cvCheckAdmin, 
	cvOverlay,
	cvSound;
	
char
	sFile[PLATFORM_MAX_PATH],
	sOverlay[PLATFORM_MAX_PATH],
	sSound[PLATFORM_MAX_PATH];

enum SuspectState
{
	SUSPECT_NONE = 0,			//	Не на проверки
	SUSPECT_ON_CHECK,			//	Проверяется
	SUSPECT_CONTACT_GIVEN		//	Дал контакты
};

enum struct settings{
	int id;
	char steam[32];
	char contact[192];
	char ip[16];
	char name[MAX_NAME_LENGTH];

	int examiner;				//	Кого проверяет админ в данный момент
	SuspectState suspect;		//	Клеймо читера, кого проверяют в данный момент | 1 на проверке, 2 дал свои контакты
	int checkedBy;				//	Кто проверяет этого player игрока

	void Init(int client)
	{
		this.id = client;
		this.checkPlayer();
	}

	void checkPlayer()
	{
		GetClientName(this.id, this.name, sizeof(this.name));
		GetClientIP(this.id, this.ip, sizeof(this.ip));
		GetClientAuthId(this.id, AuthId_Steam2, this.steam, sizeof(this.steam), true);
	}

	void ResetCehckAll()
	{
		this.suspect = SUSPECT_NONE;
		this.checkedBy = 0;
		this.examiner = 0;
	}
}

settings player[MAXPLAYERS+1];

#include "cc/menu.sp"
#include "cc/db.sp"

public Plugin myinfo =
{
	name = "[Any] CheckCheats/Проверка на читы",
	author = "Nek.'a 2x2 | vk.com/nekromio | t.me/sourcepwn ",
	description = "Вызов для проверки на читы",
	version = "1.3.2",
	url = "https://ggwp.site/"
};

public void OnPluginStart()
{
	cvOverlay = CreateConVar("sm_cc_overlay", "ggwp/cc/1.vmt", "Оверлей");
	cvSound = CreateConVar("sm_cc_sound", "", "Звук для проигрывания подозреваемому | без папки sound/");
	cvBanTime = CreateConVar("sm_cc_bantime", "700", "Время бана в минутах", _, true, 0.0, true, 99000.0);
	cvCheckAdmin = CreateConVar("sm_cc_checkadmin", "1", "Можно ли вызвать админа на проверку?", _, true, 0.0, true, 1.0);
	
	CheckFile();
	
	AddCommandListener(Command_JoinTeam, "jointeam");
	
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i)) OnClientPostAdminCheck(i);
	
	AutoExecConfig(true, "cc");
}

void CheckFile()
{
	char sTime[PLATFORM_MAX_PATH], sPath[56];
	BuildPath(Path_SM, sPath, sizeof(sPath), "logs/cc");
	if(!DirExists(sPath))
		CreateDirectory(sPath, 511);
	FormatTime(sTime, sizeof(sTime), "%Y.%m.%d");
	BuildPath(Path_SM, sFile, sizeof(sFile), "logs/cc/cc_%s.log", sTime);
}

public void OnClientPostAdminCheck(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
		return;

	player[client].Init(client);
}

public void OnConfigsExecuted()
{
    if (LibraryExists("adminmenu")) {
        TopMenu topmenu = GetAdminTopMenu();
        if (topmenu != null) OnAdminMenuReady(topmenu);
    }

	if(SQL_CheckConfig("cc"))
	{
		Database.Connect(StartConnect_MySql, "cc");
	}
	else
	{
		Custom_SQLite();
	}

	CreateTimer(1.0, CreateOverlay, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapStart()
{
	char sBuffer[PLATFORM_MAX_PATH];
	
	cvSound.GetString(sBuffer, sizeof(sBuffer));
	if(sBuffer[0])
	{
		sSound = sBuffer;
		PrecacheSound(sBuffer, true);
		FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", sSound);
		AddFileToDownloadsTable(sBuffer);
	}
	
	cvOverlay.GetString(sBuffer, sizeof(sBuffer));
	if(sBuffer[0])
	{
		sOverlay = sBuffer;
		Format(sBuffer, sizeof(sBuffer), "materials/%s", sBuffer);
		Downloader_AddFileToDownloadsTable(sBuffer);
		PrecacheModel(sBuffer, true);
	}
}

public void OnMapEnd()
{
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i))
		player[i].ResetCehckAll();
}

public Action CreateOverlay(Handle timer)
{	
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i) && player[i].suspect)
	{
		ClientCommand(i, "r_screenoverlay \"%s\"", sOverlay);
		if(GetClientTeam(i) > 1)
		{
			ChangeClientTeam(i, 1);
			PrintToChat(i, "Не пытайтесь жульничать ! Игра заблокирована до окончании проверки !");
			LogToFileOnly(sFile, "Игрок [%N] попытался сжульничать и войти за команду во время проверки !", i);
		}
	}
	
	return Plugin_Changed;
}

//	Старт проверки на читы
void StartCheckAndNotify(int admin, int cheater)
{
	if(admin < 1 || cheater < 1)
		return;

	ChangeClientTeam(cheater, 1);
	ChangeClientTeam(admin, 1);
	
	player[cheater].checkPlayer();
	PrintToChat(cheater, "Напишите свой VK/TG для проверки!");

	player[admin].examiner = cheater;				//	Запоминаем кого вызвал админ
    player[cheater].checkedBy = admin;				//	Запоминаем что за админ вызвал подозреваемого
    player[cheater].suspect = SUSPECT_ON_CHECK;		//	Ставим клеймо проверки

	LogToFileOnly(sFile, "Админ [%N][%s][%s] вызвал на проверку [%N][%s][%s]",
		admin, player[admin].steam, player[admin].ip, cheater, player[cheater].steam, player[cheater].ip);
	MenuCheack(admin, cheater);
	if(sSound[0]) EmitSoundToClient(cheater, sSound);
}

stock bool IsValidClient(int client)
{
	return 0 < client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}

public Action Command_JoinTeam(int client, const char[] command, int args)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
		
	if(player[client].suspect)
	{
		PrintToChat(client, "Вас вызвали на проверку, игра запрещена !");
		LogToFileOnly(sFile, "Игрок [%N] попытался сменить команду, действие заблокировано !", client);
		return Plugin_Handled;
	}
	else if(player[client].examiner)
	{
		PrintToChat(client, "Вы же не можете играть пока идёт проверка !");
		LogToFileOnly(sFile, "Админ [%N] попытался сменить команду, при проверке игрока !", client);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	ResetCheckIfAdminLeft(client);

	if(player[client].suspect == SUSPECT_NONE)
		return;
	
	int admin = player[client].checkedBy;
	
	MAOffBanPlayer(admin, MA_BAN_STEAM, player[client].steam, player[client].ip, player[client].name, cvBanTime.IntValue, "Вы покинули сервер при проверки !");

	ResetCehck(admin, client);
	
	PrintToChatAll("Игрок [%N] вышел с сервера во время проверки и был забанен на [%d] минут !", client, cvBanTime.IntValue);
	LogToFileOnly(sFile, "Игрок [%N][%s][%s] вышел с сервера во время проверки и был забанен на [%d] минут админом [%N][%s][%s] !",
		client, player[client].steam, player[client].ip, cvBanTime.IntValue, admin, player[admin].steam, player[admin].ip);
}

public Action OnClientSayCommand(int client, const char[] sCommand, const char[] arg)
{
	if(IsValidClient(client) && IsClientInGame(client) && !IsFakeClient(client) && player[client].suspect == SUSPECT_ON_CHECK)
	{
		char sText[192];
		strcopy(sText, sizeof(sText), arg);
		TrimString(sText);
		StripQuotes(sText);
		
		if(StrEqual(sCommand, "say") || StrEqual(sCommand, "say_team"))
		{
			int admin = player[client].checkedBy;

			if(!admin)
				LogToFileOnly(sFile, "[ERROR] Администратор не найден!");

			PrintToChat(admin, sText);
			player[client].contact = sText;
			/* PrintToChatAll("Игрок [%N][%s][%s] отправил контакты админу [%N][%d]: [%s]",
				client, player[client].steam, player[client].ip, admin, sText); */
			LogToFileOnly(sFile, "Игрок [%N][%s][%s] отправил контакты админу [%N]: [%s]",
				client, player[client].steam, player[client].ip, admin, sText);

			player[client].suspect = SUSPECT_CONTACT_GIVEN;

			CreateMenuCheack(admin, client);
			SpawnMenu(admin);
		}
		
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void LogToFileOnly(const char[] path, const char[] format, any ...)
{
    char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 3);

    char sDate[32];
    FormatTime(sDate, sizeof(sDate), "%Y:%m:%d %H:%M:%S");

    char final[600];
    Format(final, sizeof(final), "%s | %s", sDate, buffer);

    File hFile = OpenFile(path, "a");
    if (hFile != null)
    {
        WriteFileLine(hFile, final);
        delete hFile;
    }
    else
    {
        LogError("Failed to open file: %s", path);
    }
}

int getIndex(Menu menu, int item)
{
    char buffer[8];
    menu.GetItem(item, buffer, sizeof(buffer));
    int target = StringToInt(buffer);
    return target;
}

//	Проверяем наличие игрока на проверке
bool IsClientUnderCheck(int client)
{
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i))
	{
		if(player[client].examiner == i)
			return true;
	}
	return false;
}

//	Узнаём какой именно админ вызвал на проверку этого игрока
stock int GetClientExaminer(int client)
{
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i) && player[i].examiner == client)
	{
		return i;
	}
	return -1;
}

//	Проверяем вышел ли админ при проведении проверки, если да, то сбрасываем проверку
stock void ResetCheckIfAdminLeft(int client)
{
	if(!player[client].examiner)
		return;

	int target = player[client].examiner;

	PrintToChat(target, "Админ %N вышел при Вашей проверки, можете играть!", client);
	LogToFileOnly(sFile, "Админ [%N] вышел из игры при проверке игрока [%N]", client, target);
	ClientCommand(target, "r_screenoverlay \"\"");
}

void ResetCehck(int admin, int suspect)
{
	player[admin].examiner = 0;
	player[suspect].checkedBy = 0;
	player[suspect].suspect = SUSPECT_NONE;
}