
//  Добавляем меню
public void OnAdminMenuReady(Handle topmenu)
{
    if (view_as<TopMenu>(topmenu) == hTop) return;
    hTop = view_as<TopMenu>(topmenu);

    hCat = hTop.FindCategory("cc_base_menu");
    if (hCat == INVALID_TOPMENUOBJECT) {
        hCat = hTop.AddCategory("cc_base_menu", CC_Base_Cat, "cc_base", ADMFLAG_GENERIC, "Chat Control");
    }

    // Добавляем пункты внутри
    hTop.AddItem("cc_check_item", CC_Check, hCat, "cc_check", ADMFLAG_GENERIC, "Проверить");
}

public void CC_Base_Cat(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int len)
{
    if (action == TopMenuAction_DisplayTitle || action == TopMenuAction_DisplayOption)
        strcopy(buffer, len, "Проверка на читы");

    hTop.AddItem("cc_check_item", CC_Check, object_id, "cc_check", ADMFLAG_GENERIC, "Проверить");
}

public void CC_Check(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)  // Подпись
    {
        strcopy(buffer, maxlength, "Проверить");
    }
    else if (action == TopMenuAction_SelectOption)
    {
        CreateMenuCheck(client);
    }
}

//  Пустое меню
void NothingMenu(int client)
{
    Menu hNothingMenu = new Menu(Callback_NothingMenu);
    hNothingMenu.SetTitle("Доступного выбора нет");
	hNothingMenu.AddItem("item1", "Цель отсутствует!", ITEMDRAW_DISABLED);

    hNothingMenu.ExitBackButton = true;
    hNothingMenu.Display(client, 30);
}

public int Callback_NothingMenu(Menu menu, MenuAction action, int client, int item)
{
    switch(action)
    {
		case MenuAction_End:
        {
            delete menu;
        }
        case MenuAction_Cancel:
        {
            if(item == MenuCancel_ExitBack)
            {
                hTop.DisplayCategory(hCat, client);
            }
        }
	}
	return 0;
}

//  Раздел проверки
void CreateMenuCheck(int client)
{
	if(!IsValidClient(client))
		return;

	CheckFile();
	hMenu[client] = new Menu(CreateMenuClient);
	hMenu[client].SetTitle("Кого вызвать на проверку?");
	int iItem;
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i) && i != client && !iCCheat[i] && !CheckCheatClient(client))
	{
		if(!cvCheckAdmin.BoolValue && (GetUserFlagBits(i) & ADMFLAG_BAN || GetUserFlagBits(i) & ADMFLAG_ROOT))
			continue;
			
		iItem++;
		iOneChosen[client][i] = iItem;
		char sName[42];
		Format(sName, sizeof(sName), "%N", i);
		hMenu[client].AddItem("item1", sName);
		
	}
	if(!iItem)
	{
		delete hMenu[client];
		NothingMenu(client);
	}
	else{
        hMenu[client].ExitBackButton = true;
		hMenu[client].Display(client, MENU_TIME_FOREVER);
	}
}

int CreateMenuClient(Menu menu, MenuAction action, int client, int item)
{
    switch (action)
    {
        case MenuAction_End:
        {
            if(!IsValidClient(client))
			    return 0;
		
		    delete hMenu[client];
        }

        case MenuAction_Cancel:
        {
            if (item == MenuCancel_ExitBack)
                hTop.DisplayCategory(hCat, client);
        }

        case MenuAction_Select:
        {
            int idx = item + 1;
            int cheater = 0;

            for (int i = 1; i <= MaxClients; i++)
            {
                if (i != client && IsClientInGame(i) && !IsFakeClient(i) && iOneChosen[client][i] == idx)
                {
                    cheater = i;
                    break;
                }
            }

            CheckCheatsClient(client, cheater);
        }
    }

    return 0;
}

void MenuCheack(int admin, int cheater)
{
	CreateMenuCheack(admin, cheater);
	hMenu[admin].Display(admin, MENU_TIME_FOREVER);
}


int CreateMenuCheack(int admin, int cheater)
{
	hMenu[admin] = new Menu(SelectMenuCheack);
	char sTitle[64];
	Format(sTitle, sizeof(sTitle), "Действия с %N", cheater);
	if(iCCheat[cheater] == 1) hMenu[admin].SetTitle(sTitle);
	else if(iCCheat[cheater] == 2) hMenu[admin].SetTitle(sContact[cheater]); 
	hMenu[admin].AddItem("item1", "Напомнить о контактах");
	hMenu[admin].AddItem("item2", "Оправдан");
	hMenu[admin].AddItem("item3", "Забанить игрока");
	return 0;
}

int SelectMenuCheack(Menu hMenuLocal, MenuAction action, int client, int iItem)
{
	if(action == MenuAction_Select)
	{
		switch(iItem)
		{
			case 0:
			{
				if(!IsValidClient(iAdminCheck[client]))
					return 0;
				PrintToChat(iAdminCheck[client], "Вам необходимо написать свой VK/TG !");
				PrintToChat(client, "Вы напомнили о контактах игроку [%N]", iAdminCheck[client]);
				LogToFile(sFile, "Админ [%N] напомнил о контактах [%N]", client, iAdminCheck[client]);
				hMenu[client].Display(client, MENU_TIME_FOREVER);
			}
			
			case 1:
			{
				if(!IsValidClient(iAdminCheck[client]))
					return 0;
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
				if(!IsValidClient(iAdminCheck[client]))
					return 0;
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
		if(!IsValidClient(client))
			return 0;
		
		delete hMenu[client];
	}
	return 0;
}

void SpawnMenu(int client)
{
	hMenu[client].Display(client, MENU_TIME_FOREVER);
}