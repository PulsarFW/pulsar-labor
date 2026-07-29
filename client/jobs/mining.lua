local _joiner = nil
local _working = false
local _blips = {}
local eventHandlers = {}

local _nodes = nil

local _sellers = {
  {
    coords = vector3(-619.496, -225.697, 37.057),
    heading = 130.523,
    model = `a_f_y_clubcust_02`,
  },
  {
    coords = vector3(232.280, 373.679, 105.142),
    heading = 162.529,
    model = `csb_popov`,
  },
}

local miningSoundThread = false

AddEventHandler("Labor:Client:Setup", function()
  for k, v in ipairs(_sellers) do
    plsr.PedInteraction:Add(string.format("GemSeller%s", k), v.model, v.coords, v.heading, 25.0, { 
      {
        icon = "sack-dollar",
        text = "Sell Diamonds",
        event = "Mining:Client:SellGem",
        data = "diamond",
        item = "diamond",
        rep = { id = "Mining", level = 5 },
      },
      {
        icon = "sack-dollar",
        text = "Sell Emeralds",
        event = "Mining:Client:SellGem",
        data = "emerald",
        item = "emerald",
        rep = { id = "Mining", level = 5 },
      },
      {
        icon = "sack-dollar",
        text = "Sell Sapphire",
        event = "Mining:Client:SellGem",
        data = "sapphire",
        item = "sapphire",
        rep = { id = "Mining", level = 4 },
      },
      {
        icon = "sack-dollar",
        text = "Sell Ruby",
        event = "Mining:Client:SellGem",
        data = "ruby",
        item = "ruby",
        rep = { id = "Mining", level = 3 },
      },
      {
        icon = "sack-dollar",
        text = "Sell Amethyst",
        event = "Mining:Client:SellGem",
        data = "amethyst",
        item = "amethyst",
        rep = { id = "Mining", level = 2 },
      },
      {
        icon = "sack-dollar",
        text = "Sell Citrine",
        event = "Mining:Client:SellGem",
        data = "citrine",
        item = "citrine",
        rep = { id = "Mining", level = 1 },
      },
      {
        icon = "sack-dollar",
        text = "Sell Opal",
        event = "Mining:Client:SellGem",
        data = "opal",
        item = "opal",
        rep = { id = "Mining", level = 1 },
      },
    }, 'gem')
  end

  plsr.PedInteraction:Add("MiningJob", `s_m_y_construct_02`, vector3(2741.874, 2791.691, 34.214), 155.045, 25.0, {
    {
      icon = "hand-holding-dollar",
      text = "Sell Crushed Stone ($3/per)",
      event = "Mining:Client:SellStone",
    },
    {
      icon = "helmet-safety",
      text = "Start Work",
      event = "Mining:Client:StartJob",
      tempjob = "Mining",
      isEnabled = function()
        return not _working
      end,
    },
    {
      icon = "dollar-sign",
      text = "Buy Pickaxe ($250)",
      event = "Mining:Client:PuchaseAxe",
      tempjob = "Mining",
    },
    {
      icon = "handshake-angle",
      text = "Turn In Ore",
      event = "Mining:Client:TurnIn",
      tempjob = "Mining",
      isEnabled = function()
        return _working
      end,
    },
  }, 'helmet-safety')

  plsr.Callbacks:RegisterClientCallback("Mining:DoTheThingBrother", function(item, cb)
    local lastCooldown = GetGameTimer()

    MiningRockSound()

    plsr.Progress:ProgressWithTickEvent({
      name = "mining_action",
      duration = math.random(13, 35) * 1000,
      label = "Mining Ore",
      useWhileDead = false,
      canCancel = true,
      vehicle = false,
      controlDisables = {
        disableMovement = true,
        disableCarMovement = true,
        disableCombat = true,
      },
      animation = {
        animDict = "melee@large_wpn@streamed_core",
        anim = "ground_attack_on_spot",
        flags = 1
      },
      prop = {
        model = "prop_tool_pickaxe",
        bone = 57005,
        coords = { x = 0.1, y = -0.1, z = -0.02 },
        rotation = { x = 80.0, y = 0.00, z = 170.0 },
      }
    }, function(pickaxeNetId)
      if NetworkDoesNetworkIdExist(pickaxeNetId) and NetworkDoesEntityExistWithNetworkId(pickaxeNetId) then
        local pickaxe = NetworkGetEntityFromNetworkId(pickaxeNetId)

        local animTime = round(
          GetEntityAnimCurrentTime(PlayerPedId(), "melee@large_wpn@streamed_core", "ground_attack_on_spot"), 2)

        if animTime == 0.35 then
          if GetGameTimer() - lastCooldown >= 150 then
            PlayParticleFx("core", "ent_dst_rocks", 50, 0.8, 0.0, 0.0, 1.0, pickaxe)

            plsr.Sounds.Play:Location(GetEntityCoords(pickaxe), 8.0, "dirt.ogg", 0.25)

            lastCooldown = GetGameTimer()
          end
        end
      end
    end, function(cancelled)
      miningSoundThread = false
      cb(not cancelled)
    end)
  end)
end)


local function putOresOnRock(rockIndex, rock)
  local ores = {}

  local rockModel = GetEntityModel(rock)

  for _, oreOffset in ipairs(Mining.Ores[rockModel]) do
    local randomOre = plsr.Utils:WeightedRandom({
      {
        15,
        {
          model = "prop_goldore_01",

          item = "goldore"
        }
      },
      {
        1,
        {
          model = "prop_rubyore_01",

          item = "ruby",

          count = 1
        }
      },
      {
        700,
        {
          model = "prop_ironore_01",

          item = "ironore"
        }
      },
      {
        275,
        {
          model = "prop_ironore_01",

          item = "chromite"
        }
      },
      {
        275,
        {
          model = "prop_ironore_01",

          item = "silverore"
        }
      },
    })

    local randomOreModel = GetHashKey(randomOre.model)

    while not HasModelLoaded(randomOreModel) do
      Wait(0)

      RequestModel(randomOreModel)
    end

    local randomStonePosition = GetOffsetFromEntityInWorldCoords(rock, oreOffset)

    local oreHandle = CreateObject(randomOreModel, randomStonePosition, false)

    SetEntityHeading(oreHandle, math.random(120) + 0.1)

    if IsEntityTouchingEntity(oreHandle, rock) then
      FreezeEntityPosition(oreHandle, true)

      table.insert(ores, oreHandle)

	  plsr.Targeting:AddEntity(oreHandle, "hill-rockslide", {
		{
			icon = "fas fa-circle-dot",
			text = "Mine Ore",
			event = "Mining:Client:MineOre",
			data = {
				index = rockIndex,
				ore = randomOre
			  }
		},
	})
    else
      DeleteEntity(oreHandle)
    end

    SetModelAsNoLongerNeeded(randomOreModel)
  end

  return ores
end


RegisterNetEvent("Mining:Client:MineOre", function(data, oreData)
  if plsr.Inventory.Check.Player:HasItem("pickaxe", 1) then
    plsr.Callbacks:ServerCallback('Mining:Server:MineOre', oreData, function(finishedMining)
      if finishedMining then
        DeleteEntity(data.entity)
      end
      miningSoundThread = false
    end)
  else
    plsr.Notification:Error("You Need A Pickaxe To Mine This.")
  end
end)

RegisterNetEvent("Mining:Client:OnDuty", function(joiner, time)
  _joiner = joiner
  DeleteWaypoint()
  SetNewWaypoint(2741.874, 2791.691)

  eventHandlers["startup"] = RegisterNetEvent(string.format("Mining:Client:%s:Startup", joiner), function(nodes)
    if _nodes ~= nil then return end

    _working = true
    _nodes = nodes

    local rockModels = {
      GetHashKey("prop_rock_3_j"),
      GetHashKey("prop_rock_4_a"),
      GetHashKey("prop_rock_1_f"),
      GetHashKey("prop_rock_3_h"),
      GetHashKey("prop_rock_1_i")
    }

    for k, v in pairs(_nodes) do
      local rockModel = rockModels[math.random(#rockModels)]

      while not HasModelLoaded(rockModel) do
        RequestModel(rockModel)

        Wait(0)
      end

      local rockHandle = CreateObject(rockModel, v.coords - vector3(0.0, 0.0, 1.0))

      PlaceObjectOnGroundProperly(rockHandle)

      FreezeEntityPosition(rockHandle, true)

      v.handle = rockHandle

      local ores = putOresOnRock(v.id, rockHandle)

      v.ores = ores

      plsr.Blips:Add(string.format("MiningNode-%s", v.id), "Mining Node", v.coords, 679, 18, 0.8)

      SetModelAsNoLongerNeeded(rockModel)
    end
  end)

  eventHandlers["actions"] = RegisterNetEvent(string.format("Mining:Client:%s:Action", joiner), function(data)
    for k, v in pairs(_nodes) do
      if v.id == data then
        plsr.Blips:Remove(string.format("MiningNode-%s", v.id))
        _nodes[k] = nil

        if v.handle and DoesEntityExist(v.handle) then
          DeleteEntity(v.handle)
        end

        if v.ores then
          for _, ore in ipairs(v.ores) do
            if ore and DoesEntityExist(ore) then
              DeleteEntity(ore)
            end
          end
        end

        break
      end
    end
  end)
end)

AddEventHandler("Mining:Client:SellStone", function()
  plsr.Callbacks:ServerCallback('Mining:SellStone', {}) 
end)

AddEventHandler("Mining:Client:PuchaseAxe", function()
  plsr.Callbacks:ServerCallback('Mining:PurchasePickaxe', {})
end)

AddEventHandler("Mining:Client:TurnIn", function()
  plsr.Callbacks:ServerCallback('Mining:TurnIn', _joiner)
end)

AddEventHandler("Mining:Client:SellGem", function(entity, data)
  plsr.Callbacks:ServerCallback("Mining:SellGem", data)
end)

AddEventHandler("Mining:Client:StartJob", function()
  plsr.Callbacks:ServerCallback('Mining:StartJob', _joiner, function(state)
    if not state then
      plsr.Notification:Error("Unable To Start Job") 
    end
  end)
end)

RegisterNetEvent("Mining:Client:OffDuty", function(time)
  for k, v in pairs(eventHandlers) do
    RemoveEventHandler(v)
  end

  if _nodes ~= nil then
    for k, v in pairs(_nodes) do
      plsr.Blips:Remove(string.format("MiningNode-%s", v.id)) 
    end
  end

  eventHandlers = {}
  _joiner = nil
  _working = false
  _nodes = nil
end)

function MiningRockSound()
  if miningSoundThread then return end
  miningSoundThread = true
  CreateThread(function()
    local soundTimeout = 2100
    while miningSoundThread do
      Wait(soundTimeout)
      if not miningSoundThread then break end
      plsr.Sounds.Do.Play:One('mining.ogg', 0.5)
    end
  end)
end
