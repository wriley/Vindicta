#define OOP_INFO
#define OOP_WARNING
#define OOP_ERROR
#define OOP_DEBUG
#define OFSTREAM_FILE "ui.rpt"
#include "..\..\OOP_Light\OOP_Light.h"

/*
Class: Notification

Handles operation of stackable notifications.
*/

#define pr private

#define _STATE_MOVING_IN		0
#define _STATE_MOVING_NEXT_POS	1
#define _STATE_IDLE				2

#define _TIME_ANIMATION			0.1
// Vertical offset between positions of all notifications
#define _HEIGHT				0.18
#define _WIDTH				0.5

CLASS("Notification", "")

	VARIABLE("control");		// Group control handle
	VARIABLE("targetPosID");	// Target position ID, integer
	VARIABLE("timeEnd");		// End time when this notification will be destroyed
	VARIABLE("state");			// State of this notification

	STATIC_VARIABLE("objects");		// Array of notification objects
	STATIC_VARIABLE("initDone");	// Bool
	STATIC_VARIABLE("ehID");		// Event handler ID
	STATIC_VARIABLE("queue");		// Queue into which requests to create notifications are pushed

	METHOD("new") {
		params [P_THISOBJECT, P_STRING("_imagePath"), P_DYNAMIC("_category"), P_STRING("_text"), P_STRING("_hint"), P_NUMBER("_duration")];

		pr _group = (findDisplay 46) ctrlCreate ["NOTIFICATION_GROUP", -1];

		OOP_INFO_1("NEW %1", _this);
		OOP_INFO_1("  control: %1", _group);

		// Set text of controls
		pr _iconCtrl = uiNamespace getVariable "vin_not_icon";
		if (_imagePath != "") then {
			_iconCtrl ctrlSetText _imagePath;
		};

		pr _categoryCtrl = uiNamespace getVariable "vin_not_category";
		pr _categoryBGCtrl = uiNamespace getVariable "vin_not_categorybg";
		if(_category isEqualType []) then {
			_category params ["_categoryText", "_categoryFG", "_categoryBG"];
			_categoryCtrl ctrlSetText _categoryText;
			_categoryCtrl ctrlSetTextColor _categoryFG;
			_categoryBGCtrl ctrlSetTextColor _categoryBG;
		} else {
			if(_category != "") then {
				_categoryCtrl ctrlSetText _category;
			} else {
				_categoryCtrl ctrlSetBackgroundColor [0,0,0,0];
				_categoryBGCtrl ctrlSetTextColor [0,0,0,0];
			};
		};

		pr _textCtrl = uiNamespace getVariable "vin_not_text";
		_textCtrl ctrlSetText _text;

		pr _hintCtrl = uiNamespace getVariable "vin_not_hint";
		
		_hintCtrl ctrlSetText _hint;
		if(_hint == "") then {
			pr _hintBG = uiNamespace getVariable "vin_not_hintbg";
			_hintBG ctrlSetBackgroundColor [0,0,0,0.6];
		};

		#ifndef _SQF_VM
		_group ctrlSetPositionX safeZoneX;
		_group ctrlSetPositionY 0.5;
		#endif

		// Set variables
		T_SETV("control", [_group]);
		T_SETV("state", _STATE_IDLE);
		T_SETV("timeEnd", time + _duration);
		T_SETV("targetPosID", 0);
	} ENDMETHOD;

	METHOD("delete") {
		params [P_THISOBJECT];

		OOP_INFO_0("DELETE");

		pr _group = T_GETV("control") select 0;
		ctrlDelete _group;
	} ENDMETHOD;

	// Notification will start moving to position 0 from offscreen
	METHOD("_startMoveIn") {
		params [P_THISOBJECT];

		OOP_INFO_0("START MOVE IN");

		pr _ctrl = T_GETV("control") select 0;
		pr _posxy = CALLSM1("Notification", "_getTargetPosFromID", 0);
		#ifndef _SQF_VM
		// Move to start pos instantly
		_ctrl ctrlSetPositionX ((_posxy#0) - _WIDTH);
		_ctrl ctrlSetPositionY (_posxy#1);
		_ctrl ctrlCommit 0;

		// Move to dest pos with animation
		_ctrl ctrlSetPositionX (_posxy#0);
		_ctrl ctrlSetPositionY (_posxy#1);
		_ctrl ctrlCommit _TIME_ANIMATION;
		#endif

		T_SETV("targetPosID", 0);
		T_SETV("state", _STATE_MOVING_IN);
	} ENDMETHOD;

	// Notification will start moving to a new position
	METHOD("_startMoveToPos") {
		params [P_THISOBJECT, P_NUMBER("_targetPosID")];

		OOP_INFO_1("START MOVE TO POS: %1", _targetPosID);

		pr _posxy = CALLSM1("Notification", "_getTargetPosFromID", _targetPosID);
		pr _ctrl = T_GETV("control") select 0;
		#ifndef _SQF_VM
		_ctrl ctrlSetPositionX (_posxy#0);
		_ctrl ctrlSetPositionY (_posxy#1);
		_ctrl ctrlCommit _TIME_ANIMATION;
		#endif
		T_SETV("targetPosID", _targetPosID);
		T_SETV("state", _STATE_MOVING_NEXT_POS);
	} ENDMETHOD;

	// Returns [x, y] of the position with given ID
	STATIC_METHOD("_getTargetPosFromID") {
		params [P_THISCLASS, P_NUMBER("_targetID")];

		// Sanity check
		if (_targetID < 0) then {_targetID = 0};

		pr _posx = safeZoneX;
		pr _posY = safeZoneY + 0.2*safeZoneH + _targetID*_HEIGHT;

		[_posx, _posy]
	} ENDMETHOD;

	/*
	Method: (static)createNotification
	Use that to create a notification. Don't call the constructor on your own.

	Parameters: (string)_category, (string)_text, (string)_hint, (number)_duration (in seconds)
	*/
	STATIC_METHOD("createNotification") {
		params [P_THISCLASS, P_STRING("_imagePath"), P_DYNAMIC("_category"), P_STRING("_text"), P_DYNAMIC("_hint"), P_NUMBER("_duration"), P_STRING("_sound")];

		// Bail if not initialized
		if (isNil {GETSV(_thisClass, "initDone")}) exitWith {
			OOP_ERROR_0("Notification class not initialized!");
		};

		// Sanity check
		if (_duration < 0) then { _duration = 1; };

		// Add to the queue
		// The notification will be created when all previous notifications has been pushed in
		pr _queue = GETSV("Notification", "queue");
		pr _args = [_imagePath, _category, _text, _hint, _duration, _sound];
		_queue pushBack _args;
	} ENDMETHOD;

	STATIC_METHOD("onEachFrame") {
		params [P_THISCLASS];

		pr _objects = GETSV(_thisClass, "objects");

		// Check for notifications which can be deleted
		if ((count _objects) > 0) then {
			pr _i = 0;
			pr _deleted = false;
			while {_i < count _objects} do {
				pr _not = _objects#_i;
				if (time > GETV(_not, "timeEnd")) then {	// Is the time over for this notification?
					OOP_INFO_1("Deleting notification: %1", _not);
					DELETE(_not);
					_objects deleteAt _i;
					_deleted = true;
				} else {
					// Update state of this notification
					if (GETV(_not, "state") != _STATE_IDLE) then {
						// This notification is still moving somewhere
						pr _ctrl = GETV(_not, "control") select 0;
						//OOP_INFO_2(" Notification %1 position %2", _not, ctrlPosition _ctrl);
						if (ctrlCommitted _ctrl) then {
							SETV(_not, "state", _STATE_IDLE);
						};
					};
					_i = _i + 1;
				};
			};

			// If we have deleted something, recalculate the target positions, reapply the animations
			if (_deleted) then {
				pr _count = count _objects;
				for "_i" from 0 to (_count -1) do {
					pr _not = _objects#_i;
					if ((GETV(_not, "targetPosID")) != (_count - 1 - _i)) then {
						CALLM1(_not, "_startMoveToPos", _count - 1 - _i);
					};
				};
			};
		};

		// Check if we can add more notifications from the queue
		pr _queue = GETSV(_thisClass, "queue");
		if ((count _queue) > 0) then {
			//OOP_INFO_0("Queue not empty!");

			// We can push only one at a time anyway
			// We can add new notification if the topmost one has reached its destination pos
			pr _canAdd = false;
			pr _count = count _objects;
			if (_count > 0) then {

				//OOP_INFO_0("There are existing notifications!");

				pr _topmostNot = _objects select ((count _objects) - 1);
				//[_topmostNot] call OOP_dumpAllVariables;
				//OOP_INFO_2("  Topmost not %1 state: %2", _topmostNot, GETV(_topmostNot, "state") );
				if (GETV(_topmostNot, "state") == _STATE_IDLE && GETV(_topmostNot, "targetPosID") == 1) then {
					// The topmost notification has freed up space for the next notification, we can add a new notification
					_canAdd = true;
				} else {
					// Move all other notifications down by one cell
					if (GETV(_topmostNot, "targetPosID") != 1) then {
						{
							CALLM1(_x, "_startMoveToPos", _count - _forEachIndex); // Last added notification moves to pos 1
						} forEach _objects;
					};
				};
			} else {
				_canAdd = true;
			};

			if (_canAdd) then {
				pr _args = _queue select 0;

				// Play sound if needed
				pr _sound = _args#5;
				if (_sound != "") then {
					OOP_INFO_1("PLAYING SOUND: %1", _sound);
					playSound _sound;
				};

				// Create the object
				OOP_INFO_1("CREATING NOTIFICATION: %1", _args);
				pr _not = NEW("Notification", _args);
				CALLM0(_not, "_startMoveIn");
				_objects pushBack _not;

				// Delete data from the queue
				_queue deleteAt 0;
			};
		};

	} ENDMETHOD;

	/*
	Method: (static) staticInit
	Call it once to initialize the system. After that you can call createNotification.

	Parameters: none
	*/
	STATIC_METHOD("staticInit") {
		params [P_THISCLASS];

		// Bail if initialized already
		if (!isNil {GETSV(_thisClass, "initDone")}) exitWith {
			OOP_ERROR_0("Notification class already initialized!");
		};

		// Make sure we clear up previously created notifications, since they stay here on mission restarts
		pr _allControls = allControls (findDisplay 46);
		pr _prevControls = _allControls select {(ctrlClassName _x) == "NOTIFICATION_GROUP"};
		{
			ctrlDelete _x;
		} forEach _prevControls;

		// Initialize static variables
		SETSV(_thisClass, "initDone", true);
		SETSV(_thisClass, "objects", []);
		SETSV(_thisClass, "queue", []);

		// Add on each frame handler
		pr _ehid = addMissionEventHandler ["EachFrame", {CALLSM0("Notification", "onEachFrame")}];
		SETSV(_thisClass, "ehID", _ehid);
	} ENDMETHOD;

ENDCLASS;