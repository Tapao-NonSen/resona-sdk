--!strict
-- Server-side AudioPlayer playback, heard by every player; skips unavailable tracks and reports them.
-- Created in a LocalScript, it follows that shared track instead, with the same signals.
local Signal = require("./Signal")
local Types = require("./Types")
local BeatClock = require("./BeatClock")
local ReportGui = require("./ReportGui")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Player = {}
Player.__index = Player
export type Pool = { next: (self: Pool, filters: Types.Filters?) -> (Types.Track?, Types.Meta) }
export type Reporter = { report: (self: Reporter, assetId: number, kind: Types.ReportKind, note: string?) -> () }
export type Observer = { submit: (self: Observer, item: { assetId: number, duration: number }) -> () }
export type Dependencies = {
	pool: Pool,
	reporter: Reporter,
	observer: Observer?,
	now: () -> number,
	wait: (number) -> (),
	loadTimeout: number,
	runService: { Heartbeat: { Connect: (self: any, listener: (number) -> ()) -> RBXScriptConnection } },
}
export type Options = {
	filters: Types.Filters?,
	track: (Types.Track | { Types.Track })?,
	parent: Instance?,
	volume: number?,
	autoplay: boolean?,
}

-- Accepts one Track or a list; a Track is distinguished by its required `id` field.
local function trackList(track: any): { Types.Track }
	if type(track) ~= "table" then
		return {}
	end
	if track.id ~= nil then
		return { track }
	end
	return track
end
type PlayerState = {
	audio: AudioPlayer?,
	folder: Folder?,
	filters: Types.Filters?,
	autoplay: boolean?,
	queued: { Types.Track }?,
	stopped: boolean,
	destroyed: boolean,
	unavailable: boolean?,
	following: boolean?,
	failedTracks: number?,
	endedConnection: RBXScriptConnection?,
	heartbeatConnection: RBXScriptConnection?,
	beatClock: BeatClock.BeatClock?,
	TrackChanged: Signal.Signal,
	Beat: Signal.Signal,
	Bar: Signal.Signal,
}
local dependencies: Dependencies? = nil

function Player.configure(value: Dependencies)
	dependencies = value
end

function Player.new(options: Options?): PlayerState
	options = options or {}
	if RunService:IsClient() then
		return Player._follow(options)
	end
	if not dependencies then
		return setmetatable({
			stopped = true,
			destroyed = false,
			unavailable = true,
			TrackChanged = Signal.new(),
			Beat = Signal.new(),
			Bar = Signal.new(),
		}, Player)
	end
	-- AudioDeviceOutput with no Player set is heard by everyone (checked in Studio 2026-09-28).
	local folder = Instance.new("Folder")
	folder.Name = "ResonaServerPlayer"
	local audio = Instance.new("AudioPlayer")
	audio.Volume = options.volume or 0.5
	audio.Parent = folder
	local output = Instance.new("AudioDeviceOutput")
	output.Parent = folder
	local wire = Instance.new("Wire")
	wire.SourceInstance = audio
	wire.TargetInstance = output
	wire.Parent = folder
	folder.Parent = options.parent or game:GetService("SoundService")
	local player: PlayerState = setmetatable({
		audio = audio,
		folder = folder,
		filters = options.filters,
		autoplay = options.autoplay ~= false,
		queued = trackList(options.track),
		stopped = true,
		destroyed = false,
		failedTracks = 0,
		TrackChanged = Signal.new(),
		Beat = Signal.new(),
		Bar = Signal.new(),
	}, Player)
	player.endedConnection = audio.Ended:Connect(function()
		if player.stopped or player.destroyed then
			return
		end
		if player.autoplay then
			player:_playNext()
		else
			player:destroy()
		end
	end)
	return player
end

-- Client side: mirror the server player's track (the "Track" attribute) and replicated TimePosition.
function Player._follow(options: Options): PlayerState
	local player: PlayerState = setmetatable({
		stopped = true,
		destroyed = false,
		unavailable = true,
		following = true,
		TrackChanged = Signal.new(),
		Beat = Signal.new(),
		Bar = Signal.new(),
	}, Player)
	task.spawn(function()
		local parent = options.parent or game:GetService("SoundService")
		local bridge = game:GetService("ReplicatedStorage"):FindFirstChild("ResonaBridge")
		local showGui = bridge ~= nil and bridge:GetAttribute("ShowReportGui") == true
		if showGui then
			ReportGui.mount()
		end
		-- Attach to each server player the server creates, and go quiet while there is none.
		while not player.destroyed do
			local folder = parent:FindFirstChild("ResonaServerPlayer")
			while not folder and not player.destroyed do
				parent.ChildAdded:Wait()
				folder = parent:FindFirstChild("ResonaServerPlayer")
			end
			local audio = folder and folder:WaitForChild("AudioPlayer", 10) :: AudioPlayer?
			if player.destroyed or not folder or not audio then
				return
			end
			player.audio = audio
			local function onTrack()
				local raw = folder:GetAttribute("Track")
				local ok, track = pcall(HttpService.JSONDecode, HttpService, raw)
				if type(raw) == "string" and ok and type(track) == "table" then
					player:_startBeatClock(track)
					player.TrackChanged:Fire(track)
				else
					player:_stopBeatClock()
					track = nil
				end
				if showGui then
					ReportGui.setTrack(track)
				end
			end
			player.endedConnection = folder:GetAttributeChangedSignal("Track"):Connect(onTrack)
			onTrack()
			while folder.Parent == parent and not player.destroyed do
				folder.AncestryChanged:Wait()
			end
			if player.endedConnection then
				player.endedConnection:Disconnect()
				player.endedConnection = nil
			end
			player:_stopBeatClock()
			player.audio = nil
			if showGui then
				ReportGui.setTrack(nil)
			end
		end
	end)
	return player
end

function Player:_stopBeatClock()
	if self.heartbeatConnection then
		self.heartbeatConnection:Disconnect()
		self.heartbeatConnection = nil
	end
	self.beatClock = nil
end

function Player:_startBeatClock(track: Types.Track)
	self:_stopBeatClock()
	if not self.audio then
		return
	end
	local clock = BeatClock.new(track.bpm, track.firstBeatOffset or 0)
	self.beatClock = clock
	local runService = if dependencies then dependencies.runService else RunService
	self.heartbeatConnection = runService.Heartbeat:Connect(function()
		local event = clock:tick((self.audio :: AudioPlayer).TimePosition)
		if event.beat ~= nil then
			self.Beat:Fire(event.beat, track)
		end
		if event.bar ~= nil then
			self.Bar:Fire(event.bar, track)
		end
	end)
end

function Player:_playNext()
	if not dependencies or not self.audio then
		return
	end
	self:_stopBeatClock()
	local retry: Types.Track? = nil
	while not self.stopped and not self.destroyed do
		local track = retry
			or if self.queued and #self.queued > 0
				then table.remove(self.queued, 1)
				else dependencies.pool:next(self.filters)
		if not track then
			return
		end
		local audio = self.audio :: AudioPlayer
		audio:Stop()
		audio.TimePosition = 0
		audio.Asset = "rbxassetid://" .. tostring(track.id)
		-- one tick so IsReady/TimeLength reflect the new asset, not the previous track's
		dependencies.wait(0.1)
		local started = dependencies.now()
		while not audio.IsReady and dependencies.now() - started < dependencies.loadTimeout do
			dependencies.wait(0.1)
		end
		if self.stopped or self.destroyed then
			return
		end
		if audio.IsReady and audio.TimeLength > 0 then
			audio.TimePosition = 0
			audio:Play()
			if dependencies.observer then
				dependencies.observer:submit({ assetId = track.id, duration = audio.TimeLength })
			end
			self.failedTracks = 0
			(self.folder :: Folder):SetAttribute("Track", HttpService:JSONEncode(track))
			self:_startBeatClock(track)
			self.TrackChanged:Fire(track)
			return
		end
		audio:Stop()
		audio.TimePosition = 0
		if retry == nil then
			retry = track -- timeouts are often transient: retry once, then skip
			continue
		end
		retry = nil
		dependencies.reporter:report(track.id, "unavailable")
		self.failedTracks = (self.failedTracks or 0) + 1
		if self.failedTracks >= 5 then
			-- ponytail: likely an outage (HTTP timeouts), so pause and keep trying instead of stopping for good
			warn("[Resona] 5 tracks failed to load in a row; retrying in 30s")
			self.failedTracks = 0
			dependencies.wait(30)
		end
	end
end

function Player:play()
	if self.unavailable then
		return
	end
	self.stopped = false
	self:_playNext()
end
-- Plays before autoplay's pool pick, in order added, then falls back to autoplay when empty.
function Player:queue(track: Types.Track)
	if self.following then
		return
	end
	self.queued = self.queued or {}
	table.insert(self.queued, track)
end
function Player:skip()
	if not self.destroyed and not self.unavailable then
		(self.audio :: AudioPlayer):Stop()
		self.stopped = false
		self:_playNext()
	end
end
function Player:stop()
	if self.following then
		return
	end
	self.stopped = true
	self:_stopBeatClock()
	if self.audio then
		self.audio:Stop()
	end
	if self.folder then
		self.folder:SetAttribute("Track", nil)
	end
end
-- Jump within the current track; clients follow the replicated position.
function Player:seek(position: number)
	local audio = self.audio
	if self.unavailable or self.destroyed or not audio or audio.TimeLength <= 0 then
		return
	end
	audio.TimePosition = math.clamp(position, 0, audio.TimeLength)
end
function Player:destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.stopped = true
	self:_stopBeatClock()
	if self.endedConnection then
		self.endedConnection:Disconnect()
		self.endedConnection = nil
	end
	if self.folder then
		self.folder:Destroy()
	end
end

-- true: advance when a track ends; false: stop and destroy when it ends.
function Player:setAutoplay(enabled: boolean)
	self.autoplay = enabled == true
end

function Player:getQueue(): { Types.Track }
	return table.clone(self.queued or {})
end
function Player:getBeatPhase(): number?
	if not self.beatClock or not self.audio then
		return nil
	end
	local _, phase = self.beatClock:beatAt(self.audio.TimePosition)
	return phase
end

return Player
