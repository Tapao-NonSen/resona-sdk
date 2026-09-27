--!strict
-- Shared public contracts for the SDK.

export type Track = {
	id: number,
	title: string,
	artist: string,
	featuring: string?,
	album: string?,
	genre: string,
	duration: number,
	artworkAssetId: number?,
	fallbackArtworkAssetId: number?,
	mood: { string }?,
	tags: { string }?,
	bpm: number?,
	bpmConfidence: number?,
	energy: number?,
	firstBeatOffset: number?,
	explicit: boolean?,
	instrumental: boolean?,
	kind: string?,
}

export type Filters = {
	genre: string?,
	mood: string?,
	bpmMin: number?,
	bpmMax: number?,
	energyMin: number?,
	durationMax: number?,
	kind: string?,
	cursor: number?,
	limit: number?,
}
export type ReportKind = "unavailable" | "metadata" | "add"
export type MetadataSuggestion = { artworkAssetId: number?, genre: string? }
export type AddSuggestion = { title: string, artist: string }
export type ReportSuggestion = MetadataSuggestion | AddSuggestion
export type GenreCount = { genre: string, n: number }
export type AddAsset = { title: string, artist: string }
export type BeatInfo = { beat: number?, bar: number? }
export type Disallow = { genres: { string }?, uploaderIds: { number }?, assetIds: { number }? }
export type Config = {
	apiKey: string | Secret,
	baseUrl: string?,
	httpBudgetPerMin: number?,
	cacheTtl: number?,
	contribute: boolean?,
	showReportGui: boolean?,
	disallow: Disallow?,
	transport: Transport?,
}
export type Meta = { source: "network" | "cache" | "stale" | "seed", error: string?, suggestedGenres: { string }? }
export type Page = { tracks: { Track }, next: number? }
export type Request = { method: string, url: string, headers: { [string]: string | Secret }?, body: string? }
export type Response =
	{ success: boolean, status: number, body: string?, headers: { [string]: string }?, kind: string? }
export type Transport = { request: (self: Transport, request: Request) -> Response }

return {}
