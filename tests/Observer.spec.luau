--!strict
local Observer = require("../src/Observer")
local Expect = require("./helpers/Expect")
return {
	["batches a successful play and upgrades it with analysis"] = function()
		local sent, scheduled = {}, {}
		local client = {}
		function client:request(_method: string, path: string, body: any)
			table.insert(sent, { path = path, body = body })
			return "{}", { source = "network" }
		end
		local observer = Observer.new(client, function(value)
			return value
		end, function() end, function(callback)
			table.insert(scheduled, callback)
		end)
		observer:submit({ assetId = 10, duration = 123 })
		observer:submit({ assetId = 10, duration = 123 })
		scheduled[1]()
		Expect.equal(#sent, 1)
		Expect.equal(sent[1].path, "/v1/observations")
		Expect.equal(sent[1].body[1].duration, 123)
		observer:submit({ assetId = 10, duration = 123, bpm = 120 })
		scheduled[2]()
		Expect.equal(#sent, 2)
		Expect.equal(sent[2].body[1].bpm, 120)
	end,
}
