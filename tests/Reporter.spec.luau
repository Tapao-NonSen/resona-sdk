--!strict
-- Reporter batching, deduplication, and rate tests.
local Reporter = require("../src/Reporter")
local Expect = require("./helpers/Expect")
return {
	["flushes at most 25 reports per interval"] = function()
		local calls, scheduled = {}, {}
		local client = {}
		function client:request(method: string, path: string, body: string)
			table.insert(calls, { method, path, body })
		end
		local reporter = Reporter.new(client, function(value)
			return value
		end, function() end, function(callback)
			table.insert(scheduled, callback)
		end, 60)
		for id = 1, 30 do
			reporter:report(id, "unavailable")
		end
		Expect.equal(reporter:report(1, "unavailable"), false)
		Expect.equal(#calls, 0)
		Expect.equal(#scheduled, 1)
		scheduled[1]()
		Expect.equal(#calls, 1)
		Expect.equal(#calls[1][3], 25)
		Expect.equal(#scheduled, 2)
		scheduled[2]()
		Expect.equal(#calls, 2)
		Expect.equal(#calls[2][3], 5)
	end,
	["drops invalid reports"] = function()
		local calls, scheduled = {}, {}
		local client = {}
		function client:request(_method: string, _path: string, body: string)
			table.insert(calls, body)
		end
		local reporter = Reporter.new(client, function(value)
			return value
		end, function() end, function(callback)
			table.insert(scheduled, callback)
		end, 60)
		reporter:report(0, "unavailable")
		reporter:report(1, "wrong")
		reporter:report(2, "metadata", string.rep("x", 501))
		reporter:report(2, "metadata", nil, { artworkAssetId = -1 })
		reporter:report(2, "metadata", nil, { genre = " " })
		Expect.equal(#scheduled, 0)
		Expect.equal(#calls, 0)
	end,
	["sends an uploaded cover suggestion"] = function()
		local sent
		local client = {}
		function client:request(_method: string, _path: string, body: any)
			sent = body
		end
		local reporter = Reporter.new(client, function(value)
			return value
		end, function() end, function(callback)
			callback()
		end, 60)
		reporter:report(123, "metadata", "Exact cover", { artworkAssetId = 456 })
		Expect.equal(sent[1].suggested.artworkAssetId, 456)
	end,
	["sends genre with or without a cover"] = function()
		local sent = {}
		local client = {}
		function client:request(_method: string, _path: string, body: any)
			for _, report in body do table.insert(sent, report) end
		end
		local reporter = Reporter.new(client, function(value) return value end, function() end, function(callback)
			callback()
		end, 60)
		reporter:report(123, "metadata", "Wrong genre", { genre = "drum & bass" })
		reporter:report(124, "metadata", "Cover and genre", { artworkAssetId = 456, genre = "electronic" })
		Expect.equal(sent[1].suggested.genre, "drum & bass")
		Expect.equal(sent[2].suggested.artworkAssetId, 456)
		Expect.equal(sent[2].suggested.genre, "electronic")
	end,
	["keeps add title and artist as separate fields"] = function()
		local sent
		local client = {}
		function client:request(_method: string, _path: string, body: any) sent = body end
		local reporter = Reporter.new(client, function(value) return value end, function() end,
			function(callback) callback() end, 60)
		Expect.equal(reporter:report(123, "add", nil, { title = "Shiawase", artist = "Dion Timmer" }), true)
		Expect.equal(sent[1].suggested.title, "Shiawase")
		Expect.equal(sent[1].suggested.artist, "Dion Timmer")
		Expect.equal(reporter:report(124, "add", nil, { title = "Song", artist = " " }), false)
	end,
}
