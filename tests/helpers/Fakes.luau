--!strict
-- Deterministic clock, wait, and scripted transport shared by pure-module tests.
local Fakes = {}

function Fakes.clock(start: number?)
	local clock = { time = start or 0 }
	function clock.now()
		return clock.time
	end
	function clock.advance(seconds: number)
		clock.time += seconds
	end
	function clock.wait(seconds: number)
		clock.advance(seconds)
	end
	return clock
end

function Fakes.transport(responses: { any }?, delay: (() -> ())?)
	local transport = { responses = responses or {}, calls = {} }
	function transport:request(request: any)
		table.insert(self.calls, request)
		if delay then
			delay()
		end
		return table.remove(self.responses, 1) or { success = true, status = 200, body = "{}", headers = {} }
	end
	return transport
end

return Fakes
