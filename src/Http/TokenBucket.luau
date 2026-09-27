--!strict
-- Continuously refilled request budget with a one-minute burst cap.
local TokenBucket = {}
TokenBucket.__index = TokenBucket

function TokenBucket.new(perMinute: number, now: () -> number)
	return setmetatable(
		{ capacity = perMinute, tokens = perMinute, refill = perMinute / 60, now = now, updated = now() },
		TokenBucket
	)
end

function TokenBucket:_refresh()
	local current = self.now()
	self.tokens = math.min(self.capacity, self.tokens + math.max(0, current - self.updated) * self.refill)
	self.updated = current
end

function TokenBucket:tryTake(): boolean
	self:_refresh()
	if self.tokens < 1 then
		return false
	end
	self.tokens -= 1
	return true
end

function TokenBucket:timeUntilNext(): number
	self:_refresh()
	return if self.tokens >= 1 then 0 else (1 - self.tokens) / self.refill
end

return TokenBucket
