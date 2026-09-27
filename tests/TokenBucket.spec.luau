--!strict
-- Token budget refill tests.
local TokenBucket = require("../src/Http/TokenBucket")
local Fakes = require("./helpers/Fakes")
local Expect = require("./helpers/Expect")
return {
	["refills continuously"] = function()
		local clock = Fakes.clock()
		local bucket = TokenBucket.new(5, clock.now)
		for _ = 1, 5 do
			Expect.truthy(bucket:tryTake())
		end
		Expect.equal(bucket:tryTake(), false)
		Expect.equal(bucket:timeUntilNext(), 12)
		clock.advance(12)
		Expect.truthy(bucket:tryTake())
	end,
}
