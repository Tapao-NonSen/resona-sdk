--!strict
-- Cache freshness, staleness, and bounded jitter tests.
local Cache = require("../src/Http/Cache")
local Fakes = require("./helpers/Fakes")
local Expect = require("./helpers/Expect")
return {
	["expires within jitter bounds and retains stale"] = function()
		local clock = Fakes.clock()
		local cache = Cache.new(100, clock.now, function()
			return 1
		end)
		cache:set("key", "value")
		clock.advance(109.9)
		Expect.equal(cache:getFresh("key"), "value")
		clock.advance(0.2)
		Expect.equal(cache:getFresh("key"), nil)
		Expect.equal(cache:getStale("key"), "value")
	end,
}
