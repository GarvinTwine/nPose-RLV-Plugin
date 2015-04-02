// LSL script generated - patched Render.hs (0.1.6.2): RLV+.nPose-RLV-Plugin.nPose RLV+ Core V0.22.lslp Thu Apr  2 22:55:28 Mitteleuropäische Sommerzeit 2015
//LICENSE:
//
//This script and the nPose scripts are licensed under the GPLv2
//(http://www.gnu.org/licenses/gpl-2.0.txt), with the following addendum:
//
//The nPose scripts are free to be copied, modified, and redistributed, subject
//to the following conditions:
//    - If you distribute the nPose scripts, you must leave them full perms.
//    - If you modify the nPose scripts and distribute the modifications, you
//      must also make your modifications full perms.
//
//"Full perms" means having the modify, copy, and transfer permissions enabled in
//Second Life and/or other virtual world platforms derived from Second Life (such
//as OpenSim).  If the platform should allow more fine-grained permissions, then
//"full perms" will mean the most permissive possible set of permissions allowed
//by the platform.

/*
USAGE

put this script into an object together with at least the following npose scripts:
- nPose Core
- nPose Dialog
- nPose menu
- nPose Slave
- nPose SAT/NOSAT handler

Add a NC called "BTN:-RLV-" with the following content:
LINKMSG|-8000|showmenu,%AVKEY%

Finished

Documentation:
https://github.com/LeonaMorro/nPose-RLV-Plugin/wiki
Bugs:
https://github.com/LeonaMorro/nPose-RLV-Plugin/issues
or IM slmember1 Resident (Leona)
*/


// linkMessage Numbers from -8000 to -8050 are assigned to the RLV+ Plugins
// linkMessage Numbers from -8000 to -8009 are assigned to the RLV+ Core Plugin
// linkMessage Numbers from -8010 to -8019 are assigned to the RLV+ RestrictionsMenu Plugin
// linkMessage Numbers from -8020 to -8047 are reserved for later use
// linkMessage Numbers from -8048 to -8049 are assigned to universal purposes


string PLUGIN_NAME = "RLV_CORE";

string BACKBTN = "^";
string MENU_RLV_MAIN = "RLVMain";
string MENU_RLV_CAPTURE = "→Capture";
string MENU_RLV_RESTRICTIONS = "→Restrictions";
string MENU_RLV_VICTIMS = "→Victims";
string MENU_RLV_TIMER = "→Timer";
string BUTTON_RLV_RELEASE = "Release";
string BUTTON_RLV_UNSIT = "Unsit";

string RLV_COMMAND_RELEASE = "!release";
string RLV_COMMAND_VERSION = "!version";
string RLV_COMMAND_PING = "ping";
string RLV_COMMAND_PONG = "!pong";

list TIMER_BUTTONS1 = ["+1d","+6h","+1h","+15m","+1m"];
list TIMER_BUTTONS2 = ["-1d","-6h","-1h","-15m","-1m","Reset"];

string TIMER_NO_TIME = "--:--:--";
string PROMPT_VICTIM = "Selected Victim: ";
string PROMPT_CAPTURE = "Pick a victim to attempt capturing.";
string PROMPT_RELAY = "RLV Relay: ";
string PROMPT_RELAY_YES = "OK";
string PROMPT_RELAY_NO = "NOT RECOGNIZED";
string NEW_LINE = "\n";
string NO_VICTIM = "NONE";

string PATH_SEPARATOR = ":";

// --- global variables

// options
integer RLV_captureRange = 10;
integer RLV_trapTimer;
integer RLV_grabTimer;
list RLV_enabledSeats = ["*"];

key MyUniqueId;

string Path;
key NPosetoucherID;
string NPosePath;


key VictimKey;
//integer currentVictimIndex=-1; //contains the VictimsList-index of the current victim

list VictimsList;

list FreeVictimsList;

list GrabList;

list RecaptureList;

list SensorList;

integer FreeRlvEnabledSeats;
integer FreeNonRlvEnabledSeats;


// for RLV base restrictions and reading them from a notecard
string RlvBaseRestrictions = "@unsit=n|@sittp=n|@tploc=n|@tplure=n|@tplm=n|@acceptpermission=add|@editobj:%MYKEY%=add";
key NcQueryId;

//added for timer
integer TimerRunning;

string PLUGIN_NAME_RLV_RESTRICTIONS_MENU = "RLV_RESTRICTIONS_MENU";
integer RlvRestrictionsMenuAvailable;

// --- functions

debug(list message){
    llOwnerSay(llGetScriptName() + "\n##########\n#>" + llDumpList2String(message,"\n#>") + "\n##########");
}


addToVictimsList(key avatarUuid,integer timerTime){
    if (timerTime > 0) {
        timerTime += llGetUnixTime();
    }
    else  if (timerTime < 0) {
        timerTime = 0;
    }
    integer index = llListFindList(VictimsList,[avatarUuid]);
    if (~index) {
        VictimsList = llDeleteSubList(VictimsList,index,index + 3 - 1);
        llMessageLinked(-1,-8002,(string)avatarUuid,"");
    }
    llMessageLinked(-1,-8001,(string)avatarUuid,"");
    VictimsList += [avatarUuid,timerTime,0];
    SendToRlvRelay(avatarUuid,RLV_COMMAND_VERSION,"relayCheck");
    SendToRlvRelay(avatarUuid,RlvBaseRestrictions,"");
}

removeFromVictimsList(key avatarUuid){
    integer index = llListFindList(VictimsList,[avatarUuid]);
    if (~index) {
        VictimsList = llDeleteSubList(VictimsList,index,index + 3 - 1);
        llMessageLinked(-1,-8002,(string)avatarUuid,"");
    }
    if (VictimKey == avatarUuid) {
        changeCurrentVictim(NULL_KEY);
    }
}

changeCurrentVictim(key newVictimKey){
    if (newVictimKey != VictimKey) {
        if (newVictimKey == NULL_KEY || ~llListFindList(VictimsList,[newVictimKey])) {
            VictimKey = newVictimKey;
            llMessageLinked(-1,-237,(string)VictimKey,"");
        }
    }
}

addToFreeVictimsList(key avatarUuid){
    if (!~llListFindList(FreeVictimsList,[avatarUuid])) {
        FreeVictimsList += avatarUuid;
    }
}

removeFromFreeVictimsList(key avatarUuid){
    integer index = llListFindList(FreeVictimsList,[avatarUuid]);
    if (~index) {
        FreeVictimsList = llDeleteSubList(FreeVictimsList,index,index + 1 - 1);
    }
}

addToGrabList(key avatarUuid){
    if (!~llListFindList(GrabList,[avatarUuid])) {
        GrabList += [avatarUuid];
        while (llGetListLength(GrabList) > 3) {
            GrabList = llList2List(GrabList,1,-1);
        }
    }
}

removeFromGrabList(key avatarUuid){
    integer index = llListFindList(GrabList,[avatarUuid]);
    if (~index) {
        GrabList = llDeleteSubList(GrabList,index,index + 1 - 1);
    }
}

addToRecaptureList(key avatarUuid,integer timerTime){
    if (timerTime < 0) {
        timerTime = 0;
    }
    RecaptureListGarbageCollection();
    integer index = llListFindList(RecaptureList,[avatarUuid]);
    if (~index) {
        RecaptureList = llDeleteSubList(RecaptureList,index,index + 3 - 1);
    }
    RecaptureList += [avatarUuid,timerTime,0];
    while (llGetListLength(RecaptureList) > 15) {
        RecaptureList = llList2List(RecaptureList,3,-1);
    }
}

removeFromRecaptureList(key avatarUuid){
    integer index = llListFindList(RecaptureList,[avatarUuid]);
    if (~index) {
        RecaptureList = llDeleteSubList(RecaptureList,index,index + 3 - 1);
    }
}
RecaptureListGarbageCollection(){
    integer currentTime = llGetUnixTime();
    integer length = llGetListLength(RecaptureList);
    integer index;
    for (; index < length; index += 3) {
        integer timeout = llList2Integer(RecaptureList,index + 2);
        if (timeout && timeout < currentTime) {
            RecaptureList = llDeleteSubList(RecaptureList,index,index + 3 - 1);
            index -= 3;
            length -= 3;
        }
    }
}

string StringReplace(string str,string search,string replace){
    return llDumpList2String(llParseStringKeepNulls(str,[search],[]),replace);
}

ShowMenu(key targetKey,string prompt,list buttons,string menuPath){
    if (targetKey) {
        llMessageLinked(-1,-900,(string)targetKey + "|" + prompt + "\n" + menuPath + "\n" + "|" + "0" + "|" + llDumpList2String(buttons,"`") + "|" + llDumpList2String([BACKBTN],"`") + "|" + menuPath,MyUniqueId);
    }
}

ShowMainMenu(key targetKey){
    list buttons;
    string prompt = getSelectedVictimPromt();
    integer toucherIsVictim = ~llListFindList(VictimsList,[targetKey]);
    integer victimTimerRunning;
    integer numberOfVictims = llGetListLength(VictimsList) / 3;
    integer victimRelayVersion;
    if (VictimKey) {
        victimRelayVersion = getVictimRelayVersion(VictimKey);
        integer victimIndex = llListFindList(VictimsList,[VictimKey]);
        if (~victimIndex) {
            victimTimerRunning = llList2Integer(VictimsList,victimIndex + 1) > 0;
        }
    }
    if (!toucherIsVictim) {
        buttons += [MENU_RLV_CAPTURE];
    }
    if (VictimKey) {
        if (!toucherIsVictim) {
            if (RlvRestrictionsMenuAvailable && victimRelayVersion) {
                buttons += [MENU_RLV_RESTRICTIONS];
            }
            buttons += [BUTTON_RLV_RELEASE,BUTTON_RLV_UNSIT];
        }
        if (!toucherIsVictim || victimTimerRunning) {
            buttons += [MENU_RLV_TIMER];
        }
        prompt += PROMPT_RELAY + conditionalString(victimRelayVersion,PROMPT_RELAY_YES,PROMPT_RELAY_NO) + NEW_LINE + getVictimTimerString(VictimKey);
    }
    if (numberOfVictims) {
        buttons += [MENU_RLV_VICTIMS];
    }
    ShowMenu(targetKey,prompt,buttons,MENU_RLV_MAIN);
}

ShowTimerMenu(key targetKey,string path){
    list buttons = TIMER_BUTTONS1;
    if (!~llListFindList(VictimsList,[targetKey])) {
        buttons += TIMER_BUTTONS2;
    }
    ShowMenu(targetKey,getVictimTimerString(VictimKey),buttons,path);
}

// send rlv commands to the RLV relay, usable for common format (not ping)
SendToRlvRelay(key victim,string rlvCommand,string identifier){
    if (!llStringLength(identifier)) {
        identifier = (string)MyUniqueId;
    }
    if (rlvCommand) {
        if (victim) {
            llSay(-1812221819,identifier + "," + (string)victim + "," + StringReplace(rlvCommand,"%MYKEY%",(string)llGetKey()));
        }
    }
}


removeVictimTimer(key avatarUuid){
    integer index = llListFindList(VictimsList,[avatarUuid]);
    if (~index) {
        VictimsList = llListReplaceList(VictimsList,[0],index + 1,index + 1);
    }
    setTimerIfNeeded();
}

addTimeToVictim(key avatarUuid,integer time){
    integer index = llListFindList(VictimsList,[avatarUuid]);
    if (~index) {
        integer thisTime = llGetUnixTime();
        integer oldTime = llList2Integer(VictimsList,index + 1);
        if (oldTime < thisTime) {
            oldTime = thisTime;
        }
        integer newTime = oldTime + time;
        if (newTime < thisTime + 30) {
            newTime = thisTime + 30;
        }
        VictimsList = llListReplaceList(VictimsList,[newTime],index + 1,index + 1);
        if (!TimerRunning) {
            llSetTimerEvent(1.0);
            TimerRunning = 1;
        }
    }
}

setTimerIfNeeded(){
    if ((integer)llListStatistics(2,VictimsList)) {
        if (!TimerRunning) {
            llSetTimerEvent(1.0);
            TimerRunning = 1;
        }
    }
    else  {
        if (TimerRunning) {
            llSetTimerEvent(0.0);
            TimerRunning = 0;
        }
    }
}

string getVictimTimerString(key avatarUuid){
    string returnValue = "Timer: ";
    integer index = llListFindList(VictimsList,[avatarUuid]);
    if (!~index) {
        return returnValue + TIMER_NO_TIME + NEW_LINE;
    }
    integer runningTimeS = llList2Integer(VictimsList,index + 1) - llGetUnixTime();
    if (runningTimeS < 0) {
        return returnValue + TIMER_NO_TIME + NEW_LINE;
    }
    integer runningTimeM = runningTimeS / 60;
    runningTimeS = runningTimeS % 60;
    integer runningTimeH = runningTimeM / 60;
    runningTimeM = runningTimeM % 60;
    integer runningTimeD = runningTimeH / 24;
    runningTimeH = runningTimeH % 24;
    return returnValue + conditionalString(runningTimeD,(string)runningTimeD + "d ","") + llGetSubString("0" + (string)runningTimeH,-2,-1) + ":" + llGetSubString("0" + (string)runningTimeM,-2,-1) + ":" + llGetSubString("0" + (string)runningTimeS,-2,-1);
}

string conditionalString(integer conditon,string valueIfTrue,string valueIfFalse){
    if (conditon) {
        return valueIfTrue;
    }
    return valueIfFalse;
}


string getSelectedVictimPromt(){
    if (VictimKey) {
        return PROMPT_VICTIM + llKey2Name(VictimKey) + NEW_LINE;
    }
    else  {
        return PROMPT_VICTIM + NO_VICTIM + NEW_LINE;
    }
}

integer getVictimRelayVersion(key targetKey){
    integer index = llListFindList(VictimsList,[targetKey]);
    if (~index) {
        return llList2Integer(VictimsList,index + 2);
    }
    return 0;
}
setVictimRelayVersion(key targetKey,integer relayVersion){
    integer index = llListFindList(VictimsList,[targetKey]);
    if (~index) {
        VictimsList = llListReplaceList(VictimsList,[relayVersion],index + 2,index + 2);
    }
}

ReleaseAvatar(key targetKey){
    SendToRlvRelay(targetKey,RLV_COMMAND_RELEASE,"");
    addToFreeVictimsList(targetKey);
    removeFromVictimsList(targetKey);
}

UnsitAvatar(key targetKey){
    SendToRlvRelay(targetKey,"@unsit=y","");
    llSleep(0.75);
    SendToRlvRelay(targetKey,"@unsit=force","");
    llSleep(0.75);
    ReleaseAvatar(targetKey);
}

// --- states

default {

	state_entry() {
        llListen(-1812221819,"",NULL_KEY,"");
        MyUniqueId = llGenerateKey();
        llMessageLinked(-1,-8049,PLUGIN_NAME,"");
        RlvRestrictionsMenuAvailable = 0;
        llMessageLinked(-1,-8048,PLUGIN_NAME_RLV_RESTRICTIONS_MENU,"");
    }


	link_message(integer sender,integer num,string str,key id) {
        if (num == -8048) {
            if (str == PLUGIN_NAME) {
                llMessageLinked(-1,-8049,PLUGIN_NAME,"");
            }
        }
        else  if (num == -8049) {
            if (str == PLUGIN_NAME_RLV_RESTRICTIONS_MENU) {
                RlvRestrictionsMenuAvailable = 1;
            }
        }
        else  if (num == -901) {
            if (id == MyUniqueId) {
                list params = llParseString2List(str,["|"],[]);
                string selection = llList2String(params,1);
                Path = llList2String(params,3);
                NPosetoucherID = (key)llList2String(params,2);
                list pathparts = llParseString2List(Path,[PATH_SEPARATOR],[]);
                integer toucherIsVictim = ~llListFindList(VictimsList,[NPosetoucherID]);
                if (selection == BACKBTN) {
                    selection = llList2String(pathparts,-2);
                    if (Path == MENU_RLV_MAIN) {
                        llMessageLinked(-1,-800,NPosePath,NPosetoucherID);
                        return;
                    }
                    else  if (selection == MENU_RLV_MAIN) {
                        ShowMainMenu(NPosetoucherID);
                        return;
                    }
                    else  {
                        pathparts = llDeleteSubList(pathparts,-2,-1);
                        Path = llDumpList2String(pathparts,PATH_SEPARATOR);
                    }
                }
                if (Path == MENU_RLV_MAIN) {
                    if (selection == MENU_RLV_CAPTURE) {
                        Path += PATH_SEPARATOR + selection;
                        llSensor("",NULL_KEY,1,RLV_captureRange,3.14159265);
                    }
                    else  if (selection == MENU_RLV_RESTRICTIONS) {
                        llMessageLinked(-1,-8010,"showMenu," + (string)NPosetoucherID,"");
                    }
                    else  if (selection == BUTTON_RLV_RELEASE) {
                        ReleaseAvatar(VictimKey);
                        ShowMainMenu(NPosetoucherID);
                    }
                    else  if (selection == BUTTON_RLV_UNSIT) {
                        UnsitAvatar(VictimKey);
                        ShowMainMenu(NPosetoucherID);
                    }
                    else  if (selection == MENU_RLV_TIMER) {
                        ShowTimerMenu(NPosetoucherID,Path + PATH_SEPARATOR + selection);
                    }
                    else  if (selection == MENU_RLV_VICTIMS) {
                        list victimsButtons;
                        integer length = llGetListLength(VictimsList);
                        integer n;
                        for (; n < length; n += 3) {
                            victimsButtons += llGetSubString(llKey2Name(llList2Key(VictimsList,n)),0,15);
                        }
                        ShowMenu(NPosetoucherID,getSelectedVictimPromt() + "Select new active victim.",victimsButtons,Path + PATH_SEPARATOR + selection);
                    }
                    return;
                }
                else  if (Path == MENU_RLV_MAIN + PATH_SEPARATOR + MENU_RLV_CAPTURE) {
                    integer n = llListFindList(SensorList,[selection]);
                    if (~n) {
                        key avatarWorkingOn = llList2Key(SensorList,n + 1);
                        integer counter = llGetNumberOfPrims();
                        while (llGetAgentSize(llGetLinkKey(counter))) {
                            if (avatarWorkingOn == llGetLinkKey(counter)) {
                                if (~llListFindList(VictimsList,[avatarWorkingOn])) {
                                    SendToRlvRelay(avatarWorkingOn,RlvBaseRestrictions,"");
                                    changeCurrentVictim(avatarWorkingOn);
                                    ShowMainMenu(NPosetoucherID);
                                    return;
                                }
                                else  if (~llListFindList(FreeVictimsList,[avatarWorkingOn])) {
                                    removeFromFreeVictimsList(avatarWorkingOn);
                                    addToVictimsList(avatarWorkingOn,RLV_grabTimer);
                                    changeCurrentVictim(avatarWorkingOn);
                                    Path = "";
                                    llMessageLinked(-1,-800,NPosePath,NPosetoucherID);
                                    return;
                                }
                                else  {
                                    ShowMainMenu(NPosetoucherID);
                                    return;
                                }
                            }
                            counter--;
                        }
                        addToGrabList(avatarWorkingOn);
                        SendToRlvRelay(avatarWorkingOn,"@sit:" + (string)llGetKey() + "=force","");
                        Path = "";
                        llMessageLinked(-1,-800,NPosePath,NPosetoucherID);
                    }
                }
                else  if (Path == MENU_RLV_MAIN + PATH_SEPARATOR + MENU_RLV_TIMER) {
                    if (selection == "Reset") {
                        removeVictimTimer(VictimKey);
                    }
                    else  if (llGetSubString(selection,0,0) == "-" || llGetSubString(selection,0,0) == "+") {
                        integer multiplier = 60;
                        string unit = llGetSubString(selection,-1,-1);
                        if (unit == "h") {
                            multiplier = 3600;
                        }
                        else  if (unit == "d") {
                            multiplier = 86400;
                        }
                        else  if (unit == "w") {
                            multiplier = 604800;
                        }
                        addTimeToVictim(VictimKey,multiplier * (integer)llGetSubString(selection,0,-2));
                    }
                    ShowTimerMenu(NPosetoucherID,Path);
                }
                else  if (Path == MENU_RLV_MAIN + PATH_SEPARATOR + MENU_RLV_VICTIMS) {
                    integer length = llGetListLength(VictimsList);
                    integer n;
                    for (; n < length; n += 3) {
                        key avatarWorkingOn = llList2Key(VictimsList,n);
                        if (llGetSubString(llKey2Name(avatarWorkingOn),0,15) == selection) {
                            changeCurrentVictim(avatarWorkingOn);
                        }
                    }
                    ShowMainMenu(NPosetoucherID);
                }
            }
        }
        else  if (num == -8000) {
            list temp = llParseStringKeepNulls(str,[","],[]);
            string cmd = llToLower(llStringTrim(llList2String(temp,0),3));
            key target = (key)StringReplace(llStringTrim(llList2String(temp,1),3),"%VICTIM%",(string)VictimKey);
            list params = llDeleteSubList(temp,0,1);
            if (target) {
            }
            else  {
                target = VictimKey;
            }
            if (cmd == "showmenu") {
                ShowMainMenu(target);
            }
            else  if (cmd == "rlvcommand") {
                SendToRlvRelay(target,StringReplace(llList2String(params,0),"/","|"),"");
            }
            else  if (cmd == "release") {
                ReleaseAvatar(target);
            }
            else  if (cmd == "unsit") {
                UnsitAvatar(target);
            }
            else  if (cmd == "addtime") {
                addTimeToVictim(target,(integer)llList2String(params,0));
            }
            else  if (cmd == "resettime") {
                removeVictimTimer(target);
            }
            else  if (cmd == "read") {
                string rlvRestrictionsNotecard = llList2String(params,0);
                if (llGetInventoryType(rlvRestrictionsNotecard) == 7) {
                    NcQueryId = llGetNotecardLine(rlvRestrictionsNotecard,0);
                }
                else  {
                    llWhisper(0,"Error: rlvRestrictions Notecard " + rlvRestrictionsNotecard + " not found");
                }
            }
        }
        else  if (num == -234) {
            ShowMenu(NPosetoucherID,PROMPT_CAPTURE,llCSV2List(str),MENU_RLV_MAIN + PATH_SEPARATOR + MENU_RLV_CAPTURE);
        }
        else  if (num == -233) {
            llSensor("",NULL_KEY,1,RLV_captureRange,3.14159265);
        }
        else  if (num == -802) {
            NPosePath = str;
            NPosetoucherID = id;
        }
        else  if (num == 35353) {
            FreeNonRlvEnabledSeats = 0;
            FreeRlvEnabledSeats = 0;
            list slotsList = llParseStringKeepNulls(str,["^"],[]);
            integer length = llGetListLength(slotsList);
            integer index;
            for (; index < length; index += 8) {
                key avatarWorkingOn = (key)llList2String(slotsList,index + 4);
                integer seatNumber = index / 8 + 1;
                integer isRlvEnabledSeat = ~llListFindList(RLV_enabledSeats,["*"]) || ~llListFindList(RLV_enabledSeats,[(string)seatNumber]);
                if (avatarWorkingOn) {
                    if (isRlvEnabledSeat) {
                        if (!~llListFindList(VictimsList,[avatarWorkingOn])) {
                            if (~llListFindList(GrabList,[avatarWorkingOn])) {
                                addToVictimsList(avatarWorkingOn,RLV_grabTimer);
                                changeCurrentVictim(avatarWorkingOn);
                            }
                            else  if (~llListFindList(RecaptureList,[avatarWorkingOn])) {
                                addToVictimsList(avatarWorkingOn,llList2Integer(RecaptureList,llListFindList(RecaptureList,[avatarWorkingOn]) + 1));
                                changeCurrentVictim(avatarWorkingOn);
                            }
                            else  if (~llListFindList(FreeVictimsList,[avatarWorkingOn])) {
                            }
                            else  {
                                addToVictimsList(avatarWorkingOn,RLV_trapTimer);
                                changeCurrentVictim(avatarWorkingOn);
                            }
                        }
                    }
                    else  {
                        if (~llListFindList(VictimsList,[avatarWorkingOn]) || ~llListFindList(RecaptureList,[avatarWorkingOn])) {
                            SendToRlvRelay(avatarWorkingOn,RLV_COMMAND_RELEASE,"");
                        }
                        removeFromVictimsList(avatarWorkingOn);
                        removeFromFreeVictimsList(avatarWorkingOn);
                    }
                }
                else  {
                    if (isRlvEnabledSeat) {
                        FreeRlvEnabledSeats++;
                    }
                    else  {
                        FreeNonRlvEnabledSeats++;
                    }
                }
                if (~llListFindList(GrabList,[avatarWorkingOn])) {
                    removeFromGrabList(avatarWorkingOn);
                }
                if (~llListFindList(RecaptureList,[avatarWorkingOn])) {
                    removeFromRecaptureList(avatarWorkingOn);
                }
            }
            length = llGetListLength(FreeVictimsList);
            index = 0;
            for (; index < length; index += 1) {
                key avatarWorkingOn = llList2Key(FreeVictimsList,index);
                if (!~llListFindList(slotsList,[(string)avatarWorkingOn])) {
                    removeFromFreeVictimsList(avatarWorkingOn);
                }
            }
            length = llGetListLength(VictimsList);
            index = 0;
            for (; index < length; index += 3) {
                key avatarWorkingOn = llList2Key(VictimsList,index);
                if (!~llListFindList(slotsList,[(string)avatarWorkingOn])) {
                    if (getVictimRelayVersion(avatarWorkingOn)) {
                        addToRecaptureList(avatarWorkingOn,llList2Integer(VictimsList,index + 1) - llGetUnixTime());
                    }
                    removeFromVictimsList(avatarWorkingOn);
                    index -= 3;
                    length -= 3;
                }
            }
            setTimerIfNeeded();
        }
        else  if (num == -240) {
            list optionsToSet = llParseStringKeepNulls(str,["~"],[]);
            integer length = llGetListLength(optionsToSet);
            integer n;
            for (; n < length; ++n) {
                list optionsItems = llParseString2List(llList2String(optionsToSet,n),["="],[]);
                string optionItem = llToLower(llStringTrim(llList2String(optionsItems,0),3));
                string optionSetting = llStringTrim(llList2String(optionsItems,1),3);
                if (optionItem == "rlv_capturerange") {
                    RLV_captureRange = (integer)optionSetting;
                }
                else  if (optionItem == "rlv_traptimer") {
                    RLV_trapTimer = (integer)optionSetting;
                }
                else  if (optionItem == "rlv_grabtimer") {
                    RLV_grabTimer = (integer)optionSetting;
                }
                else  if (optionItem == "rlv_enabledseats") {
                    RLV_enabledSeats = llParseString2List(optionSetting,["/"],[]);
                }
            }
        }
        else  if (num == 34334) {
            llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit() + ", Leaving " + (string)llGetFreeMemory() + " memory free.");
        }
        else  if (num == -8008) {
            debug(["VictimsList"] + VictimsList);
            debug(["FreeVictimsList"] + FreeVictimsList);
            debug(["GrabList"] + GrabList);
            debug(["RecaptureList"] + RecaptureList);
        }
    }


	changed(integer change) {
        if (change & 128) {
            llResetScript();
        }
        else  if (change & 1) {
            RlvRestrictionsMenuAvailable = 0;
            llMessageLinked(-1,-8048,PLUGIN_NAME_RLV_RESTRICTIONS_MENU,"");
        }
    }


	dataserver(key id,string data) {
        if (id == NcQueryId) {
            RlvBaseRestrictions = StringReplace(data,"/","|");
        }
    }


	listen(integer channel,string name,key id,string message) {
        if (channel == -1812221819) {
            list messageParts = llParseStringKeepNulls(message,[","],[]);
            if ((key)llList2String(messageParts,1) == llGetKey()) {
                string cmd_name = llList2String(messageParts,0);
                string command = llList2String(messageParts,2);
                string reply = llList2String(messageParts,3);
                key senderAvatarId = llGetOwnerKey(id);
                if (command == RLV_COMMAND_VERSION) {
                    setVictimRelayVersion(senderAvatarId,(integer)reply);
                }
                else  if (command == RLV_COMMAND_RELEASE) {
                    if (reply == "ok") {
                        if (~llListFindList(VictimsList,[senderAvatarId])) {
                            addToFreeVictimsList(senderAvatarId);
                        }
                        removeFromVictimsList(senderAvatarId);
                        removeFromGrabList(senderAvatarId);
                        removeFromRecaptureList(senderAvatarId);
                    }
                }
                else  if (command == RLV_COMMAND_PING) {
                    if (cmd_name == command && reply == command) {
                        RecaptureListGarbageCollection();
                        integer index = llListFindList(RecaptureList,[senderAvatarId]);
                        if (~index) {
                            if (FreeRlvEnabledSeats) {
                                RecaptureList = llListReplaceList(RecaptureList,[llGetUnixTime() + 60],index,index + 3 - 1);
                                llSay(-1812221819,RLV_COMMAND_PING + "," + (string)senderAvatarId + "," + RLV_COMMAND_PONG);
                            }
                            else  {
                                removeFromRecaptureList(senderAvatarId);
                            }
                        }
                    }
                }
            }
        }
    }


	timer() {
        integer currentTime = llGetUnixTime();
        integer length = llGetListLength(VictimsList);
        integer index;
        for (; index < length; index += 3) {
            integer time = llList2Integer(VictimsList,index + 1);
            if (time && time <= currentTime) {
                key avatarWorkingOn = llList2Key(VictimsList,index);
                SendToRlvRelay(avatarWorkingOn,RLV_COMMAND_RELEASE,"");
                removeFromVictimsList(avatarWorkingOn);
                addToFreeVictimsList(avatarWorkingOn);
            }
        }
        setTimerIfNeeded();
    }


	sensor(integer num) {
        SensorList = [];
        integer n;
        for (n = 0; n < num; ++n) {
            SensorList += [llGetSubString(llDetectedName(n),0,15),llDetectedKey(n)];
        }
        llMessageLinked(-1,-234,llList2CSV(llList2ListStrided(SensorList,0,-1,2)),NPosetoucherID);
    }


	no_sensor() {
        SensorList = [];
        llMessageLinked(-1,-234,"",NPosetoucherID);
    }
}
