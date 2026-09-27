--!strict
-- In-memory TTL cache retaining expired values for stale fallbacks.
local Cache = {}
Cache.__index = Cache

function Cache.new(ttl: number, now: () -> number, random: (() -> number)?)
	return setmetatable({ ttl = ttl, now = now, random = random or math.random, entries = {} }, Cache)
end

function Cache:getFresh(key: string): string?
	local entry = self.entries[key]
	if entry and self.now() < entry.expires then
		return entry.value
	end
	return nil
end

function Cache:getStale(key: string): string?
	local entry = self.entries[key]
	return if entry then entry.value else nil
end

function Cache:set(key: string, value: string)
	local jitter = 0.9 + self.random() * 0.2
	self.entries[key] = { value = value, expires = self.now() + self.ttl * jitter }
end

return Cache
