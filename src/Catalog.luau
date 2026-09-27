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
type CatalogState = { client: Client, decode: (string) -> unknown, seed: { Types.Track } }

function Catalog.new(client: Client, jsonDecode: (string) -> unknown, seed: { Types.Track }): CatalogState
	return setmetatable({ client = client, decode = jsonDecode, seed = seed }, Catalog)
end

function Catalog:_seed(filters: Types.Filters?): { Types.Track }
	local tracks: { Types.Track } = {}
	for _, track in self.seed do
		if
			(not filters or not filters.genre or track.genre == filters.genre)
			and (not filters or not filters.durationMax or track.duration <= filters.durationMax)
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

local function withQuery(path: string, filters: Types.Filters?): string
	local query = Query.build(filters)
	return path .. (if query == "" then "" else "?" .. query)
end

function Catalog:tracks(filters: Types.Filters?): (Types.Page, Types.Meta)
	local value, meta = self:_get(withQuery("/v1/tracks", filters), { tracks = self:_seed(filters), next = nil })
	return value :: TracksResponse, meta
end

function Catalog:get(id: number): (Types.Track?, Types.Meta)
	local fallback: Types.Track? = nil
	for _, track in self.seed do
		if track.id == id then
			fallback = track
			break
		end
	end
	local value, meta = self:_get("/v1/tracks/" .. tostring(id), fallback)
	return value :: Types.Track?, meta
end

function Catalog:search(text: string, filters: Types.Filters?): ({ Types.Track }, Types.Meta)
	local query = table.clone(filters or {})
	query.q = text
	local value, meta = self:_get(withQuery("/v1/search", query), { tracks = self:_seed(filters) })
	return (value :: SearchResponse).tracks or {}, meta
end

function Catalog:genres(kind: string?): ({ Types.GenreCount }, Types.Meta)
	local value, meta =
		self:_get(withQuery("/v1/genres", { kind = kind }), { genres = { { genre = "electronic", n = #self.seed } } })
	return (value :: GenresResponse).genres or {}, meta
end

function Catalog:randomPool(filters: Types.Filters?, count: number): ({ Types.Track }, Types.Meta)
	local query = table.clone(filters or {})
	query.count = count
	local value, meta = self:_get(withQuery("/v1/random", query), { tracks = self:_seed(filters) })
	return (value :: RandomResponse).tracks or {}, meta
end

return Catalog
