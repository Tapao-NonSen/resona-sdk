--!strict
-- Backoff growth, Retry-After, and reset tests.
local Backoff = require("../src/Http/Backoff")
local Fakes = require("./helpers/Fakes")
local Expect = require("./helpers/Expect")
return {
	["backs off exponentially and honors retry-after"] = function()
		local clock = Fakes.clock()
		local backoff = Backoff.new(clock.now, function()
			return 0.5
		end)
		Expect.equal(backoff:fail(nil), 1)
		clock.advance(1)
		Expect.equal(backoff:fail(nil), 2)
		clock.advance(2)
		Expect.equal(backoff:fail(7), 7)
		backoff:success()
		Expect.equal(backoff:timeRemaining(), 0)
	end,
}
