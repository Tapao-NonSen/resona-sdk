--!strict
-- Server-side Sound playback that skips unavailable tracks and reports them.
local Signal = require("./Signal")
local Types = require("./Types")
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
	TrackChanged: Signal.Signal,
}
local dependencies: Dependencies? = nil

function Player.configure(value: Dependencies)
	dependencies = value
end

function Player.new(options: Options?): PlayerState
	options = options or {}
	if not dependencies then
		return setmetatable(
			{ stopped = true, destroyed = false, unavailable = true, TrackChanged = Signal.new() },
			Player
		)
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
	}, Player)
	player.endedConnection = sound.Ended:Connect(function()
		if not player.stopped and not player.destroyed then
			player:_playNext()
		end
	end)
	return player
end

function Player:_playNext()
	if not dependencies or not self.sound then
		return
	end
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
	if self.endedConnection then
		self.endedConnection:Disconnect()
		self.endedConnection = nil
	end
	if self.sound then
		self.sound:Destroy()
	end
end

return Player
