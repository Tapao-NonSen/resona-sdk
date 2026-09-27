--!strict
-- Deduplicates reports and flushes bounded batches no more than once per minute.
local Types = require("./Types")
local Reporter = {}
Reporter.__index = Reporter

export type Client = { request: (self: Client, method: string, path: string, body: string?) -> (string?, Types.Meta) }
export type Report = { assetId: number, kind: Types.ReportKind, note: string? }
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

function Reporter:report(assetId: number, kind: string, note: string?)
	if
		type(assetId) ~= "number"
		or assetId <= 0
		or assetId % 1 ~= 0
		or type(kind) ~= "string"
		or (kind ~= "unavailable" and kind ~= "metadata" and kind ~= "add")
		or (note ~= nil and (type(note) ~= "string" or #note > 500))
	then
		warn("Resona: dropped invalid report")
		return
	end
	local reportKind = kind :: Types.ReportKind
	local key = tostring(assetId) .. ":" .. reportKind
	if self.keys[key] then
		return
	end
	self.keys[key] = true
	table.insert(self.queue, { assetId = assetId, kind = reportKind, note = note })
	if self.scheduled then
		return
	end
	self.scheduled = true
	self.spawn(function()
		self.wait(self.interval)
		self:flush()
	end)
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
