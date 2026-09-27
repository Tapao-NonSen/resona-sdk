--!strict
local Estimator = require("../src/Analysis/Estimator")
local Expect = require("./helpers/Expect")

return {
	["yielded BPM search preserves the result"] = function()
		local envelope = { t = {}, f = {}, r = {} }
		for frame = 0, 719 do
			local timeMs = frame * 33
			table.insert(envelope.t, timeMs)
			table.insert(envelope.f, if timeMs % 500 < 33 then 10 else 0)
			table.insert(envelope.r, 1000)
		end
		local expected = Estimator.estimateBpm(envelope)
		local yields = 0
		local actual, onset = Estimator.estimateBpm(envelope, function()
			yields += 1
		end)
		Expect.equal(actual.bpm, expected.bpm)
		Expect.equal(actual.firstBeatOffset, expected.firstBeatOffset)
		assert(yields > 100 and #onset > 100)
	end,
}
