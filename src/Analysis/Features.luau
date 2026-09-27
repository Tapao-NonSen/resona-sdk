--!strict
-- Pure summary features captured for later energy-model calibration.

export type Features = {
	rmsMean: number,
	rmsStd: number,
	rmsP90: number,
	fluxMean: number,
	onsetRate: number,
	lowShare: number?,
	midShare: number?,
	highShare: number?,
	centroidMean: number?,
}

local DT = 0.005
local Features = {}

local function round(value: number): number
	return math.round(value * 10000) / 10000
end

local function mean(values: { number }, scale: number?): number
	local sum = 0
	for _, value in values do
		sum += value
	end
	return sum / #values / (scale or 1)
end

function Features.features(envelope, onset: { number }): Features
	local rmsMean = mean(envelope.r, 10000)
	local variance = 0
	for _, value in envelope.r do
		variance += (value / 10000 - rmsMean) ^ 2
	end
	local sortedRms = table.clone(envelope.r)
	table.sort(sortedRms)

	local onsetMean = mean(onset)
	local onsets, lastOnset = 0, -math.huge
	for index = 2, #onset - 1 do
		if
			onset[index] > onsetMean * 1.5
			and onset[index] > onset[index - 1]
			and onset[index] >= onset[index + 1]
			and (index - lastOnset) * DT >= 0.1
		then
			onsets += 1
			lastOnset = index
		end
	end

	local lowShare, midShare, highShare, centroidMean = nil, nil, nil, nil
	if envelope.lo and envelope.mid and envelope.hi and envelope.c then
		local low, mid, high = 0, 0, 0
		for index = 1, #envelope.lo do
			local total = envelope.lo[index] + envelope.mid[index] + envelope.hi[index]
			if total > 0 then
				low += envelope.lo[index] / total
				mid += envelope.mid[index] / total
				high += envelope.hi[index] / total
			end
		end
		lowShare = round(low / #envelope.lo)
		midShare = round(mid / #envelope.lo)
		highShare = round(high / #envelope.lo)
		centroidMean = round(mean(envelope.c))
	end

	return {
		rmsMean = round(rmsMean),
		rmsStd = round(math.sqrt(variance / #envelope.r)),
		rmsP90 = round(sortedRms[math.ceil(#sortedRms * 0.9)] / 10000),
		fluxMean = round(mean(envelope.f)),
		onsetRate = round(onsets / (#onset * DT)),
		lowShare = lowShare,
		midShare = midShare,
		highShare = highShare,
		centroidMean = centroidMean,
	}
end

return Features
