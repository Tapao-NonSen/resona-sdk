--!strict
-- Catalog endpoints decode API responses and provide filtered seed fallbacks.
local Query = require("./Query")
local Types = require("./Types")
local Catalog = {}
Catalog.__index = Catalog

export type Client = { request: (self: Client, method: string, path: string, body: string?) -> (string?, Types.Meta) }
type TracksResponse = Types.Page
type SearchResponse = { tracks: { Types.Track } }
type GenresResponse = { genres: { Types.GenreCount } }
type RandomResponse = { tracks: { Types.Track } }
export type Disallowed = { genres: { [string]: boolean }, assetIds: { [number]: boolean }, uploaderIds: string? }
type CatalogState = {
	client: Client,
	decode: (string) -> unknown,
	seed: { Types.Track },
	warned: { [string]: boolean },
	disallow: Disallowed,
}

function Catalog.new(
	client: Client,
	jsonDecode: (string) -> unknown,
	seed: { Types.Track },
	disallow: Disallowed?
): CatalogState
	return setmetatable({
		client = client,
		decode = jsonDecode,
		seed = seed,
		warned = {},
		disallow = disallow or { genres = {}, assetIds = {}, uploaderIds = nil },
	}, Catalog)
end

-- The game's disallow list: genres and asset IDs are dropped here; uploaders are filtered by the API.
function Catalog:_allowed(track: any): boolean
	return type(track) == "table"
		and not self.disallow.assetIds[track.id]
		and not (type(track.genre) == "string" and self.disallow.genres[track.genre:lower()])
end

function Catalog:_keep(tracks: any): { Types.Track }
	local kept = {}
	for _, track in if type(tracks) == "table" then tracks else {} do
		if self:_allowed(track) then
			table.insert(kept, track)
		end
	end
	return kept
end

function Catalog:_query(filters: any): any
	local query = table.clone(filters or {})
	query.excludeUploaders = self.disallow.uploaderIds
	return query
end

function Catalog:_seed(filters: Types.Filters?): { Types.Track }
	local tracks: { Types.Track } = {}
	for _, track in self.seed do
		if
			(not filters or not filters.genre or track.genre:lower() == filters.genre:lower())
			and (not filters or not filters.durationMax or track.duration <= filters.durationMax)
			and self:_allowed(track)
		then
			table.insert(tracks, track)
		end
	end
	return tracks
end

function Catalog:_get(path: string, fallback: unknown): (unknown, Types.Meta)
	local body, meta = self.client:request("GET", path)
	if body ~= nil then
		local ok, decoded = pcall(self.decode, body)
		if ok then
			return decoded, meta
		end
		meta.error = "invalid_json"
	end
	meta.source = "seed"
	return fallback, meta
end

-- An empty genre query comes back with genres that do have tracks: expose them and warn once per genre.
function Catalog:_suggest(value: any, meta: Types.Meta, filters: Types.Filters?)
	local suggested = if type(value) == "table" then value.suggestedGenres else nil
	if type(suggested) ~= "table" or #suggested == 0 then
		return
	end
	meta.suggestedGenres = suggested
	local genre = if filters and filters.genre then filters.genre else ""
	if not self.warned[genre] then
		self.warned[genre] = true
		warn(`[Resona] No tracks for genre "{genre}"; available: {table.concat(suggested, ", ")}`)
	end
end

local function withQuery(path: string, filters: Types.Filters?): string
	local query = Query.build(filters)
	return path .. (if query == "" then "" else "?" .. query)
end

function Catalog:tracks(filters: Types.Filters?): (Types.Page, Types.Meta)
	local value: any, meta =
		self:_get(withQuery("/v1/tracks", self:_query(filters)), { tracks = self:_seed(filters), next = nil })
	self:_suggest(value, meta, filters)
	if type(value) ~= "table" then
		value = { tracks = {}, next = nil }
	end
	return { tracks = self:_keep(value.tracks), next = value.next } :: TracksResponse, meta
end

function Catalog:get(id: number): (Types.Track?, Types.Meta)
	local fallback: Types.Track? = nil
	for _, track in self.seed do
		if track.id == id then
			fallback = track
			break
		end
	end
	local value, meta = self:_get(withQuery("/v1/tracks/" .. tostring(id), self:_query(nil)), fallback)
	return if self:_allowed(value) then value :: Types.Track? else nil, meta
end

function Catalog:search(text: string, filters: Types.Filters?): ({ Types.Track }, Types.Meta)
	local query = self:_query(filters)
	query.q = text
	local value: any, meta = self:_get(withQuery("/v1/search", query), { tracks = self:_seed(filters) })
	return self:_keep(if type(value) == "table" then value.tracks else nil), meta
end

function Catalog:genres(kind: string?): ({ Types.GenreCount }, Types.Meta)
	local value, meta =
		self:_get(withQuery("/v1/genres", { kind = kind }), { genres = { { genre = "electronic", n = #self.seed } } })
	local kept = {}
	for _, item in (value :: GenresResponse).genres or {} do
		if not (type(item.genre) == "string" and self.disallow.genres[item.genre:lower()]) then
			table.insert(kept, item)
		end
	end
	return kept, meta
end

function Catalog:randomPool(filters: Types.Filters?, count: number): ({ Types.Track }, Types.Meta)
	local query = self:_query(filters)
	query.count = count
	local value: any, meta = self:_get(withQuery("/v1/random", query), { tracks = self:_seed(filters) })
	self:_suggest(value, meta, filters)
	return self:_keep(if type(value) == "table" then value.tracks else nil), meta
end

return Catalog
