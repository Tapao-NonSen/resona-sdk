--!strict
-- Shared exponential cooldown gate for retryable server responses.
local Backoff = {}
Backoff.__index = Backoff

function Backoff.new(now: () -> number, random: (() -> number)?)
	return setmetatable({ now = now, random = random or math.random, failures = 0, readyAt = 0 }, Backoff)
end

function Backoff:timeRemaining(): number
	return math.max(0, self.readyAt - self.now())
end

function Backoff:fail(retryAfter: number?): number
	self.failures += 1
	local exponential = math.min(60, 2 ^ (self.failures - 1))
	local delay = retryAfter or exponential * (0.9 + self.random() * 0.2)
	self.readyAt = math.max(self.readyAt, self.now() + delay)
	return delay
end

function Backoff:success()
	self.failures = 0
	self.readyAt = 0
end

return Backoff
