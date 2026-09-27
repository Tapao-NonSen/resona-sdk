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

local Resona = { VERSION = "0.1.0", Player = Player }
type CatalogApi = {
	tracks: (self: CatalogApi, filters: Types.Filters?) -> (Types.Page, Types.Meta),
	get: (self: CatalogApi, id: number) -> (Types.Track?, Types.Meta),
	search: (self: CatalogApi, text: string, filters: Types.Filters?) -> ({ Types.Track }, Types.Meta),
	genres: (self: CatalogApi, kind: string?) -> ({ Types.GenreCount }, Types.Meta),
}
type PoolApi = { next: (self: PoolApi, filters: Types.Filters?) -> (Types.Track?, Types.Meta) }
type ReporterApi = { report: (self: ReporterApi, assetId: number, kind: string, note: string?) -> () }
type State = { catalog: CatalogApi, pool: PoolApi, reporter: ReporterApi }
local state: State? = nil
local warned = { http_disabled = false, unauthorized = false }
local notInitialized: Types.Meta = { source = "seed", error = "not initialized" }

function Resona.init(input: Types.Config)
	local resolved, configError = Config.resolve(input)
	if not resolved then
		state = nil
		warn("Resona: " .. tostring(configError))
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
	state = { catalog = catalog, pool = pool, reporter = reporter }
	Player.configure({ pool = pool, reporter = reporter, now = now, wait = waitFn, loadTimeout = Config.LOAD_TIMEOUT })
end

local function noteWarning(meta: Types.Meta)
	if meta.error == "http_disabled" and not warned.http_disabled then
		warned.http_disabled = true
		warn("Resona: HTTP requests are not enabled; using bundled tracks")
	elseif meta.error == "unauthorized" and not warned.unauthorized then
		warned.unauthorized = true
		warn("Resona: API key was rejected")
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
function Resona.report(assetId: number, kind: Types.ReportKind, note: string?)
	if state then
		state.reporter:report(assetId, kind, note)
	end
end

return Resona
