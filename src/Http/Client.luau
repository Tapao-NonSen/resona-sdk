--!strict
-- Pure HTTP pipeline coordinating cache, single-flight, budget, and backoff.
local Types = require("../Types")
local Client = {}
Client.__index = Client

export type Cache = {
	getFresh: (self: Cache, key: string) -> string?,
	getStale: (self: Cache, key: string) -> string?,
	set: (self: Cache, key: string, value: string) -> (),
}
export type Bucket = { tryTake: (self: Bucket) -> boolean, timeUntilNext: (self: Bucket) -> number }
export type Backoff = {
	timeRemaining: (self: Backoff) -> number,
	fail: (self: Backoff, retryAfter: number?) -> number,
	success: (self: Backoff) -> (),
}
export type Dependencies = {
	transport: Types.Transport,
	cache: Cache,
	bucket: Bucket,
	backoff: Backoff,
	wait: (seconds: number) -> (),
	baseUrl: string,
	apiKey: string | Secret,
}
type Flight = { done: boolean, value: string?, meta: Types.Meta? }
type ClientState = Dependencies & { inFlight: { [string]: Flight } }

function Client.new(deps: Dependencies): ClientState
	return setmetatable({
		transport = deps.transport,
		cache = deps.cache,
		bucket = deps.bucket,
		backoff = deps.backoff,
		wait = deps.wait,
		baseUrl = deps.baseUrl,
		apiKey = deps.apiKey,
		inFlight = {},
	}, Client)
end

local function errorKind(response: Types.Response): string
	if response.kind then
		return response.kind
	end
	if response.status == 429 then
		return "rate_limited"
	end
	if response.status >= 500 then
		return "server"
	end
	if response.status == 401 then
		return "unauthorized"
	end
	if response.status == 404 then
		return "not_found"
	end
	return "bad_request"
end

function Client:request(method: string, path: string, body: string?): (string?, Types.Meta)
	local key = method .. " " .. path
	if method == "GET" then
		local fresh = self.cache:getFresh(key)
		if fresh ~= nil then
			return fresh, { source = "cache" }
		end
		local flight = self.inFlight[key]
		if flight then
			while not flight.done do
				self.wait(0)
			end
			return flight.value, flight.meta
		end
		flight = { done = false }
		self.inFlight[key] = flight
	end

	local function finish(value: string?, meta: Types.Meta): (string?, Types.Meta)
		local flight = self.inFlight[key]
		if flight then
			flight.value, flight.meta, flight.done = value, meta, true
			self.inFlight[key] = nil
		end
		return value, meta
	end

	local stale = if method == "GET" then self.cache:getStale(key) else nil
	if not self.bucket:tryTake() then
		if stale ~= nil then
			return finish(stale, { source = "stale", error = "budget_exhausted" })
		end
		self.wait(self.bucket:timeUntilNext())
		if not self.bucket:tryTake() then
			return finish(nil, { source = "stale", error = "budget_exhausted" })
		end
	end
	local cooldown = self.backoff:timeRemaining()
	if cooldown > 0 then
		if stale ~= nil then
			return finish(stale, { source = "stale", error = "cooldown" })
		end
		self.wait(cooldown)
	end

	local ok, responseOrError = pcall(function(): Types.Response
		return self.transport:request({
			method = method,
			url = self.baseUrl .. path,
			headers = { ["x-api-key"] = self.apiKey, ["content-type"] = "application/json" },
			body = body,
		})
	end)
	local response: Types.Response = if ok
		then responseOrError :: Types.Response
		else { success = false, status = 0, kind = "network" }
	if response.success and response.status >= 200 and response.status < 300 then
		self.backoff:success()
		if method == "GET" then
			self.cache:set(key, response.body)
		end
		return finish(response.body, { source = "network" })
	end

	local kind = errorKind(response)
	-- rate_limited covers both HTTP 429 and Roblox's own "Number of requests exceeded limit" (status 0).
	if kind == "rate_limited" or kind == "network" or response.status >= 500 then
		local retryAfter = response.headers
			and tonumber(response.headers["Retry-After"] or response.headers["retry-after"])
		self.backoff:fail(retryAfter)
	end
	return finish(stale, { source = if stale ~= nil then "stale" else "seed", error = kind })
end

return Client
