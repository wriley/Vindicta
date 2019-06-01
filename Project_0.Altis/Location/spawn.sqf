#include "..\OOP_Light\OOP_Light.h"
#include "..\MessageReceiver\MessageReceiver.hpp"
// Class: Location
/*
Method: spawn
Spawns Location.

Threading: should be called through postMethod (see <MessageReceiverEx>)

Returns: nil
*/

params [P_THISOBJECT];


OOP_INFO_0("SPAWN");

ASSERT_THREAD(_thisObject);


T_PRVAR(spawned);

if (_spawned) exitWith {
	OOP_ERROR_0("Already spawned");
	DUMP_CALLSTACK;
};

// Set spawned flag
T_SETV("spawned", true);


//spawn civilians
T_GETV("cpModule") call CivPresence_fnc_spawn;

//force immediate spawn update of the garrison
{
	CALLM2(_x, "postMethodAsync", "updateSpawnState", []);
} forEach T_GETV("garrisons");

CALLM(gGameMode, "locationSpawned", [_thisObject]);