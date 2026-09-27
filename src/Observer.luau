--!strict
-- Batches compact playback evidence. No player identifiers or raw audio leave the game.
local Observer = {}
Observer.__index = Observer

export type Observation = {
	assetId: number,
	duration: number,
	bpm: number?,
	bpmConfidence: number?,
	firstBeatOffset: number?,
	features: { [string]: number }?,
}
export type Client = { request: (self: Client, method: string, path: string, body: string?) -> (string?, any) }

function Observer.new(
	client: Client,
	encode: ({ Observation }) -> string,
	waitFn: (number) -> (),
	spawnFn: ((() -> ()) -> ())?
)
	return setmetatable({
		client = client,
		encode = encode,
		wait = waitFn,
		spawn = spawnFn or task.spawn,
		queue = {},
		sent = {},
		scheduled = false,
	}, Observer)
end

function Observer:submit(item: Observation)
	if self.disabled then
		return
	end
	if
		type(item.assetId) ~= "number"
		or item.assetId <= 0
		or item.assetId % 1 ~= 0
		or type(item.duration) ~= "number"
		or item.duration <= 0
		or item.duration > 36000
	then
		return
	end
	if self.sent[item.assetId] == "analysis" or (self.sent[item.assetId] == "playback" and item.bpm == nil) then
		return
	end
	self.queue[item.assetId] = item
	if self.scheduled then
		return
	end
	self.scheduled = true
	self.spawn(function()
		self.wait(60)
		self:flush()
	end)
end

function Observer:flush()
	self.scheduled = false
	local batch = {}
	for id, item in self.queue do
		table.insert(batch, item)
		self.queue[id] = nil
		if #batch == 25 then
			break
		end
	end
	if #batch == 0 then
		return
	end
	local response, meta = self.client:request("POST", "/v1/observations", self.encode(batch))
	if response ~= nil then
		for _, item in batch do
			self.sent[item.assetId] = if item.bpm then "analysis" else "playback"
		end
	elseif meta and (meta.error == "rate_limited" or meta.error == "bad_request") then
		self.disabled = true
		table.clear(self.queue)
	else
		for _, item in batch do
			local newer = self.queue[item.assetId]
			if not newer or (newer.bpm == nil and item.bpm ~= nil) then
				self.queue[item.assetId] = item
			end
		end
	end
	if next(self.queue) then
		self.scheduled = true
		self.spawn(function()
			self.wait(60)
			self:flush()
		end)
	end
end

return Observer
