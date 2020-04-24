/**
 * Developed by JDW
 * All rights reserved.
 *
 * P.S.: For fuck's sake, don't redistribute this plugin for CSGOLife and any affliated web-sites (such as PawnDev)!
 */

#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

public Plugin myinfo = 
{
	name = "[Core]Dynamic console variables",
	author = "JDW",
	version = "1.1.1 [BETA]",
	url = "JDW#0930"
};

int online,
    counter,
    blockEvent,
    eventStart,
    eventEnd,
    minOnline[64],
    handlerType[64];

bool block,
     useBot,
     hide,
     eventMessage[64];
	 
EngineVersion engine;

char eventsExecutePath[64][PLATFORM_MAX_PATH],
     eventsTranslations[64][PLATFORM_MAX_PATH];

public void OnPluginStart()
{
    HookEvent("round_start", Event_ExecuteEvent, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_ExecuteEvent, EventHookMode_PostNoCopy);
    HookEvent("server_cvar", Event_ServerCvar, EventHookMode_Pre);
	
	if(engine == Engine_SourceSDK2006 || engine == Engine_Left4Dead || engine == Engine_Left4Dead2)
	{
		LoadTranslations("dcv_old.phrases");
	}
	else 
	{
		LoadTranslations("dcv.phrases");
	}

    char buffer[PLATFORM_MAX_PATH];
    FormatEx(buffer, PLATFORM_MAX_PATH, "%t", "Cvar Bot");

    ConVar cvar;

    (cvar = CreateConVar("dcv_bot", "0", buffer)).AddChangeHook(Cvar_Bot);
    useBot = cvar.BoolValue;

    FormatEx(buffer, PLATFORM_MAX_PATH, "%t", "Cvar Hide");

    (cvar = CreateConVar("dcv_hide", "1", buffer)).AddChangeHook(Cvar_Hide);
    hide = cvar.BoolValue;    

    RegAdminCmd("sm_dcvreload", Command_Reload, ADMFLAG_ROOT);

    AutoExecConfig(true, "dcv", "dcv");
	
	block = true;

    for(int i = 1; i != MaxClients; i++)
    {
        if(IsClientInGame(i))
        {
            OnClientConnected(i);
        }
    }
}

public Action Command_Reload(int client, int args)
{
    ConfigLoad(client);

    return Plugin_Handled;
}

public void Cvar_Bot(ConVar cvar, const char[] oldValue, const char[] newValue){
    useBot = cvar.BoolValue;
}

public void Cvar_Hide(ConVar cvar, const char[] oldValue, const char[] newValue){
    hide = cvar.BoolValue;
}

public void OnMapStart()
{
    ConfigLoad();
    ExecuteConfigs();
    BlockAllExecute();
}

public void OnMapEnd()
{
    BlockAllExecute();
}

public void OnClientConnected(int client)
{
    if(!useBot && IsFakeClient(client))
    {
        return;
    }

    IncPlayer();
}

public void OnClientDisconnect(int client)
{
    DecPlayer();
}

public void Event_ExecuteEvent(Event event, const char[] name, bool dontBroadcast)
{
    if(!block)
    {
        switch(name[6])
        {
            case 's':
            {
                if(eventStart != -1)
                {
                    ExecuteConfigs(eventStart);
                    eventStart = -1;
                }
            }
            case 'e':
            {
                if(eventEnd != -1)
                {
                    ExecuteConfigs(eventEnd);
                    eventEnd = -1;
                }
            }
        }
    }
}

public void Event_ServerCvar(Event event, const char[] name, bool dontBroadcast)
{
    if(!dontBroadcast && hide)
    {
        event.BroadcastDisabled = true;
    }
}

void ConfigLoad(const int client = 0)
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/dcv.ini");

    KeyValues kv = new KeyValues("DCV");

    if(!kv.ImportFromFile(path) || !kv.GotoFirstSubKey())
    {
        SetFailState("File (%s) not found", path);
    }

    kv.Rewind();
    counter = 0;

    if(kv.GotoFirstSubKey())
    {
        do 
        {
            minOnline[counter] = kv.GetNum("Online");
            handlerType[counter] = kv.GetNum("Handler Type");
            kv.GetString("Execute", eventsExecutePath[counter], PLATFORM_MAX_PATH);
            kv.GetString("Message", eventsTranslations[counter], PLATFORM_MAX_PATH);

            if(!StrEqual(eventsTranslations[counter], "", false))
            {
                eventMessage[counter] = true;
            }

            counter++;
        }
        while(kv.GotoNextKey(true));
    }

    eventStart = -1;
    eventEnd = -1;
    blockEvent = -1;

    if(client)
    {
        ESPrintToChat(client, "%T%T", "Prefix", client, "Settings Reload", client);
    }
}

void ExecuteConfigs(const int index = -1)
{
    char buffer[PLATFORM_MAX_PATH];

    if(index == -1)
    {
        GetCurrentMap(buffer, PLATFORM_MAX_PATH);
        Format(buffer, PLATFORM_MAX_PATH, "cfg/dcv/maps/%s.cfg", buffer);
    }
    else 
    {
        if(blockEvent == index)
        {
            return;
        }

        FormatEx(buffer, PLATFORM_MAX_PATH, "cfg/dcv/online/%s.cfg", eventsExecutePath[index]);
        blockEvent = index;

        if(eventMessage[index])
        {
            for(int i = 1; i != MaxClients; i++)
            {
                if(IsClientInGame(i) && !IsFakeClient(i))
                {
                    ESPrintToChat(i, "%T%T", "Prefix", i, eventsTranslations[index], i);
                }
            }
        }
    }
    ExecuteConfig(buffer);
}

void ExecuteConfig(const char[] config)
{
    if(FileExists(config))
    {
        ServerCommand("exec %s", config[4]);
    }
}

void IncPlayer()
{
    online++;
    CheckOnline();
}

void DecPlayer()
{
    online--;
    CheckOnline();
}

void CheckOnline()
{
    int index = -1;

    for(int i, buffer; i < counter; i++)
    {
        if(minOnline[i] < online + 1)
        {
            if(buffer < minOnline[i])
            {
                index = i;
                buffer = minOnline[i];
            }
        }
    }

    eventStart = -1;
    eventEnd = -1;

    if(index != -1)
    {
        switch(handlerType[index])
        {
            case 0:
            {
                ExecuteConfigs(index);
            }
            case 1:
            {
                eventStart = index;
            }
            case 2:
            {
                eventEnd = index;
            }
        }
    }
}

void BlockAllExecute()
{
    block = !block;
}

static const char colorsBefore[][] = 
{
    "{default}",
    "{team}",
    "{green}",
    "{red}",
    "{lime}",
    "{lightgreen}",
    "{lightred}",
    "{gray}",
    "{lightolive}",
    "{olive}",
    "{lightblue}",
    "{blue}",
    "{purple}",
    "{brightred}"
};

static const char colors[][] = 
{
    "\x01",
    "\x03", 
    "\x04", 
    "\x02", 
    "\x05", 
    "\x06", 
    "\x07", 
    "\x08", 
    "\x09", 
    "\x10", 
    "\x0B", 
    "\x0C", 
    "\x0E", 
    "\x0F"
};

static const int colorsOB[] = 
{
    0xFFFFFF, 
    0x000000, 
    0x00AD00, 
    0xFF0000, 
    0x00FF00, 
    0x99FF99, 
    0xFF4040, 
    0xCCCCCC, 
    0xFFBD6B, 
    0xFA8B00, 
    0x99CCFF, 
    0x3D46FF, 
    0xFA00FA, 
    0xFF6055
};

void ESParse(const int client, char[] message)
{
    if(client && IsClientInGame(client) && !IsFakeClient(client))
    {
        engine = GetEngineVersion();

        if(message[0])
        {
            if(engine != Engine_SourceSDK2006)
            {
                ReplaceString(message, 2048, "{WHITE}", "{DEFAULT}");
            }

            switch(engine)
            {
                case Engine_CSGO:
                {
                    Format(message, 2048, " %s", message);

                    for(int i; i != sizeof(colorsBefore); i++)
                    {
                        ReplaceString(message, 2048, colorsBefore[i], colors[i]);
                    }  
                }
                case Engine_SourceSDK2006, Engine_Left4Dead, Engine_Left4Dead2:
                {
                    for(int i; i != 3; i++)
                    {
                        ReplaceString(message, 2048, colorsBefore[i], colors[i]);
                    }
                }
                case Engine_CSS, Engine_TF2, Engine_DODS, Engine_HL2DM:
                {
                    static char color[16];
                    static int len;

                    len = StrContains(message, colorsBefore[1], false);

                    if(len != -1)
                    {
                        static const int colorsTeam[] = 
                        {
                            0xFFFFFF, 
                            0xCCCCCC, 
                            0xFF4040, 
                            0x99CCFF
                        };

                        FormatEx(color, 16, "\x07%06X", colorsTeam[GetClientTeam(client)]);
                        ReplaceString(message[len], 2048 - len, colorsBefore[1], color);
                    }

                    for(int i; i != sizeof(colorsBefore); i++)
                    {
                        if((len = StrContains(message, colorsBefore[i], false)) != -1)
                        {
                            FormatEx(color, 16, "\x07%06X", colorsOB[i]);
                            ReplaceString(message[len], 2048 - len, colorsBefore[i], color);
                        }
                    }
                }
            }
        }

        SendMessage(client, message);
    }
}

stock void ESPrintToChat(const int client, const char[] format, any ...)
{
    char message[2048];
    VFormat(message, 2048, format, 3);
    ESParse(client, message);
}

stock void ESPrintToChatAll(const char[] format, any ...)
{
    char message[2048];
    VFormat(message, 2048, format, 2);

    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && !IsFakeClient(i))
        {
            ESParse(i, message);
        }
    }
}

void SendMessage(const int client, const char[] text)
{
    Handle hMsg = StartMessageOne("SayText2", client, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS);

    if(hMsg)
    {
        if(GetUserMessageType() == UM_Protobuf)
        {
            Protobuf protoBuf = UserMessageToProtobuf(hMsg);
            protoBuf.SetInt("ent_idx", client);
            protoBuf.SetBool("chat", true);
            protoBuf.SetString("msg_name", text);
            protoBuf.AddString("params", "");
            protoBuf.AddString("params", "");
            protoBuf.AddString("params", "");
            protoBuf.AddString("params", "");
        }
        else 
        {
            BfWrite bfWrite = UserMessageToBfWrite(hMsg);
            bfWrite.WriteByte(client);
            bfWrite.WriteByte(true);
            bfWrite.WriteString(text);
        }
    }

    EndMessage();
}