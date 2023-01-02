# CheckCheat
Plugin for calling players to check for cheats

# EN:
Description: The plugin makes it possible to conveniently check the player
1. The player and the administrator are frozen in observers all the time of the check
2. Menu call command for sm_cc admin
3. The plugin only works with the material admin system
4. For convenience, you can embed a call button in the admin menu

/addons/sourcemod/configs/adminmenu_custom.txt


"Commands"
{
	"Checking for cheats"
	{
		"Check for cheats"
		{
			"cmd" "sm_cc"
			"admin" "sm_ban"
		}
	}
}


5. In the settings file, you can change the call overlay and the ban time
/cfg/sourcemod/cc.cfg

# RU
Описание: Плагин даёт возможность удобной проверки игрока
1. Игрок и администратор заморожены в наблюдателях всё время проверки
2. Команда вызова меню для адмна sm_cc
3. Плагин работает только с системой materialadmin
4. Для удобства можно встроить в меню админа кнопку вызова

/addons/sourcemod/configs/adminmenu_custom.txt

"Commands"
{
	"Проверка на читы"
	{
	
		"Проверить на читы"
		{
			"cmd"           "sm_cc"
			"admin"			"sm_ban"
		}
	}
}

5. В файле настроек можно изменить оверлей вызова и время бана
/cfg/sourcemod/cc.cfg
