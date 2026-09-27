--!strict
-- Query canonicalization tests.
local Query = require("../src/Query")
local Expect = require("./helpers/Expect")
return {
	["sorts keys and drops nil"] = function()
		Expect.equal(Query.build({ bpmMax = 130, genre = "dance", mood = nil }), "bpmMax=130&genre=dance")
		Expect.equal(Query.build({ genre = "dance", bpmMax = 130 }), "bpmMax=130&genre=dance")
	end,
}
