#pragma semicolon 1
#pragma newdecls required

#include <sdktools_stringtables>
#include <smartdm>
#include <materialadmin>
#include <sdktools_sound>
#include <adminmenu>

TopMenu hTop;

TopMenuObject hCat;

ConVar
	cvBanTime,
	cvCheckAdmin, 
	cvOverlay,
	cvSound;
	
Menu
	hMenu[MAXPLAYERS+1];

int
	iAdminCheck[MAXPLAYERS+1],	//Кого проверяет админ в данный момент
	iOneChosen[MAXPLAYERS+1][MAXPLAYERS+1],		//Для передачи индекса выбранного игрока при выборе в меню
	iCCheat[MAXPLAYERS+1];		//Клеймо читера, кого проверяют в данный момент | 1 на проверке, 2 дал свои контакты
	
char
	sFile[PLATFORM_MAX_PATH],
	sOverlay[PLATFORM_MAX_PATH],
	sSound[PLATFORM_MAX_PATH],
	sContact[MAXPLAYERS+1][192],
	sSteam[MAXPLAYERS+1][32],
	sIp[MAXPLAYERS+1][16],
	gsName[MAXPLAYERS+1][64];

#include "cc/menu.sp"

public Plugin myinfo =
{
	name = "[Any] CheckCheats/Проверка на читы",
	author = "Nek.'a 2x2 | ggwp.site ",
	description = "Вызов для проверки на читы",
	version = "1.3.0",
	url = "https://ggwp.site/"
};

public void OnPluginStart()
{
	cvOverlay = CreateConVar("sm_cc_overlay", "ggwp/cc/1.vmt", "Оверлей");
	
	cvSound = CreateConVar("sm_cc_sound", "", "Звук для проигрывания подозреваемому | без папки sound/");
	
	cvBanTime = CreateConVar("sm_cc_bantime", "700", "Время бана в минутах");
	
	cvCheckAdmin = CreateConVar("sm_cc_checkadmin", "1", "Можно ли вызвать админа на проверку?");
	
	//RegAdminCmd("sm_cc", Cmd_CC, ADMFLAG_BAN, "Меню вызова на проверку");
	
	CheckFile();
	
	AddCommandListener(Command_JoinTeam, "jointeam");
	
	CreateTimer(1.0, CreateOverlay, _, TIMER_REPEAT);
	
	for(int i = 1; i <= MaxClients; i++) CheckInfoClient(i);
	
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
	CheckInfoClient(client);
}

void CheckInfoClient(int client)
{
	if(!(IsClientInGame(client) && !IsFakeClient(client)))
		return;
		
	GetClientIP(client, sIp[client], sizeof(sIp[]));
	GetClientAuthId(client, AuthId_Steam2, sSteam[client], sizeof(sSteam[]), true);
}

public Action CreateOverlay(Handle timer)
{	
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i) && iCCheat[i])
	{
		ClientCommand(i, "r_screenoverlay \"%s\"", sOverlay);
		if(GetClientTeam(i) > 1)
		{
			ChangeClientTeam(i, 1);
			PrintToChat(i, "Не пытайтесь жульничать ! Игра заблокирована до окончании проверки !");
			LogToFile(sFile, "Игрок [%N] попытался сжульничать и войти за команду во время проверки !", i);
		}
	}
	
	return Plugin_Changed;
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

public void OnConfigsExecuted()
{
    if (LibraryExists("adminmenu")) {
        TopMenu topmenu = GetAdminTopMenu();
        if (topmenu != null) OnAdminMenuReady(topmenu);
    }
}

public void OnMapEnd()
{
	for(int i = 1; i <= MaxClients; i++) iAdminCheck[i] = iCCheat[i] = 0;
}

void CheckCheatsClient(int admin, int cheater)
{
	if(admin < 1 || cheater < 1)
		return;

	ChangeClientTeam(cheater, 1);
	ChangeClientTeam(admin, 1);
	
	GetClientName(cheater, gsName[cheater], sizeof(gsName[]));
	PrintToChat(cheater, "Напишите свой скайп/дискорд для проверки !");
	iCCheat[cheater] = 1;
	iAdminCheck[admin] = cheater;
	LogToFile(sFile, "Админ [%N][%s][%s] вызвал на проверку [%N][%s][%s]", admin, sSteam[admin], sIp[admin], cheater, sSteam[cheater], sIp[cheater]);
	MenuCheack(admin, cheater);
	if(sSound[0])
		EmitSoundToClient(cheater, sSound);
	
}

stock bool IsValidClient(int client)
{
	return 0 < client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}

public Action Command_JoinTeam(int client, const char[] command, int args)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
		
	if(iCCheat[client])
	{
		PrintToChat(client, "Вас вызвали на проверку, игра запрещена !");
		LogToFile(sFile, "Игрок [%N] попытался сменить команду, действие заблокировано !", client);
		return Plugin_Handled;
	}
	else if(iAdminCheck[client])
	{
		PrintToChat(client, "Вы же не можете играть пока идёт проверка !");
		LogToFile(sFile, "Админ [%N] попытался сменить команду, при проверке игрока !", client);
		return Plugin_Handled;
	}
	return Plugin_Changed;
}

bool CheckCheatClient(int client)
{
	for(int i = 1; i <= MaxClients; i++) if(IsValidClient(i) && IsClientInGame(i) && !IsFakeClient(i))
	{
		if(iAdminCheck[client] == i)
			return true;
	}
	return false;
}

void CheckAdmin(int client)
{
	for(int i = 1; i <= MaxClients; i++) if(IsValidClient(i) && IsClientInGame(i) && !IsFakeClient(i))
		if(iAdminCheck[client] == i)
		{
			PrintToChat(i, "Админ %N вышел при Вашей проверки, можете играть !", client);
			LogToFile(sFile, "Админ [%N] вышел из игры при проверке игрока [%N]", client, i);
			iAdminCheck[client] = 0;
			iCCheat[i] = 0;
			ClientCommand(i, "r_screenoverlay \"\"");
		}
}

public void OnClientDisconnect(int client)
{
	CheckAdmin(client);
		
	if(iCCheat[client])
	{
		int admin = -1;
		for(int i; i <= MaxClients; i++)
			if(iAdminCheck[i] == client && i != client)
				admin = i;
		
		if(IsValidClient(admin))		//
			MAOffBanPlayer(admin, MA_BAN_STEAM, sSteam[client], sIp[client], gsName[client], cvBanTime.IntValue, "Вы покинули сервер при проверки !");
		else
			MAOffBanPlayer(0, MA_BAN_STEAM, sSteam[client], sIp[client], gsName[client], cvBanTime.IntValue, "Вы покинули сервер при проверки !");

		iCCheat[client] = 0;
		
		PrintToChatAll("Игрок [%N] вышел с сервера во время проверки и был забанен на [%d] минут !", client, cvBanTime.IntValue);
		LogToFile(sFile, "Игрок [%N][%s][%s] вышел с сервера во время проверки и был забанен на [%d] минут админом [%N][%s][%s] !", client, sSteam[client], sIp[client], cvBanTime.IntValue, admin, sSteam[admin], sIp[admin]);
		
		for(int i; i <= MaxClients; i++)
			if(iAdminCheck[i] == client)
				iAdminCheck[i] = 0;
	}
}

public Action OnClientSayCommand(int client, const char[] sCommand, const char[] arg)
{
	if(IsValidClient(client) && IsClientInGame(client) && !IsFakeClient(client) && iCCheat[client] == 1)
	{
		char sText[192];
		strcopy(sText, sizeof(sText), arg);
		TrimString(sText);
		StripQuotes(sText);
		
		if(StrEqual(sCommand, "say") || StrEqual(sCommand, "say_team"))
		{
			int admin = -1;

			for(int i; i <= MaxClients; i++)
				if(iAdminCheck[i] == client && i != client)
					admin = i;
			if(admin == -1)
				LogToFile(sFile, "Ошибка, индекс админа -1 !");
			if(!admin)
				LogMessage(sFile, "Ошибка, индекс админа 0 !");
			PrintToChat(admin, sText);
			sContact[client] = sText;
			//PrintToChatAll("Игрок [%N][%s][%s] отправил контакты админу [%N][%d]: [%s]", client, sSteam[client], sIp[client], admin, admin, sText);
			LogToFile(sFile, "Игрок [%N][%s][%s] отправил контакты админу [%N]: [%s]", client, sSteam[client], sIp[client], admin, sText);
			iCCheat[client] = 2;
			CreateMenuCheack(admin, client);
			SpawnMenu(admin);
		}
		
		return Plugin_Changed;
	}
	return Plugin_Continue;
}