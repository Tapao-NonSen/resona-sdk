--!strict
-- Client report calls cross the server bridge; the API key never reaches a LocalScript.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Types = require("./Types")
local ReportClient = {}

function ReportClient.submit(
	assetId: number,
	kind: Types.ReportKind,
	note: string?,
	suggested: Types.ReportSuggestion?
): (boolean, string)
	if not RunService:IsClient() then
		return false, "Reports from a client require a LocalScript."
	end
	local bridge = ReplicatedStorage:WaitForChild("ResonaBridge", 10)
	local remote = bridge and bridge:FindFirstChild("SubmitReport")
	if not remote then
		return false, "Report service is unavailable."
	end
	local ok, accepted, message = pcall(function()
		return (remote :: RemoteFunction):InvokeServer({
			assetId = assetId,
			kind = kind,
			note = note,
			suggested = suggested,
		})
	end)
	if not ok then
		return false, "Report service is unavailable."
	end
	return accepted == true, tostring(message)
end

function ReportClient.checkAdd(assetId: number): (boolean, string, any?)
	if not RunService:IsClient() then
		return false, "Use a LocalScript to check an asset."
	end
	local bridge = ReplicatedStorage:WaitForChild("ResonaBridge", 10)
	local remote = bridge and bridge:FindFirstChild("CheckAdd")
	if not remote then
		return false, "Public audio check is unavailable."
	end
	local ok, eligible, message, asset = pcall(function()
		return (remote :: RemoteFunction):InvokeServer(assetId)
	end)
	if not ok then
		return false, "Public audio check is unavailable."
	end
	return eligible == true, tostring(message), asset
end

return ReportClient
