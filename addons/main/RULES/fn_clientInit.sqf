/**
* Description:
* Initialisierung Rules System 
*
* Author:
* Lord-MDB
*
* Arguments:
* None
*
* Return Value:
* None
*
* Server only:
* No
*
* Public:
* No 
* 
* Global:
* No
* 
* API:
* No
*
* Example:
* [] call FUNC(clientInit);
*/
#include "macros.hpp"

// Spieler wird getötet wenn er sich zu nah an eine Feindbasis wagt
#define MIN_DISTANCE_TO_ENEMYBASE 2000

// Wie oft (in Sekunden) wird die Spielerposition geprüft
#define INTERVAL_DISTANCE_CHECK 15

["missionStarted",
{
    [] call FUNC(setup_classnames);

    player addEventHandler ["Take", {_this call FUNC(weaponCheck)}];

    // EH für Positionssperre in Fahrzeugen beim Einsteigen
    player addEventHandler ["GetInMan", 
    {
        /*  
            unit: Object - Unit the event handler is assigned to
            position: String - Can be either "driver", "gunner" or "cargo"
            vehicle: Object - Vehicle the unit entered
            turret: Array - turret path
        */
        params ["_unit", "_pos", "_vec", "_turret"];

        if (!(OPT_SECTORCONTROL_trainingon)) then 
        {
            if (!(typeOf _unit in GVAR(pilots))) then 
            {
                if (_vec isKindOf "Air" && _pos in GVAR(blockedVehiclePositions_air)) then 
                {
                    if (!(typeOf _vec in ["Steerable_Parachute_F", "NonSteerable_Parachute_F"])) then 
                    {
                        _unit action ["GetOut", _vec];
                        private _txt = MLOC(SLOT_LOCK_PILOT);
                        private _header = MLOC(SLOT_LOCK);
                        hint format ["%1\n\n%2", _header, _txt];
                    };
                };
            };
        };

        if (!(OPT_SECTORCONTROL_trainingon)) then 
        {
            if (!(typeOf _unit in GVAR(crew))) then 
            {
                if (_pos in GVAR(blockedVehiclePositions_veh)) then 
                {
                    if (typeOf _vec in GVAR(crew_vecs) || _vec isKindOf "Tank") then 
                    {
                        _unit action ["GetOut", _vec];
                        private _txt = MLOC(SLOT_LOCK_CREW);
                        private _header = MLOC(SLOT_LOCK);
                        hint format ["%1\n\n%2", _header, _txt];
                    };
                };
            };
        };
    }];
    
    // EH für Positionssperre in Fahrzeugen bei Platztausch
    player addEventHandler ["SeatSwitchedMan", 
    {
        /*  
            unit1: Object - Unit switching seat.
            unit2: Object - Unit with which unit1 is switching seat.
            vehicle: Object - Vehicle where switching seats is taking place.
        */
        params ["_unit1", "_unit2", "_vec"];

        if (!(OPT_SECTORCONTROL_trainingon)) then 
        {
            if (!(typeOf _unit1 in GVAR(pilots))) then 
            {
                if (_vec isKindOf "Air" && (assignedVehicleRole  _unit1 select 0) in GVAR(blockedVehiclePositions_air)) then 
                {
                    if (!(typeOf _vec in ["Steerable_Parachute_F", "NonSteerable_Parachute_F"])) then 
                    {
                        _unit1 action ["GetOut", _vec];
                        _txt = MLOC(SLOT_LOCK_PILOT);
                        private _header = MLOC(SLOT_LOCK);
                        hint format ["%1\n\n%2", _header, _txt];
                    };
                };
            };

            if (!(typeOf _unit1 in GVAR(crew))) then 
            {
                if ( (assignedVehicleRole _unit1 select 0) in GVAR(blockedVehiclePositions_veh)) then 
                {
                    if (typeOf _vec in GVAR(crew_vecs) || _vec isKindOf "Tank") then 
                    {
                        _unit1 action ["GetOut", _vec];
                        _txt = MLOC(SLOT_LOCK_CREW);
                        private _header = MLOC(SLOT_LOCK);
                        hint format ["%1\n\n%2", _header, _txt];
                    };
                };
            };
        };
    }];

    // EH für Sprengmeister
    player addEventHandler ["FiredMan", 
    {
        /* 
            0 unit: Object - Unit the event handler is assigned to (the instigator)
            1 weapon: String - Fired weapon
            2 muzzle: String - Muzzle that was used
            3 mode: String - Current mode of the fired weapon
            4 ammo: String - Ammo used
            5 magazine: String - magazine name which was used
            6 projectile: Object - Object of the projectile that was shot out
            7 vehicle: Object - Vehicle, if weapon is vehicle weapon, otherwise objNull
        */
        if ((_this select 1 == "Put") and !(typeOf player in GVAR(pioniers)) and !(((_this select 5) isEqualTo "SatchelCharge_Remote_Mag") or ((_this select 5) isEqualTo "DemoCharge_Remote_Mag") or ((_this select 5) isEqualTo "ClaymoreDirectionalMine_Remote_Mag"))) then
        {
            // lösche Mine
            deleteVehicle (_this select 6);
            // gib Spieler Mine zurück
            player addMagazine (_this select 5);
            // Warnhinweis
            private _txt = MLOC(PLACE_MINE);
            private _header = MLOC(RULE_VIOLATION);
            hint format ["%1\n\n%2", _header, _txt];
        };  
    }];

    // UAV Drohenstation kontrolle
    // [] call FUNC(uav);

    // Hint Meldung das Zuschauerslot besetzt wurde. 
    if ((player isKindOf "VirtualSpectator_F") or (player isKindOf "ace_spectator_virtual")) then 
    {
        private _txt = format["Spieler %1 hat einen Zuschauerslot ausgewählt.", name player];
        [_txt] remoteExecCall ["hint", 0, false];
    };

    // Regelmäßig checken ob sich der Spieler außerhalb der Karte aufhält (Livonia = 12800 x 12800)
    [{
        private _posX = (getPos player) select 0;
        private _posY = (getPos player) select 1;
        if ((_posX < 0) or (_posX > 12800) or (_posY < 0) or (_posY > 12800)) then
        {
            player setDamage 1;
            [MLOC(PLAYER_OUT_OF_MAP)] remoteExecCall ["hint", -2]; 
        };
    }, INTERVAL_DISTANCE_CHECK] call CFUNC(addPerFrameHandler);

    // Regelmäßig checken ob sich der Spieler in einem verbotenen Bereich in der nähe einer Feindlichen Basis aufhält
    switch OPT_GELDZEIT_Fraktionauswahl do 
    {
        case "AAFvsCSAT":
        {
            switch playerSide do
            {
                case east:
                {
                    [{
                        if (((player distance2D getMarkerPos "AAF_T_Zone1") < MIN_DISTANCE_TO_ENEMYBASE) or ((player distance2D getMarkerPos "AAF_T_Zone2") < MIN_DISTANCE_TO_ENEMYBASE)) then
                        {
                            player setDamage 1;
                            [MLOC(BASE_DISTANCE)] remoteExecCall ["hint", -2]; 
                        };
                    }, INTERVAL_DISTANCE_CHECK] call CFUNC(addPerFrameHandler);
                };

                case independent:
                {
                    [{
                        if (((player distance2D getMarkerPos "CSAT_T_Zone1") < MIN_DISTANCE_TO_ENEMYBASE) or ((player distance2D getMarkerPos "CSAT_T_Zone2") < MIN_DISTANCE_TO_ENEMYBASE)) then
                        {
                            player setDamage 1;
                            [MLOC(BASE_DISTANCE)] remoteExecCall ["hint", -2]; 
                        };
                    }, INTERVAL_DISTANCE_CHECK] call CFUNC(addPerFrameHandler);
                };
            };
        };

        case "NATOvsCSAT":
        {
            switch playerSide do
            {
                case east:
                {
                    [{
                        if (((player distance2D getMarkerPos "NATO_T_Zone1") < MIN_DISTANCE_TO_ENEMYBASE) or ((player distance2D getMarkerPos "NATO_T_Zone2") < MIN_DISTANCE_TO_ENEMYBASE)) then
                        {
                            player setDamage 1;
                            [MLOC(BASE_DISTANCE)] remoteExecCall ["hint", -2]; 
                        };
                    }, INTERVAL_DISTANCE_CHECK] call CFUNC(addPerFrameHandler);
                };

                case west:
                {
                    [{
                        if (((player distance2D getMarkerPos "CSAT_T_Zone1") < MIN_DISTANCE_TO_ENEMYBASE) or ((player distance2D getMarkerPos "CSAT_T_Zone2") < MIN_DISTANCE_TO_ENEMYBASE)) then
                        {
                            player setDamage 1;
                            [MLOC(BASE_DISTANCE)] remoteExecCall ["hint", -2]; 
                        };
                    }, INTERVAL_DISTANCE_CHECK] call CFUNC(addPerFrameHandler);
                };
            };
        };

        case "NATOvsAAF":
        {
            switch playerSide do
            {
                case independent:
                {
                    [{
                        if (((player distance2D getMarkerPos "NATO_T_Zone1") < MIN_DISTANCE_TO_ENEMYBASE) or ((player distance2D getMarkerPos "NATO_T_Zone2") < MIN_DISTANCE_TO_ENEMYBASE)) then
                        {
                            player setDamage 1;
                            [MLOC(BASE_DISTANCE)] remoteExecCall ["hint", -2]; 
                        };
                    }, INTERVAL_DISTANCE_CHECK] call CFUNC(addPerFrameHandler);
                };

                case west:
                {
                    [{
                        if (((player distance2D getMarkerPos "AAF_T_Zone1") < MIN_DISTANCE_TO_ENEMYBASE) or ((player distance2D getMarkerPos "AAF_T_Zone2") < MIN_DISTANCE_TO_ENEMYBASE)) then
                        {
                            player setDamage 1;
                            [MLOC(BASE_DISTANCE)] remoteExecCall ["hint", -2]; 
                        };
                    }, INTERVAL_DISTANCE_CHECK] call CFUNC(addPerFrameHandler);
                };
            };
        };

        default 
        {
            ERROR_LOG("RulesClientInit: Fehlerhafte Datenübergabe - Keine Fraktionauswahl erkannt");
        };
    };
}] call CFUNC(addEventhandler);
