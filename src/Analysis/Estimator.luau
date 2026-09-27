--!strict
-- Pure BPM and beat-phase estimation from a recorded envelope (port of spikes/bpm/estimate.ts).
-- No energy yet: loudness tracks mastering level, not energy (fixture RMS 0.08–0.51 with no link to feel), so it
-- stays null until it can be calibrated against human-labelled tracks.

export type Envelope = { t: { number }, f: { number }, r: { number } }
export type Estimate = { bpm: number, confidence: number, firstBeatOffset: number }

local DT = 0.005
local Estimator = {}

function Estimator.onsetCurve(envelope: Envelope): ({ number }, number)
	local times, flux = {}, {}
	for index = 1, #envelope.t do
		if not (envelope.f[index] == 0 and index > 1 and envelope.r[index] == envelope.r[index - 1]) then
			local seconds = envelope.t[index] / 1000
			if #times > 0 and seconds <= times[#times] then
				flux[#flux] += envelope.f[index]
			else
				table.insert(times, seconds)
				table.insert(flux, envelope.f[index])
			end
		end
	end

	local count = math.floor((times[#times] - times[1]) / DT)
	local grid = table.create(count, 0)
	local sourceIndex = 1
	for index = 1, count do
		local seconds = times[1] + (index - 1) * DT
		while sourceIndex < #times - 1 and times[sourceIndex + 1] < seconds do
			sourceIndex += 1
		end
		local fraction =
			math.clamp((seconds - times[sourceIndex]) / (times[sourceIndex + 1] - times[sourceIndex]), 0, 1)
		grid[index] = flux[sourceIndex] + (flux[sourceIndex + 1] - flux[sourceIndex]) * fraction
	end

	local prefix = table.create(count + 1, 0)
	prefix[1] = 0
	for index = 1, count do
		prefix[index + 1] = prefix[index] + grid[index]
	end
	local onset = table.create(count, 0)
	local halfWindow = math.round(0.5 / DT)
	for zeroIndex = 0, count - 1 do
		local first = math.max(0, zeroIndex - halfWindow)
		local afterLast = math.min(count, zeroIndex + halfWindow)
		local movingMean = (prefix[afterLast + 1] - prefix[first + 1]) / (afterLast - first)
		onset[zeroIndex + 1] = math.max(0, grid[zeroIndex + 1] - movingMean)
	end
	return onset, times[1]
end

local function autocorrelation(onset: { number }, lag: number): number
	local whole = math.floor(lag)
	local fraction = lag - whole
	local sum = 0
	for zeroIndex = 0, #onset - whole - 2 do
		local shifted = onset[zeroIndex + whole + 1] * (1 - fraction) + onset[zeroIndex + whole + 2] * fraction
		sum += onset[zeroIndex + 1] * shifted
	end
	return sum / (#onset - whole)
end

function Estimator.estimateBpm(envelope: Envelope, yieldFn: (() -> ())?): (Estimate, { number })
	local onset, windowStart = Estimator.onsetCurve(envelope)
	local bestBpm, bestScore, totalScore, scoreCount = 0, -1, 0, 0
	for step = 0, (200 - 60) * 4 do
		if yieldFn and step % 2 == 0 then
			yieldFn()
		end
		local bpm = 60 + step * 0.25
		local period = 60 / bpm / DT
		local score = autocorrelation(onset, period)
			+ 0.5 * autocorrelation(onset, 2 * period)
			+ 0.33 * autocorrelation(onset, 3 * period)
			+ 0.25 * autocorrelation(onset, 4 * period)
		local prior = math.exp(-0.5 * (math.log(bpm / 120, 2)) ^ 2)
		totalScore += score
		scoreCount += 1
		if score * prior > bestScore then
			bestScore, bestBpm = score * prior, bpm
		end
	end

	local periodSamples = 60 / bestBpm / DT
	local bestPhase, bestPhaseScore = 0, -1
	local phase = 0
	while phase < periodSamples do
		local score = 0
		local sample = phase
		while math.round(sample) < #onset do
			score += onset[math.round(sample) + 1]
			sample += periodSamples
		end
		if score > bestPhaseScore then
			bestPhase, bestPhaseScore = phase, score
		end
		phase += 0.5
	end
	local beatPeriod = 60 / bestBpm
	return {
		bpm = bestBpm,
		confidence = math.round(bestScore / (totalScore / scoreCount) * 100) / 100,
		firstBeatOffset = (windowStart + bestPhase * DT) % beatPeriod,
	},
		onset
end

return Estimator
