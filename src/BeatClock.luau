--!strict
-- Computes beat positions and emits crossed beat boundaries without Roblox APIs.
local BeatClock = {}
BeatClock.__index = BeatClock

export type Tick = { beat: number?, bar: number? }
export type BeatClock = typeof(setmetatable(
	{} :: {
		period: number,
		firstBeatOffset: number,
		beatsPerBar: number,
		lastBeat: number?,
	},
	BeatClock
))

-- ponytail: unanalyzed tracks tick at a common dance tempo until a measured BPM replaces the clock.
BeatClock.DEFAULT_BPM = 128

function BeatClock.new(bpm: number?, firstBeatOffset: number, beatsPerBar: number?): BeatClock
	return setmetatable({
		period = 60 / (if bpm and bpm > 0 then bpm else BeatClock.DEFAULT_BPM),
		firstBeatOffset = firstBeatOffset,
		beatsPerBar = beatsPerBar or 4,
		lastBeat = nil,
	}, BeatClock)
end

function BeatClock.beatAt(self: BeatClock, timePosition: number): (number, number)
	local position = (timePosition - self.firstBeatOffset) / self.period
	local nearestBeat = math.round(position)
	if math.abs(position - nearestBeat) < 1e-9 then
		position = nearestBeat
	end
	local beat = math.floor(position)
	return beat, position - beat
end

function BeatClock.tick(self: BeatClock, timePosition: number): Tick
	local beat = self:beatAt(timePosition)
	local previous = self.lastBeat
	self.lastBeat = beat
	if beat < 0 or (previous ~= nil and beat <= previous) then
		return { beat = nil, bar = nil }
	end
	return {
		beat = beat,
		bar = if beat % self.beatsPerBar == 0 then beat / self.beatsPerBar else nil,
	}
end

return BeatClock
