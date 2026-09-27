--!strict
-- Verifies beat math and stateful boundary emission with deterministic timestamps.
local BeatClock = require("../src/BeatClock")
local Expect = require("./helpers/Expect")

local tests = {}

local function close(actual: number, expected: number)
	assert(math.abs(actual - expected) < 1e-9, string.format("expected %.12f, got %.12f", expected, actual))
end

function tests.beatAt_reports_index_and_phase()
	local clock = BeatClock.new(120, 0.2)
	local beat, phase = clock:beatAt(0.2)
	Expect.equal(beat, 0)
	close(phase, 0)
	beat, phase = clock:beatAt(0.45)
	Expect.equal(beat, 0)
	close(phase, 0.5)
	beat, phase = clock:beatAt(0.7)
	Expect.equal(beat, 1)
	close(phase, 0)
	beat, phase = clock:beatAt(0.1)
	Expect.equal(beat, -1)
	close(phase, 0.8)
end

function tests.tick_fires_each_beat_and_bar_once()
	local clock = BeatClock.new(120, 0.2)
	local beats, bars = {}, {}
	for frame = 0, math.ceil(2.3 * 60) do
		local event = clock:tick(frame / 60)
		if event.beat ~= nil then
			table.insert(beats, event.beat)
		end
		if event.bar ~= nil then
			table.insert(bars, event.bar)
		end
	end
	Expect.deepEqual(beats, { 0, 1, 2, 3, 4 })
	Expect.deepEqual(bars, { 0, 1 })
end

function tests.seeks_resync_without_backlogs()
	local clock = BeatClock.new(120, 0)
	clock:tick(0.5)
	local forward = clock:tick(10)
	Expect.equal(forward.beat, 20)
	local backward = clock:tick(0.5)
	Expect.equal(backward.beat, nil)
	Expect.equal(clock:tick(0.99).beat, nil)
	Expect.equal(clock:tick(1).beat, 2)
end

function tests.large_offsets_and_fractional_bpm_stay_consistent()
	local clock = BeatClock.new(100.25, 2.5)
	local period = 60 / 100.25
	local beat, phase = clock:beatAt(2.5 + period * 7.25)
	Expect.equal(beat, 7)
	close(phase, 0.25)
	Expect.equal(clock:tick(2.5 - period * 0.1).beat, nil)
	Expect.equal(clock:tick(2.5).beat, 0)
end

function tests.missing_bpm_defaults_to_128()
	close(BeatClock.new(nil, 0).period, 60 / 128)
	close(BeatClock.new(0, 0).period, 60 / 128)
end

return tests
