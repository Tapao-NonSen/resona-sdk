--!strict
-- Random pool request count and no-repeat tests.
local Pool = require("../src/Pool")
local Expect = require("./helpers/Expect")
return {
	["serves 60 picks with at most two requests"] = function()
		local catalog = { calls = 0 }
		function catalog:randomPool(_filters: any, count: number)
			self.calls += 1
			local tracks = {}
			for index = 1, count do
				table.insert(tracks, { id = (self.calls - 1) * count + index })
			end
			return tracks, { source = "network" }
		end
		local pool = Pool.new(catalog, 50, 10, function(callback)
			callback()
		end, function()
			return 0.5
		end)
		local seen = {}
		for _ = 1, 60 do
			local track = pool:next({ genre = "dance" })
			Expect.equal(seen[track.id], nil)
			seen[track.id] = true
		end
		Expect.truthy(catalog.calls <= 2)
	end,
	["caps cached filter pools"] = function()
		local catalog = {}
		function catalog:randomPool()
			return { { id = 1 } }, { source = "network" }
		end
		local pool = Pool.new(catalog, 1, 0, function(callback) callback() end)
		for index = 1, 40 do pool:next({ genre = tostring(index) }) end
		local count = 0
		for _ in pool.pools do count += 1 end
		Expect.equal(count, 32)
	end,
}
