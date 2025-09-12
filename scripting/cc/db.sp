// ====================== SQLite ======================
void Custom_SQLite()
{
    KeyValues kv = new KeyValues("");
    kv.SetString("driver", "sqlite");
    kv.SetString("database", "cc");

    char err[255];
    hDatabase = SQL_ConnectCustom(kv, err, sizeof err, true);
    kv.Close();

    if (!hDatabase || err[0])
    {
        SetFailState("SQLite connect error: %s", err);
        return;
    }
    Migrate_Start_SQLite();
}

void Migrate_Start_SQLite()
{
    iStepSQLite = 0;
    Migrate_RunNext_SQLite();
}

bool BuildStep_SQLite(int step, char[] q, int maxlen)
{
    switch (step)
    {
        case 0:
        {
            FormatEx(q, maxlen, "PRAGMA foreign_keys=ON;"); return true;
        }
        case 1:
        {
            FormatEx(q, maxlen, "CREATE TABLE IF NOT EXISTS `cc_users` (\
                `id` INTEGER PRIMARY KEY AUTOINCREMENT,\
                `steamid` VARCHAR(32) NOT NULL UNIQUE,\
                `name` VARCHAR(64) NOT NULL,\
                `last_ip` BLOB NULL,\
                `created_at` TEXT NOT NULL DEFAULT (datetime('now')),\
                `updated_at` TEXT NOT NULL DEFAULT (datetime('now'))\
                );"); return true;
        }
        case 2:
        {
            FormatEx(q, maxlen, "CREATE TABLE IF NOT EXISTS `cc_outcomes` (\
                `id` INTEGER PRIMARY KEY,\
                `code` TEXT NOT NULL UNIQUE,\
                `title` TEXT NOT NULL,\
                `is_final` INTEGER NOT NULL DEFAULT 0,\
                `implies_ban` INTEGER NOT NULL DEFAULT 0\
                );"); return true;
        }
        case 3:
        {
            FormatEx(q, maxlen, "INSERT OR IGNORE INTO `cc_outcomes` (id,code,title,is_final,implies_ban) VALUES\
                (0,'pending','Вызван',0,0),\
                (1,'in_progress','Идёт проверка',0,0),\
                (2,'left_banned','Вышел и забанен',1,1),\
                (3,'cheat_banned','Уличён и забанен',1,1),\
                (4,'admin_left','Админ вышел (прервана)',1,0),\
                (5,'map_change','Смена карты (прервана)',1,0),\
                (6,'clean','Читов не найдено (успешно)',1,0);"); return true;
        }
        case 4:
        {
            FormatEx(q, maxlen, "CREATE TABLE IF NOT EXISTS `cc_checks` (\
                `id` INTEGER PRIMARY KEY AUTOINCREMENT,\
                `user_id` INTEGER NOT NULL,\
                `admin_id` INTEGER NOT NULL,\
                `server_id` INTEGER NULL,\
                `started_at` TEXT NOT NULL,\
                `ended_at` TEXT NULL,\
                `outcome_id` INTEGER NOT NULL,\
                `ban_minutes` INTEGER NULL,\
                `user_ip_at_start` BLOB NULL,\
                `notes` TEXT NULL,\
                `created_at` TEXT NOT NULL DEFAULT (datetime('now')),\
                `updated_at` TEXT NOT NULL DEFAULT (datetime('now')),\
                FOREIGN KEY (`user_id`) REFERENCES `cc_users`(`id`),\
                FOREIGN KEY (`admin_id`) REFERENCES `cc_users`(`id`),\
                FOREIGN KEY (`outcome_id`) REFERENCES `cc_outcomes`(`id`)\
                );"); return true;
        }
    }
    return false;
}

void Migrate_RunNext_SQLite()
{
    char q[2048];
    if (!BuildStep_SQLite(iStepSQLite, q, sizeof q))
    {
        PrintToServer("[CC] SQLite migrations OK");
        return;
    }
    hDatabase.Query(Migrate_CB_SQLite, q);
}

public void Migrate_CB_SQLite(Database db, DBResultSet res, const char[] err, any data)
{
    if (err[0])
    {
        LogError("[CC] SQLite step %d error: %s", iStepSQLite + 1, err);
        return;
    }
    iStepSQLite++;
    Migrate_RunNext_SQLite();
}

// ====================== MySQL ======================
void StartConnect_MySql(Database db, const char[] szError, any data)
{
    if (!db || szError[0])
    {
        SetFailState("MySQL connect error: %s", szError);
        return;
    }
    hDatabase = db;
    hDatabase.SetCharset("utf8mb4");
    Migrate_Start_MySQL();
}

void Migrate_Start_MySQL()
{
    iStepMySQL = 0;
    Migrate_RunNext_MySQL();
}

bool BuildStep_MySQL(int step, char[] q, int maxlen)
{
    switch (step)
    {
        case 0:
        {
            FormatEx(q, maxlen, "CREATE TABLE IF NOT EXISTS `cc_users` (\
                `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,\
                `steamid` VARCHAR(32) NOT NULL UNIQUE,\
                `name` VARCHAR(64) NOT NULL,\
                `last_ip` VARBINARY(16) NULL,\
                `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,\
                `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,\
                PRIMARY KEY (`id`), INDEX (`name`)\
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;"); return true;
        }
        case 1:
        {
            FormatEx(q, maxlen, "CREATE TABLE IF NOT EXISTS `cc_outcomes` (\
                `id` TINYINT PRIMARY KEY,\
                `code` VARCHAR(32) NOT NULL UNIQUE,\
                `title` VARCHAR(64) NOT NULL,\
                `is_final` TINYINT(1) NOT NULL DEFAULT 0,\
                `implies_ban` TINYINT(1) NOT NULL DEFAULT 0\
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;"); return true;
        }
        case 2:
        {
            FormatEx(q, maxlen, "INSERT IGNORE INTO `cc_outcomes` (id,code,title,is_final,implies_ban) VALUES\
                (0,'pending','Вызван',0,0),\
                (1,'in_progress','Идёт проверка',0,0),\
                (2,'left_banned','Вышел и забанен',1,1),\
                (3,'cheat_banned','Уличён и забанен',1,1),\
                (4,'admin_left','Админ вышел (прервана)',1,0),\
                (5,'map_change','Смена карты (прервана)',1,0),\
                (6,'clean','Читов не найдено (успешно)',1,0);"); return true;
        }
        case 3:
        {
            FormatEx(q, maxlen, "CREATE TABLE IF NOT EXISTS `cc_checks` (\
                `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,\
                `user_id` BIGINT UNSIGNED NOT NULL,\
                `admin_id` BIGINT UNSIGNED NOT NULL,\
                `server_id` INT NULL,\
                `started_at` DATETIME NOT NULL,\
                `ended_at` DATETIME NULL,\
                `outcome_id` TINYINT NOT NULL,\
                `ban_minutes` INT NULL,\
                `user_ip_at_start` VARBINARY(16) NULL,\
                `notes` TEXT NULL,\
                `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,\
                `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,\
                PRIMARY KEY (`id`),\
                INDEX (`user_id`), INDEX (`admin_id`), INDEX (`outcome_id`), INDEX (`started_at`),\
                CONSTRAINT `fk_checks_user` FOREIGN KEY (`user_id`) REFERENCES `cc_users`(`id`) ON DELETE RESTRICT,\
                CONSTRAINT `fk_checks_admin` FOREIGN KEY (`admin_id`) REFERENCES `cc_users`(`id`) ON DELETE RESTRICT,\
                CONSTRAINT `fk_checks_outcome` FOREIGN KEY (`outcome_id`) REFERENCES `cc_outcomes`(`id`) ON DELETE RESTRICT\
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;"); return true;
        }
    }
    return false;
}

void Migrate_RunNext_MySQL()
{
    char q[2048];
    if (!BuildStep_MySQL(iStepMySQL, q, sizeof q))
    {
        PrintToServer("[CC] MySQL migrations OK");
        return;
    }
    hDatabase.Query(Migrate_CB_MySQL, q);
}

public void Migrate_CB_MySQL(Database db, DBResultSet res, const char[] err, any data)
{
    if (err[0])
    {
        LogError("[CC] MySQL step %d error: %s", iStepMySQL + 1, err);
        return;
    }
    iStepMySQL++;
    Migrate_RunNext_MySQL();
}

//  Отправляем данные о начале проверки
