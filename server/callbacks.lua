function RegisterCallbacks()
	plsr.Callbacks:RegisterServerCallback("Labor:GetJobs", function(source, data, cb)
		cb(plsr.Labor.Get:Jobs())
	end)
	plsr.Callbacks:RegisterServerCallback("Labor:GetGroups", function(source, data, cb)
		cb(plsr.Labor.Get:Groups())
	end)

	plsr.Callbacks:RegisterServerCallback("Labor:GetReputations", function(source, data, cb)
		cb(plsr.Reputation:View(source))
	end)

	plsr.Callbacks:RegisterServerCallback("Labor:AcceptRequest", function(source, data, cb)
		if _pendingInvites[data.source] ~= nil then
			local state = plsr.Labor.Workgroups:Join(_pendingInvites[data.source], data.source)

			if state then
				plsr.Phone.Notification:Add(
					data.source,
					"Job Activity",
					"You Joined A Workgroup",
					os.time(),
					6000,
					"labor",
					{}
				)
			end

			_pendingInvites[data.source] = nil
			cb(state)
		else
			cb(false)
		end
	end)

	plsr.Callbacks:RegisterServerCallback("Labor:DeclineRequest", function(source, data, cb)
		if _pendingInvites[data.source] ~= nil then
			_pendingInvites[data.source] = nil

			plsr.Phone.Notification:Add(
				data.source,
				"Job Activity",
				"Your Group Request Was Denied",
				os.time(),
				6000,
				"labor",
				{}
			)

			plsr.Phone.Notification:Add(
				source,
				"Labor Activity",
				"You Denied A Group Request",
				os.time(),
				6000,
				"labor",
				{}
			)

			cb(true)
		else
			cb(false)
		end
	end)
end
