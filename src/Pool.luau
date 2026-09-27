--!strict
-- Maintains shuffled per-query random pools and refills them before exhaustion.
local Query = require("./Query")
local Types = require("./Types")
local Pool = {}
Pool.__index = Pool

export type Catalog = {
	randomPool: (self: Catalog, filters: Types.Filters?, count: number) -> ({ Types.Track }, Types.Meta),
}
type Entry = { tracks: { Types.Track }, meta: Types.Meta, filling: boolean }
type PoolState = {
	catalog: Catalog,
	size: number,
	refillAt: number,
	spawn: (() -> ()) -> (),
	random: () -> number,
	pools: { [string]: Entry },
}

function Pool.new(
	catalog: Catalog,
	size: number,
	refillAt: number,
	spawnFn: ((() -> ()) -> ())?,
	random: (() -> number)?
): PoolState
	return setmetatable({
		catalog = catalog,
		size = size,
		refillAt = refillAt,
		spawn = spawnFn or task.spawn,
		random = random or math.random,
		pools = {},
	}, Pool)
end

function Pool:_shuffle(tracks: { Types.Track })
	for index = #tracks, 2, -1 do
		local other = math.floor(self.random() * index) + 1
		tracks[index], tracks[other] = tracks[other], tracks[index]
	end
end

function Pool:_fill(key: string, filters: Types.Filters?): Entry
	local tracks, meta = self.catalog:randomPool(filters, self.size)
	self:_shuffle(tracks)
	self.pools[key] = { tracks = tracks, meta = meta, filling = false }
	return self.pools[key]
end

function Pool:next(filters: Types.Filters?): (Types.Track?, Types.Meta)
	local key = Query.build(filters)
	local pool = self.pools[key]
	if not pool or #pool.tracks == 0 then
		pool = self:_fill(key, filters)
	end
	local track = table.remove(pool.tracks)
	local meta = pool.meta
	if #pool.tracks < self.refillAt and not pool.filling then
		pool.filling = true
		self.spawn(function()
			self:_fill(key, filters)
		end)
	end
	return track, meta
end

return Pool
