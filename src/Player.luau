--!strict
-- Server-side AudioPlayer playback, heard by every player; skips unavailable tracks and reports them.
local Signal = require("./Signal")
local Types = require("./Types")
local BeatClock = require("./BeatClock")
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
export type Options = { filters: Types.Filters?, parent: Instance?, volume: number? }
type PlayerState = {
	audio: AudioPlayer?,
	folder: Folder?,
	filters: Types.Filters?,
	stopped: boolean,
	destroyed: boolean,
	unavailable: boolean?,
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
		stopped = true,
		destroyed = false,
		failedTracks = 0,
		TrackChanged = Signal.new(),
		Beat = Signal.new(),
		Bar = Signal.new(),
	}, Player)
	player.endedConnection = audio.Ended:Connect(function()
		if not player.stopped and not player.destroyed then
			player:_playNext()
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
	if not dependencies or not self.audio then
		return
	end
	local clock = BeatClock.new(track.bpm, track.firstBeatOffset or 0)
	self.beatClock = clock
	self.heartbeatConnection = dependencies.runService.Heartbeat:Connect(function()
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
	while not self.stopped and not self.destroyed do
		local track = dependencies.pool:next(self.filters)
		if not track then
			return
		end
		local audio = self.audio :: AudioPlayer
		audio:Stop()
		audio.Asset = "rbxassetid://" .. tostring(track.id)
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
			self:_startBeatClock(track)
			self.TrackChanged:Fire(track)
			return
		end
		dependencies.reporter:report(track.id, "unavailable")
		self.failedTracks = (self.failedTracks or 0) + 1
		if self.failedTracks >= 5 then
			self.stopped = true
			warn("[Resona] Stopped player after 5 unavailable tracks")
			return
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
function Player:skip()
	if not self.destroyed and not self.unavailable then
		(self.audio :: AudioPlayer):Stop()
		self.stopped = false
		self:_playNext()
	end
end
function Player:stop()
	self.stopped = true
	self:_stopBeatClock()
	if self.audio then
		self.audio:Stop()
	end
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

function Player:getBeatPhase(): number?
	if not self.beatClock or not self.audio then
		return nil
	end
	local _, phase = self.beatClock:beatAt(self.audio.TimePosition)
	return phase
end

return Player
