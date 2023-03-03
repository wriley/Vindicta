#include "..\common.h"

// Client side only
if (!hasInterface) exitWith {};
params ["_target", "_caller", "_actionId", "_arguments"];

[[_target, _actionId], {
	if (!hasInterface) exitWith {};
	params ["_target", "_actionId"];
	_target removeAction _actionId;
}] remoteExec ["call", 0, false];


// This is sent to server
// TODO: need to update this script to use new recruitment system
[[_caller, _target], {
	params ["_caller", "_target"];
	
	private _maybe = random 2;
	private _sentence = "";
	if (_maybe > 1) then {
		CALLM1(SideStatWest, "incrementHumanResourcesBy", 1);
		gSideStatWestHR = CALLM0(SideStatWest, "getHumanResources");
		publicVariable "gSideStatWestHR";

		_sentence = "OK, I'm in";
	} else {
		_sentence = "Hell no!";
	};
	[_target, _sentence] call vin_fnc_dialogue_createSentence;
	//[_target, _sentence, _caller, false] remoteExecCall ["vin_fnc_dialogue_createSentence", owner _caller];

}] remoteExec ["spawn", 2, false];
