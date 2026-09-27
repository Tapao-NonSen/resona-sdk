--!strict
-- Runs every module spec with compact per-test pass/fail output.
local process = require("@lune/process")
local specs = {
	"BeatClock",
	"Query",
	"Config",
	"Cache",
	"TokenBucket",
	"Backoff",
	"Client",
	"Pool",
	"Reporter",
	"Observer",
	"Analysis",
	"Catalog",
}
local passed, failed = 0, 0
for _, name in specs do
	local tests = require("./" .. name .. ".spec")
	local names = {}
	for testName in tests do
		table.insert(names, testName)
	end
	table.sort(names)
	for _, testName in names do
		local ok, message = pcall(tests[testName])
		if ok then
			passed += 1
			print("[Resona] PASS " .. name .. " - " .. testName)
		else
			failed += 1
			print("[Resona] FAIL " .. name .. " - " .. testName .. ": " .. tostring(message))
		end
	end
end
print(string.format("[Resona] %d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
