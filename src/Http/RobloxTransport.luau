--!strict
-- Roblox RequestAsync adapter; this is the only module that touches HttpService.
local Types = require("../Types")
local HttpService = game:GetService("HttpService")
local RobloxTransport = {}
RobloxTransport.__index = RobloxTransport

function RobloxTransport.new()
	return setmetatable({}, RobloxTransport)
end

function RobloxTransport.decode(value: string): any
	return HttpService:JSONDecode(value)
end
function RobloxTransport.encode(value: any): string
	return HttpService:JSONEncode(value)
end

function RobloxTransport:request(request: Types.Request): Types.Response
	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = request.url,
			Method = request.method,
			Headers = request.headers,
			Body = request.body,
		})
	end)
	if not ok then
		local message = tostring(response)
		local kind = if message:find("Http requests are not enabled", 1, true)
			then "http_disabled"
			elseif message:find("Number of requests exceeded limit", 1, true) then "rate_limited"
			else "network"
		return { success = false, status = 0, kind = kind, body = message }
	end
	return { success = response.Success, status = response.StatusCode, body = response.Body, headers = response.Headers }
end

return RobloxTransport
