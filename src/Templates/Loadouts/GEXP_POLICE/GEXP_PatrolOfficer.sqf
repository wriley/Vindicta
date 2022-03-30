removeAllWeapons this;
removeAllItems this;
removeAllAssignedItems this;
removeUniform this;
removeVest this;
removeBackpack this;
removeHeadgear this;
removeGoggles this;

//	==== Head Gear ====
this addHeadgear "Patrol_Cap";

//	==== Face Gear ====
if(random 10 < 3) then {
	private _goggles = [
		"G_Shades_Black",
		"G_WirelessEarpiece_F",
		"G_Aviator"
	];
	
	this addGoggles selectRandom _goggles;
};

//	==== Uniform ====
this forceAddUniform "Gendarmerie_Officer1_uniform";
this addItemToUniform "FirstAidKit";

//	==== Vest ====
private _vest = [
	"TacVest_V1",
	"Patrol_Vest"
];

this addVest selectRandom _vest;

//	==== Weapons ====
if(random 10 < 2) then {
	private _gunAndAmmo = [
		["SMG_03_black", "50Rnd_570x28_SMG_03"],			0.5,
		["prpl_benelli_rail", "prpl_6Rnd_12Gauge_Pellets"],	0.2,
		["ExpansionMod_SMG_03C_black", "50Rnd_570x28_SMG_03"], 0.3,
		["SMG_02_F", "30Rnd_9x21_Mag_SMG_02"], 0.4
	];

	(selectRandomWeighted _gunAndAmmo) params ["_gun", "_ammo"];
	this addWeapon _gun;
	this addPrimaryWeaponItem _ammo;
	for "_i" from 1 to 2 do {this addItemToVest _ammo;};
};

this addWeapon "hgun_Rook40_F";
this addHandgunItem "16Rnd_9x21_Mag";
for "_i" from 1 to 4 do {this addItemToVest "16Rnd_9x21_Mag";};

//	==== Misc Items ====
this linkItem "ItemMap"; 		// Map
this linkItem "ItemWatch"; 		// Watch
this linkItem "ItemCompass"; 	// Compass