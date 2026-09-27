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
		reporter:report(1, "unavailable")
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
		Expect.equal(#scheduled, 0)
		Expect.equal(#calls, 0)
	end,
}
