--!strict
-- Client pipeline tests for cache, single-flight, fallback, budget, and cooldown.
local Client = require("../src/Http/Client")
local Cache = require("../src/Http/Cache")
local TokenBucket = require("../src/Http/TokenBucket")
local Backoff = require("../src/Http/Backoff")
local Fakes = require("./helpers/Fakes")
local Expect = require("./helpers/Expect")
local task = require("@lune/task")

local function makeClient(clock: any, transport: any, ttl: number?, budget: number?)
	return Client.new({
		transport = transport,
		cache = Cache.new(ttl or 60, clock.now, function()
			return 0.5
		end),
		bucket = TokenBucket.new(budget or 20, clock.now),
		backoff = Backoff.new(clock.now, function()
			return 0.5
		end),
		wait = clock.wait,
		baseUrl = "https://example.test",
		apiKey = "secret",
	})
end

return {
	["caches until ttl then refetches"] = function()
		local clock = Fakes.clock()
		local transport = Fakes.transport({
			{ success = true, status = 200, body = "one" },
			{ success = true, status = 200, body = "two" },
		})
		local client = makeClient(clock, transport, 10)
		local first, firstMeta = client:request("GET", "/x")
		local second, secondMeta = client:request("GET", "/x")
		Expect.equal(first, "one")
		Expect.equal(firstMeta.source, "network")
		Expect.equal(second, "one")
		Expect.equal(secondMeta.source, "cache")
		Expect.equal(#transport.calls, 1)
		clock.advance(11)
		Expect.equal(client:request("GET", "/x"), "two")
		Expect.equal(#transport.calls, 2)
	end,
	["deduplicates 200 concurrent requests"] = function()
		local clock = Fakes.clock()
		local transport = Fakes.transport({ { success = true, status = 200, body = "shared" } }, function()
			task.wait()
		end)
		local client = makeClient(clock, transport)
		client.wait = task.wait
		local done, values = 0, {}
		for index = 1, 200 do
			task.spawn(function()
				values[index] = client:request("GET", "/same")
				done += 1
			end)
		end
		while done < 200 do
			task.wait()
		end
		Expect.equal(#transport.calls, 1)
		for _, value in values do
			Expect.equal(value, "shared")
		end
	end,
	["returns stale on retryable errors and honors cooldown"] = function()
		local clock = Fakes.clock()
		local transport = Fakes.transport({
			{ success = true, status = 200, body = "old" },
			{ success = false, status = 429, headers = { ["Retry-After"] = "7" } },
			{ success = true, status = 200, body = "new" },
		})
		local client = makeClient(clock, transport, 1)
		client:request("GET", "/x")
		clock.advance(2)
		local stale, meta = client:request("GET", "/x")
		Expect.equal(stale, "old")
		Expect.equal(meta.source, "stale")
		Expect.equal(meta.error, "rate_limited")
		client:request("GET", "/y")
		Expect.truthy(clock.now() >= 9)
	end,
	["backs off on Roblox's own HTTP limit (status 0)"] = function()
		local clock = Fakes.clock()
		local transport = Fakes.transport({
			{ success = false, status = 0, kind = "rate_limited" },
			{ success = true, status = 200, body = "ok" },
		})
		local client = makeClient(clock, transport, 1)
		local _, meta = client:request("GET", "/x")
		Expect.equal(meta.error, "rate_limited")
		local start = clock.now()
		client:request("GET", "/x")
		Expect.truthy(clock.now() > start) -- the retry waited out the backoff instead of firing immediately
	end,
	["returns stale immediately during cooldown"] = function()
		local clock = Fakes.clock()
		local transport = Fakes.transport({
			{ success = true, status = 200, body = "old" },
			{ success = false, status = 429, headers = { ["Retry-After"] = "7" } },
		})
		local client = makeClient(clock, transport, 1)
		local waits = 0
		client.wait = function(seconds)
			waits += 1
			clock.wait(seconds)
		end
		client:request("GET", "/x")
		clock.advance(2)
		client:request("GET", "/x")
		local value, meta = client:request("GET", "/x")
		Expect.equal(value, "old")
		Expect.equal(meta.source, "stale")
		Expect.equal(waits, 0)
	end,
	["handles transport errors without stranding waiters"] = function()
		local clock = Fakes.clock()
		local transport = { calls = 0 }
		function transport:request(_request)
			self.calls += 1
			task.wait()
			error("offline")
		end
		local client = makeClient(clock, transport)
		client.wait = task.wait
		local done, errors = 0, {}
		for index = 1, 2 do
			task.spawn(function()
				local _value, meta = client:request("GET", "/broken")
				errors[index] = meta.error
				done += 1
			end)
		end
		while done < 2 do
			task.wait()
		end
		Expect.equal(transport.calls, 1)
		Expect.equal(errors[1], "network")
		Expect.equal(errors[2], "network")
	end,
	["waits for budget when no stale value exists"] = function()
		local clock = Fakes.clock()
		local transport = Fakes.transport()
		local client = makeClient(clock, transport, 60, 5)
		for index = 1, 6 do
			client:request("GET", "/" .. tostring(index))
		end
		Expect.equal(#transport.calls, 6)
		Expect.equal(clock.now(), 12)
	end,
}
