--!strict
local Config = require("../src/Config")
local Expect = require("./helpers/Expect")

return {
	["report panel is off until enabled by the server"] = function()
		local default = Config.resolve({ apiKey = "test" })
		local enabled = Config.resolve({ apiKey = "test", showReportGui = true })
		local invalid, message = Config.resolve({ apiKey = "test", showReportGui = "yes" } :: any)
		Expect.equal(default.showReportGui, false)
		Expect.equal(enabled.showReportGui, true)
		Expect.equal(invalid, nil)
		Expect.equal(message, "showReportGui must be a boolean")
	end,
}
