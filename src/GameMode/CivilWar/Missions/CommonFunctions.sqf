#include "..\common.hpp"

// Send a unit running away into the distance, then delete it when it gets there
vin_fnc_CivieRunAway = {
	// Cleaning old orders by moving group
	private _oldGrp = group _this;
	private _grp = createGroup [west, true];
	[_this] joinSilent _grp;
	deleteGroup _oldGrp;
	// WAYPOINT - run away!
	// Run far away!
	private _wp = _grp addWaypoint [[position _this, 1000, 2000] call BIS_fnc_findSafePos, 0];
	_wp setWaypointType "MOVE";
	_wp setWaypointBehaviour "AWARE";
	_wp setWaypointSpeed "NORMAL";
	_wp setWaypointStatements ["true", "deleteVehicle this;"];
};

vin_fnc_dialogue_createSentence = {
	params ["_tgt", "_msg"];
	private _sentence = "";
	private _type = typeName _msg;
	if(_type == "ARRAY")then{
		_sentence = selectRandom _msg;
	}else{
		_sentence = _msg;
	};
	CALLSM3("Dialogue", "objectSaySentence", NULL_OBJECT, _tgt, _sentence);
};