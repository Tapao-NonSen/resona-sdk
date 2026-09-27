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
	["disallow resolves to lookup sets and a sorted uploader list"] = function()
		local resolved = Config.resolve({
			apiKey = "test",
			disallow = { genres = { "Phonk" }, assetIds = { 10 }, uploaderIds = { 7, 5 } },
		}) :: any
		Expect.equal(resolved.disallow.genres.phonk, true)
		Expect.equal(resolved.disallow.assetIds[10], true)
		Expect.equal(resolved.disallow.uploaderIds, "5,7")
		Expect.equal(Config.resolve({ apiKey = "test" }).disallow.uploaderIds, nil)
		local invalid, message = Config.resolve({ apiKey = "test", disallow = { uploaderIds = { 1.5 } } } :: any)
		Expect.equal(invalid, nil)
		Expect.equal(message, "disallow.uploaderIds must contain positive integer ids")
	end,
}
