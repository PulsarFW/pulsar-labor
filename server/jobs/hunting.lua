local _JOB = "Hunting"
local _joiners = {}
local _hunting = {}

local _baitCds = {}

local _saleData = {
	[1] = { rep = 4, price = 750, item = "hide_tier1" },
	[2] = { rep = 5, price = 1500, item = "hide_tier2" },
	[3] = { rep = 6, price = 2000, item = "hide_tier3" },
	[4] = { rep = 7, price = 3500, item = "hide_tier4" },
}

AddEventHandler("Labor:Server:Startup", function()
	RegisterHuntingItems()

	plsr.Middleware:Add("Characters:Spawning", function(source)
		TriggerClientEvent("Hunting:Client:Polys", source, HuntingConfig)
	end)

	plsr.Vendor:Create("HuntingBaits", false, "Hunting", false, {}, {
		{ id = 1, item = "cow_bait", price = 250, qty = -1, vpn = false, rep = "Hunting", repLvl = 2, },
		{ id = 2, item = "chicken_bait", price = 250, qty = -1, vpn = false, rep = "Hunting", repLvl = 2, },
		{ id = 3, item = "rabbit_bait", price = 250, qty = -1, vpn = false, rep = "Hunting", repLvl = 2, },
		{ id = 4, item = "pig_bait", price = 250, qty = -1, vpn = false, rep = "Hunting", repLvl = 2, },
		{ id = 5, item = "boar_bait", price = 250, qty = -1, vpn = false, rep = "Hunting", repLvl = 4, },
		{ id = 6, item = "deer_bait", price = 250, qty = -1, vpn = false, rep = "Hunting", repLvl = 4, },
		{ id = 7, item = "exotic_bait", price = 1000, qty = -1, vpn = false, rep = "Hunting", repLvl = 7, },
	}, "dollar-sign", "Hunting")

	plsr.Callbacks:RegisterServerCallback("Hunting:StartJob", function(source, data, cb)
		if _hunting[data] ~= nil and _hunting[data].state == 0 then
			_hunting[_joiners[source]].state = 1
			plsr.Labor.Offers:Start(_joiners[source], _JOB, "Harvest Animals", 6)
			TriggerClientEvent(string.format("Hunting:Client:%s:Startup", data), -1)
			cb(true)
		else
			cb(false)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Hunting:FinishJob", function(source, data, cb)
		if _joiners[source] ~= nil and _hunting[_joiners[source]].state == 2 then
			_hunting[_joiners[source]].state = 3
			plsr.Labor.Workgroups:SendEvent(_joiners[source], string.format("Hunting:Client:%s:FinishJob", _joiners[source]))
			plsr.Labor.Offers:ManualFinish(_joiners[source], _JOB)
			cb(true)
		else
			cb(false)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Hunting:HarvestAnimal", function(source, data, cb)
		local char = plsr.Fetch:CharacterSource(source)
		local luck = math.random(100)
		local animal = data.animal
		local isSpawned = data.isSpawned
		if
			char:GetData("TempJob") ~= _JOB
			or _joiners[source] == nil
			or (_joiners[source] ~= nil and _hunting[_joiners[source]]) ~= nil
		then
			luck = luck - 25
		end

		if isSpawned then -- Only Allow Hides for Baited Animals
			if luck >= 90 then
				plsr.Inventory:AddItem(char:GetData("SID"), "hide_tier4", 1, {}, 1)
			elseif luck >= 80 then
				plsr.Inventory:AddItem(char:GetData("SID"), "hide_tier3", 1, {}, 1)
			elseif luck >= 70 then
				plsr.Inventory:AddItem(char:GetData("SID"), "hide_tier2", 1, {}, 1)
			elseif luck >= 50 then
				plsr.Inventory:AddItem(char:GetData("SID"), "hide_tier1", 1, {}, 1)
			end
		end

		if #HuntingSrvConfig.Loot[animal] > 0 then
			plsr.Loot:CustomSetWithCount(HuntingSrvConfig.Loot[animal], char:GetData("SID"), 1)
		end

		if char:GetData("TempJob") == _JOB and _joiners[source] ~= nil and _hunting[_joiners[source]] ~= nil then
			if plsr.Labor.Offers:Update(_joiners[source], _JOB, 1, true) then
				_hunting[_joiners[source]].state = 2
				plsr.Labor.Offers:Task(_joiners[source], _JOB, "Talk To The Shop Owner")
				plsr.Labor.Workgroups:SendEvent(_joiners[source], string.format("Hunting:Client:%s:Finish", _joiners[source]))
			end
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Hunting:GenerateAnimal", function(source, data, cb)
		plsr.Callbacks:ClientCallback(source, "Polyzone:GetAllZonesPlayerIn", {}, function(zones)
			local found = false
			for _, zone in ipairs(zones) do
				if zone and string.sub(zone.id, 1, string.len("hunting")) == "hunting" then
					local zoneId = tonumber(string.sub(zone.id, string.len("hunting") + 1))
					if HuntingConfig.Zones[zoneId] ~= nil then
						local anims = {}
						for k, v in ipairs(HuntingConfig.Baits[data].animals) do
							local animData = HuntingConfig.Animals[v]
							if not animData.Illegal or (animData.Illegal and HuntingConfig.Zones[zoneId].illegal) then
								table.insert(anims, animData)
							end
						end
						local animal = anims[math.random(#anims)]
						cb({
							animal = animal,
							isIllegal = HuntingConfig.Zones[zoneId].illegal,
						})

						found = true
						break
					end
				end
			end

			if not found then
				plsr.Execute:Client(source, "Notification", "Error", "Not Allowed To Hunt Here")
			end
		end)
	end)

	plsr.Callbacks:RegisterServerCallback("Hunting:Sell", function(source, data, cb)
		local char = plsr.Fetch:CharacterSource(source)
		local repLvl = plsr.Reputation:GetLevel(source, _JOB)

		if _saleData[data] ~= nil then
			if repLvl >= _saleData[data].rep then
				local count = plsr.Inventory.Items:GetCount(char:GetData("SID"), 1, _saleData[data].item) or 0
				if count > 0 then
					if plsr.Inventory.Items:Remove(char:GetData("SID"), 1, _saleData[data].item, count) then
						plsr.Wallet:Modify(source, _saleData[data].price * count)
					end
				else
					plsr.Execute:Client(source, "Notification", "Error", "You Have No Hides Of That Tier")
				end
			else
				plsr.Execute:Client(source, "Notification", "Error", "You Must Prove Yourself First")
			end
		end
	end)
end)

function RegisterHuntingItems()
	plsr.Inventory.Items:RegisterUse("hunting_map_dark", "HuntingMap", function(source, itemData)
		if itemData then
			plsr.Callbacks:ClientCallback(source, "Hunting:Client:CanShowMap", itemData, function(canShow)
				TriggerClientEvent("Hunting:Client:ShowMap", source, itemData)
			end)
		end
	end)
	plsr.Inventory.Items:RegisterUse("hunting_map_light", "HuntingMap", function(source, itemData)
		if itemData then
			plsr.Callbacks:ClientCallback(source, "Hunting:Client:CanShowMap", itemData, function(canShow)
				TriggerClientEvent("Hunting:Client:ShowMap", source, itemData)
			end)
		end
	end)

	for k, v in pairs(HuntingConfig.Baits) do
		plsr.Inventory.Items:RegisterUse(k, "Hunting", function(source, item)
			if
				_baitCds[source] == nil
				or (os.time() - _baitCds[source]) >= HuntingConfig.Baits[item.Name].cooldown * 60
			then
				local char = plsr.Fetch:CharacterSource(source)
				plsr.Callbacks:ClientCallback(source, "Polyzone:GetAllZonesPlayerIn", {}, function(zones)
					local found = false
					for _, zone in ipairs(zones) do
						if zone and string.sub(zone.id, 1, string.len("hunting")) == "hunting" then
							local zoneId = tonumber(string.sub(zone.id, string.len("hunting") + 1))
							if HuntingConfig.Zones[zoneId] ~= nil then
								plsr.Callbacks:ClientCallback(source, "Hunting:PlaceTrap", item.Name, function(successful)
									if successful then
										_baitCds[source] = os.time()
										plsr.Inventory.Items:RemoveSlot(item.Owner, item.Name, 1, item.Slot, 1)
									end
								end)

								found = true
								break
							end
						end
					end

					if not found then
						plsr.Execute:Client(source, "Notification", "Error", "Not Allowed To Hunt Here")
					end
				end)
			else
				plsr.Execute:Client(source, "Notification", "Error", "You Cannot Use Bait Yet")
			end
		end)
	end
end

AddEventHandler("Hunting:Server:OnDuty", function(joiner, members, isWorkgroup)
	_joiners[joiner] = joiner
	_hunting[joiner] = {
		joiner = joiner,
		isWorkgroup = isWorkgroup,
		started = os.time(),
		state = 0,
	}

	local char = plsr.Fetch:CharacterSource(joiner)
	char:SetData("TempJob", _JOB)
	plsr.Phone.Notification:Add(joiner, "Job Activity", "You started a job", os.time(), 6000, "labor", {})
	TriggerClientEvent("Hunting:Client:OnDuty", joiner, joiner, os.time())

	plsr.Labor.Offers:Task(joiner, _JOB, "Talk To The Shop Owner")
	if #members > 0 then
		for k, v in ipairs(members) do
			_joiners[v.ID] = joiner
			local member = plsr.Fetch:CharacterSource(v.ID)
			member:SetData("TempJob", _JOB)
			plsr.Phone.Notification:Add(v.ID, "Job Activity", "You started a job", os.time(), 6000, "labor", {})
			TriggerClientEvent("Hunting:Client:OnDuty", v.ID, joiner, os.time())
		end
	end
end)

AddEventHandler("Hunting:Server:OffDuty", function(source, joiner)
	_joiners[source] = nil
	TriggerClientEvent("Hunting:Client:OffDuty", source)
end)

AddEventHandler("Hunting:Server:FinishJob", function(joiner)
	_hunting[joiner] = nil
end)
