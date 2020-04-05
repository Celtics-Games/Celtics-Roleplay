
/*

    Celtics Roleplay
    LuisSAMP, KapeX

*/


#include <a_samp>
#include <a_mysql>
#include <a_mysql_yinline>
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
#define SERVER_WEBURL       "www.sa-mp.com"
#define SERVER_COIN         "CR"

/* RCON */
#define RCON_PASS       "lska@04"

/* MySQL */
#define MYSQL_HOST      "localhost"
#define MYSQL_PASS      ""
#define MYSQL_USER      "root"
#define MYSQL_DB        "crp"

new MySQL:Database, bool:server_loaded, TOTAL_PLAYERS;

new Float:New_User_Pos[4] = {};

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
    pt_TIMERS[MAX_TIMERS_PER_PLAYER]
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
    "Operador"
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

    LoadServerInfo();
    return 1;
}

ConnectDatabase()
{
    new MySQLOpt:options = mysql_init_options();
    mysql_set_options(options, AUTO_RECONNECT, true);
    mysql_set_options(options, MULTI_STATEMENTS, true);

    Database = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DB);
    if(msyql_errno(Database) == 0)
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
    new againts_ip, ip_count = 0;
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

                PLAYER_TEMP[playerid][pt_USER_EXIT] = true;
            }
            else PLAYER_TEMP[playerid][pt_USER_EXIT] = false;
        }
    }*/
    return 1;
}
