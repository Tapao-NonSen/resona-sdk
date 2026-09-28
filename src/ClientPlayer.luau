--!strict
-- Client playback and opt-in-spectrum-by-use: analyze only the audible track chosen by the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Signal = require("./Signal")
local BeatClock = require("./BeatClock")
local Recorder = require("./Analysis/Recorder")
local Estimator = require("./Analysis/Estimator")
local Features = require("./Analysis/Features")
local ReportGui = require("./ReportGui")
local ClientPlayer = {}
ClientPlayer.__index = ClientPlayer

export type Options = { filters: any?, volume: number?, autoplay: boolean? }

function ClientPlayer.new(options: Options?)
	options = options or {}
	local self = setmetatable({
		stopped = true,
		destroyed = false,
		generation = 0,
		filters = options.filters,
		autoplay = options.autoplay ~= false,
		failedTracks = 0,
		seeks = 0,
		queued = {},
		TrackChanged = Signal.new(),
		Beat = Signal.new(),
		Bar = Signal.new(),
	}, ClientPlayer)
	if not RunService:IsClient() then
		warn("[Resona] Player requires a LocalScript; call Resona.init on the server")
		self.unavailable = true
		return self
	end
	local bridge = ReplicatedStorage:WaitForChild("ResonaBridge", 10)
	if not bridge then
		warn("[Resona] Server bridge not found; call Resona.init on the server")
		self.unavailable = true
		return self
	end
	self.nextTrack = bridge:WaitForChild("NextTrack")
	self.evidence = bridge:WaitForChild("Evidence")
	if bridge:GetAttribute("ShowReportGui") == true then
		ReportGui.mount()
	end
	local folder = Instance.new("Folder")
	folder.Name = "ResonaPlayer"
	folder.Parent = SoundService
	self.folder = folder
	local player = Instance.new("AudioPlayer")
	player.Volume = options.volume or 0.5
	player.Parent = folder
	self.audioPlayer = player
	local output = Instance.new("AudioDeviceOutput")
	output.Parent = folder
	local wire = Instance.new("Wire")
	wire.SourceInstance = player
	wire.TargetInstance = output
	wire.Parent = folder
	self.ended = player.Ended:Connect(function()
		if self.stopped or self.destroyed then
			return
		end
		if self.autoplay then
			self:_playNext()
		else
			self:destroy()
		end
	end)
	return self
end

function ClientPlayer:_stopClock()
	if self.heartbeat then
		self.heartbeat:Disconnect()
		self.heartbeat = nil
	end
	self.clock = nil
end

function ClientPlayer:_startClock(track: any)
	self:_stopClock()
	local clock = BeatClock.new(track.bpm, track.firstBeatOffset or 0)
	self.clock = clock
	self.heartbeat = RunService.Heartbeat:Connect(function()
		local event = clock:tick(self.audioPlayer.TimePosition)
		if event.beat ~= nil then
			self.Beat:Fire(event.beat, track)
		end
		if event.bar ~= nil then
			self.Bar:Fire(event.bar, track)
		end
	end)
end

function ClientPlayer:_playNext()
	if self.unavailable or self.stopped or self.destroyed then
		return
	end
	self.generation += 1
	local generation = self.generation
	self:_stopClock()
	ReportGui.setTrack(nil)

	local track, contribute, analyze, fromQueue
	if #self.queued > 0 then
		track = table.remove(self.queued, 1)
		fromQueue = true
	else
		local waitFor = 2.05 - (os.clock() - (self.lastRequestAt or -math.huge))
		if waitFor > 0 then
			task.wait(waitFor)
		end
		if generation ~= self.generation or self.stopped then
			return
		end
		self.lastRequestAt = os.clock()
		local ok, result = pcall(function()
			return self.nextTrack:InvokeServer(self.filters)
		end)
		if generation ~= self.generation or self.stopped then
			return
		end
		if not ok or type(result) ~= "table" or type(result.track) ~= "table" then
			return
		end
		track = result.track
		contribute = result.contribute
		analyze = result.analyze
	end
	self.audioPlayer.Asset = "rbxassetid://" .. tostring(track.id)
	local started = os.clock()
	while generation == self.generation and not self.audioPlayer.IsReady and os.clock() - started < 10 do
		task.wait(0.1)
	end
	if generation ~= self.generation or self.stopped then
		return
	end
	if not self.audioPlayer.IsReady or self.audioPlayer.TimeLength <= 0 then
		-- A queued track never went through the bridge, so the server has no issued id to match this against.
		if not fromQueue then
			self.evidence:FireServer({ assetId = track.id, failed = true })
		end
		self.failedTracks += 1
		if self.failedTracks >= 5 then
			self.stopped = true
			warn("[Resona] Stopped after 5 unavailable tracks")
			return
		end
		task.wait(2) -- bridge limits rapid track requests
		return self:_playNext()
	end
	self.failedTracks = 0
	self.audioPlayer:Play()
	self:_startClock(track)
	self.TrackChanged:Fire(track)
	ReportGui.setTrack(track)
	if contribute then
		self.evidence:FireServer({ assetId = track.id, duration = self.audioPlayer.TimeLength })
	end
	if analyze then
		local seeks = self.seeks
		task.spawn(function()
			local envelope = Recorder.record(self.audioPlayer, function()
				return generation == self.generation and seeks == self.seeks and not self.stopped and not self.destroyed
			end)
			if not envelope then
				return
			end
			local valid, estimate, features = pcall(function()
				local bpm, onset = Estimator.estimateBpm(envelope, function()
					task.wait()
					if generation ~= self.generation or seeks ~= self.seeks or self.stopped or self.destroyed then
						error("cancelled")
					end
				end)
				return bpm, Features.features(envelope, onset)
			end)
			if valid and estimate.confidence >= 1.5 then
				-- Use the estimate now: Beat/Bar start mid-track; the server reuses it for later plays.
				track.bpm = estimate.bpm
				track.bpmConfidence = estimate.confidence
				track.firstBeatOffset = estimate.firstBeatOffset
				self:_startClock(track)
				self.evidence:FireServer({
					assetId = track.id,
					duration = self.audioPlayer.TimeLength,
					bpm = estimate.bpm,
					bpmConfidence = estimate.confidence,
					firstBeatOffset = estimate.firstBeatOffset,
					features = features,
				})
			end
		end)
	end
end

-- Plays before autoplay's server pick, in order added, then falls back to autoplay when empty.
function ClientPlayer:queue(track: any)
	if self.unavailable or self.destroyed then
		return
	end
	table.insert(self.queued, track)
end
function ClientPlayer:play()
	if self.unavailable or self.destroyed then
		return
	end
	self.stopped = false
	self:_playNext()
end
function ClientPlayer:skip()
	if self.unavailable or self.destroyed then
		return
	end
	self.generation += 1
	self.audioPlayer:Stop()
	self.stopped = false
	self:_playNext()
end
function ClientPlayer:stop()
	self.stopped = true
	self.generation += 1
	self:_stopClock()
	ReportGui.setTrack(nil)
	if self.audioPlayer then
		self.audioPlayer:Stop()
	end
end
function ClientPlayer:destroy()
	if self.destroyed then
		return
	end
	self:stop()
	self.destroyed = true
	if self.ended then
		self.ended:Disconnect()
	end
	if self.folder then
		self.folder:Destroy()
	end
end
-- Jump within the current track. Cancels a running analysis: its envelope assumes unbroken playback.
function ClientPlayer:seek(position: number)
	if self.unavailable or self.destroyed or self.audioPlayer.TimeLength <= 0 then
		return
	end
	self.seeks += 1
	self.audioPlayer.TimePosition = math.clamp(position, 0, self.audioPlayer.TimeLength)
end
-- true: advance when a track ends; false: stop and destroy when it ends.
function ClientPlayer:setAutoplay(enabled: boolean)
	self.autoplay = enabled == true
end

function ClientPlayer:getBeatPhase(): number?
	if not self.clock then
		return nil
	end
	local _, phase = self.clock:beatAt(self.audioPlayer.TimePosition)
	return phase
end

return ClientPlayer
