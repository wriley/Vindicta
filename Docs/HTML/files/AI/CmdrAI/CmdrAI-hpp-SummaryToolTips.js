NDSummary.OnToolTipsLoaded("File:AI/CmdrAI/CmdrAI.hpp",{140:"<div class=\"NDToolTip TEnumeration LSQF\"><div class=\"TTSummary\">Flags for &lt;Model.WorldModel.new&gt; type parameter.&nbsp; WORLD_TYPE_REAL - Real world model, contained objects represent the last known state of actual garrisons, locations, clusters etc.&nbsp; WORLD_TYPE_SIM_NOW - Sim model with only current effects of actions applied.&nbsp; i.e. Real world model + the effects of any active action that would be applied immediately if the action itself were to update. For instance if the action is to split a garrison in half, it would apply immediately because splitting a garrison is an instantaneous operation. But a move action would not apply because moving takes time.&nbsp; The purpose of this model of the world is mostly to simulate changes in available resources while new actions are being planned. Usually the first part of an action is to allocate its resources (e.g. splitting a detachment off from an existing garrison to perform the action with).&nbsp; WORLD_TYPE_SIM_FUTURE - Sim model with current and future effects of actions applied</div></div>",141:"<div class=\"NDToolTip TEnumeration LSQF\"><div class=\"TTSummary\">Flags for &lt;Model.GarrisonModel.splitActual&gt; flags parameter, they control logic and validation.&nbsp; ASSIGN_TRANSPORT - Attempt to assign transport for the new garrison FAIL_WITHOUT_FULL_TRANSPORT -Fail if we couldn\'t assign transport to the new garrison (&lt;ASSIGN_TRANSPORT&gt; required) FAIL_UNDER_EFF -Fail if the split garrison didn\'t meet efficiency requirements CHEAT_TRANSPORT -Spawn trucks if they are not available and transport is requested OCCUPYING_FORCE_HINT -Hint to select units approproiate for an occupying force (e.g. plenty of inf) COMBAT_FORCE_HINT -Hint to select units approproiate for direct combat (e.g. heavy firepower) RECON_FORCE_HINT -Hint to select units approproiate for a recon force (e.g. recon units, fast transport) SPEC_OPS_FORCE_HINT -Hint to select units approproiate for a spec ops (e.g. spec ops units, covert transport) PATROL_FORCE_HINT -Hint to select units approproiate for a patrol force (e.g. normal units, fast/lightly armed transport)</div></div>",142:"<div class=\"NDToolTip TEnumeration LSQF\"><div class=\"TTSummary\">Cmdr planning constants CMDR_PLANNING_PRIORITY_HIGH - highest priority, reserved for actions that need to respond to events quickly, i.e. QRFs.&nbsp; CMDR_PLANNING_PRIORITY_NORMAL - normal priority, things like reinforcements CMDR_PLANNING_PRIORITY_LOW - low priority, long term planning like taking new locations, resource shuffling etc.</div></div>"});