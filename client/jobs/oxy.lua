local eventHandlers = {}
local _state = 0
local _joiner = nil
local _working = false
local _blip = nil
local _blipArea = nil
local _l = nil
local _v = nil
local _entered = nil
local _psychoShit = nil
local _inPoly = false
local _fuckedOff = false

local _queueLoc = nil
RegisterNetEvent("Labor:Client:GetLocs", function(locs)
    _queueLoc = locs.oxy or {}
end)

AddEventHandler("Labor:Client:Setup", function()
    plsr.State.flags.inOxyPickup = false
    plsr.State.flags.inOxySell = false

    while _queueLoc == nil do
        Wait(10)
    end

    if _queueLoc.coords == nil then return end
	plsr.PedInteraction:Add("OxyRunner", `s_m_m_movspace_01`,  _queueLoc.coords, _queueLoc.heading, 25.0, {
		{
			icon = "tablets",
			text = "Want a Job to do?",
			event = "OxyRun:Client:Enable",
            data = {},
            isEnabled = function()
                return not hasValue(plsr.State.character.States or {}, "SCRIPT_OXY_RUN") and plsr.State.flags.onDuty ~= "police"
            end,
		},
	}, 'question', 'WORLD_HUMAN_HUMAN_STATUE')

    plsr.Callbacks:RegisterClientCallback("OxyRun:GetSpawn", function(data, cb)
        if not plsr.State.flags.inOxySell then
            cb(false)
            return
        end

        local offset = GetOffsetFromEntityInWorldCoords(PlayerPedId(), math.random(-20, 20) + 0.0, math.random(-20, 20) + 0.0, 0.0)
        local success, spawn, heading = GetNthClosestVehicleNodeFavourDirection(offset.x, offset.y, offset.z, _l.coords.x, _l.coords.y, _l.coords.z, 20, 0, 0x40400000, 0)

        RequestModel(data.ped)
        local timeout = 0
        while not HasModelLoaded(data.ped) do 
            if timeout >= 10000 then
                print('failed to load ped model, please report this: ' .. data.ped)
                return cb(false)
            end
            Wait(10)
            timeout += 10
        end

        local lol = {}
        plsr.Game.Vehicles:Spawn(spawn, data.veh, heading, function(vehicle)
            print('oxy vehicle: ', vehicle)
            if vehicle and DoesEntityExist(vehicle) then
                SetVehicleDoorsLockedForAllPlayers(vehicle, true)
                local driver = CreatePedInsideVehicle(vehicle, 6, data.ped, -1, true, true)
                SetDriverAbility(driver, 1.0)
                SetDriverAggressiveness(driver, 0.0)
                SetPedKeepTask(driver, true)
                TaskVehicleDriveToCoord(
                    driver,
                    vehicle,
                    _l.coords.x,
                    _l.coords.y,
                    _l.coords.z,
                    12.0,
                    1,
                    data.veh,
                    786603,
                    11.0,
                    true
                )
    
                CreateThread(function()
                    local dist = #(_l.coords - GetEntityCoords(vehicle))
                    
                    local arrived = false
                    local forceEnd = false

                    SetTimeout(180000, function()
                        if not arrived then
                            forceEnd = true
                        end
                    end)

                    while dist > 15.0 and _l ~= nil and vehicle and DoesEntityExist(vehicle) and not forceEnd do
                        Wait(100)
                        if _l ~= nil then
                            dist = #(_l.coords - GetEntityCoords(vehicle))
                        end
                    end
                    arrived = true
    
                    Wait(25000)
                    if forceEnd or _psychoShit ~= nil and _psychoShit.veh == VehToNet(vehicle) and not _fuckedOff then
                        _fuckedOff = true
                        TaskVehicleDriveWander(NetToPed(_psychoShit.ped), NetToVeh(_psychoShit.veh), 20.0, 786603)
                        Citizen.SetTimeout(30000, function()
                            plsr.Callbacks:ServerCallback("OxyRun:DeleteShit", _psychoShit)
                        end)
                    end
                end)
    
                cb(VehToNet(vehicle), PedToNet(driver))
            else
                cb(false)
            end
        end)
    end)
end)

-- AddEventHandler("gameEventTriggered", function(name, args)
-- 	if name == "CEventNetworkVehicleUndrivable" then
-- 	  local entity, destoyer, weapon = table.unpack(args)
  
--       if (_v ~= nil) then
--         print(string.format("event: %s, trigger: %s, triggerNet: %s", tostring(_v?.ent), entity, NetToVeh(entity)))
--       end

--       if (_v?.ent == entity or _v?.ent == NetToVeh(entity)) then
--         print("Entity is oxy run car")
--         plsr.Callbacks:ServerCallback("OxyRun:DestroyVehicle")
--       end
-- 	end
-- end)

RegisterNetEvent("OxyRun:Client:OnDuty", function(joiner, time)
	_joiner = joiner
    plsr.State.flags.oxyJoiner = joiner
    _working = true
    _fuckedOff = false

    eventHandlers["primary_action"] = AddEventHandler("Keybinds:Client:KeyUp:primary_action", function()
        if _working and _state == 3 and plsr.State.flags.inOxyPickup and not plsr.State.flags.doingAction then
            local veh = GetVehiclePedIsIn(PlayerPedId())
            if veh == _v.ent and GetPedInVehicleSeat(_v.ent, -1) == PlayerPedId() then
                plsr.Action:Hide("oxysale")
                plsr.Callbacks:ServerCallback("OxyRun:CheckPickup", {}, function(s)
                    if s then
                        plsr.Progress:ProgressWithTickEvent({
                            name = 'oxy_pickup',
                            duration = 10000,
                            label = 'Waiting',
                            tickrate = 990,
                            useWhileDead = false,
                            canCancel = false,
                            vehicle = true,
                            ignoreModifier = true,
                            controlDisables = {
                                disableMovement = true,
                                disableCarMovement = true,
                                disableCombat = true,
                            },
                        }, function()
                            local veh = GetVehiclePedIsIn(PlayerPedId())
                            if _state ~= 3 or veh ~= _v.ent or GetPedInVehicleSeat(_v.ent, -1) ~= PlayerPedId() then
                                plsr.Progress:Cancel()
                                plsr.Callbacks:ServerCallback("OxyRun:CancelPickup")
                                return
                            end
        
                            plsr.Callbacks:ServerCallback("OxyRun:PickupProduct")
                        end, function(cancelled)
        
                        end)
                    else
                        plsr.Notification:Error("Not Enough Room In Your Trunk")
                    end
                end)
            end
        end
    end)

	eventHandlers["poly-enter"] = AddEventHandler("Polyzone:Enter", function(id, testedPoint, insideZones, data)
        if _working and id == "OxyPickup" then
            plsr.State.flags.inOxyPickup = true
            if _state == 2 then
                plsr.Callbacks:ServerCallback("OxyRun:EnteredPickup")
            else
                local veh = GetVehiclePedIsIn(PlayerPedId())
                if _state == 3 and veh == _v.ent and GetPedInVehicleSeat(_v.ent, -1) == PlayerPedId() then
                    plsr.Action:Show("oxysale", "{keybind}primary_action{/keybind} Load Product")
                end
            end
        elseif _working and id == "OxySale" then
            plsr.State.flags.inOxySell = true
        end
    end)

	eventHandlers["poly-exit"] = AddEventHandler("Polyzone:Exit", function(id, testedPoint, insideZones, data)
        if _working and id == "OxyPickup" then
            plsr.State.flags.inOxyPickup = false
            plsr.Action:Hide("oxysale")
        elseif _working and id == "OxySale" and plsr.State.flags.loggedIn then
            plsr.State.flags.inOxySell = false
            plsr.Callbacks:ServerCallback("OxyRun:LeftZone")
        end
    end)

	eventHandlers["entered-car"] = RegisterNetEvent('Vehicles:Client:EnterVehicle', function(veh)
        plsr.Callbacks:ServerCallback("OxyRun:EnteredCar", {
            VIN = plsr.State.Entity(veh).VIN,
            NetId = VehToNet(veh),
            Class = GetVehicleClass(veh),
            Model = GetEntityModel(veh),
        })
    end)

	eventHandlers["receive"] = RegisterNetEvent(string.format("OxyRun:Client:%s:Receive", joiner), function(location)
        _state = 1
	end)

	eventHandlers["start-pickup"] = RegisterNetEvent(string.format("OxyRun:Client:%s:StartPickup", joiner), function(pu, veh)
        _state = 2
        _v = veh
        _v.ent = NetToVeh(_v.NetId)
        
        DeleteWaypoint()
        SetNewWaypoint(pu.coords.x, pu.coords.y)
        _blip = plsr.Blips:Add("OxyRun", "Oxy Pickup", { x = pu.coords.x, y = pu.coords.y, z = pu.coords.z }, 51, 64, 0.9)
        plsr.Polyzone.Create:Box("OxyPickup", pu.coords, pu.length, pu.width, pu.options)

        CreateThread(function()
            local ending = false
            while _working and _v ~= nil do
                if not ending then
                    if _v?.ent ~= nil and DoesEntityExist(_v.ent) then
                        if GetEntityHealth(_v.ent) == 0 or not IsVehicleDriveable(_v.ent) then
                            plsr.Logger:Trace("OxyRun", "Vehicle Health 0 or Not Drivable")
                            ending = true
                            plsr.Callbacks:ServerCallback("OxyRun:DestroyVehicle")
                        end
                    end
                end
                Wait(10)
            end
        end)
	end)

	eventHandlers["eligible-pickup"] = RegisterNetEvent(string.format("OxyRun:Client:%s:EligiblePickup", joiner), function()
        _state = 3
        local veh = GetVehiclePedIsIn(PlayerPedId())
        if plsr.State.flags.inOxyPickup and veh == _v.ent and GetPedInVehicleSeat(_v.ent, -1) == PlayerPedId() then
            plsr.Action:Show("oxysale", "{keybind}primary_action{/keybind} Load Product")
        end
	end)

	eventHandlers["start-sale"] = RegisterNetEvent(string.format("OxyRun:Client:%s:StartSale", joiner), function(location)
        _state = 4
        _l = location

        DeleteWaypoint()
        SetNewWaypoint(_l.coords.x, _l.coords.y)

        if _blip then
            plsr.Blips:Remove("OxyRun")
        end
        _blip = plsr.Blips:Add("OxyRun", "Oxy Sale", { x = _l.coords.x, y = _l.coords.y, z = _l.coords.z }, 51, 64, 0.9)

		_blipArea = AddBlipForRadius(_l.coords.x, _l.coords.y, _l.coords.maxZ, _l.radius + 0.0)
		SetBlipColour(_blipArea, 3)
		SetBlipAlpha(_blipArea, 90)

		plsr.Polyzone.Create:Circle("OxySale", _l.coords, _l.radius, _l.options)

        CreateThread(function()
            while _working and _state == 4 do
                local dist = #(vector3(plsr.State.flags.position.x, plsr.State.flags.position.y, plsr.State.flags.position.z) - _l.coords)
                if dist <= 10.0 then
                    plsr.Callbacks:ServerCallback("OxyRun:EnteredArea")
                end
                Wait(10 * dist)
            end
        end)
	end)

	eventHandlers["near"] = RegisterNetEvent(string.format("OxyRun:Client:%s:Near", joiner), function(data)
        _state = 5
	end)

	eventHandlers["spawned"] = RegisterNetEvent(string.format("OxyRun:Client:%s:Spawn", joiner), function(data)
        plsr.State.flags.oxyBuyer = data
        _fuckedOff = false
        _psychoShit = data
	end)

	eventHandlers["action"] = RegisterNetEvent(string.format("OxyRun:Client:%s:Action", joiner), function()
        plsr.State.flags.oxyBuyer = nil
	end)

	eventHandlers["target"] = RegisterNetEvent("OxyRun:Client:MakeSale", function(data)
        local pda = math.random(100)
        if pda >= 60 then
            plsr.EmergencyAlerts:CreateIfReported(100.0, "oxysale", true)
        end

        local c = deepcopy(plsr.State.flags.oxyBuyer)
        plsr.Callbacks:ServerCallback("OxyRun:SellProduct", _psychoShit.veh, function(s)
            if (s) then
                loadAnimDict( "mp_safehouselost@" )
                TaskPlayAnim( PlayerPedId(), "mp_safehouselost@", "package_dropoff", 8.0, 1.0, -1, 16, 0, 0, 0, 0 )  
            end

            Wait(8000)

            _fuckedOff = true
            TaskVehicleDriveWander(NetToPed(_psychoShit.ped), NetToVeh(_psychoShit.veh), 20.0, 786603)
            local wait = math.random(30, 100) * 1000
            Citizen.SetTimeout(wait, function()
                plsr.Callbacks:ServerCallback("OxyRun:DeleteShit", _psychoShit)
            end)
        end)
	end)

	eventHandlers["end-sale"] = RegisterNetEvent(string.format("OxyRun:Client:%s:EndSale", joiner), function()
        _state = 6
        if _blip then
            plsr.Blips:Remove("OxyRun")
        end
        RemoveBlip(_blipArea)
	end)

    eventHandlers["veh-poofed"] = RegisterNetEvent(string.format("OxyRun:Client:%s:VehiclePoofed", joiner), function()
        plsr.Callbacks:ServerCallback("OxyRun:VehiclePoofed")
	end)
end)

AddEventHandler("OxyRun:Client:Enable", function()
    plsr.Callbacks:ServerCallback('OxyRun:Enable', {})
end)

AddEventHandler("OxyRun:Client:TurnIn", function()
    plsr.Callbacks:ServerCallback('OxyRun:TurnIn', _joiner)
end)

AddEventHandler("OxyRun:Client:StartJob", function()
    plsr.Callbacks:ServerCallback('OxyRun:StartJob', _joiner, function(state)
		if not state then
			plsr.Notification:Error("Unable To Start Job")
		end
    end)
end)

RegisterNetEvent("OxyRun:Client:OffDuty", function(time)
	for k, v in pairs(eventHandlers) do
		RemoveEventHandler(v)
	end

    DeleteWaypoint()

    plsr.Polyzone:Remove("OxyPickup")
    plsr.Polyzone:Remove("OxySale")
    if _blip then
        plsr.Blips:Remove("OxyRun")
    end

    if _blipArea then
        RemoveBlip(_blipArea)
    end

    plsr.State.flags.oxyBuyer = nil
    plsr.State.flags.oxyJoiner = nil

    eventHandlers = {}
    _state = 0
    _joiner = nil
    _working = false
    _blip = nil
    _blipArea = nil
    _l = nil
    _v = nil
    _entered = nil
    _psychoShit = nil
    _inPoly = false
    _fuckedOff = false
end)