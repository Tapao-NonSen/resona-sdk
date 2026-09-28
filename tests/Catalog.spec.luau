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
	["drops disallowed genres and ids, sends uploaders to the API"] = function()
		local paths = {}
		local client = {}
		function client:request(_method: string, path: string)
			table.insert(paths, path)
			return "encoded", { source = "network" }
		end
		local tracks = {
			{ id = 1, genre = "Phonk" },
			{ id = 2, genre = "pop" },
			{ id = 3, genre = "rock" },
		}
		local catalog = Catalog.new(client, function()
			return { tracks = tracks, next = 9 }
		end, {}, { genres = { phonk = true }, assetIds = { [3] = true }, uploaderIds = "5,7" })
		local page = catalog:tracks({ genre = "pop" })
		Expect.equal(#page.tracks, 1)
		Expect.equal(page.tracks[1].id, 2)
		Expect.equal(page.next, 9)
		Expect.equal(#catalog:randomPool(nil, 10), 1)
		Expect.equal(#catalog:search("x", nil), 1)
		assert(paths[1]:find("excludeUploaders=5%2C7", 1, true), paths[1])
		assert(paths[2]:find("excludeUploaders=5%2C7", 1, true), paths[2])
		local single = Catalog.new(client, function()
			return { id = 3, genre = "rock" }
		end, {}, { genres = {}, assetIds = { [3] = true }, uploaderIds = nil })
		Expect.equal(single:get(3), nil)
	end,
	["getBatch preserves order (including a JSON-null hole) and applies seed fallback and disallow"] = function()
		local seed = { { id = 5, genre = "dance", duration = 100 } }
		local client = { calls = 0 }
		function client:request(_method: string, _path: string)
			self.calls += 1
			if self.calls == 1 then
				return "encoded", { source = "network" }
			end
			return nil, { source = "seed", error = "network" }
		end
		local catalog = Catalog.new(client, function()
			return { tracks = { { id = 1, genre = "pop" }, nil, { id = 3, genre = "Phonk" } } }
		end, seed, { genres = { phonk = true }, assetIds = {}, uploaderIds = nil })
		-- A miss is a nil hole (like the JSON null it came from): index by position, never trust #tracks.
		local tracks, meta = catalog:getBatch({ 1, 2, 3 })
		Expect.equal(tracks[1].id, 1)
		Expect.equal(tracks[2], nil)
		Expect.equal(tracks[3], nil) -- disallowed genre, even though the API returned it
		Expect.equal(meta.source, "network")
		local fallback = catalog:getBatch({ 5, 9 }) -- request #2 fails; per-id seed fallback
		Expect.equal(fallback[1].id, 5)
		Expect.equal(fallback[2], nil)
	end,
}
