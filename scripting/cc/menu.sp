
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
	char buffer[8];
	int count;
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i) && i != client &&
		player[i].suspect == SUSPECT_NONE	//	Игрок не на проверки в данный момент
		&& !IsClientUnderCheck(client)		//	Админ не имеет игрока на проверке
		)
	{
		if(!cvCheckAdmin.BoolValue && (GetUserFlagBits(i) & ADMFLAG_BAN || GetUserFlagBits(i) & ADMFLAG_ROOT))
			continue;
		count++;
		Format(buffer, sizeof(buffer), "%d", i);
		hMenu[client].AddItem(buffer, player[i].name);
	}
	if(!count)
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
	if(!IsValidClient(client))
		return 0;

    switch (action)
    {
        case MenuAction_End:
        {
		    delete hMenu[client];
        }

        case MenuAction_Cancel:
        {
            if (item == MenuCancel_ExitBack)
                hTop.DisplayCategory(hCat, client);
        }

        case MenuAction_Select:
        {
			int target = getIndex(menu, item);
            StartCheckAndNotify(client, target);
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
	if(player[cheater].suspect == SUSPECT_ON_CHECK) 
		hMenu[admin].SetTitle(sTitle);
	else if(player[cheater].suspect == SUSPECT_CONTACT_GIVEN)
		hMenu[admin].SetTitle(player[cheater].contact); 
	hMenu[admin].AddItem("item1", "Напомнить о контактах");
	hMenu[admin].AddItem("item2", "Оправдан");
	hMenu[admin].AddItem("item3", "Забанить игрока");
	return 0;
}

int SelectMenuCheack(Menu hMenuLocal, MenuAction action, int client, int iItem)
{
	if(!IsValidClient(client) || !IsValidClient(player[client].examiner))
			return 0;
	int target = player[client].examiner;

	if(action == MenuAction_Select)
	{
		switch(iItem)
		{
			case 0:
			{
				PrintToChat(target, "Вам необходимо написать свой VK/TG !");
				PrintToChat(client, "Вы напомнили о контактах игроку [%N]", target);
				LogToFileOnly(sFile, "Админ [%N] напомнил о контактах [%N]", client, target);
				hMenu[client].Display(client, MENU_TIME_FOREVER);
			}
			
			case 1:
			{
				player[target].suspect = SUSPECT_NONE;
				PrintToChat(target, "Проверка завершена ! Спасибо за сотрудничество !");
				PrintToChat(client, "Вы завершили проверку [%N] - он чист !", target);
				LogToFileOnly(sFile, "Игрок [%N][%s][%s] завершил проверку [%N][%s][%s] ! Игрок чист !",
					client, player[client].steam, player[client].ip, target, player[target].steam, player[target].ip);
				ClientCommand(target, "r_screenoverlay \"\"");
				player[client].examiner = 0;
			}
			
			case 2:
			{
				player[target].suspect = SUSPECT_NONE;
				PrintToChat(target, "Проверка завершена ! Вы были уличены в читерстве !");
				LogToFileOnly(sFile, "Игрок [%N][%s][%s] завершил проверку [%N][%s][%s] ! Игрок уличен в читерстве !",
					client, player[client].steam, player[client].ip, target, player[target].steam, player[target].ip);
				//BanClient(target, 1, 0, "Не прошёл проверку и был забанен !", "Вы не прошли проверку на читы и были забанены !");
				MABanPlayer(client, target, MA_BAN_STEAM, cvBanTime.IntValue, "Вы не прошли проверку на читы и были забанены !");
				ClientCommand(target, "r_screenoverlay \"\"");
				player[client].examiner = 0;
			}
		}
	}
	else if(action == MenuAction_Cancel)
	{
		RequestFrame(SpawnMenu, client);
	}
	else if(action == MenuAction_End)
	{
		delete hMenu[client];
	}
	return 0;
}

void SpawnMenu(int client)
{
	hMenu[client].Display(client, MENU_TIME_FOREVER);
}