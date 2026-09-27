--!strict
-- Tiny readable assertions for the dependency-free Lune test runner.
local Expect = {}

function Expect.equal(actual: any, expected: any)
	assert(actual == expected, string.format("expected %s, got %s", tostring(expected), tostring(actual)))
end

local function same(left: any, right: any, seen: { [any]: boolean }): boolean
	if left == right then
		return true
	end
	if type(left) ~= "table" or type(right) ~= "table" or seen[left] then
		return false
	end
	seen[left] = true
	for key, value in left do
		if not same(value, right[key], seen) then
			return false
		end
	end
	for key in right do
		if left[key] == nil then
			return false
		end
	end
	return true
end

function Expect.deepEqual(actual: any, expected: any)
	assert(same(actual, expected, {}), "tables are not deeply equal")
end

function Expect.truthy(value: any)
	assert(value, "expected a truthy value")
end

return Expect
