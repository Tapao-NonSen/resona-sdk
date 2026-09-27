--!strict
-- Catalog decoding and constrained seed fallback tests.
local Catalog = require("../src/Catalog")
local Expect = require("./helpers/Expect")
return {
	["decodes success and filters seed fallback"] = function()
		local client = { calls = 0 }
		function client:request(_method: string, _path: string)
			self.calls += 1
			if self.calls == 1 then
				return "encoded", { source = "network" }
			end
			return nil, { source = "seed", error = "network" }
		end
		local seed = {
			{ id = 1, genre = "dance", duration = 100 },
			{ id = 2, genre = "rock", duration = 90 },
			{ id = 3, genre = "dance", duration = 300 },
		}
		local catalog = Catalog.new(client, function()
			return { tracks = { { id = 9 } }, next = 4 }
		end, seed)
		local page = catalog:tracks({ genre = "dance" })
		Expect.equal(page.tracks[1].id, 9)
		local fallback, meta = catalog:tracks({ genre = "dance", durationMax = 200 })
		Expect.equal(#fallback.tracks, 1)
		Expect.equal(fallback.tracks[1].id, 1)
		Expect.equal(meta.source, "seed")
	end,
	["exposes suggested genres for an empty genre"] = function()
		local client = {}
		function client:request(_method: string, _path: string)
			return "encoded", { source = "network" }
		end
		local catalog = Catalog.new(client, function()
			return { tracks = {}, suggestedGenres = { "pop", "rock" } }
		end, {})
		local tracks, meta = catalog:randomPool({ genre = "jazz" }, 10)
		Expect.equal(#tracks, 0)
		Expect.deepEqual(meta.suggestedGenres, { "pop", "rock" })
		local _, pageMeta = catalog:tracks({ genre = "jazz" })
		Expect.deepEqual(pageMeta.suggestedGenres, { "pop", "rock" })
	end,
}
