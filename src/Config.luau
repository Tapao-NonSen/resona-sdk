--!strict
-- Applies SDK defaults and validates caller-controlled configuration.
local Types = require("./Types")
local Config = {}

Config.BASE_URL = "https://resona.nyxbot.app"
Config.HTTP_BUDGET_PER_MIN = 20
Config.CACHE_TTL = 3600
Config.POOL_SIZE = 50
Config.POOL_REFILL_AT = 10
Config.REPORT_INTERVAL = 60
Config.LOAD_TIMEOUT = 10

export type Resolved = {
	apiKey: string | Secret,
	baseUrl: string,
	httpBudgetPerMin: number,
	cacheTtl: number,
	contribute: boolean,
	showReportGui: boolean,
	disallow: Disallowed,
	transport: Types.Transport?,
}
-- Sets for local filtering; uploader IDs go to the API, which filters on them but never returns them.
export type Disallowed = { genres: { [string]: boolean }, assetIds: { [number]: boolean }, uploaderIds: string? }

local function ids(list: any, name: string, max: number): ({ number }?, string?)
	if list == nil then
		return {}, nil
	end
	if type(list) ~= "table" or #list > max then
		return nil, `disallow.{name} must be a list of at most {max} ids`
	end
	for _, id in list do
		if type(id) ~= "number" or id % 1 ~= 0 or id <= 0 then
			return nil, `disallow.{name} must contain positive integer ids`
		end
	end
	return list, nil
end

function Config.resolve(input: Types.Config): (Resolved?, string?)
	if input == nil or input.apiKey == nil then
		return nil, "apiKey is required"
	end
	local budget = input.httpBudgetPerMin or Config.HTTP_BUDGET_PER_MIN
	local ttl = input.cacheTtl or Config.CACHE_TTL
	if type(budget) ~= "number" or budget <= 0 then
		return nil, "httpBudgetPerMin must be positive"
	end
	if type(ttl) ~= "number" or ttl < 0 then
		return nil, "cacheTtl must be non-negative"
	end
	if input.contribute ~= nil and type(input.contribute) ~= "boolean" then
		return nil, "contribute must be a boolean"
	end
	if input.showReportGui ~= nil and type(input.showReportGui) ~= "boolean" then
		return nil, "showReportGui must be a boolean"
	end
	local disallow = input.disallow or {}
	if type(disallow) ~= "table" then
		return nil, "disallow must be a table"
	end
	local assetIds, assetError = ids(disallow.assetIds, "assetIds", 10000)
	local uploaderIds, uploaderError = ids(disallow.uploaderIds, "uploaderIds", 100)
	if not assetIds or not uploaderIds then
		return nil, assetError or uploaderError
	end
	if disallow.genres ~= nil and type(disallow.genres) ~= "table" then
		return nil, "disallow.genres must be a list of strings"
	end
	local resolvedDisallow: Disallowed = { genres = {}, assetIds = {}, uploaderIds = nil }
	for _, genre in disallow.genres or {} do
		if type(genre) ~= "string" then
			return nil, "disallow.genres must be a list of strings"
		end
		resolvedDisallow.genres[genre:lower()] = true
	end
	for _, id in assetIds do
		resolvedDisallow.assetIds[id] = true
	end
	if #uploaderIds > 0 then
		local sorted = table.clone(uploaderIds)
		table.sort(sorted)
		resolvedDisallow.uploaderIds = table.concat(sorted, ",")
	end
	return {
		apiKey = input.apiKey,
		baseUrl = input.baseUrl or Config.BASE_URL,
		httpBudgetPerMin = budget,
		cacheTtl = ttl,
		contribute = input.contribute ~= false,
		showReportGui = input.showReportGui == true,
		disallow = resolvedDisallow,
		transport = input.transport,
	},
		nil
end

return Config
