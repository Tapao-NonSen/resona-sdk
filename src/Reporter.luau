--!strict
-- Deduplicates reports and flushes bounded batches no more than once per minute.
local Types = require("./Types")
local Reporter = {}
Reporter.__index = Reporter

export type Client = { request: (self: Client, method: string, path: string, body: string?) -> (string?, Types.Meta) }
export type Report = { assetId: number, kind: Types.ReportKind, note: string?, suggested: Types.ReportSuggestion? }
export type Dependencies = {
	client: Client,
	encode: ({ Report }) -> string,
	wait: (number) -> (),
	spawn: ((() -> ()) -> ())?,
	interval: number?,
}

function Reporter.new(
	client: Client,
	encode: ({ Report }) -> string,
	waitFn: (number) -> (),
	spawnFn: ((() -> ()) -> ())?,
	interval: number?
)
	return setmetatable({
		client = client,
		encode = encode,
		wait = waitFn,
		spawn = spawnFn or task.spawn,
		interval = interval or 60,
		queue = {},
		keys = {},
		scheduled = false,
	}, Reporter)
end

local function validName(value: any): boolean
	return type(value) == "string" and #value <= 120 and value:match("%S") ~= nil and value:find("%c") == nil
end

local function validAddSuggestion(value: any): boolean
	if type(value) ~= "table" or not validName(value.title) or not validName(value.artist) then
		return false
	end
	for key in value do
		if key ~= "title" and key ~= "artist" then
			return false
		end
	end
	return true
end

function Reporter:report(assetId: number, kind: string, note: string?, suggested: Types.ReportSuggestion?)
	if
		type(assetId) ~= "number"
		or assetId <= 0
		or assetId % 1 ~= 0
		or type(kind) ~= "string"
		or (kind ~= "unavailable" and kind ~= "metadata" and kind ~= "add")
		or (note ~= nil and (type(note) ~= "string" or #note > 500))
		or (suggested ~= nil and kind == "unavailable")
		or (suggested ~= nil and kind == "add" and not validAddSuggestion(suggested))
		or (
			suggested ~= nil
			and kind == "metadata"
			and (
				type(suggested) ~= "table"
				or (suggested.artworkAssetId == nil and suggested.genre == nil)
				or (suggested.artworkAssetId ~= nil and (type(suggested.artworkAssetId) ~= "number" or suggested.artworkAssetId <= 0 or suggested.artworkAssetId > 9007199254740991 or suggested.artworkAssetId % 1 ~= 0))
				or (
					suggested.genre ~= nil
					and (
						type(suggested.genre) ~= "string"
						or #suggested.genre > 60
						or not suggested.genre:match("%S")
						or suggested.genre:find("%c") ~= nil
					)
				)
			)
		)
	then
		warn("[Resona] Dropped invalid report")
		return false
	end
	local reportKind = kind :: Types.ReportKind
	local key = tostring(assetId) .. ":" .. reportKind
	if self.keys[key] then
		return false
	end
	self.keys[key] = true
	table.insert(self.queue, { assetId = assetId, kind = reportKind, note = note, suggested = suggested })
	if self.scheduled then
		return true
	end
	self.scheduled = true
	self.spawn(function()
		self.wait(self.interval)
		self:flush()
	end)
	return true
end

function Reporter:flush()
	self.scheduled = false
	if #self.queue == 0 then
		return
	end
	local batch = {}
	for _ = 1, math.min(25, #self.queue) do
		local report = table.remove(self.queue, 1)
		self.keys[tostring(report.assetId) .. ":" .. report.kind] = nil
		table.insert(batch, report)
	end
	self.client:request("POST", "/v1/reports", self.encode(batch))
	if #self.queue > 0 then
		self.scheduled = true
		self.spawn(function()
			self.wait(self.interval)
			self:flush()
		end)
	end
end

return Reporter
