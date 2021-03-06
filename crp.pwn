
/*

    Celtics Roleplay
    LuisSAMP, KapeX

*/


#include <a_samp>
#include <a_mysql>
//#include <a_mysql_yinline>
#include <streamer>
#include <sscanf2>
#include <Pawn.CMD>
#include <Pawn.RakNet>

#undef MAX_PLAYERS
#define MAX_PLAYERS     150

#define SERVER_VERSION  "1.0"
#define BUILD_VERSION   "04/04/2020"

#define SERVER_NAME         "Celtics Roleplay"
#define SERVER_HOSTNAME     "[ESP] |    Celtics Roleplay    | (Español)"
#define SERVER_GAMEMODE     "Roleplay en español"
#define SERVER_LANGUAGE     "Español - Spanish"
#define SERVER_WEBURL       "Próximamente"
#define SERVER_COIN         "CR"

/* RCON */
#define RCON_PASS       "lska@04"

/* MySQL */
#define MYSQL_HOST      "localhost"
#define MYSQL_PASS      ""
#define MYSQL_USER      "root"
#define MYSQL_DB        "crp"

new MySQL:Database, bool:server_loaded, TOTAL_PLAYERS;//,
//SERVER_TIME[2], SERVER_WEATHER = 11;

new Float:New_User_Pos[4] = {1773.307250, -1896.441040, 13.551166, 270.0};

new Skin_Intro = 250;

#define MAX_TIMERS_PER_PLAYER       30

new Coin_Price = 100000;

main()
{
    print("--- > "SERVER_NAME" < ---");
}

enum Temp_Enum
{
    pt_IP[16],
    pt_NAME[24],
    bool:pt_USER_EXIT,
    bool:pt_USER_LOGGED,
    pt_RP_NAME[24],
    pt_TIMERS[MAX_TIMERS_PER_PLAYER],
    pt_BAD_LOGIN_ATTEMPS
};
new PLAYER_TEMP[MAX_PLAYERS][Temp_Enum];

enum enum_PI
{
    pi_ID,
    pi_IP[16],
    pi_NAME[24],
    pi_CASH,
    pi_SKIN,
    Float:pi_POS[3],
    Float:pi_ANGLE,
    pi_MEDICINE,
    pi_CRACK,
    pi_ADMIN_LEVEL,
    Float:pi_HEALTH,
    Float:pi_ARMOUR,
    pi_GENDER,
    pi_STATE,
    pi_PASS[64 + 1],
    pi_SALT[17]
};
new PI[MAX_PLAYERS][enum_PI];

new ADMIN_LEVELS[][] =
{
    "Ayudante",
    "Moderador",
    "Operador",
    "Administrador",
    "Desarrollador"
};

public OnGameModeInit()
{
    SetGameModeText(SERVER_GAMEMODE);
    SendRconCommand("hostname "SERVER_HOSTNAME"");
    SendRconCommand("language "SERVER_LANGUAGE"");
    SendRconCommand("weburl   "SERVER_WEBURL"");
    SendRconCommand("rcon password "RCON_PASS"");

    ConnectDatabase();
    UsePlayerPedAnims();
    SpawnVehicles();

    LoadServerInfo();
    return 1;
}

ConnectDatabase()
{
    new MySQLOpt:options = mysql_init_options();
    mysql_set_option(options, AUTO_RECONNECT, true);
    mysql_set_option(options, MULTI_STATEMENTS, true);

    Database = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DB);
    if(mysql_errno(Database) == 0)
    {
        print("\n----------------------------------------");
        print("La conexión con la base de datos funciona.");
        print("----------------------------------------\n");
    }
    else
    {
        print("No se puedo conectar con la base de datos.");
        SendRconCommand("exit");
    }

    return 1;
}

enum
{
    DIALOG_INFO,
    DIALOG_REGISTER,
    DIALOG_REGISTER_EMAIL,
    DIALOG_LOGIN,
    DIALOG_BUY_COINS
};

LoadServerInfo()
{
    server_loaded = true;
    return 1;
}

public OnPlayerConnect(playerid)
{
    TOTAL_PLAYERS ++;

    GetPlayerName(playerid, PLAYER_TEMP[playerid][pt_NAME], 24);
    GetPlayerIp(playerid, PLAYER_TEMP[playerid][pt_IP], 16);

    new num_players_on_ip = CountPlayersOnThisIP(PLAYER_TEMP[playerid][pt_IP]);
    if(num_players_on_ip > 3)
    {
        ShowPlayerDialog(playerid, DIALOG_INFO, DIALOG_STYLE_MSGBOX, "Aviso", "Has sido expulsado por exceder el máximo de conexiones desde una IP.", "Entiendo", "");
        KickEx(playerid);
        return 1;
    }

    SetRolePlayNames(playerid);
    printf("%s (%d) ha ingresado al servidor.", PLAYER_TEMP[playerid][pt_NAME], playerid);

    return 1;
}

stock SetRolePlayNames(playerid)
{
    new name[24];
    format(name, 24, "%s", PLAYER_TEMP[playerid][pt_NAME]);
    format(PLAYER_TEMP[playerid][pt_RP_NAME], 24, "%s", name);

    for(new i = 0; i < 24; i++)
    {
        if(name[i] == '_') PLAYER_TEMP[playerid][pt_RP_NAME][i] = ' ';
    }

    return 1;
}

CountPlayersOnThisIP(test_ip[])
{
    new againts_ip[16], ip_count = 0;
    for(new x = 0, j = GetPlayerPoolSize(); x <= j; x++)
    {
        if(IsPlayerConnected(x))
        {
            GetPlayerIp(x, againts_ip, 16);
            if(!strcmp(test_ip, againts_ip)) ip_count ++;
        }
    }

    return ip_count;
}

enum
{
    TYPE_NONE,
    TYPE_WARNING,
    TYPE_KICK,
    TYPE_BAN,
    TYPE_TEMP_BAN
};

ShowDialog(playerid, dialogid)
{
    switch(dialogid)
    {
        case DIALOG_REGISTER: return ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_PASSWORD, ""SERVER_NAME" - Registrarse", "Bienvenido, esta cuenta no está registrada.\nIngresa una contraseña para continuar", "Aceptar", "Cancelar");
        case DIALOG_REGISTER_EMAIL: return ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_INPUT, ""SERVER_NAME" - Email", "Ahora necesitamos que registres tu Email, ya que es la única manera de\nrecuperar tu contraseña\ntTranquilo, no sufrirás SPAM ni suscripciones", "Aceptar", "Cancelar");
        case DIALOG_LOGIN: return ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_PASSWORD, ""SERVER_NAME" - Ingresar", "Bienvenido de nuevo, esta cuenta si está registrada, ingresa la\ncontraseña para ingresar", "Aceptar", "Cancelar");
    }

    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    GetPlayerPos(playerid, PI[playerid][pi_POS][0], PI[playerid][pi_POS][1], PI[playerid][pi_POS][2]);
    GetPlayerFacingAngle(playerid, PI[playerid][pi_ANGLE]);

    GetPlayerHealth(playerid, PI[playerid][pi_HEALTH]);
    GetPlayerArmour(playerid, PI[playerid][pi_ARMOUR]);

    if(PLAYER_TEMP[playerid][pt_USER_EXIT]) SavePlayerData(playerid);
    return 1;
}

SavePlayerData(playerid)
{
    if(!PLAYER_TEMP[playerid][pt_USER_EXIT]) return 0;

    new DB_Query[900];
    mysql_format(Database, DB_Query, sizeof DB_Query,
    "\
        UPDATE player SET \
        ip = '%e',\
        name = '%e',\
        pass = '%e',\
        salt = '%e',\
        cash = %d,\
        skin = %d,\
        gender = %d\
        WHERE id = %d;\
    ", PI[playerid][pi_IP], PI[playerid][pi_NAME], PI[playerid][pi_PASS], PI[playerid][pi_SALT],
    PI[playerid][pi_CASH], PI[playerid][pi_SKIN], PI[playerid][pi_GENDER], PI[playerid][pi_ID]);

    mysql_tquery(Database, DB_Query);
    return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
    /*inline CheckPlayerRegister()
    {
        new rows;
        if(cache_get_row_count(rows))
        {
            if(rows)
            {
                cache_get_value_name_int(0, "id", PI[playerid][pi_ID]);
                cache_get_value_name(0, "name", PI[playerid][pi_NAME], 24);
                cache_get_value_name(0, "salt", PI[playerid][pi_SALT], 16);
                cache_get_value_name(0, "pass", PI[playerid][pi_PASS], 64 + 1);

                PLAYER_TEMP[playerid][pt_USER_EXIT] = true;
            }
            else PLAYER_TEMP[playerid][pt_USER_EXIT] = false;
        }
    }

    if(PLAYER_TEMP[playerid][pt_USER_EXIT]) ShowDialog(playerid, DIALOG_LOGIN);
    else ShowDialog(playerid, DIALOG_REGISTER);

    new DB_Query[120];
    mysql_format(Database, DB_Query, sizeof DB_Query, "SELECT id, name, salt, pass FROM player WHERE id = %d;", PI[playerid][pi_ID]);
    mysql_tquery_inline(Database, DB_Query, using inline CheckPlayerRegister);*/

    return 1;
}

KickEx(playerid, time = 0)
{
    if(!time) Kick(playerid);
    else
    {
        KillTimer(PLAYER_TEMP[playerid][pt_TIMERS][0]);
        PLAYER_TEMP[playerid][pt_TIMERS][0] = SetTimerEx("KickPlayer", time, false, "i", playerid);
    }

    return 1;
}

forward KickPlayer(playerid);
public KickPlayer(playerid)
{
    return Kick(playerid);
}

RegisterNewPlayer(playerid)
{
    if(PLAYER_TEMP[playerid][pt_USER_EXIT]) return 0;

    new DB_Query[120];
    format(DB_Query, sizeof DB_Query, "INSERT INTO player\
        (name, salt, pass, cash, skin, gender, pos_x, pos_y, pos_z, angle, health, armour, admin_level)\
        VALUES \
        ('%e', '%e', '%e', '%e', %d, %d, %d, %f, %f, %f, %f, %f, %f, %d)\
    ", PI[playerid][pi_NAME], PI[playerid][pi_SALT], PI[playerid][pi_PASS], PI[playerid][pi_CASH], PI[playerid][pi_SKIN], PI[playerid][pi_GENDER],
    PI[playerid][pi_POS][0], PI[playerid][pi_POS][1], PI[playerid][pi_POS][2], PI[playerid][pi_ANGLE], PI[playerid][pi_HEALTH], PI[playerid][pi_ARMOUR],
    PI[playerid][pi_ADMIN_LEVEL]);

    mysql_tquery(Database, DB_Query, "OnPlayeRegister", "i", playerid);
    return 1;
}

forward OnPlayerRegister(playerid);
public OnPlayerRegister(playerid)
{
    print("Jugador registrado");
    SendClientMessage(playerid, -1, "Bienvenido!");

    return 1;
}

public OnPlayerUpdate(playerid)
{
    new Float:player_health;
    GetPlayerHealth(playerid, player_health);

    if(player_health > 100.0) return Kick(playerid);

    return 1;
}

CheckPassword(playerid, pass[])
{
    if(!strcmp(pass, PI[playerid][pi_PASS], false))
    {
        LoadPlayerData(playerid);
        return true;
    }
    else
    {
        PLAYER_TEMP[playerid][pt_BAD_LOGIN_ATTEMPS] ++;
        if(PLAYER_TEMP[playerid][pt_BAD_LOGIN_ATTEMPS] >= 3) return Kick(playerid);
        ShowDialog(playerid, DIALOG_LOGIN);

        return false;
    }

    return false;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        case DIALOG_REGISTER:
        {
            if(response)
            {
                if(strlen(inputtext) < 8 || strlen(inputtext) > 24) return ShowDialog(playerid, dialogid);

                format(PI[playerid][pi_NAME], 24, "%s", PLAYER_TEMP[playerid][pt_NAME]);
                format(PI[playerid][pi_IP], 16, "%s", PLAYER_TEMP[playerid][pt_IP]);

                new salt[16];
                getRandomSalt(salt);
                format(PI[playerid][pi_SALT], 16, "%s", salt);

                SHA256_PassHash(inputtext, PI[playerid][pi_SALT], PI[playerid][pi_PASS], 64 + 1);
                RegisterNewPlayer(playerid);

                return 1;
            }
            else Kick(playerid);
        }
        case DIALOG_LOGIN:
        {
            if(!response) return Kick(playerid);
            if(!strlen(inputtext)) return ShowDialog(playerid, dialogid);

            new password[64 + 1];
            SHA256_PassHash(inputtext, PI[playerid][pi_SALT], password, sizeof password);
            CheckPassword(playerid, password);

            return 1;
        }
    }

    return 1;
}

LoadPlayerData(playerid)
{
    new DB_Query[120];
    format(DB_Query, sizeof DB_Query, "SELECT cash, skin, gender, pos_x, pos_y, pos_z, angle FROM player WHERE id = %d;", PI[playerid][pi_ID]);
    mysql_tquery(Database, DB_Query, "LoadPlayerDataLoaded", "i", playerid);

    return 1;
}

forward LoadPlayerDataLoaded(playerid);
public LoadPlayerDataLoaded(playerid)
{
    new count;
    cache_get_row_count(count);
    if(count)
    {
        cache_get_value_name_int(0, "cash", PI[playerid][pi_CASH]);
        cache_get_value_name_int(0, "skin", PI[playerid][pi_SKIN]);
    }

    return 1;
}

SpawnVehicles()
{
    CreateVehicle(481, 1768.4666, -1905.9497, 13.0901, 0.0000, -1, -1, 100);
    CreateVehicle(481, 1767.4142, -1905.8678, 13.0901, 0.0000, -1, -1, 100);
    CreateVehicle(481, 1766.1255, -1905.8784, 13.0901, 0.0000, -1, -1, 100);
    CreateVehicle(481, 1763.4052, -1905.9004, 13.0901, 359.7867, -1, -1, 100);
    CreateVehicle(481, 1764.7534, -1905.8895, 13.0901, 0.0000, -1, -1, 100);
    CreateVehicle(481, 1761.1735, -1905.9080, 13.0901, 359.7867, -1, -1, 100);
    CreateVehicle(481, 1762.2684, -1905.9276, 13.0901, 359.7867, -1, -1, 100);
    CreateVehicle(481, 1760.2510, -1905.8459, 13.0901, 359.7867, -1, -1, 100);

    return 1;
}

getRandomSalt(salt[], length = sizeof salt)
{
    for(new i = 0; i != length; i ++)
	{
		salt[i] = random(2) ? (random(26) + (random(2) ? 'a' : 'A')) : (random(10) + '0');
	}
	return true;
}
