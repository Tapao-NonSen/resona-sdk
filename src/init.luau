--!strict
-- Public facade wiring the SDK's focused modules; behavior lives in those modules.
local Types = require("@self/Types")
local Config = require("@self/Config")
local Seed = require("@self/Seed")
local Cache = require("@self/Http/Cache")
local TokenBucket = require("@self/Http/TokenBucket")
local Backoff = require("@self/Http/Backoff")
local Client = require("@self/Http/Client")
local Catalog = require("@self/Catalog")
local Pool = require("@self/Pool")
local Reporter = require("@self/Reporter")
local ReportClient = require("@self/ReportClient")
local ReportGui = require("@self/ReportGui")
local Observer = require("@self/Observer")
local ClientBridge = require("@self/ClientBridge")
local ClientPlayer = require("@self/ClientPlayer")
local Player = require("@self/Player")

export type Track = Types.Track
export type Filters = Types.Filters
export type ConfigInput = Types.Config
export type Meta = Types.Meta
export type Page = Types.Page
export type Transport = Types.Transport
export type Request = Types.Request
export type Response = Types.Response
export type ReportKind = Types.ReportKind
export type MetadataSuggestion = Types.MetadataSuggestion
export type AddSuggestion = Types.AddSuggestion
export type BeatInfo = Types.BeatInfo

local Resona = { VERSION = "0.3.0", Player = ClientPlayer, ServerPlayer = Player, ReportGui = ReportGui }
type CatalogApi = {
	tracks: (self: CatalogApi, filters: Types.Filters?) -> (Types.Page, Types.Meta),
	get: (self: CatalogApi, id: number) -> (Types.Track?, Types.Meta),
	search: (self: CatalogApi, text: string, filters: Types.Filters?) -> ({ Types.Track }, Types.Meta),
	genres: (self: CatalogApi, kind: string?) -> ({ Types.GenreCount }, Types.Meta),
}
type PoolApi = { next: (self: PoolApi, filters: Types.Filters?) -> (Types.Track?, Types.Meta) }
type ReporterApi = {
	report: (
		self: ReporterApi,
		assetId: number,
		kind: string,
		note: string?,
		suggested: Types.ReportSuggestion?
	) -> boolean,
}
type State = {
	catalog: CatalogApi,
	pool: PoolApi,
	reporter: ReporterApi,
	validateAdd: (number) -> (boolean, string, any?),
}
local state: State? = nil
local warned = { http_disabled = false, unauthorized = false }
local notInitialized: Types.Meta = { source = "seed", error = "not initialized" }

function Resona.init(input: Types.Config)
	if not game:GetService("RunService"):IsServer() then
		warn("[Resona] init must run on the server so the API key stays private")
		return
	end
	local resolved, configError = Config.resolve(input)
	if not resolved then
		state = nil
		warn("[Resona] " .. tostring(configError))
		return
	end
	local RobloxTransport = require("@self/Http/RobloxTransport")
	local transport = resolved.transport or RobloxTransport.new()
	local now, waitFn = os.clock, task.wait
	local client = Client.new({
		transport = transport,
		cache = Cache.new(resolved.cacheTtl, now),
		bucket = TokenBucket.new(resolved.httpBudgetPerMin, now),
		backoff = Backoff.new(now),
		wait = waitFn,
		baseUrl = resolved.baseUrl,
		apiKey = resolved.apiKey,
	})
	local catalog = Catalog.new(client, RobloxTransport.decode, Seed)
	local pool = Pool.new(catalog, Config.POOL_SIZE, Config.POOL_REFILL_AT)
	local reporter = Reporter.new(client, RobloxTransport.encode, waitFn, nil, Config.REPORT_INTERVAL)
	local observer = if resolved.contribute then Observer.new(client, RobloxTransport.encode, waitFn, nil) else nil
	local function validateAdd(id: number): (boolean, string, any?)
		local body, meta = client:request("GET", "/v1/reports/add-check/" .. tostring(id))
		if not body or meta.error then
			return false, "Public audio check unavailable. Try again later."
		end
		local ok, result = pcall(RobloxTransport.decode, body)
		if not ok or type(result) ~= "table" then
			return false, "Public audio check unavailable. Try again later."
		end
		if result.eligible == true then
			return true, "Public Music confirmed.", result.asset
		end
		if result.reason == "not_public" then
			return false, "This ID is not listed publicly in the Creator Store."
		end
		if result.reason == "not_music" then
			return false, "This is not a Music audio asset."
		end
		if result.reason == "too_short" then
			return false, "Music must be at least 60 seconds long."
		end
		return false, "Could not verify this public audio asset."
	end
	state = { catalog = catalog, pool = pool, reporter = reporter, validateAdd = validateAdd }
	ClientBridge.start(pool, observer, reporter, resolved.showReportGui, validateAdd)
	Player.configure({
		pool = pool,
		reporter = if resolved.contribute then reporter else { report = function() end },
		observer = observer,
		now = now,
		wait = waitFn,
		loadTimeout = Config.LOAD_TIMEOUT,
		runService = game:GetService("RunService"),
	})
end

local function noteWarning(meta: Types.Meta)
	if meta.error == "http_disabled" and not warned.http_disabled then
		warned.http_disabled = true
		warn("[Resona] HTTP requests are not enabled; using bundled tracks")
	elseif meta.error == "unauthorized" and not warned.unauthorized then
		warned.unauthorized = true
		warn("[Resona] API key was rejected")
	end
end

local function call<T>(fallback: T, request: () -> (T, Types.Meta)): (T, Types.Meta)
	if not state then
		return fallback, notInitialized
	end
	local value, meta = request()
	noteWarning(meta)
	return value, meta
end

function Resona.tracks(filters: Types.Filters?): (Types.Page, Types.Meta)
	return call({ tracks = Seed, next = nil }, function()
		return (state :: State).catalog:tracks(filters)
	end)
end
function Resona.get(id: number): (Types.Track?, Types.Meta)
	return call(nil, function()
		return (state :: State).catalog:get(id)
	end)
end
function Resona.search(text: string, filters: Types.Filters?): ({ Types.Track }, Types.Meta)
	return call({}, function()
		return (state :: State).catalog:search(text, filters)
	end)
end
function Resona.random(filters: Types.Filters?): (Types.Track?, Types.Meta)
	return call(Seed[math.random(1, #Seed)], function()
		return (state :: State).pool:next(filters)
	end)
end
function Resona.genres(): ({ Types.GenreCount }, Types.Meta)
	return call({ { genre = "electronic", n = #Seed } }, function()
		return (state :: State).catalog:genres(nil)
	end)
end
function Resona.report(assetId: number, kind: Types.ReportKind, note: string?, suggested: Types.ReportSuggestion?)
	if game:GetService("RunService"):IsClient() then
		return ReportClient.submit(assetId, kind, note, suggested)
	end
	if state then
		if kind == "add" then
			if type(assetId) ~= "number" or assetId % 1 ~= 0 or assetId <= 0 or assetId > 9007199254740991 then
				return false
			end
			local eligible = state.validateAdd(assetId)
			if not eligible then
				return false
			end
		end
		return state.reporter:report(assetId, kind, note, suggested)
	end
	return false
end

function Resona.checkAdd(assetId: number): (boolean, string, any?)
	if game:GetService("RunService"):IsClient() then
		return ReportClient.checkAdd(assetId)
	end
	if not state then
		return false, "Resona is not initialized."
	end
	if type(assetId) ~= "number" or assetId % 1 ~= 0 or assetId <= 0 or assetId > 9007199254740991 then
		return false, "Enter a valid Roblox audio asset ID."
	end
	return state.validateAdd(assetId)
end

return Resona
