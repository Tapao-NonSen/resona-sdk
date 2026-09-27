--!strict
-- Server-side Sound playback that skips unavailable tracks and reports them.
local Signal = require("./Signal")
local Types = require("./Types")
local BeatClock = require("./BeatClock")
local Player = {}
Player.__index = Player
export type Pool = { next: (self: Pool, filters: Types.Filters?) -> (Types.Track?, Types.Meta) }
export type Reporter = { report: (self: Reporter, assetId: number, kind: Types.ReportKind, note: string?) -> () }
export type Dependencies = {
	pool: Pool,
	reporter: Reporter,
	now: () -> number,
	wait: (number) -> (),
	loadTimeout: number,
	runService: { Heartbeat: { Connect: (self: any, listener: (number) -> ()) -> RBXScriptConnection } },
}
export type Options = { filters: Types.Filters?, parent: Instance?, volume: number? }
type PlayerState = {
	sound: Sound?,
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
	local sound = Instance.new("Sound")
	sound.Volume = options.volume or 0.5
	sound.Parent = options.parent or game:GetService("SoundService")
	local player: PlayerState = setmetatable({
		sound = sound,
		filters = options.filters,
		stopped = true,
		destroyed = false,
		failedTracks = 0,
		TrackChanged = Signal.new(),
		Beat = Signal.new(),
		Bar = Signal.new(),
	}, Player)
	player.endedConnection = sound.Ended:Connect(function()
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
	if not dependencies or not track.bpm or track.bpm <= 0 or not self.sound then
		return
	end
	local clock = BeatClock.new(track.bpm, track.firstBeatOffset or 0)
	self.beatClock = clock
	self.heartbeatConnection = dependencies.runService.Heartbeat:Connect(function()
		local event = clock:tick((self.sound :: Sound).TimePosition)
		if event.beat ~= nil then
			self.Beat:Fire(event.beat, track)
		end
		if event.bar ~= nil then
			self.Bar:Fire(event.bar, track)
		end
	end)
end

function Player:_playNext()
	if not dependencies or not self.sound then
		return
	end
	self:_stopBeatClock()
	while not self.stopped and not self.destroyed do
		local track = dependencies.pool:next(self.filters)
		if not track then
			return
		end
		self.sound.SoundId = "rbxassetid://" .. tostring(track.id)
		self.sound:Play()
		local started = dependencies.now()
		while not self.sound.IsLoaded and dependencies.now() - started < dependencies.loadTimeout do
			dependencies.wait(0.1)
		end
		if self.sound.IsLoaded and self.sound.TimeLength > 0 then
			self.failedTracks = 0
			self:_startBeatClock(track)
			self.TrackChanged:Fire(track)
			return
		end
		dependencies.reporter:report(track.id, "unavailable")
		self.failedTracks = (self.failedTracks or 0) + 1
		if self.failedTracks >= 5 then
			self.stopped = true
			warn("Resona: stopped player after 5 unavailable tracks")
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
		self.sound:Stop()
		self.stopped = false
		self:_playNext()
	end
end
function Player:stop()
	self.stopped = true
	self:_stopBeatClock()
	if self.sound then
		self.sound:Stop()
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
	if self.sound then
		self.sound:Destroy()
	end
end

function Player:getBeatPhase(): number?
	if not self.beatClock or not self.sound then
		return nil
	end
	local _, phase = self.beatClock:beatAt(self.sound.TimePosition)
	return phase
end

return Player
