#define OOP_INFO
#define OOP_WARNING
#include "..\common.h"
#include "..\Message\Message.hpp"
#include "Location.hpp"
#include "..\MessageTypes.hpp"
#include "..\Group\Group.hpp"
#include "..\Garrison\Garrison.hpp"

#ifndef RELEASE_BUILD
#define DEBUG_LOCATION_MARKERS
#endif

#ifdef _SQF_VM
#undef DEBUG_LOCATION_MARKERS
#endif

/*
Class: Location
Location has garrisons at a static place and spawns units.

Author: Sparker 28.07.2018
*/
#ifdef DEBUG_LOCATION_MARKERS
#define UPDATE_DEBUG_MARKER T_CALLM("updateMarker", [])
#else
#define UPDATE_DEBUG_MARKER
#endif

FIX_LINE_NUMBERS()

#define pr private

#define OOP_CLASS_NAME Location
CLASS("Location", ["MessageReceiverEx" ARG "Storable"])

	/* save */ 	VARIABLE_ATTR("type", [ATTR_SAVE]);						// String, location type
	/* save */ 	VARIABLE_ATTR("name", [ATTR_SAVE]);						// String, location name
	/* save */ 	VARIABLE_ATTR("children", [ATTR_SAVE]);					// Children of this location if it has any (e.g. police stations are children of cities)
	/* save */ 	VARIABLE_ATTR("parent", [ATTR_SAVE]); 					// Parent of the Location if it has one (e.g. parent of police station is its containing city location)
	/* save */ 	VARIABLE_ATTR("garrisons", [ATTR_SAVE]);				// Array of garrisons registered here
	/* save */ 	VARIABLE_ATTR("boundingRadius", [ATTR_SAVE]); 			// _radius for a circle border, sqrt(a^2 + b^2) for a rectangular border
	/* save */ 	VARIABLE_ATTR("border", [ATTR_SAVE]); 					// [center, a, b, angle, isRectangle, c]
	/* save */ 	VARIABLE_ATTR("borderPatrolWaypoints", [ATTR_SAVE]);	// Array for patrol waypoints along the border
				VARIABLE("patrolRoutes");								// Patrol routes read from map
	/* save */ 	VARIABLE_ATTR("useParentPatrolWaypoints", [ATTR_SAVE]);	// If true then use the parents patrol waypoints instead
	/* save */ 	VARIABLE_ATTR("allowedAreas", [ATTR_SAVE]); 			// Array with allowed areas
	/* save */ 	VARIABLE_ATTR("pos", [ATTR_SAVE]); 						// Position of this location
				VARIABLE("spawnPosTypes"); 								// Array with spawn positions types
				VARIABLE("spawned"); 									// Is this location spawned or not
				VARIABLE("timer"); 										// Timer object which generates messages for this location
				VARIABLE("capacityInf"); 								// Infantry capacity
				VARIABLE("capacityHeli"); 								// Helicopter capacity
	/* save */	VARIABLE_ATTR("capacityCiv", [ATTR_SAVE]); 				// Civilian capacity
	/* save */	VARIABLE_ATTR("isBuilt", [ATTR_SAVE]); 					// true if this location has been build
				VARIABLE_ATTR("buildProgress", [ATTR_SAVE]);			// How much of the location is built from 0 to 1
				VARIABLE("lastBuildProgressTime");						// Time build progress was last updated
				VARIABLE("buildableObjects");							// Objects that will be constructed
	/* save */	VARIABLE_ATTR("gameModeData", [ATTR_SAVE]);				// Custom object that the game mode can use to store info about this location
				VARIABLE("hasPlayers"); 								// Bool, means that there are players at this location, updated at each process call
				VARIABLE("hasPlayerSides"); 							// Array of sides of players at this location
				VARIABLE("buildingsOpen"); 								// Handles of buildings which can be entered (have buildingPos)
				VARIABLE("objects"); 									// Handles of objects which can't be entered and other objects
				VARIABLE("ambientAnimObjects"); 						// Handles of objects representing ambient activities that relaxing units can do
				VARIABLE("targetRangeObjects"); 						// Handles of objects representing target range targets that units can shoot at
				VARIABLE("helipads"); 									// Handles of helipads
	/* save */	VARIABLE_ATTR("respawnSides", [ATTR_SAVE]); 			// Sides for which player respawn is enabled
				VARIABLE_ATTR("hasRadio", [ATTR_SAVE]); 				// Bool, means that this location has a radio
	/* save */	VARIABLE_ATTR("wasOccupied", [ATTR_SAVE]); 				// Bool, false at start but sets to true when garrisons are attached here
	/* save */	VARIABLE_ATTR("sideCreated", [ATTR_SAVE]);				// Side which has created this location dynamically. CIVILIAN if it was here on the map.

	// Variables which are set up only for saving process
	/* save */	VARIABLE_ATTR("savedObjects", [ATTR_SAVE]);				// Array of [className, posWorld, vectorDir, vectorUp] of objects
	/* save */	VARIABLE_ATTR("intel", [ATTR_SAVE]);					// Array of intel items civilians know about.

				VARIABLE("playerRespawnPos");						// Position for player to respawn
				VARIABLE("alarmDisabled");							// If the player disabled the alarm
				VARIABLE("helperObject");							// An arma object placed at position of this location, for proximity checks.
	STATIC_VARIABLE("all");

	// |                              N E W
	/*
	Method: new

	Parameters: _pos

	_pos - position of this location
	*/
	METHOD(new)
		params [P_THISOBJECT, ["_pos", [0,0,0], [[]]], ["_createdBySide", CIVILIAN, [CIVILIAN]] ];

		// Check existance of neccessary global objects
		if (isNil "gTimerServiceMain") exitWith {"[MessageLoop] Error: global timer service doesn't exist!";};
		if (isNil "gMessageLoopMain") exitWith {"[MessageLoop] Error: global location message loop doesn't exist!";};
		if (isNil "gLUAP") exitWith {"[MessageLoop] Error: global location unit array provider doesn't exist!";};

		T_SETV_PUBLIC("name", "noname");
		T_SETV_PUBLIC("garrisons", []);
		T_SETV_PUBLIC("boundingRadius", 0);
		T_SETV_PUBLIC("border", []);
		T_SETV("borderPatrolWaypoints", []);
		T_SETV("patrolRoutes", []);
		T_SETV("useParentPatrolWaypoints", false);
		T_SETV_PUBLIC("pos", _pos);
		T_SETV("spawnPosTypes", []);
		T_SETV("spawned", false);
		T_SETV("capacityInf", 0);
		T_SETV_PUBLIC("capacityInf", 0);
		T_SETV("capacityHeli", 0);
		T_SETV_PUBLIC("capacityHeli", 0);
		T_SETV("capacityCiv", 0);
		T_SETV_PUBLIC("isBuilt", false);
		T_SETV("lastBuildProgressTime", 0);
		T_SETV_PUBLIC("buildProgress", 0);
		T_SETV("buildableObjects", []);
		T_SETV("children", []);
		T_SETV("parent", NULL_OBJECT);
		T_SETV_PUBLIC("parent", NULL_OBJECT);
		T_SETV_PUBLIC("gameModeData", NULL_OBJECT);
		T_SETV("hasPlayers", false);
		T_SETV("hasPlayerSides", []);

		T_SETV("buildingsOpen", []);
		T_SETV("objects", []);
		T_SETV("ambientAnimObjects", []);
		T_SETV("targetRangeObjects", []);
		T_SETV("helipads", []);

		T_SETV_PUBLIC("respawnSides", []);
		T_SETV_PUBLIC("playerRespawnPos", _pos);

		T_SETV_PUBLIC("allowedAreas", []);
		T_SETV_PUBLIC("type", LOCATION_TYPE_UNKNOWN);

		T_SETV("hasRadio", false);

		T_SETV_PUBLIC("wasOccupied", false);
		T_SETV("wasOccupied", false);

		T_SETV("sideCreated", _createdBySide);

		// Setup basic border
		T_CALLM1("setBorderCircle", 20);
		
		T_SETV("timer", NULL_OBJECT);

		T_SETV_PUBLIC("alarmDisabled", false);

		//Push the new object into the array with all locations
		private _allArray = GETSV("Location", "all");
		_allArray pushBack _thisObject;
		PUBLIC_STATIC_VAR("Location", "all");

		// Register at game mode so that it gets saved
		if (!isNil {gGameMode}) then {
			CALLM1(gGameMode, "registerLocation", _thisObject);
		};

		// Init helper object
		T_CALLM0("_initHelperObject");

		T_SETV("intel", []);

		UPDATE_DEBUG_MARKER;
	ENDMETHOD;

	// Initializes helper object
	METHOD(_initHelperObject)
		params [P_THISOBJECT];
		pr _pos = T_GETV("pos");
		
		pr _args = [_thisObject, _pos];
		#ifndef _SQF_VM
		REMOTE_EXEC_CALL_STATIC_METHOD("Location", "_initHelperObjectOnClient", _args, ON_ALL, _thisObject + "_initHelperObj");
		#endif

	ENDMETHOD;

	// This is executed on JIP too
	STATIC_METHOD(_initHelperObjectOnClient)
		params [P_THISCLASS, P_OOP_OBJECT("_loc"), P_ARRAY("_pos")];

		#ifndef _SQF_VM
		pr _obj = createLocation ["vin_location", _pos, 0, 0];
		#else
		pr _obj = "vin_location" createVehicle _pos;
		#endif
		_obj setVariable ["location", _loc];
		SETV(_loc, "helperObject", _obj);

		OOP_INFO_1("initHelperObject: %1", _obj);

	ENDMETHOD;

	// |                 S E T   D E B U G   N A M E
	/*
	Method: setName
	Sets debug name of this MessageLoop.

	Parameters: _name

	_name - String

	Returns: nil
	*/
	public METHOD(setName)
		params [P_THISOBJECT, P_STRING("_name")];
		T_SETV_PUBLIC("name", _name);
	ENDMETHOD;

	public METHOD(setCapacityInf)
		params [P_THISOBJECT, P_NUMBER("_capacityInf")];
		T_SETV("capacityInf", _capacityInf);
		T_SETV_PUBLIC("capacityInf", _capacityInf);
	ENDMETHOD;

	public METHOD(setCapacityCiv)
		params [P_THISOBJECT, P_NUMBER("_capacityCiv")];
		T_SETV("capacityCiv", _capacityCiv);
	ENDMETHOD;

	/*
	Method: addChild
	Adds a child location to this location (also sets the childs parent).
	Child must not belong to another location already.
	*/
	public METHOD(addChild)
		params [P_THISOBJECT, P_OOP_OBJECT("_childLocation")];
		ASSERT_OBJECT_CLASS(_childLocation, "Location");
		ASSERT_MSG(IS_NULL_OBJECT(GETV(_childLocation, "parent")), "Location is already assigned to another parent");
		T_GETV("children") pushBack _childLocation;
		//SETV(_childLocation, "parent", _thisObject);
		SET_VAR_PUBLIC(_childLocation, "parent", _thisObject);
		nil
	ENDMETHOD;

	/*
	Method: findAllObjects
	Finds all relevant objects in the locations area, and records them.
	This includes allowed areas, vehicle spawn points and buildings
	*/
	public METHOD(findAllObjects)
		params [P_THISOBJECT];

		OOP_DEBUG_1("findAllObjects for %1", T_GETV("name"));

		// Setup marker allowed areas
		ASP_SCOPE_START(addAllowedAreas);
		private _allowedAreas = (allMapMarkers select {(tolower _x) find "allowedarea" == 0}) select {
			T_CALLM1("isInBorder", markerPos _x)
		};
		{
			private _pos = markerPos _x;
			(markerSize _x) params ["_a", "_b"];
			private _dir = markerDir _x;
			
			//#ifdef RELEASE_BUILD
			_x setMarkerAlpha 0;
			deleteMarker _x;
			//#endif
			
			OOP_INFO_1("Adding allowed area: %1", _x);
			T_CALLM4("addAllowedArea", _pos, _a, _b, _dir);
		} forEach _allowedAreas;
		ASP_SCOPE_END(addAllowedAreas);

		// Setup location's spawn positions
		private _radius = T_GETV("boundingRadius");
		private _locPos = T_GETV("pos");
		private _locType = T_GETV("type");

		#ifndef _SQF_VM
		ASP_SCOPE_START(findNearestObjects);

		// Lots of objects from the map have typeOf "" unfortunately (thanks to arma)
		// But we must scan them anyway
		
		// Lots of useful objects plus lots of junk (trees)
		private _terrainObjects = nearestTerrainObjects [_locPos, [], _radius, false, true]; // select { typeOf _x != "" };
		// Lots of useful objects plus those placed in the editor
		private _nearObjects = _locPos nearObjects _radius;
		ASP_SCOPE_END(findNearestObjects);

		OOP_INFO_1("findAllObjects: scanning %1 objects", count _nearObjects);

		#else
		private _nearObjects = [];
		private _terrainObjects = [];
		#endif
		FIX_LINE_NUMBERS()

		// hashmap to quickly mark those objects which have been processed
		// We can't set variables on terrain objects
		#ifndef _SQF_VM
		private _processedObjects = [false] call CBA_fnc_createNamespace;
		#else
		private _processedObjects = "dummy" createVehicle [0,0,0];
		#endif

		ASP_SCOPE_START(scanFoundObjects);
		{

			if (!(_processedObjects getVariable [str _x, false])) then { // Don't process same object twice
				if ((typeOf _x) != "" || { ! isNil {gObjectAnimMarkers getVariable ((getModelInfo _x) select 0);} }) then { // Ignore trees, there are so many of them

					private _type = typeOf _x;
					private _modelName = (getModelInfo _x) select 0;
					private _object = _x;
					ASP_SCOPE_START(scanObject_x);

					if(T_CALLM1("isInBorder", _object)) then
					{
						

						// Disable object simulation if needed
						if ((_type != "") && {(getText (configFile >> "cfgVehicles" >> _type >> "simulation")) != "house" }) then {
							_object enableSimulationGlobal false;
						};

						switch true do {
							// Process buildings, objects with anim markers, and shooting targets
							case (_type isKindOf "House" || { ! isNil {gObjectAnimMarkers getVariable _modelName;} } || { _type in gShootingTargetTypes }): {
								T_CALLM2("addObject", _object, _object in _terrainObjects);
								OOP_DEBUG_1("findAllObjects for %1: found house", T_GETV("name"));
							};
							// A truck's position defined the position for tracked and wheeled vehicles
							case (_type == "b_truck_01_transport_f"): {
								private _args = [T_PL_tracked_wheeled, [GROUP_TYPE_INF, GROUP_TYPE_VEH], getPosATL _object, direction _object, objNull];
								T_CALLM("addSpawnPos", _args);
								deleteVehicle _object;
								OOP_DEBUG_1("findAllObjects for %1: found vic spawn marker", T_GETV("name"));
							};
							// A mortar's position defines the position for mortars
							case (_type == "b_mortar_01_f"): {
								private _args = [[T_VEH, T_VEH_stat_mortar_light], [GROUP_TYPE_INF, GROUP_TYPE_STATIC], getPosATL _object, direction _object, objNull];
								T_CALLM("addSpawnPos", _args);
								deleteVehicle _object;
								OOP_DEBUG_1("findAllObjects for %1: found mortar spawn marker", T_GETV("name"));
							};
							// A low HMG defines a position for low HMGs and low GMGs
							case (_type == "b_hmg_01_f"): {
								private _args = [T_PL_HMG_GMG_low, [GROUP_TYPE_INF, GROUP_TYPE_STATIC], getPosATL _object, direction _object, objNull];
								T_CALLM("addSpawnPos", _args);
								deleteVehicle _object;
								OOP_DEBUG_1("findAllObjects for %1: found low hmg/gpg spawn marker", T_GETV("name"));
							};
							// A high HMG defines a position for high HMGs and high GMGs
							case (_type == "b_hmg_01_high_f"): {
								private _args = [T_PL_HMG_GMG_high, [GROUP_TYPE_INF, GROUP_TYPE_STATIC], getPosATL _object, direction _object, objNull];
								T_CALLM("addSpawnPos", _args);
								deleteVehicle _object;
								OOP_DEBUG_1("findAllObjects for %1: found high hmg/gpg spawn marker", T_GETV("name"));
							};
							// A cargo container defines a position for cargo boxes
							case (_type == "b_slingload_01_cargo_f"): {
								private _args = [T_PL_cargo, [GROUP_TYPE_INF], getPosATL _object, direction _object, objNull];
								T_CALLM("addSpawnPos", _args);
								deleteVehicle _object;
								OOP_DEBUG_1("findAllObjects for %1: found cargo box spawn marker", T_GETV("name"));
							};
							// Patrol routs
							case (_type == "i_soldier_f"): {
								T_CALLM1("addPatrolRoute", _object);
								OOP_DEBUG_1("findAllObjects for %1: found patrol route", T_GETV("name"));
								deleteVehicle _object;
							};
							// Ambient anims
							case (_type == "i_soldier_ar_f"): {
								private _anims = (_object getVariable ["enh_ambientanimations_anims", []]) apply { toLower _x };
								private _ambientAnimIdx = gAmbientAnimSets findIf { _x#1 isEqualTo _anims };
								if(_ambientAnimIdx != NOT_FOUND) then {
									private _anim = gAmbientAnimSets#_ambientAnimIdx#0;
									private _mrk = "Sign_Pointer_Cyan_F" createVehicleLocal getPos _object;
									_mrk setDir getDir _object;
									_mrk setVariable ["vin_defaultAnims", [_anim]];
									_mrk hideObjectGlobal true;
								};
								deleteVehicle _object;
								OOP_DEBUG_1("findAllObjects for %1: found predefined solider position", T_GETV("name"));
							};
							// Helipads
							case (_type in location_bt_helipad): {
								T_CALLM2("addObject", _object, _object in _terrainObjects);
								OOP_DEBUG_1("findAllObjects for %1: found helipad", T_GETV("name"));
							};
							// Spawn positions for non-houses
							case (_type call location_fnc_objectClassHasSpawnPositions): {
								T_CALLM2("addObject", _object, _object in _terrainObjects);
								OOP_DEBUG_1("findAllObjects for %1: found predefined spawn positions for non-house", T_GETV("name"));
							};
							
							// A boat defines a position for boat spawn positions
							// Only relevant for cities
							case (_type == "C_Boat_Civil_01_F" && _locType == LOCATION_TYPE_CITY): {
								private _args = [[[T_VEH, T_VEH_boat_unarmed]], [GROUP_TYPE_INF, GROUP_TYPE_VEH], getPosATL _object, direction _object, objNull];
								T_CALLM("addSpawnPos", _args);
								deleteVehicle _object;
								OOP_DEBUG_1("findAllObjects for %1: found city boat spawn position", T_GETV("name"));
							};
							
						};
					};
				};

				// Mark object as processed
				_processedObjects setVariable [str _x, true];
			};

		} forEach (_nearObjects + _terrainObjects);
		ASP_SCOPE_END(scanFoundObjects);

		#ifndef _SQF_VM
		deleteLocation _processedObjects;
		#endif

		T_CALLM0("findBuildables");
	ENDMETHOD;

	/*
	Method: addObject
	Adds an object to this location (building or another object)
	
	Arguments: _hObject
	*/
	public METHOD(addObject)
		params [P_THISOBJECT, P_OBJECT("_hObject"), P_BOOL("_isTerrainObject")];

		private _type = typeOf _hObject;

		//OOP_INFO_1("ADD OBJECT: %1", _hObject);
		private _countBP = count (_hObject buildingPos -1);
		private _alreadyRegistered = if (_countBP > 0) then {
			private _array = T_GETV("buildingsOpen");
			if(_hObject in _array) then {
				true
			} else {
				_array pushBackUnique _hObject;
				// This variable records which positions in the building are occupied by a unit (it is modified in unit Actions)
				_hObject setVariable ["vin_occupied_positions", []];
				T_CALLM1("addSpawnPosFromBuilding", _hObject);
				false 
			}
		} else {
			private _array = T_GETV("objects");
			if(_hObject in _array) then {
				true
			} else {
				_array pushBackUnique _hObject;
				T_CALLM1("addSpawnPosFromBuilding", _hObject);
				false
			}
		};
		if(_alreadyRegistered) exitWith {};

		// Check how it affects the location's infantry capacity
		private _modelName = (getModelInfo _hObject) select 0;
		private _index = location_b_capacity findIf {_type in _x#0};
		private _cap = 0;
		if (_index != -1) then {
			_cap = location_b_capacity#_index#1;
		} else {
			_cap = _countBP;
		};

		// Increase infantry capacity
		if (_cap > 0) then {
			private _capacityInf = T_GETV("capacityInf") + _cap;
			//_capacityInf = _capacityInf min CALLSM1("Location", "getCapacityInfForType", T_GETV("type"));
			T_SETV("capacityInf", _capacityInf);
			T_SETV_PUBLIC("capacityInf", _capacityInf);
		};

		// Check if it enabled radio functionality for the location
		private _index = location_bt_radio find _type;
		if (_index != -1) then {
			T_SETV("hasRadio", _index != -1);
			// Init radio object actions
			CALLSM1("Location", "initRadioObject", _hObject);
		};

		// Check if it is a medical object that requires initialization
		if (_type in location_bt_medical) then {
			CALLSM1("Location", "initMedicalObject", _hObject);
		};

		if (_type in location_bt_repair) then {
			CALLSM1("Location", "initRepairObject", _hObject);
		};

		// Check for helipad
		if(_type in location_bt_helipad) then {
			T_GETV("helipads") pushBack _hObject;
			private _args = [T_PL_helicopters, [GROUP_TYPE_INF, GROUP_TYPE_VEH], getPosATL _hObject, direction _hObject, _hObject];
			T_CALLM("addSpawnPos", _args);
			//T_GETV("spawnPosHeli") pushBackUnique position _hObject;
		};

		// Process it for ambient anims
		private _animMarkers = gObjectAnimMarkers getVariable _modelName;
		if(! isNil "_animMarkers") then {
			_animMarkers params ["_t", "_animMarkers"];
			private _ambientAnimObjects = T_GETV("ambientAnimObjects");
			{
				_x params ["_relPos", "_relDir", "_anim"]; 
				private _mrk = "Sign_Pointer_Cyan_F" createVehicleLocal [0,0,0];
				if(_isTerrainObject) then {
					_mrk setPos (_hObject modelToWorldVisual _relPos);
					_mrk setDir (getDir _hObject + _relDir);
				} else {
					_mrk attachTo [_hObject, _relPos];
					_mrk setDir _relDir;
					_mrk attachTo [_hObject, _relPos];
				};
				_mrk setVariable ["vin_parent", _hObject];
				_mrk setVariable ["vin_anim", _anim];
				_mrk hideObjectGlobal true;
				_ambientAnimObjects pushBack _mrk;
			} forEach _animMarkers;

			// Add marker for debug
			/*
			_mrkName = format ["%1_%2", _thisObject, str _hObject];
			pr _mrk = createMarkerLocal [_mrkName, (getPos _hObject)];
			_mrk setMarkerShapeLocal "ICON";
			_mrk setMarkerBrushLocal "SolidFull";
			_mrk setMarkerColorLocal "ColorRed";
			_mrk setMarkerAlphaLocal 1.0;
			_mrk setMarkerTypeLocal "mil_dot";
			//_mrk setMarkerSizeLocal [0.3, 0.3];
			_mrk setMarkerTextLocal (str _hObject);
			*/
		};

		// Process target range objects
		if(_type in gShootingTargetTypes) then {
			if(isNil {_hObject getVariable "vin_target_range"}) then {
				_hObject setVariable ["vin_target_range", [-25, 0]];
			};
		};

		if(!isNil { _hObject getVariable "vin_target_range" }) then {
			T_GETV("targetRangeObjects") pushBackUnique _hObject;
		};
	ENDMETHOD;

	/* private */ METHOD(addPatrolRoute)
		params [P_THISOBJECT, P_OBJECT("_hObject")];
		private _waypoints = waypoints group _hObject apply { getWPPos _x };

		private _patrolRoutes = T_GETV("patrolRoutes");
		_patrolRoutes pushBack _waypoints;

		group _hObject deleteGroupWhenEmpty true;
	ENDMETHOD;

	// Adds an intel object
	/* public */ METHOD(addIntel)
		params [P_THISOBJECT, P_OOP_OBJECT("_intel")];
		OOP_INFO_1("addIntel: %1", _intel);
		T_GETV("intel") pushBackUnique _intel;
	ENDMETHOD;

	METHOD(findBuildables)
		params [P_THISOBJECT];

		private _radius = T_GETV("boundingRadius");
		private _locPos = T_GETV("pos");

		OOP_INFO_3("Finding buildables for %1 with radius %2 at %3", T_GETV("name"), _radius, _locPos);

		private _objects = T_GETV("objects");
		private _buildables = [];
		private _sortableArray = [];
#ifndef _SQF_VM
		/*
		private _nearbyObjects = [];
		{
			_nearbyObjects pushBackUnique _x;
		} foreach (nearestTerrainObjects [_locPos, [], _radius] + nearestObjects [_locPos, [], _radius]);
		*/
		private _nearbyObjects = _locPos nearObjects _radius;

		{
			private _object = _x;
			private _modelName = (getModelInfo _object)#0;
			if(!(_object in _objects) && {T_CALLM1("isInBorder", _object)} && {_modelName in gMilitaryBuildingModels || (typeOf _x) in gMilitaryBuildingTypes}) then
			{
				private _pos = getPosATL _object;
				private _zPos = 0 max _pos#2;
				// Alias height at 1/3 m
				_zPos = (floor (_zPos * 3)) / 3;
				// Volume is our second critera, we build smaller things first
				(boundingBox _object) params ["_bbMin", "_bbMax"];
				private _vol = (_bbMax#0 - _bbMin#0) * (_bbMax#1 - _bbMin#1) * (_bbMax#2 - _bbMin#2);
				// Make a definitive sorting hash so we don't get non unstable sorting behavior
				private _posHash = (_pos#0 mod 5 + _pos#1 mod 5);
				// Sort key + index (we need to do this as we can't sort an array with actual objects in it)
				_sortableArray pushBack [_zPos, _vol, _posHash, _modelName, count _buildables];
				// Object
				_buildables pushBack _object;
			};
		} foreach _nearbyObjects;
#endif
		FIX_LINE_NUMBERS();

		// Sort objects by height above ground (to nearest 20cm) so we can build from the bottom up
		_sortableArray sort ASCENDING;
		private _sortedBuildables = _sortableArray apply { _buildables#(_x#4) };
		T_SETV("buildableObjects", _sortedBuildables);

		OOP_INFO_2("Buildables for %1: %2", T_GETV("name"), _sortedBuildables);
	ENDMETHOD;

	public METHOD(isEnemy)
		params [P_THISOBJECT];
		private _enemySide = CALLM0(gGameMode, "getEnemySide");
		(count T_CALLM1("getGarrisons", _enemySide)) > 0
	ENDMETHOD;

	public METHOD(isPlayer)
		params [P_THISOBJECT];
		private _playerSide = CALLM0(gGameMode, "getPlayerSide");
		(count T_CALLM1("getGarrisons", _playerSide)) > 0
	ENDMETHOD;

	// Initialize build progress from garrisons that are present, call on campaign creation
	public METHOD(initBuildProgress)
		params [P_THISOBJECT];
		if !(T_GETV("type") in LOCATIONS_BUILD_PROGRESS) exitWith {};
		if(T_CALLM0("isEnemy")) then {
			#ifdef DEBUG_BUILDING
			// Start from 0 when testing.
			private _buildProgress = 0;
			#else
			private _scale = switch(T_GETV("type")) do {
				case LOCATION_TYPE_AIRPORT: { 0.5 };
				case LOCATION_TYPE_BASE:	{ 0.25 };
				case LOCATION_TYPE_OUTPOST: { 0.125 };
			};
			private _buildProgress = 0 max (_scale * random[0.5, 1, 1.5]) min 1;
			#endif
			#ifdef FULLY_BUILT
			private _buildProgress = 1;
			#endif
			FIX_LINE_NUMBERS()

			T_SETV_PUBLIC("buildProgress", _buildProgress);
		} else {
			T_SETV_PUBLIC("buildProgress", 0);
		};
		T_CALLM0("updateBuildProgress");
	ENDMETHOD;
	
	// https://www.desmos.com/calculator/2drp0pktyo
	#define OFFICER_RATE(officers) (1 + log (2 * (officers) + 1))
	// https://www.desmos.com/calculator/2drp0pktyo
	// 0 men = inf hrs, 10 men = 18 hrs, 20 = 12 hrs, 100 = 7 hrs
	#define BUILD_TIME(men) (5 + 1 / log (1 + (men) / 50))
	#define BUILD_RATE(men, hours) ((hours) / BUILD_TIME(men))

	#define ALIASED_VALUE(value, aliasing) (floor ((value) / (aliasing)))

	// Build all buildables in the location
	METHOD(updateBuildProgress)
		params [P_THISOBJECT, P_NUMBER("_dt")];
		if !(T_GETV("type") in LOCATIONS_BUILD_PROGRESS) exitWith {};

		private _buildables = T_GETV("buildableObjects");
		private _buildProgress = T_GETV("buildProgress");

		if(_dt > 0) then {
			if(T_CALLM0("isEnemy")) then {
				private _enemySide = CALLM0(gGameMode, "getEnemySide");
				// Determine if enemy is building this location
				private _manPower = 0;
				{
					_manPower = _manPower + CALLM0(_x, "countInfantryUnits") * OFFICER_RATE(CALLM0(_x, "countOfficers"));
				} forEach T_CALLM1("getGarrisons", _enemySide);
				private _buildRate = if(_manPower > 0) then { BUILD_RATE(_manPower, _dt / 3600) } else { 0 };
				_buildProgress = SATURATE(_buildProgress + _buildRate);
			} else {
				/*
				// Disabled the location build progress decay for now
				private _playerSide = CALLM0(gGameMode, "getPlayerSide");
				private _oldBuildProgress = T_GETV("buildProgress");
				private _friendlyUnits = 0;
				{
					_friendlyUnits = _friendlyUnits + CALLM0(_x, "countInfantryUnits");
				} forEach T_CALLM1("getGarrisons", _playerSide);

				// 20 friendly units garrisoned will stop decay
				private _manpowerDeficit = CLAMP_POSITIVE(20 - _friendlyUnits);
				private _decay = if(_manpowerDeficit > 0) then { BUILD_RATE(_manpowerDeficit, _dt / 3600) } else { 0 };
				_buildProgress = SATURATE(_buildProgress - _decay);
				if(T_CALLM0("isPlayer")) then {
					// If progress has degraded by a 5% chunk
					if(ALIASED_VALUE(_oldBuildProgress * 100, 5) < ALIASED_VALUE(_buildProgress * 100, 5)) then {
						// Notify players of what happened
						private _args = [localize "STR_LOC_GONE", format[localize "STR_LOC_BUILDINGS_REMOVED", T_GETV("name")], localize "STR_LOC_GONE_HINT"];
						REMOTE_EXEC_CALL_STATIC_METHOD("NotificationFactory", "createResourceNotification", _args, ON_CLIENTS, NO_JIP);
					};
				};
				*/
			};

			OOP_INFO_3("UpdateBuildProgress: %1 %2 %3", T_GETV("name"), _buildProgress, _buildables);
			T_SETV_PUBLIC("buildProgress", _buildProgress);
		};

		private _pos = T_GETV("pos");

		// Only update the actual building if no garrisons are spawned here, and no players nearby
		if(count _buildables > 0 
			&& {(T_CALLM0("getGarrisons") findIf {CALLM0(_x, "isSpawned")}) == NOT_FOUND}
			&& {(allPlayers findIf {getPos _x distance _pos < 1000}) == NOT_FOUND}) then {
			OOP_INFO_2("UpdateBuildProgress: updating buildable states %1 %2", T_GETV("name"), _buildables);
			{	
				private _hideObj = ((_forEachIndex + 1) / count _buildables) > _buildProgress;
				if((isObjectHidden _x) isEqualTo (!_hideObj)) then
				{
					_x hideObjectGlobal _hideObj;
				};
			} forEach _buildables;
		};

	ENDMETHOD;
	
	public METHOD(debugAddBuildProgress)
		params [P_THISOBJECT, P_NUMBER("_amount")];
		private _buildProgress = T_GETV("buildProgress");
		_buildProgress = 0 max (_buildProgress + _amount) min 1;
		T_SETV_PUBLIC("buildProgress", _buildProgress);
	ENDMETHOD;
	
	#ifdef DEBUG_LOCATION_MARKERS
	METHOD(updateMarker)
		params [P_THISOBJECT];

		private _type = T_GETV("type");
		deleteMarker _thisObject;
		deleteMarker (_thisObject + "_label");
		private _pos = T_GETV("pos");

		if(count _pos > 0) then {

			private _mrk = createmarker [_thisObject, _pos];
			_mrk setMarkerType (switch T_GETV("type") do {
				case LOCATION_TYPE_ROADBLOCK: { "mil_triangle" };
				case LOCATION_TYPE_BASE: { "mil_circle" };
				case LOCATION_TYPE_OUTPOST: { "mil_box" };
				case LOCATION_TYPE_CITY: { "mil_marker" };
				case LOCATION_TYPE_POLICE_STATION: { "mil_warning" };
				default { "mil_dot" };
			});
			_mrk setMarkerColor "ColorYellow";
			_mrk setMarkerAlpha 1;
			_mrk setMarkerText "";

			private _border = T_GETV("border");
			if(_border isEqualType []) then {
				_mrk setMarkerDir _border#2;
			};
			
			if(not (_type in [LOCATION_TYPE_ROADBLOCK])) then {
				_mrk = createmarker [_thisObject + "_label", _pos vectorAdd [-200, -200, 0]];
				_mrk setMarkerType "Empty";
				_mrk setMarkerColor "ColorYellow";
				_mrk setMarkerAlpha 1;
				private _name = T_GETV("name");
				private _type = T_GETV("type");
				_mrk setMarkerText format ["%1 (%2)(%3)", _thisObject, _name, _type];
			};
		};
	ENDMETHOD;
	#endif
	FIX_LINE_NUMBERS()
	
	// |                            D E L E T E                             |
	/*
	Method: delete
	*/
	METHOD(delete)
		params [P_THISOBJECT];

		// Delete the helper object
		#ifndef _SQF_VM
		deleteLocation T_GETV("helperObject");
		#endif

		// Remove the timer
		private _timer = T_GETV("timer");
		if (!IS_NULL_OBJECT(_timer)) then {
			DELETE(_timer);
			T_SETV("timer", nil);
		};

		//Remove this unit from array with all units
		private _allArray = GETSV("Location", "all");
		_allArray deleteAt (_allArray find _thisObject);
		PUBLIC_STATIC_VAR("Location", "all");

		#ifdef DEBUG_LOCATION_MARKERS
		deleteMarker _thisObject;
		deleteMarker _thisObject + "_label";
		#endif
		FIX_LINE_NUMBERS()
	ENDMETHOD;


	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// |                               G E T T I N G   M E M B E R   V A L U E S
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


	// |                            G E T   A L L
	/*
	Method: (static)getAll
	Returns an array of all locations.

	Returns: Array of location objects
	*/
	public STATIC_METHOD(getAll)
		private _all = GETSV("Location", "all");
		private _return = +_all;
		_return
	ENDMETHOD;


	// |                            G E T   P O S                           |
	/*
	Method: getPos
	Returns position of this location

	Returns: Array, position
	*/
	public METHOD(getPos)
		params [P_THISOBJECT];
		T_GETV("pos")
	ENDMETHOD;

	// Returns array of all intel items
	public METHOD(getIntel)
		params [P_THISOBJECT];
		+T_GETV("intel");
	ENDMETHOD;

	
	// |                         I S   S P A W N E D                        |
	/*
	Method: isSpawned
	Is the location spawned?

	Returns: bool
	*/
	public METHOD(isSpawned)
		params [P_THISOBJECT];
		T_GETV("spawned")
	ENDMETHOD;

	/*
	Method: hasPlayers
	Returns true if there are any players in the location area.
	The actual value gets updated infrequently, on timer.

	Returns: Bool
	*/
	public METHOD(hasPlayers)
		params [P_THISOBJECT];
		T_GETV("hasPlayers")
	ENDMETHOD;

	/*
	Method: getPlayerSides
	Returns array of sides of players within this location.

	Returns: array<Side>
	*/
	public METHOD(getPlayerSides)
		params [P_THISOBJECT];
		T_GETV("hasPlayerSides")
	ENDMETHOD;

	// |               G E T   P A T R O L   W A Y P O I N T S
	/*
	Method: getPatrolWaypoints
	Returns array with positions for patrol waypoints.

	Returns: Array of positions
	*/
	public METHOD(getPatrolWaypoints)
		params [P_THISOBJECT];
		if(T_GETV("useParentPatrolWaypoints")) then {
			private _parent = T_GETV("parent");
			CALLM0(_parent, "getPatrolWaypoints")
		} else {
			// Prefer selecting a random existing route
			private _patrolRoutes = T_GETV("patrolRoutes");
			if(count _patrolRoutes == 0) then {
				+T_GETV("borderPatrolWaypoints")
			} else {
				+(selectRandom _patrolRoutes)
			}
		}
	ENDMETHOD;

	public METHOD(getPatrolRoutes)
		params [P_THISOBJECT];
		if(T_GETV("useParentPatrolWaypoints")) then {
			private _parent = T_GETV("parent");
			CALLM0(_parent, "getPatrolRoutes")
		} else {
			+T_GETV("patrolRoutes")
		}
	ENDMETHOD;

	// |                  G E T   M E S S A G E   L O O P
	public override METHOD(getMessageLoop) //Derived classes must implement this method
		gMessageLoopMain
	ENDMETHOD;

	public METHOD(isAlarmDisabled)
		params [P_THISOBJECT];
		T_GETV("alarmDisabled")
	ENDMETHOD;

	public METHOD(setAlarmDisabled)
		params [P_THISOBJECT, P_BOOL("_disabled")];
		T_SETV_PUBLIC("alarmDisabled", _disabled);
	ENDMETHOD;

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// |                               S E T T I N G   M E M B E R   V A L U E S
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	public METHOD(registerGarrison)
		params [P_THISOBJECT, P_OOP_OBJECT("_gar")];
		
		pr _gars = T_GETV("garrisons");
		if (! (_gar in _gars)) then {
			_gars pushBackUnique _gar;
			PUBLIC_VAR(_thisObject, "garrisons");
			REF(_gar);

			// TODO: work out how this should work properly? This isn't terrible but we will
			// have resource constraints etc. Probably it should be in Garrison.process to build
			// at location when they have resources?

			T_CALLM("build", []);

			// Update player respawn rules
			pr _gmdata = T_GETV("gameModeData");
			if (!IS_NULL_OBJECT(_gmdata)) then {
				CALLM0(_gmdata, "updatePlayerRespawn");
			};

			// Re-enable the alarm
			T_CALLM1("setAlarmDisabled", false);
		};

		// From now on this place is occupied or was occupied
		T_SETV_PUBLIC("wasOccupied", true);
	ENDMETHOD;

	public METHOD(unregisterGarrison)
		params [P_THISOBJECT, P_OOP_OBJECT("_gar")];
		
		pr _gars = T_GETV("garrisons");
		if (_gar in _gars) then {
			_gars deleteAt (_gars find _gar);
			PUBLIC_VAR(_thisObject, "garrisons");
			UNREF(_gar);

			// Update player respawn rules
			pr _gmdata = T_GETV("gameModeData");
			if (!IS_NULL_OBJECT(_gmdata)) then {
				CALLM0(_gmdata, "updatePlayerRespawn");
			};
		};
	ENDMETHOD;

	public METHOD(getGarrisons)
		params [P_THISOBJECT, P_DYNAMIC_DEFAULT("_sides", 0), P_DYNAMIC_DEFAULT("_types", GARRISON_TYPE_GENERAL)];
		if(_types isEqualType GARRISON_TYPE_GENERAL) then {
			_types = [_types];
		};
		if (_sides isEqualTo 0) then {
			T_GETV("garrisons") select { CALLM0(_x, "getType") in _types }
		} else {
			if(_sides isEqualType west) then {
				_sides = [_sides];
			};
			T_GETV("garrisons") select { CALLM0(_x, "getSide") in _sides && { CALLM0(_x, "getType") in _types } }
		};
	ENDMETHOD;

	// Get all garrisons that consider this location home
	public METHOD(getHomeGarrisons)
		params [P_THISOBJECT, P_DYNAMIC_DEFAULT("_sides", 0), P_DYNAMIC_DEFAULT("_types", GARRISON_TYPE_GENERAL)];
		if(_types isEqualType GARRISON_TYPE_GENERAL) then {
			_types = [_types];
		};
		if (_sides isEqualTo 0) then {
			CALLSM0("Garrison", "getAll") select { CALLM0(_x, "getHome") == _thisObject && { CALLM0(_x, "getType") in _types } };
			//T_GETV("garrisons") select { CALLM0(_x, "getType") in _types }
		} else {
			if(_sides isEqualType west) then {
				_sides = [_sides];
			};
			CALLSM0("Garrison", "getAll") select { CALLM0(_x, "getHome") == _thisObject && { CALLM0(_x, "getSide") in _sides } && { CALLM0(_x, "getType") in _types } }
		};
	ENDMETHOD;

	public METHOD(hasGarrisons)
		params [P_THISOBJECT, P_DYNAMIC_DEFAULT("_sides", 0), P_DYNAMIC_DEFAULT("_types", GARRISON_TYPE_GENERAL)];
		count T_CALLM2("getGarrisons", _sides, _types) > 0
	ENDMETHOD;

	public METHOD(getGarrisonsRecursive)
		params [P_THISOBJECT, P_DYNAMIC_DEFAULT("_sides", 0), P_DYNAMIC_DEFAULT("_types", GARRISON_TYPE_GENERAL)];
		private _myGarrisons = T_CALLM2("getGarrisons", _sides, _types);
		{
			_myGarrisons append CALLM2(_x, "getGarrisonsRecursive", _sides, _types);
		} forEach T_GETV("children");
		_myGarrisons
	ENDMETHOD;

	/*
	Method: getType
	Returns type of this location

	Returns: String
	*/
	public METHOD(getType)
		params [P_THISOBJECT];
		T_GETV("type")
	ENDMETHOD;

	/*
	Method: getType
	Returns a nice string associated with this location type

	Returns: String
	*/
	public STATIC_METHOD(getTypeString)
		params [P_THISCLASS, "_type"];
		switch (_type) do {
			case LOCATION_TYPE_OUTPOST: {localize "STR_LOC_OUTPOST"};
			case LOCATION_TYPE_CAMP: {localize "STR_LOC_CAMP"};
			case LOCATION_TYPE_BASE: {localize "STR_LOC_BASE"};
			case LOCATION_TYPE_UNKNOWN: {localize "STR_LOC_UNKOWN"};
			case LOCATION_TYPE_CITY: {localize "STR_LOC_CITY"};
			case LOCATION_TYPE_OBSERVATION_POST: {localize "STR_LOC_OB"};
			case LOCATION_TYPE_ROADBLOCK: {localize "STR_LOC_ROADBLOCK"};
			case LOCATION_TYPE_POLICE_STATION: {localize "STR_LOC_POLICE_STATION"};
			case LOCATION_TYPE_AIRPORT: {localize "STR_LOC_AIRPORT"};
			case LOCATION_TYPE_RESPAWN: {localize "STR_LOC_RESPAWN"};
			default {localize "STR_LOC_ERROR"};
		};
	ENDMETHOD;

	// Gets default radius of location type
	public STATIC_METHOD(getDefaultRadius)
		params [P_THISCLASS, "_type"];
		switch (_type) do {
			case LOCATION_TYPE_CAMP: {100;};
			case LOCATION_TYPE_ROADBLOCK: {40;};
			default {100;};
		};
	ENDMETHOD;

	/*
	Method: getName

	Returns: String
	*/
	public METHOD(getName)
		params [P_THISOBJECT];
		T_GETV("name")
	ENDMETHOD;

	/*
	Method: getDisplayName

	Returns a display name to show in UIs. Format is: <type> <name>, like "Camp Potato".
	*/
	public METHOD(getDisplayName)
		params [P_THISOBJECT];
		pr _gmdata = T_GETV("gameModeData");
		if(_gmdata != NULL_OBJECT) then {
			CALLM0(_gmdata, "getDisplayName")
		} else {
			T_GETV("name")
		};
	ENDMETHOD;

	/*
	Method: getDisplayColor

	Returns a display color to show in UIs. Format is: [r,g,b,a].
	*/
	public METHOD(getDisplayColor)
		params [P_THISOBJECT];
		pr _gmdata = T_GETV("gameModeData");
		if(_gmdata != NULL_OBJECT) then {
			CALLM0(_gmdata, "getDisplayColor")
		} else {
			[1,1,1,1]
		};
	ENDMETHOD;

	/*
	Method: getSide
	Returns side of the garrison that controls this location.

	Returns: Side, or Civilian if there is no garrison
	*/
	/*
	public METHOD(getSide)
		params [P_THISOBJECT];
		pr _gar = T_GETV("garrisonMilMain");
		if (_gar == "") then {
			CIVILIAN
		} else {
			CALLM0(_gar, "getSide");
		};
	ENDMETHOD;
	*/

	/*
	Method: getCapacityInf
	Returns infantry capacity of this location -- how many infantry can be stationed here

	Returns: Integer
	*/
	public METHOD(getCapacityInf)
		params [P_THISOBJECT];
		T_GETV("capacityInf");
	ENDMETHOD;

	/*
	Method: getCapacityInfForType
	Returns absolute maximum infantry capacity for given location type.
	*/
	public STATIC_METHOD(getCapacityInfForType)
		params [P_THISOBJECT, P_STRING("_type")];
		switch (_type) do {
			case LOCATION_TYPE_UNKNOWN: { 0 }; // ??
			case LOCATION_TYPE_CITY: { 50 };
			case LOCATION_TYPE_CAMP: { 30 };
			case LOCATION_TYPE_BASE: { 80 };
			case LOCATION_TYPE_OUTPOST: { 60 };
			case LOCATION_TYPE_DEPOT: { 40 };
			case LOCATION_TYPE_POWER_PLANT: { 40 };
			case LOCATION_TYPE_POLICE_STATION: { 20 };
			case LOCATION_TYPE_RADIO_STATION: { 30 };
			case LOCATION_TYPE_AIRPORT: { 80 };
			case LOCATION_TYPE_ROADBLOCK: { 15 };
			case LOCATION_TYPE_OBSERVATION_POST: { 10 };
			case LOCATION_TYPE_RESPAWN: { 0 }; // ??
			default { 40 };
		};
	ENDMETHOD;

	/*
	Method: getCapacityAAForType
	Returns absolute maximum AA capacity for given location type.
	*/
	public STATIC_METHOD(getCapacityAAForType)
		params [P_THISOBJECT, P_STRING("_type")];
		switch (_type) do {
			case LOCATION_TYPE_AIRPORT: { 2 };
			default { 0 };
		};
	ENDMETHOD;

	/*
	Method: getCapacityHeli
	Returns helicopter capacity of this location -- how many helicopters can be stationed here

	Returns: Integer
	*/
	public METHOD(getCapacityHeli)
		params [P_THISOBJECT];
		count T_GETV("helipads")
	ENDMETHOD;

	/*
	Method: getCapacityPlane
	Returns plane capacity of this location -- how many planes can be stationed here

	Returns: Integer
	*/
	public METHOD(getCapacityPlane)
		params [P_THISOBJECT];
		0
	ENDMETHOD;

	/*
	Method: getCapacityCiv
	Returns civ capacity of this location -- how many civilians this location can have

	Returns: Integer
	*/
	public METHOD(getCapacityCiv)
		params [P_THISOBJECT];
		T_GETV("capacityCiv")
	ENDMETHOD;

	/*
	Method: getOpenBuildings
	Returns an array of object handles of buildings in which AI infantry can enter (they must return buildingPos positions)
	*/
	public METHOD(getOpenBuildings)
		params [P_THISOBJECT];
		T_GETV("buildingsOpen") select { damage _x < 0.98 && !isObjectHidden _x }
	ENDMETHOD;

	/*
	Method: getAmbientAnimObjects
	Returns an array of object handles marking ambient animations
	*/
	public METHOD(getAmbientAnimObjects)
		params [P_THISOBJECT];
		T_GETV("ambientAnimObjects") select { !isObjectHidden (_x getVariable ["vin_parent", objNull]) }
	ENDMETHOD;

	/*
	Method: getTargetRangeObjects
	Returns an array of object handles for shooting range targets
	*/
	public METHOD(getTargetRangeObjects)
		params [P_THISOBJECT];
		T_GETV("targetRangeObjects") select { !isObjectHidden _x }
	ENDMETHOD;

	/*
	Method: getGameModeData
	Returns gameModeData object
	*/
	public METHOD(getGameModeData)
		params [P_THISOBJECT];
		T_GETV("gameModeData")
	ENDMETHOD;

	/*
	Method: hasRadio
	Returns true if this location has any object of the radio object types
	*/
	public METHOD(hasRadio)
		params [P_THISOBJECT];
		T_GETV("hasRadio")
	ENDMETHOD;

	/*
	Method: wasOccupied
	Returns value of wasOccupied variable.
	*/
	public METHOD(wasOccupied)
		params [P_THISOBJECT];
		T_GETV("wasOccupied")
	ENDMETHOD;

	public STATIC_METHOD(findRoadblocks)
		params [P_THISCLASS, P_POSITION("_pos")];

		//private _pos = T_CALLM("getPos", []);

		private _roadblockPositions = [];

		// Get near roads and sort them far to near, taking width into account
		private _roads_remaining = ((_pos nearRoads 1500) select {
			pr _roadPos = getPos _x;
			_roadPos distance2D _pos > 400 &&			// Pos is far enough
			count (_x nearRoads 20) < 3 &&				// Not too many roads because it might mean a crossroad
			count (roadsConnectedTo _x) == 2			// Connected to two roads, we don't need end road elements
			// Let's not create roadblocks inside other locations
			//{count (CALLSM1("Location", "getLocationsAt", _roadPos)) == 0}	// There are no locations here
		}) apply {
			pr _width = [_x, 0.2, 20] call misc_fnc_getRoadWidth;
			pr _dist = position _x distance _pos;
			// We value wide roads more, also we value roads further away more
			[_dist*_width*_width*((random 10) + 1), _dist, _x]
		};

		// Sort roads by their value metric
		_roads_remaining sort DESCENDING; // We sort by the value metric!
		private _itr = 0;

		while {count _roads_remaining > 0 and _itr < 4} do {
			(_roads_remaining#0) params ["_valueMetric", "_dist", "_road"];
			private _roadscon = roadsConnectedto _road apply { [position _x distance _pos, _x] };
			_roadscon sort DESCENDING;
			if (count _roadscon > 0) then {
				private _roadcon = _roadscon#0#1;
				//private _dir = _roadcon getDir _road;
				private _roadblock_pos = getPos _road; //[getPos _road, _x, _dir] call BIS_Fnc_relPos;
					
				_roadblockPositions pushBack _roadblock_pos;
			};

			_roads_remaining = _roads_remaining select {
				( getPos _road distance2D getPos (_x select 2) > 300) &&
				{(getPos _road vectorDiff _pos) vectorCos (getPos (_x select 2) vectorDiff _pos) < 0.3}
			};
			_itr = _itr + 1;
		};

		_roadblockPositions
	ENDMETHOD;

	/*
	Method: getBorder
	Gets border parameters of this location

	Returns: [center, a, b, angle, isRectangle, c]
	*/
	public METHOD(getBorder)
		params [P_THISOBJECT];
		T_GETV("border")
	ENDMETHOD;

	/*
	Method: getBoundingRadius
	Gets the bounding circle radius of this location

	Returns: number
	*/
	public METHOD(getBoundingRadius)
		params [P_THISOBJECT];
		T_GETV("boundingRadius")
	ENDMETHOD;

	/*
	Method: setType
	Set the Type.

	Parameters: _type

	_type - String

	Returns: nil
	*/
	public METHOD(setType)
		params [P_THISOBJECT, P_STRING("_type")];
		T_SETV_PUBLIC("type", _type);

		// Create a timer object if the type of the location is a city or a roadblock
		//if (_type in [LOCATION_TYPE_CITY, LOCATION_TYPE_ROADBLOCK]) then {
		
			T_CALLM0("initTimer");
			
		//};

		// if (_type == LOCATION_TYPE_ROADBLOCK) then {
		// 	T_SETV_PUBLIC("isBuilt", false); // Unbuild this
		// };

		T_CALLM("updateWaypoints", []);

		UPDATE_DEBUG_MARKER;
	ENDMETHOD;

	METHOD(initTimer)
		params [P_THISOBJECT];
		
		// Delete previous timer if we had it
		pr _timer = T_GETV("timer");
		if (!IS_NULL_OBJECT(_timer)) then {
			DELETE(_timer);
		};

		// Create timer object
		private _msg = MESSAGE_NEW();
		_msg set [MESSAGE_ID_DESTINATION, _thisObject];
		_msg set [MESSAGE_ID_SOURCE, ""];
		_msg set [MESSAGE_ID_DATA, 0];
		_msg set [MESSAGE_ID_TYPE, LOCATION_MESSAGE_PROCESS];
		// This timer will execude code in unscheduled!!
		private _args = [_thisObject, 1, _msg, gTimerServiceMain, true]; //P_OOP_OBJECT("_messageReceiver"), ["_interval", 1, [1]], P_ARRAY("_message"), P_OOP_OBJECT("_timerService")
		private _timer = NEW("Timer", _args);
		T_SETV("timer", _timer);
	ENDMETHOD;

	// /*
	// Method: getCurrentGarrison
	// Returns the current garrison attached to this location

	// Returns: <Garrison> or "" if there is no current garrison
	// */
	// METHOD(getCurrentGarrison)
	// 	params [P_THISOBJECT];

	// 	private _garrison = T_GETV("garrisonMilAA");
	// 	if (_garrison == "") then { _garrison = T_GETV("garrisonMilMain"); };
	// 	if (_garrison == "") then { OOP_WARNING_1("No garrison found for location %1", _thisObject); };
	// 	_garrison
	// ENDMETHOD;

	/*
	Method: (static)findSafePosOnRoad
	Finds an empty position for a vehicle class name on road close to specified position.

	Parameters: _startPos 
	_startPos - start position ATL where to start searching for a position.

	Returns: Array, [_pos, _dir]
	*/
	#define ROAD_DIR_LIMIT 15

	public STATIC_METHOD(findSafePosOnRoad)
		params [P_THISCLASS, P_POSITION("_startPos"), P_STRING("_className"), P_NUMBER("_maxRange")];

		// Try to find a safe position on a road for this vehicle
		private _searchRadius = 50;
		private _return = [];
		_maxRange = _maxRange max _searchRadius;
		while {_return isEqualTo [] && {_searchRadius <= _maxRange}} do {
			private _roads = _startPos nearRoads _searchRadius;
			if (count _roads < 3) then {
				// Search for more roads at the next iteration
				_searchRadius = _searchRadius * 2;
			} else {
				_roads = _roads apply { [_x distance2D _startPos, _x] };
				_roads sort ASCENDING;
				private _i = 0;
				while {_i < count _roads && _return isEqualTo []} do {
					(_roads select _i) params ["_dist", "_road"];
					private _rct = roadsConnectedTo _road;
					// TODO: we can preprocess spawn locations better than this probably.
					// Need a connected road (this is guaranteed probably?)
					// Avoid spawning too close to a junction
					if(count _rct > 0) then {
						private _dir = _road getDir _rct#0;
						private _count = {
							private _rctOther = roadsConnectedTo _x;
							if(count _rctOther == 0) then {
								false
							} else {
								private _dirOther = _x getDir _rctOther#0;
								private _relDir = _dir - _dirOther;
								if(_relDir < 0) then { _relDir = _relDir + 360 };
								(_relDir > ROAD_DIR_LIMIT and _relDir < 180-ROAD_DIR_LIMIT) or (_relDir > 180+ROAD_DIR_LIMIT and _relDir < 360-ROAD_DIR_LIMIT)
							};
						} count ((getPos _road) nearRoads 25);
						if ( _count == 0 ) then {
							// Check position if it's safe
							private _width = [_road, 1, 8] call misc_fnc_getRoadWidth;
							// Move to the edge
							private _pos = [getPos _road, _width - 4, _dir + (selectRandom [90, 270]) ] call BIS_Fnc_relPos;
							// Move up and down the street a bit
							_pos = [_pos, _width * 0.5, _dir + (selectRandom [0, 180]) ] call BIS_Fnc_relPos;
							// Perturb the direction a bit
							private _dirPert = _dir + random [-20, 0, 20] + (selectRandom [0, 180]);
							// Perturb the position a bit
							private _posPert = _pos vectorAdd [random [-1, 0, 1], random [-1, 0, 1], 0];
							if(CALLSM3("Location", "isPosEvenSafer", _posPert, _dirPert, _className)) then {
								_return = [_posPert, _dirPert];
							};
						};
					};
					_i = _i + 1;
				};
				// Increase the radius
				if(_searchRadius == _maxRange) then {
					// This will just cause while loop to exit
					_searchRadius = _searchRadius * 2 
				} else {
					// Make sure we do a check at the max radius
					_searchRadius = _maxRange min (_searchRadius * 2);
				};
			};
		};
		if(_return isEqualTo []) then {
			OOP_WARNING_3("[Location::findSafePosOnRoad] Warning: failed to find safe pos on road for %1 at %2 in radius %3, looking for any safe pos", _className, _startPos, _maxRange);
			_return = CALLSM3("Location", "findSafePos", _startPos, _className, _searchRadius);
		};
		_return
	ENDMETHOD;

	/*
	Method: (static)findSafePos
	Finds a safe spawn position for a vehicle with given class name.

	Parameters: _className, _pos

	_className - String, vehicle class name
	_startPos - position where to start searching from

	Returns: [_pos, _dir]
	*/
	public STATIC_METHOD(findSafePos)
		params [P_THISCLASS, P_POSITION("_startPos"), P_STRING("_className"), P_NUMBER("_maxRadius")];

		private _found = false;
		private _searchRadius = 50;
		_maxRadius = _maxRadius max _searchRadius;
		pr _posAndDir = [_startPos, 0];
		while {!_found and _searchRadius <= _maxRadius} do {
			for "_i" from 0 to 16 do {
				pr _pos = _startPos vectorAdd [-_searchRadius + random(2*_searchRadius), -_searchRadius + random(2*_searchRadius), 0];
				pr _dir = random 360;
				if (CALLSM3("Location", "isPosEvenSafer", _pos, _dir, _className) && ! (surfaceIsWater _pos)) exitWith {
					_posAndDir = [_pos, _dir];
					_found = true;
				};
			};
			
			// Search in a larger area at the next iteration
			if(_searchRadius == _maxRadius) then {
				_searchRadius = _searchRadius * 2;
			} else {
				_searchRadius = _maxRadius min (_searchRadius * 2);
			};
		};

		_posAndDir
	ENDMETHOD;

	/*
	Method: countAvailableUnits
	Returns an number of current units of this location

	Returns: Integer
	*/
	public METHOD(countAvailableUnits)
		params [P_THISOBJECT, P_SIDE("_side") ];

		// TODO: Yeah we need mutex here!
		private _garrisons = T_CALLM("getGarrisons", [_side]);
		if (count _garrisons == 0) exitWith { 0 };
		private _sum = 0;
		{
			_sum = _sum + CALLM0(_x, "countAllUnits");
		} forEach _garrisons;
		_sum
	ENDMETHOD;

	/*
	Method: setBorderCircle
	Sets border parameters for this location as a circle

	Arguments:
	_radius
	*/
	public METHOD(setBorderCircle)
		params [P_THISOBJECT, P_NUMBER("_radius")];
		T_CALLM1("setBorder", [_radius ARG _radius ARG 0 ARG false]);
	ENDMETHOD;

	/*
	Method: setBorder
	Sets border parameters for this location

	Arguments:
	_data - [radiusA, radiusB, angle, isRectangle]
	*/
	public METHOD(setBorder)
		params [P_THISOBJECT, ["_data", [50, 50, 0, false], [[]]] ];

		_data params ["_a", "_b", "_dir", "_isRectangle"];
		private _boundingRadius = if(_isRectangle) then {
			sqrt(_a*_a + _b*_b);
		} else {
			_a max _b
		};

		// Ensure bounding radius is within limit
		if (_boundingRadius > LOCATION_BOUNDING_RADIUS_MAX) then {
			OOP_ERROR_3("Bounding radius exceeds limit: %1 > %2, position: %3", _boundingRadius, LOCATION_BOUNDING_RADIUS_MAX, T_GETV("pos"));
		};

		T_SETV_PUBLIC("boundingRadius", _boundingRadius);
		pr _border = [T_GETV("pos"), _a, _b, _dir, _isRectangle, -1]; // [center, a, b, angle, isRectangle, c]
		T_SETV_PUBLIC("border", _border);
		T_CALLM0("updateWaypoints");
		T_CALLM0("updateCivCapacity");
	ENDMETHOD;

	public METHOD(updateCivCapacity)
		params [P_THISOBJECT];
		private _locCapacityCiv = if(T_GETV("type") == LOCATION_TYPE_CITY) then {
			private _baseRadius = 300; // Radius at which it 
			private _border = T_GETV("border");
			_border params ["_pos", "_a", "_b"];
			private _area = 3.14*_a*_b;
			private _density_km2 = 6000;	// Amount of civilians per square km
			private _civsRaw = round(3.14*_a*_b*_density_km2/1000000);

			OOP_INFO_1("Civilian capacity: %1", _civsRaw);

			_civsRaw;

			// https://www.desmos.com/calculator/nahw1lso9f
			/*
			_locCapacityCiv = ceil (30 * log (0.0001 * _locBorder#0 * _locBorder#1 + 1));
			OOP_INFO_MSG("%1 civ count set to %2", [_locName ARG _locCapacityCiv]);
			//private _houses = _locSectorPos nearObjects ["House", _locBorder#0 max _locBorder#1];
			//diag_log format["%1 houses at %2", count _houses, _locName];
			*/

			// https://www.desmos.com/calculator/nahw1lso9f
			//_locCapacityInf = ceil (40 * log (0.00001 * _locBorder#0 * _locBorder#1 + 1));
			//OOP_INFO_MSG("%1 inf count set to %1", [_locCapacityInf]);
		} else {
			0
		};
		T_CALLM1("setCapacityCiv", _locCapacityCiv);
	ENDMETHOD;
	

	// How many civilian cars ought we to spawn in this location (we assume its an appropriate location)
	public METHOD(getMaxCivilianVehicles)
		params [P_THISOBJECT];
		private _radius = T_GETV("boundingRadius");
		CLAMP(0.03 * _radius, 3, 12)
	ENDMETHOD;

	public METHOD(getMaxCivilianBoats)
		params [P_THISOBJECT];
		private _cap = T_CALLM("getUnitCapacity", [[T_VEH ARG T_VEH_boat_unarmed] ARG GROUP_TYPE_ALL]);
		_cap min 4;
	ENDMETHOD;

	// File-based methods

	// Handles messages
	public override METHOD_FILE(handleMessageEx, QUOTE_COMMON_PATH(Location\handleMessageEx.sqf));

	// Sets border parameters
	METHOD_FILE(updateWaypoints, QUOTE_COMMON_PATH(Location\updateWaypoints.sqf));

	// Checks if given position is inside the border
	public METHOD_FILE(isInBorder, QUOTE_COMMON_PATH(Location\isInBorder.sqf));

	// Adds a spawn position
	METHOD_FILE(addSpawnPos, QUOTE_COMMON_PATH(Location\addSpawnPos.sqf));

	// Adds multiple spawn positions from a building
	METHOD_FILE(addSpawnPosFromBuilding, QUOTE_COMMON_PATH(Location\addSpawnposFromBuilding.sqf));

	// Calculates infantry capacity based on buildings at this location
	// It's old and better not to use it
	METHOD_FILE(calculateInfantryCapacity, QUOTE_COMMON_PATH(Location\calculateInfantryCapacity.sqf));

	// Gets a spawn position to spawn some unit
	public METHOD_FILE(getSpawnPos, QUOTE_COMMON_PATH(Location\getSpawnPos.sqf));

	// Returns a random position within border
	public METHOD_FILE(getRandomPos, QUOTE_COMMON_PATH(Location\getRandomPos.sqf));

	// Returns how many units of this type and group type this location can hold
	public METHOD_FILE(getUnitCapacity, QUOTE_COMMON_PATH(Location\getUnitCapacity.sqf));

	// Checks if given position is safe to spawn a vehicle here
	public STATIC_METHOD_FILE(isPosSafe, QUOTE_COMMON_PATH(Location\isPosSafe.sqf));

	// Checks if given position is even safer to spawn a vehicle here (conservative, doesn't allow spawning 
	// in buildings etc.)
	public STATIC_METHOD_FILE(isPosEvenSafer, QUOTE_COMMON_PATH(Location\isPosEvenSafer.sqf));

	// Returns the nearest location to given position and distance to it
	public STATIC_METHOD_FILE(getNearestLocation, QUOTE_COMMON_PATH(Location\getNearestLocation.sqf));

	// Returns location that has its border overlapping given position
	public STATIC_METHOD_FILE(getLocationAtPos, QUOTE_COMMON_PATH(Location\getLocationAtPos.sqf));

	// Returns an array of locations that have their border overlapping given position
	public STATIC_METHOD_FILE(getLocationsAtPos, QUOTE_COMMON_PATH(Location\getLocationsAtPos.sqf));

	// Adds an allowed area
	METHOD_FILE(addAllowedArea, QUOTE_COMMON_PATH(Location\addAllowedArea.sqf));

	// Checks if player is in any of the allowed areas
	public METHOD_FILE(isInAllowedArea, QUOTE_COMMON_PATH(Location\isInAllowedArea.sqf));

	// Handle PROCESS message
	public METHOD_FILE(process, QUOTE_COMMON_PATH(Location\process.sqf));

	// Spawns the location
	METHOD_FILE(spawn, QUOTE_COMMON_PATH(Location\spawn.sqf));

	// Despawns the location
	METHOD_FILE(despawn, QUOTE_COMMON_PATH(Location\despawn.sqf));

	// Builds the location
	METHOD_FILE(build, QUOTE_COMMON_PATH(Location\build.sqf));

	/*
	Method: isBuilt
	Getter for isBuilt
	*/
	public METHOD(isBuilt)
		params [P_THISOBJECT]; T_GETV("isBuilt")
	ENDMETHOD;

	/*
	Method: enablePlayerRespawn
	
	Parameters: _side, _enable
	*/
	public METHOD(enablePlayerRespawn)
		params [P_THISOBJECT, P_SIDE("_side"), P_BOOL("_enable")];

		pr _markName = switch (_side) do {
			case WEST: {"respawn_west"};
			case EAST: {"respawn_east"};
			case INDEPENDENT: {"respawn_guerrila"};
			default {"respawn_civilian"};
		};

		pr _respawnSides = T_GETV("respawnSides");

		if (_enable) then {

			pr _pos = T_GETV("pos");
			pr _type = T_GETV("type");
			
			// Find an alternative spawn place for a city or police station
			if (_type == LOCATION_TYPE_CITY) then {
				// Find appropriate player spawn point, not to near and not to far from the police station, inside a house
				private _houses = (_pos nearObjects ["House", 200]) apply { [_pos distance getPos _x, _x] };
				//_nearbyHouses sort false; // Descending
				_nearbyHouses = _houses call BIS_fnc_arrayShuffle;
				private _spawnPos = _pos vectorAdd [100, 100, 0];
				{
					_x params ["_dist", "_building"];
					private _positions = _building buildingPos -1;
					if(count _positions > 0) exitWith {
						_spawnPos = selectRandom _positions;
					}
				} forEach _nearbyHouses;
				_pos = _spawnPos;
			};

			T_SETV_PUBLIC("playerRespawnPos", _pos);	// Broadcast the new pos

			_respawnSides pushBackUnique _side;
		} else {

			_respawnSides deleteAt (_respawnSides find _side);
		};
		PUBLIC_VAR(_thisObject, "respawnSides"); // Broadcast the sides which can respawn
	ENDMETHOD;

	/*
	Method: playerRespawnEnabled

	Parameters: _side

	Returns true if player respawn is enabled for this side
	*/
	public METHOD(playerRespawnEnabled)
		params [P_THISOBJECT, P_SIDE("_side")];

		// Always true for respawn type of location
		if (T_GETV("type") == LOCATION_TYPE_RESPAWN) exitWith { true };

		_side in T_GETV("respawnSides")
	ENDMETHOD;

	/*
	Method: getPlayerRespawnPos

	Returns respawn pos for players
	*/
	public METHOD(getPlayerRespawnPos)
		params [P_THISOBJECT];

		T_GETV("playerRespawnPos");
	ENDMETHOD;

	/*
	Method: iterates through objects inside the border and updated the buildings variable
	Parameters: _filter - String, each object will be tested with isKindOf command against this filter
	Returns: nothing
	*/
	public METHOD(processObjectsInArea)
		params [P_THISOBJECT, ["_filter", "House", [""]], ["_addSpecialObjects", false, [false]]];

		// Setup location's spawn positions
		private _radius = T_GETV("boundingRadius");
		private _locPos = T_GETV("pos");
		private _no = _locPos nearObjects _radius;

		//OOP_INFO_1("PROCESS OBJECTS IN AREA: %1", _this);
		//OOP_INFO_2("	Radius: %1, pos: %2", _radius, _locPos);
		//OOP_INFO_1("	Objects: %1", _no);

		// forEach _nO;
		{
			_object = _x;
			//OOP_INFO_1("	Object: %1", _object);
			if(T_CALLM1("isInBorder", _object)) then {
				//OOP_INFO_0("	In border");
				if (_object isKindOf _filter) then {
					//OOP_INFO_0("		Is kind of filter");
					T_CALLM1("addObject", _object);
				} else {
					//OOP_INFO_0("    	Does not match filter");
					pr _type = typeOf _object;
					if (_addSpecialObjects) then {
						// Check if this object has capacity defined
						//   or adds radio functionality
						//  or... 
						private _index = location_b_capacity findIf {_type in _x#0};
						private _indexRadio = location_bt_radio find _type;
						if (_index != -1 || _indexRadio != -1) then {
							//OOP_INFO_0("    	Is a special object");
							T_CALLM1("addObject", _object);
						};
					};
				};
			};
		} forEach _nO;
	ENDMETHOD;

	/*
	Method: addSpawnPosFromBuildings
	Iterates its buildings and adds spawn positions from them
	*/
	public METHOD(addSpawnPosFromBuildings)
		params [P_THISOBJECT];
		pr _buildings = T_GETV("buildingsOpen");
		{
			T_CALLM1("addSpawnPosFromBuilding", _x);
		} forEach _buildings;
	ENDMETHOD;

	/*
	Method: (static)nearLocations
	Returns an array of locations that are _radius meters from _pos. Distance is checked in 2D mode.

	Parameters: _pos, _radius

	Returns: nil
	*/
	public STATIC_METHOD(nearLocations)
		params [P_THISCLASS, P_ARRAY("_pos"), P_NUMBER("_radius")];

		(nearestLocations  [_pos, ["vin_location"], _radius]) apply {
			GET_LOCATION_FROM_HELPER_OBJECT(_x);
		};
	ENDMETHOD;

	/*
	Method: (static)overlappingLocations
	Returns an array of locations that are overlapping with a circle _radius meters at _pos. Distance is checked in 2D mode.

	Parameters: _pos, _radius

	Returns: nil
	*/
	public STATIC_METHOD(overlappingLocations)
		params [P_THISCLASS, P_ARRAY("_pos"), P_NUMBER("_radius")];
		pr _helpers = nearestLocations  [_pos, ["vin_location"], LOCATION_BOUNDING_RADIUS_MAX+_radius];
		pr _nearLocations = _helpers apply { GET_LOCATION_FROM_HELPER_OBJECT(_x); };
		_nearLocations select {
			(GETV(_x, "pos") distance2D _pos) < (_radius + GETV(_x, "boundingRadius"));
		};
	ENDMETHOD;

	// Runs "process" of locations within certain distance from the point
	// Actually it only checks cities and roadblocks now, because other locations don't need to have "process" method to be called on them
	// Public, thread-safe
	public STATIC_METHOD(processLocationsNearPos)
		params [P_THISCLASS, P_POSITION("_pos")];
		
		pr _args = ["Location", "_processLocationsNearPos", [_pos]];
		CALLM2(gMessageLoopMainManager, "postMethodAsync", "callStaticMethodInThread", _args);
	ENDMETHOD;

	public STATIC_METHOD(_processLocationsNearPos)
		params [P_THISCLASS, P_POSITION("_pos")];
		pr _locs = CALLSM2("Location", "overlappingLocations", _pos, 2000);
		//  select { // todo arbitrary number for now
		// 	(GETV(_x, "type") in [LOCATION_TYPE_CITY, LOCATION_TYPE_ROADBLOCK])
		// };

		{
			CALLM0(_x, "process");
		} forEach _locs;
	ENDMETHOD;

	STATIC_METHOD(initRepairObject)
		params [P_THISCLASS, P_OBJECT("_object")];

		if (!isServer) exitWith {
			OOP_ERROR_0("initRepairObject must be called on server!");
		};

		// Generate a JIP ID
		private _ID = 0;
		if(isNil "location_repair_nextID") then {
			location_repair_nextID = 0;
			_ID = 0;
		} else {
			_ID = location_repair_nextID;
		};
		location_repair_nextID = location_repair_nextID + 1;

		private _JIPID = format ["loc_repair_jip_%1", _ID];
		_object setVariable ["loc_repair_jip", _JIPID];

		// Add an event handler to delete the init from the JIP queue when the object is gone
		_object addEventHandler ["Deleted", {
			params ["_entity"];
			private _JIPID = _entity getVariable "loc_repair_jip";
			if (isNil "_JIPID") exitWith {
				OOP_ERROR_1("loc_repair_jip not found for object %1", _entity);
			};
			remoteExecCall ["", _JIPID]; // Remove it from the queue
		}];

		REMOTE_EXEC_CALL_STATIC_METHOD("Location", "initRepairObjectAction", [_object], 0, _JIPID); // global, JIP

	ENDMETHOD;

	// Initalization of different objects
	STATIC_METHOD(initMedicalObject)
		params [P_THISCLASS, P_OBJECT("_object")];

		if (!isServer) exitWith {
			OOP_ERROR_0("initMedicalObject must be called on server!");
		};

		// Generate a JIP ID
		private _ID = 0;
		if(isNil "location_medical_nextID") then {
			location_medical_nextID = 0;
			_ID = 0;
		} else {
			_ID = location_medical_nextID;
		};
		location_medical_nextID = location_medical_nextID + 1;

		private _JIPID = format ["loc_medical_jip_%1", _ID];
		_object setVariable ["loc_medical_jip", _JIPID];

		// Add an event handler to delete the init from the JIP queue when the object is gone
		_object addEventHandler ["Deleted", {
			params ["_entity"];
			private _JIPID = _entity getVariable "loc_medical_jip";
			if (isNil "_JIPID") exitWith {
				OOP_ERROR_1("loc_medical_jip not found for object %1", _entity);
			};
			remoteExecCall ["", _JIPID]; // Remove it from the queue
		}];

		REMOTE_EXEC_CALL_STATIC_METHOD("Location", "initMedicalObjectAction", [_object], 0, _JIPID); // global, JIP

	ENDMETHOD;

	STATIC_METHOD(initMedicalObjectAction)
		params [P_THISCLASS, P_OBJECT("_object")];

		OOP_INFO_1("INIT MEDICAL OBJECT ACTION: %1", _object);

		// Estimate usage radius
		private _radius = (sizeof typeof _object) + 5;

		_object setVariable["ACE_medical_isMedicalFacility", true];
		_object allowdamage false;

		_object addAction [localize "STR_LOC_HEAL_SELF", // title
			{
				player setdamage 0;
				[player] call ace_medical_treatment_fnc_fullHealLocal;
				player playMove "AinvPknlMstpSlayWrflDnon_medic";
			}, 
			0, // Arguments
			100, // Priority
			true, // ShowWindow
			false, //hideOnUse
			"", //shortcut
			"true", //condition
			_radius, //radius
			false, //unconscious
			"", //selection
			""]; //memoryPoint
	ENDMETHOD;

	STATIC_METHOD(initRepairObjectAction)
		params [P_THISCLASS, P_OBJECT("_object")];

		OOP_INFO_1("INIT REPAIR OBJECT ACTION: %1", _object);

		// Estimate usage radius
		private _radius = (sizeof typeof _object) + 5;

		_object setVariable["ACE_isRepairFacility", true];
		_object allowdamage false;

		_object addAction [localize "STR_LOC_REPAIR_VEHICLES", // title
			{
				_nearVehicles = [];
				_nearVehicles = position (_this select 0) nearObjects ["AllVehicles", 14];
				if (count _nearVehicles > 0) then{
					private _args = [localize "STR_LOC_REPAIR", localize "STR_LOC_REPAIR_REPAIRING_VEHICLES", ""];
					REMOTE_EXEC_CALL_STATIC_METHOD("NotificationFactory", "createHint", _args, _this select 1, NO_JIP);
					{
						[_x, false] remoteExec ['engineOn', _x]; //shut engine off

						{
							if (_x in allPlayers) then {
								moveOut _x;
								private _args = [localize "STR_LOC_REPAIR", localize "STR_LOC_REPAIR_YOU_WERE_DISEMBARKED", localize "STR_LOC_REPAIR_THE_VEHICLE_IS_REPAIRED"];
								REMOTE_EXEC_CALL_STATIC_METHOD("NotificationFactory", "createHint", _args, _x, NO_JIP);

							};
						} forEach crew _x; //disembark all crew

    					[_x, 0] remoteExec ['setDamage', _x]; //repair vehicle
					} forEach _nearVehicles;
				} else {
					private _args = [localize "STR_LOC_REPAIR", localize "STR_LOC_REPAIR_NO_VEHICLES_FOUND", localize "STR_LOC_REPAIR_CHECK_VEHICLES_CLOSE", localize "STR_LOC_REPAIR_CHECK_VEHICLES_CLOSE"];
					REMOTE_EXEC_CALL_STATIC_METHOD("NotificationFactory", "createHint", _args, _this select 1, NO_JIP);
				};
			},
			0, // Arguments
			100, // Priority
			true, // ShowWindow
			false, //hideOnUse
			"", //shortcut
			"true", //condition
			_radius, //radius
			false, //unconscious
			"", //selection
			""]; //memoryPoint
	ENDMETHOD;

	STATIC_METHOD(initRadioObject)
		params [P_THISCLASS, P_OBJECT("_object")];

		if (!isServer) exitWith {
			OOP_ERROR_0("initRadioObject must be called on server!");
		};

		// Generate a JIP ID
		private _ID = 0;
		if(isNil "location_radio_nextID") then {
			location_radio_nextID = 0;
			_ID = 0;
		} else {
			_ID = location_radio_nextID;
		};
		location_radio_nextID = location_radio_nextID + 1;

		private _JIPID = format ["loc_radio_jip_%1", _ID];
		_object setVariable ["loc_radio_jip", _JIPID];

		// Add an event handler to delete the init from the JIP queue when the object is gone
		_object addEventHandler ["Deleted", {
			params ["_entity"];
			private _JIPID = _entity getVariable "loc_radio_jip";
			if (isNil "_JIPID") exitWith {
				OOP_ERROR_1("loc_radio_jip not found for object %1", _entity);
			};
			remoteExecCall ["", _JIPID]; // Remove it from the queue
		}];

		//OOP_INFO_2("INIT RADIO OBJECT: %1 at %2", _object, getPos _object);
		//OOP_INFO_1("  JIP ID: %1", _JIPID);

		REMOTE_EXEC_CALL_STATIC_METHOD("Location", "initRadioObjectAction", [_object], 0, _JIPID); // global, JIP
	ENDMETHOD;

	public STATIC_METHOD(initRadioObjectAction)
		params [P_THISCLASS, P_OBJECT("_object")];

		OOP_INFO_1("INIT RADIO OBJECT ACTION: %1", _object);

		// Estimate usage radius
		private _radius = (sizeof typeof _object) + 5;

		_object addAction [localize "STR_LOC_MANAGE_KEYS", // title
			{
				// Open the radio key dialog
				private _dlg0 = NEW("RadioKeyDialog", []);
			}, 
			0, // Arguments
			100, // Priority
			true, // ShowWindow
			false, //hideOnUse
			"", //shortcut
			"['', player] call PlayerMonitor_fnc_isUnitAtFriendlyLocation", //condition
			_radius, //radius
			false, //unconscious
			"", //selection
			""]; //memoryPoint
	ENDMETHOD;

	public STATIC_METHOD(deleteEditorAllowedAreaMarkers)
		params [P_THISCLASS];
		private _allowedAreas = (allMapMarkers select {(tolower _x) find "allowedarea" == 0});
		{_x setMarkerAlpha 0;} forEach _allowedAreas;
	ENDMETHOD;


	// - - - - - - S T O R A G E - - - - - -

	public override METHOD(preSerialize)
		params [P_THISOBJECT, P_OOP_OBJECT("_storage")];
		
		// Save objects which we own
		pr _gmData = T_GETV("gameModeData");
		if (!IS_NULL_OBJECT(_gmData)) then {
			CALLM1(_storage, "save", T_GETV("gameModeData"));
		};

		// Convert our objects to an array
		pr _savedObjects = (T_GETV("objects") + T_GETV("buildingsOpen")) apply {
			private _obj = _x;
			private _tags = SAVED_OBJECT_TAGS apply { [_x, _obj getVariable [_x, nil]] } select { !isNil { _x#1 } };
			[
				typeOf _obj,
				(getModelInfo _obj)#1, // Model path
				getPosWorld _obj,
				vectorDir _obj,
				vectorUp _obj,
				_tags
			]
		};

		T_SETV("savedObjects", _savedObjects);

		// Save all garrisons attached here
		{
			pr _gar = _x;
			CALLM1(_storage, "save", _gar);
		} forEach T_GETV("garrisons");

		true
	ENDMETHOD;

	// Must return true on success
	public override METHOD(postSerialize)
		params [P_THISOBJECT, P_OOP_OBJECT("_storage")];

		// Call method of all base classes
		CALLCM("MessageReceiverEx", _thisObject, "postSerialize", [_storage]);

		// Erase temporary variables
		T_SETV("savedObjects", []);

		true
	ENDMETHOD;

	// These methods must return true on success
	
	public override METHOD(postDeserialize)
		params [P_THISOBJECT, P_OOP_OBJECT("_storage")];

		// Call method of all base classes
		CALLCM("MessageReceiverEx", _thisObject, "postDeserialize", [_storage]);

		// Set default values of variables whic hwere not saved
		T_SETV("hasPlayers", false);
		T_SETV("hasPlayerSides", []);

		T_SETV("buildingsOpen", []);
		T_SETV("objects", []);
		T_SETV("ambientAnimObjects", []);
		T_SETV("targetRangeObjects", []);

		T_SETV("spawnPosTypes", []);
		T_SETV("buildableObjects", []);
		T_SETV("lastBuildProgressTime", 0);
		T_SETV("hasRadio", false);
		T_SETV("capacityInf", 0);
		T_SETV("helipads", []);
		T_SETV("timer", NULL_OBJECT);
		T_SETV("spawned", false);
		T_SETV_PUBLIC("alarmDisabled", false);
		T_SETV("patrolRoutes", []);

		// Lets try and find a location sector that we can update from, incase it changed
		#ifndef _SQF_VM
		private _locSectors = entities "Vindicta_LocationSector";
		#else
		private _locSectors = [];
		#endif
		FIX_LINE_NUMBERS()
		private _foundIdx = _locSectors findIf {
			(_x getVariable ["Name", ""]) isEqualTo T_GETV("name") && (_x getVariable ["Type", ""]) isEqualTo T_GETV("type")
		};
		if(_foundIdx != NOT_FOUND) then {
			private _locSector = _locSectors#_foundIdx;
			private _locBorder = _locSector getVariable ["objectArea", [50, 50, 0, true]];
			T_CALLM1("setBorder", _locBorder);
		};

		pr _gmData = T_GETV("gameModeData");
		if (!IS_NULL_OBJECT(_gmData)) then {
			CALLM1(_storage, "load", _gmData);
		};
		T_PUBLIC_VAR("gameModeData");

		// Load garrisons
		{
			pr _gar = _x;
			CALLM1(_storage, "load", _gar);
		} forEach T_GETV("garrisons");

		// Find existing objects before we place constructed ones
		T_CALLM0("findAllObjects");

		// Rebuild the objects which have been constructed here
		{ // forEach T_GETV("savedObjects");
			_x params ["_type", "_modelPath", "_posWorld", "_vDir", "_vUp", ["_tags", nil]];
			// Check if there is such an object here already
			pr _objs = nearestObjects [_posWorld, [], 0.25, true] select { (typeOf _x == _type) || {((getModelInfo _x)#1) == _modelPath;} };
			pr _hO = if (count _objs == 0) then {
				pr _hO = if (count _type > 0) then {
					_type createVehicle [0, 0, 0];
				} else {
					createSimpleObject [_modelPath, [0,0,0], false]; 
				};
				_hO setPosWorld _posWorld;
				_hO setVectorDirAndUp [_vDir, _vUp];
				_hO;
			} else {
				_objs#0;
			};
			if(!isNil {_tags}) then {
				{
					_hO setVariable (_x + [true]);
				} forEach _tags;
			};
			T_CALLM1("addObject", _hO);
		} forEach T_GETV("savedObjects");

		T_SETV("savedObjects", []);

		// Enable player respawn
		{
			pr _side = _x;
			T_CALLM2("enablePlayerRespawn", _side, true);
		} forEach T_GETV("respawnSides");

		// Broadcast public variables
		T_PUBLIC_VAR("name");
		T_PUBLIC_VAR("garrisons");
		T_PUBLIC_VAR("boundingRadius");
		T_PUBLIC_VAR("border");
		T_PUBLIC_VAR("pos");
		T_PUBLIC_VAR("isBuilt");

		T_PUBLIC_VAR("buildProgress");

		T_PUBLIC_VAR("allowedAreas");
		T_PUBLIC_VAR("type");
		T_PUBLIC_VAR("wasOccupied");
		T_PUBLIC_VAR("parent");
		T_PUBLIC_VAR("respawnSides");
		T_PUBLIC_VAR("playerRespawnPos");

		// Init helper object
		T_CALLM0("_initHelperObject");

		//Push the new object into the array with all locations
		GETSV("Location", "all") pushBackUnique _thisObject;
		PUBLIC_STATIC_VAR("Location", "all");

		// T_CALLM0("findBuildables");

		// Restore timer -- don't panic: processing won't start until the processing threads are unlocked at the 
		// very end of loading process.
		T_CALLM0("initTimer");

		true
	ENDMETHOD;

	public STATIC_METHOD(postLoad)
		params [P_THISCLASS];

		{
			private _loc = _x;
			private _gmData = CALLM0(_x, "getGameModeData");
			if(!IS_NULL_OBJECT(_gmData)) then {
				// Refresh spawnability
				CALLM0(_gmData, "updatePlayerRespawn");
			};
			// Update build progress
			CALLM0(_loc, "updateBuildProgress");
		} forEach GETSV("Location", "all");
		
	ENDMETHOD;
	

	STATIC_METHOD(saveStaticVariables)
		params [P_THISCLASS, P_OOP_OBJECT("_storage")];
	ENDMETHOD;

	STATIC_METHOD(loadStaticVariables)
		params [P_THISCLASS, P_OOP_OBJECT("_storage")];
		SETSV("Location", "all", []);
	ENDMETHOD;

ENDCLASS;

if (isNil {GETSV("Location", "all")}) then {
	SETSV("Location", "all", []);
};

#ifndef _SQF_VM

// Initialize arrays with building types
CALL_COMPILE_COMMON("Location\initBuildingTypes.sqf");
// Initialize ambient animation info
CALL_COMPILE_COMMON("Location\initAmbientAnim.sqf");

#endif

// Tests
#ifdef _SQF_VM
["Location.save and load", {
	pr _loc = NEW("Location", [[0 ARG 1 ARG 2]]);
	CALLM1(_loc, "setName", "testLocationName");
	pr _storage = NEW("StorageProfileNamespace", []);
	CALLM1(_storage, "open", "testRecordLocation");
	CALLM1(_storage, "save", _loc);
	CALLSM1("Location", "saveStaticVariables", _storage);
	DELETE(_loc);
	CALLSM1("Location", "loadStaticVariables", _storage);
	CALLM1(_storage, "load", _loc);

	["Object loaded", GETV(_loc, "name") == "testLocationName"] call test_Assert;

	true
}] call test_AddTest;
#endif