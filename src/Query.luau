--!strict
-- Converts filters into stable, URL-safe query strings used as cache keys.
local Types = require("./Types")
local Query = {}

local function encode(value: string | number): string
	return tostring(value)
		:gsub("\n", "\r\n")
		:gsub("([^%w%-%.%_%~ ])", function(char)
			return string.format("%%%02X", string.byte(char))
		end)
		:gsub(" ", "%%20")
end

function Query.build(filters: Types.Filters?): string
	local keys = {}
	for key, value in filters or {} do
		if value ~= nil then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	local parts = {}
	for _, key in keys do
		local value = (filters :: Types.Filters)[key :: keyof<Types.Filters>]
		if value ~= nil then
			table.insert(parts, encode(key) .. "=" .. encode(value))
		end
	end
	return table.concat(parts, "&")
end

return Query
