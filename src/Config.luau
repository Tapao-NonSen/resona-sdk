--!strict
-- Applies SDK defaults and validates caller-controlled configuration.
local Types = require("./Types")
local Config = {}

Config.BASE_URL = "https://resona-api.6ybckvd5ns.workers.dev"
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
	transport: Types.Transport?,
}

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
	return {
		apiKey = input.apiKey,
		baseUrl = input.baseUrl or Config.BASE_URL,
		httpBudgetPerMin = budget,
		cacheTtl = ttl,
		transport = input.transport,
	},
		nil
end

return Config
