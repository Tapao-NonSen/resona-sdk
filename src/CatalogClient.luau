--!strict
-- Client catalog lookups cross the server bridge, same as reports; the API key never reaches a LocalScript.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Types = require("./Types")
local CatalogClient = {}

local unavailable: Types.Meta = { source = "seed", error = "unavailable" }

local function invoke(op: string, extra: { [string]: any }?): (any, Types.Meta)
	if not RunService:IsClient() then
		return nil, unavailable
	end
	local bridge = ReplicatedStorage:WaitForChild("ResonaBridge", 10)
	local remote = bridge and bridge:FindFirstChild("CatalogQuery")
	if not remote then
		return nil, unavailable
	end
	local request = extra or {}
	request.op = op
	local ok, value, meta = pcall(function()
		return (remote :: RemoteFunction):InvokeServer(request)
	end)
	if not ok or type(meta) ~= "table" then
		return nil, unavailable
	end
	return value, meta
end

function CatalogClient.get(id: number): (Types.Track?, Types.Meta)
	return invoke("get", { id = id })
end

function CatalogClient.getBatch(ids: { number }): ({ Types.Track? }, Types.Meta)
	local value, meta = invoke("get", { ids = ids })
	return (if type(value) == "table" then value else {}) :: { Types.Track? }, meta
end

function CatalogClient.search(text: string, filters: Types.Filters?): ({ Types.Track }, Types.Meta)
	local value, meta = invoke("search", { text = text, filters = filters })
	return (if type(value) == "table" then value else {}) :: { Types.Track }, meta
end

function CatalogClient.random(filters: Types.Filters?): (Types.Track?, Types.Meta)
	return invoke("random", { filters = filters })
end

function CatalogClient.genres(): ({ Types.GenreCount }, Types.Meta)
	local value, meta = invoke("genres")
	return (if type(value) == "table" then value else {}) :: { Types.GenreCount }, meta
end

return CatalogClient
