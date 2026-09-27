--!strict
-- Capture a short spectral envelope from the same AudioPlayer the listener hears.
local Recorder = {}
local SAMPLE_INTERVAL = 1 / 30

function Recorder.record(player: AudioPlayer, alive: () -> boolean): any?
	local analyzer = Instance.new("AudioAnalyzer")
	analyzer.Parent = player.Parent
	local wire = Instance.new("Wire")
	wire.SourceInstance = player
	wire.TargetInstance = analyzer
	wire.Parent = player.Parent
	local envelope = { t = {}, f = {}, r = {}, lo = {}, mid = {}, hi = {}, c = {} }
	local previous: { number }? = nil
	local current: { number } = {}
	local start = player.TimePosition
	local deadline = os.clock() + 34
	while alive() and player.TimePosition < start + 24 and os.clock() < deadline do
		task.wait(SAMPLE_INTERVAL)
		if not alive() then break end
		local spectrum = analyzer:GetSpectrum()
		if #spectrum > 0 then
			local flux, low, mid, high, weighted, total = 0, 0, 0, 0, 0, 0
			for index, value in spectrum do
				current[index] = math.log(1 + 1000 * value)
				total += value
				weighted += index * value
				if index <= 6 then low += value elseif index <= 85 then mid += value else high += value end
			end
			if previous then
				for index = 1, #spectrum do flux += math.max(0, current[index] - (previous[index] or 0)) end
				table.insert(envelope.t, math.floor(player.TimePosition * 1000 + 0.5))
				table.insert(envelope.f, math.floor(flux * 100 + 0.5) / 100)
				table.insert(envelope.r, math.floor(analyzer.RmsLevel * 10000 + 0.5))
				table.insert(envelope.lo, low)
				table.insert(envelope.mid, mid)
				table.insert(envelope.hi, high)
				table.insert(envelope.c, if total == 0 then 0 else weighted / total)
			end
			previous, current = current, previous or {}
		end
	end
	wire:Destroy()
	analyzer:Destroy()
	if not alive() or #envelope.t < 100 or player.TimePosition < start + 23 then return nil end
	return envelope
end

return Recorder
