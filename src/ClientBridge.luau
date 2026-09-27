--!strict
-- Server-only bridge: keeps the API key off clients and accepts evidence only for an issued track.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Bridge = {}
local connections = {}
local ANALYSIS_INTERVAL = 300 -- at most one 24-second capture per game server every five minutes

function Bridge.start(pool: any, observer: any, reporter: any, showReportGui: boolean?, validateAdd: (number) -> (boolean, string, any?))
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	local folder = ReplicatedStorage:FindFirstChild("ResonaBridge") or Instance.new("Folder")
	folder.Name = "ResonaBridge"
	folder:SetAttribute("ShowReportGui", showReportGui == true)
	folder.Parent = ReplicatedStorage
	local nextTrack = folder:FindFirstChild("NextTrack") or Instance.new("RemoteFunction")
	nextTrack.Name = "NextTrack"
	nextTrack.Parent = folder
	local evidence = folder:FindFirstChild("Evidence") or Instance.new("RemoteEvent")
	evidence.Name = "Evidence"
	evidence.Parent = folder
	local submitReport = folder:FindFirstChild("SubmitReport") or Instance.new("RemoteFunction")
	submitReport.Name = "SubmitReport"
	submitReport.Parent = folder
	local checkAdd = folder:FindFirstChild("CheckAdd") or Instance.new("RemoteFunction")
	checkAdd.Name = "CheckAdd"
	checkAdd.Parent = folder
	local issued: { [Player]: { id: number, at: number, analyze: boolean } } = {}
	local claimed: { [number]: Player } = {}
	local attempted: { [number]: boolean } = {}
	local active: number? = nil
	local lastAnalysis = -math.huge
	local lastRequest: { [Player]: number } = {}
	local lastReport: { [Player]: number } = {}
	local lastAttempt: { [Player]: number } = {}
	local validating: { [Player]: boolean } = {}
	local lastCheck: { [Player]: number } = {}
	local checking: { [Player]: boolean } = {}
	local checkCount: { [Player]: number } = {}
	local reportCount: { [Player]: number } = {}
	local allowed = { genre = true, mood = true, bpmMin = true, bpmMax = true, energyMin = true,
		durationMax = true, kind = true }

	nextTrack.OnServerInvoke = function(player: Player, filters: any)
		local now = os.clock()
		if now - (lastRequest[player] or -math.huge) < 2 then return nil end
		lastRequest[player] = now
		if filters ~= nil and type(filters) ~= "table" then return nil end
		local safeFilters = {}
		if filters then
			for key, value in filters do
				if allowed[key] and ((type(value) == "string" and #value <= 60)
					or (type(value) == "number" and value == value and value >= 0 and value <= 10000)) then
					safeFilters[key] = value
				end
			end
		end
		local track = pool:next(safeFilters)
		if not track then return nil end
		local previous = issued[player]
		if previous and claimed[previous.id] == player then
			claimed[previous.id] = nil
			if active == previous.id then active = nil end
		end
		if active then
			local owner = claimed[active]
			local claim = owner and issued[owner]
			if not claim or os.clock() - claim.at > 45 then
				claimed[active] = nil
				active = nil
			end
		end
		local analyze = observer ~= nil and track.bpm == nil and not attempted[track.id]
			and active == nil and now - lastAnalysis >= ANALYSIS_INTERVAL
		if analyze then
			claimed[track.id] = player
			attempted[track.id] = true
			active = track.id
			lastAnalysis = now
		end
		issued[player] = { id = track.id, at = now, analyze = analyze }
		return { track = track, analyze = analyze, contribute = observer ~= nil }
	end

	checkAdd.OnServerInvoke = function(player: Player, id: any)
		if type(id) ~= "number" or id % 1 ~= 0 or id <= 0 or id > 9007199254740991 then
			return false, "Enter a valid Roblox audio asset ID."
		end
		if (checkCount[player] or 0) >= 10 then return false, "Public audio check limit reached for this session." end
		local now = os.clock()
		if checking[player] or now - (lastCheck[player] or -math.huge) < 2 then
			return false, "Please wait before checking another ID."
		end
		lastCheck[player] = now
		checkCount[player] = (checkCount[player] or 0) + 1
		checking[player] = true
		local ok, eligible, message, asset = pcall(validateAdd, id)
		checking[player] = nil
		if not ok then return false, "Public audio check unavailable. Try again later." end
		if not eligible then return false, message end
		return true, message, {
			title = if type(asset) == "table" and type(asset.title) == "string" then asset.title:sub(1, 120) else "",
			artist = if type(asset) == "table" and type(asset.artist) == "string" then asset.artist:sub(1, 120) else "",
		}
	end

	submitReport.OnServerInvoke = function(player: Player, item: any)
		local now = os.clock()
		if now - (lastReport[player] or -math.huge) < 10 then return false, "Please wait before submitting again." end
		if validating[player] or now - (lastAttempt[player] or -math.huge) < 2 then return false, "Please wait before trying again." end
		lastAttempt[player] = now
		if (reportCount[player] or 0) >= 10 then return false, "Report limit reached for this session." end
		if type(item) ~= "table" then return false, "Invalid report." end
		local id, kind, note = item.assetId, item.kind, item.note
		if type(id) ~= "number" or id % 1 ~= 0 or id <= 0 or id > 9007199254740991
			or (kind ~= "metadata" and kind ~= "add" and kind ~= "unavailable")
			or (note ~= nil and (type(note) ~= "string" or #note > 500)) then
			return false, "Invalid track ID or report."
		end
		local suggested = nil
		if item.suggested ~= nil then
			if kind == "unavailable" or type(item.suggested) ~= "table" then return false, "Invalid suggestion." end
			for key in item.suggested do
				if (kind == "metadata" and key ~= "artworkAssetId" and key ~= "genre")
					or (kind == "add" and key ~= "title" and key ~= "artist") then return false, "Invalid suggestion." end
			end
			suggested = if kind == "add"
				then { title = item.suggested.title, artist = item.suggested.artist }
				else { artworkAssetId = item.suggested.artworkAssetId, genre = item.suggested.genre }
		end
		if kind == "add" and suggested ~= nil then
			for _, value in { suggested.title, suggested.artist } do
				if type(value) ~= "string" or #value > 120 or not value:match("%S") or value:find("%c") then
					return false, "Enter a valid title and artist."
				end
			end
		end
		if kind == "add" then
			validating[player] = true
			local ok, eligible, message = pcall(validateAdd, id)
			validating[player] = nil
			if not ok then return false, "Public audio check unavailable. Try again later." end
			if not eligible then return false, message end
		end
		if not reporter:report(id, kind, note, suggested) then return false, "Already queued or invalid report." end
		lastReport[player] = os.clock()
		reportCount[player] = (reportCount[player] or 0) + 1
		return true, if kind == "add"
			then "Public Music confirmed. Track request queued for review."
			else "Report queued for review."
	end

	table.insert(connections, evidence.OnServerEvent:Connect(function(player: Player, item: any)
		if not observer or type(item) ~= "table" then return end
		local current = issued[player]
		if not current or item.assetId ~= current.id then return end
		if item.failed == true then
			reporter:report(current.id, "unavailable")
			if claimed[current.id] == player then
				claimed[current.id] = nil
				if active == current.id then active = nil end
			end
			issued[player] = nil
			return
		end
		if type(item.duration) ~= "number" or item.duration ~= item.duration or item.duration <= 0 or item.duration > 36000 then return end
		local safe: any = { assetId = current.id, duration = item.duration }
		if item.bpm ~= nil then
			if not current.analyze or os.clock() - current.at < 20
				or type(item.bpm) ~= "number" or item.bpm ~= item.bpm or item.bpm < 40 or item.bpm > 250
				or type(item.bpmConfidence) ~= "number" or item.bpmConfidence ~= item.bpmConfidence or item.bpmConfidence < 0 or item.bpmConfidence > 100
				or type(item.firstBeatOffset) ~= "number" or item.firstBeatOffset ~= item.firstBeatOffset or item.firstBeatOffset < 0 or item.firstBeatOffset > 60
				or type(item.features) ~= "table" then return end
			local count, features = 0, {}
			for key, value in item.features do
				count += 1
				if count > 16 or type(key) ~= "string" or not key:match("^[a-zA-Z][a-zA-Z0-9]*$")
					or #key > 24 or type(value) ~= "number" or value ~= value or math.abs(value) > 1000000 then return end
				features[key] = value
			end
			safe.bpm = item.bpm
			safe.bpmConfidence = item.bpmConfidence
			safe.firstBeatOffset = item.firstBeatOffset
			safe.features = features
		end
		observer:submit(safe)
		if item.bpm ~= nil then
			if claimed[current.id] == player then
				claimed[current.id] = nil
				if active == current.id then active = nil end
			end
			issued[player] = nil
		end
	end))

	table.insert(connections, Players.PlayerRemoving:Connect(function(player: Player)
		local current = issued[player]
		if current and claimed[current.id] == player then
			claimed[current.id] = nil
			if active == current.id then active = nil end
		end
		issued[player] = nil
		lastRequest[player] = nil
		lastReport[player] = nil
		lastAttempt[player] = nil
		validating[player] = nil
		lastCheck[player] = nil
		checking[player] = nil
		checkCount[player] = nil
		reportCount[player] = nil
	end))
end

return Bridge
