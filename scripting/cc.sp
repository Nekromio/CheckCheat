#pragma semicolon 1
#pragma newdecls required

#include <sdktools_stringtables>
#include <smartdm>
#include <materialadmin>

ConVar
	cvBanTime;
	
Menu
	hMenu[MAXPLAYERS+1];

int
	iAdminCheck[MAXPLAYERS+1],	//Кого проверяет админ в данный момент
	iOneChosen[MAXPLAYERS+1][MAXPLAYERS+1],		//Для передачи индекса выбранного игрока при выборе в меню
	iCCheat[MAXPLAYERS+1];		//Клеймо читера, кого проверяют в данный момент | 1 на проверке, 2 дал свои контакты
	
char
	sFile[PLATFORM_MAX_PATH],
	sOverlay[PLATFORM_MAX_PATH],
	sContact[MAXPLAYERS+1][192],
	sSteam[MAXPLAYERS+1][32],
	sIp[MAXPLAYERS+1][16],
	gsName[MAXPLAYERS+1][64];

public Plugin myinfo =
{
	name = "[Any] CheckCheats/Проверка на читы",
	author = "Nek.'a 2x2 | ggwp.site ",
	description = "Вызов для проверки на читы",
	version = "1.0.5",
	url = "https://ggwp.site/"
};

public void OnPluginStart()
{
	ConVar cvar;
	cvar = CreateConVar("sm_cc_overlay", "overlay_cheats/ban_cheats_v10.vmt", "Оверлей");
	GetConVarString(cvar, sOverlay, sizeof(sOverlay));
	HookConVarChange(cvar, OnConVarChanges_Overlay);
	
	cvBanTime = CreateConVar("sm_cc_bantime", "700", "Время бана в минутах");
	
	RegAdminCmd("sm_cc", Cmd_CC, ADMFLAG_BAN, "Меню вызова на проверку");
	
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

public void OnConVarChanges_Overlay(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	GetConVarString(cvar, sOverlay, sizeof(sOverlay));
}

public Action CreateOverlay(Handle timer)
{
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i) && iCCheat[i])
		ClientCommand(i, "r_screenoverlay \"%s\"", sOverlay);
	
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i) && iCCheat[i])
	{
		if(GetClientTeam(i) == 2 || GetClientTeam(i) == 3)
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
	char buffer[PLATFORM_MAX_PATH];
	if(sOverlay[0])
	{
		Format(buffer, sizeof(buffer), "materials/%s", sOverlay);
		Downloader_AddFileToDownloadsTable(buffer);
		PrecacheModel(buffer, true);
	}
}

public Action Cmd_CC(int client, any arg)
{
	if(!client)
		return Plugin_Continue;
		
	CreatMenu(client);
	hMenu[client].Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Changed;
}

void CreatMenu(int client)
{
	if(!IsValidClient(client))
		return;
	CheckFile();
	hMenu[client] = new Menu(CreatMenuClient);
	hMenu[client].SetTitle("Кого вызвать на проверку?");
	int iItem;
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i) && i != client)
	{
		iItem++;
		iOneChosen[client][i] = iItem;
		char sName[42];
		Format(sName, sizeof(sName), "%N", i);
		hMenu[client].AddItem("item1", sName);
		//PrintToChatAll("[Проверка] Ник %N Индекс [%d] | Итем [%d]", i, i, iOneChosen[client][i]);
	}
}

public int CreatMenuClient(Menu hMenuLocal, MenuAction action, int client, int iItem)
{
	if(!IsValidClient(client))
		return;
		
	iItem++;
	int cheater;
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i))
		if(iOneChosen[client][i] == iItem)
		{
			//cheater = iOneChosen[client][i];
			cheater = i;
			//PrintToChatAll("Индекс cheater равен [%d]", cheater);
		}
	if(action == MenuAction_Select)
	{
		CheckCheatsClient(client, cheater);
		//PrintToChatAll("Выбран игрок [%N] Инекс [%d]/Пункт [%d]", iItem, iItem, iItem);
	}
	else if(action == MenuAction_End)
	{
		//hMenuLocal.Close();
		delete hMenu[client];
	}
}

void CheckCheatsClient(int admin, int cheater)
{
	//PrintToChatAll("Индекс [%d]", cheater);
	if(IsClientInGame(cheater))
		ChangeClientTeam(cheater, 1);
	if(IsClientInGame(admin))
		ChangeClientTeam(admin, 1);
	
	GetClientName(cheater, gsName[cheater], sizeof(gsName[]));
	PrintToChat(cheater, "Напишите свой скайп/дискорд для проверки !");
	iCCheat[cheater] = 1;
	iAdminCheck[admin] = cheater;
	LogToFile(sFile, "Админ [%N][%s][%s] вызвал на проверку [%N][%s][%s]", admin, sSteam[admin], sIp[admin], cheater, sSteam[cheater], sIp[cheater]);
	MenuCheack(admin, cheater);
}

void MenuCheack(int admin, int cheater)
{
	CreatMenuCheack(admin, cheater);
	hMenu[admin].Display(admin, MENU_TIME_FOREVER);
}

public int CreatMenuCheack(int admin, int cheater)
{
	hMenu[admin] = new Menu(SelectMenuCheack);
	char sTitle[64];
	Format(sTitle, sizeof(sTitle), "Действия с %N", cheater);
	Format(sTitle, sizeof(sTitle), "Действия с %N", cheater);
	if(iCCheat[cheater] == 1) hMenu[admin].SetTitle(sTitle);
	else if(iCCheat[cheater] == 2) hMenu[admin].SetTitle(sContact[cheater]); 
	hMenu[admin].AddItem("item1", "Напомнить о контактах");
	hMenu[admin].AddItem("item2", "Оправдан");
	hMenu[admin].AddItem("item3", "Забанить игрока");
}

public int SelectMenuCheack(Menu hMenuLocal, MenuAction action, int client, int iItem)
{
	if(!IsValidClient(client) || !IsValidClient(iAdminCheck[client]))
		return;
		
	if(action == MenuAction_Select)
	{
		switch(iItem)
		{
			case 0:
			{
				if(!IsValidClient(client) || !IsValidClient(iAdminCheck[client]))
					return;
				PrintToChat(iAdminCheck[client], "Вам необходимо написать свой скайп/дискорд !");
				PrintToChat(client, "Вы напомнили о контактах игроку [%N]", iAdminCheck[client]);
				LogToFile(sFile, "Админ [%N] напомнил о контактах [%N]", client, iAdminCheck[client]);
				hMenu[client].Display(client, MENU_TIME_FOREVER);
			}
			
			case 1:
			{
				if(!IsValidClient(client) || !IsValidClient(iAdminCheck[client]))
					return;
				iCCheat[iAdminCheck[client]] = 0;
				PrintToChat(iAdminCheck[client], "Проверка завершена ! Спасибо за сотрудничество !");
				PrintToChat(client, "Вы завершили проверку [%N] - он чист !", iAdminCheck[client]);
				LogToFile(sFile, "Игрок [%N][%s][%s] завершил проверку [%N][%s][%s] ! Игрок чист !",
					client, sSteam[client], sIp[client], iAdminCheck[client], sSteam[iAdminCheck[client]], sIp[iAdminCheck[client]]);
				ClientCommand(iAdminCheck[client], "r_screenoverlay \"\"");
				iAdminCheck[client] = 0;
			}
			
			case 2:
			{
				if(!IsValidClient(client) || !IsValidClient(iAdminCheck[client]))
					return;
				iCCheat[iAdminCheck[client]] = 0;
				PrintToChat(iAdminCheck[client], "Проверка завершена ! Вы были уличены в читерстве !");
				LogToFile(sFile, "Игрок [%N][%s][%s] завершил проверку [%N][%s][%s] ! Игрок уличен в читерстве !",
					client, sSteam[client], sIp[client], iAdminCheck[client], sSteam[iAdminCheck[client]], sIp[iAdminCheck[client]]);
				//BanClient(iAdminCheck[client], 1, 0, "Не прошёл проверку и был забанен !", "Вы не прошли проверку на читы и были забанены !");
				MABanPlayer(client, iAdminCheck[client], MA_BAN_STEAM, cvBanTime.IntValue, "Вы не прошли проверку на читы и были забанены !");
				ClientCommand(iAdminCheck[client], "r_screenoverlay \"\"");
				iAdminCheck[client] = 0;
			}
		}
	}
	else if(action == MenuAction_Cancel)
	{
		if(iAdminCheck[client])
			RequestFrame(SpawnMenu, client);
	}
	else if(action == MenuAction_End)
	{
		//hMenuLocal.Close();
		if(IsValidClient(client))
		{
			delete hMenu[client];
			//PrintToChatAll("Меню было удалено");
		}
	}
}

public void SpawnMenu(int client)
{
	hMenu[client].Display(client, MENU_TIME_FOREVER);
}

stock bool IsValidClient(int client)
{
	if(0 < client <= MaxClients)
		return true;
	else return false;
}

public Action Command_JoinTeam(int client, const char[] command, any args)
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

public void OnClientDisconnect(int client)
{
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
			//LogToFile(sFile, "Игрок [%N]", client);
			//PrintToChatAll("Игрок [%N][%d] отправил сообщение админу", client, client);
			int admin = -1;
/*		
			for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i) && i != client)
			{
				admin = iOneChosen[i][client];
			}*/
			
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
			CreatMenuCheack(admin, client);
			SpawnMenu(admin);
		}
		
		return Plugin_Changed;
	}
	return Plugin_Continue;
}