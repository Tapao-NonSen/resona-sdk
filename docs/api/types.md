# Types

Every type is exported from the module, so annotate with `Resona.<Type>`:

```luau
local Resona = require(game.ReplicatedStorage.Packages.Resona)
local function show(track: Resona.Track) end
```

```luau
type Track = {
    id: number,                        -- Roblox audio asset ID
    title: string,
    artist: string,
    featuring: string?,
    album: string?,
    genre: string,
    duration: number,                  -- seconds
    artworkAssetId: number?,
    fallbackArtworkAssetId: number?,
    mood: { string }?,
    tags: { string }?,
    bpm: number?,                      -- nil until analyzed
    bpmConfidence: number?,            -- ≈1 = no clear beat, >2 = clear
    energy: number?,
    firstBeatOffset: number?,          -- seconds to the first beat
    explicit: boolean?,
    instrumental: boolean?,
    kind: string?,                     -- "song" or "library"
}

type Filters = {
    genre: string?,
    mood: string?,
    bpmMin: number?,
    bpmMax: number?,
    energyMin: number?,
    durationMax: number?,              -- seconds
    kind: string?,                     -- "song" (default) or "library"
    cursor: number?,                   -- tracks() only: page.next from the previous page
    limit: number?,                    -- tracks() and search() only
}

type Meta = { source: "network" | "cache" | "stale" | "seed", error: string? }
type Page = { tracks: { Track }, next: number? }
type GenreCount = { genre: string, n: number }

type ReportKind = "unavailable" | "metadata" | "add"
type MetadataSuggestion = { artworkAssetId: number?, genre: string? }
type AddSuggestion = { title: string, artist: string }
type ReportSuggestion = MetadataSuggestion | AddSuggestion
type AddAsset = { title: string, artist: string }

type ConfigInput = {
    apiKey: string | Secret,
    baseUrl: string?,
    httpBudgetPerMin: number?,
    cacheTtl: number?,                 -- seconds
    contribute: boolean?,
    showReportGui: boolean?,
    transport: Transport?,             -- custom HTTP transport; defaults to HttpService
}
```

Some verified tracks have no BPM or energy yet.

`meta.source` is `"network"`, `"cache"`, `"stale"`, or `"seed"`; `meta.error` may describe a failed request. A `seed` result is fallback data, so check the source if current catalog data matters. For `http_disabled`, enable HTTP Requests; for `unauthorized`, check the server secret and API key.

Most catalog calls accept filters such as `genre`, `mood`, `bpmMin`, `bpmMax`, `energyMin`, `durationMax`, and `kind`. [tracks](tracks.md) also accepts `cursor` and `limit`. See each API page for its supported filters.

For cover art, try `artworkAssetId` first. If the image fails to load, use `fallbackArtworkAssetId`:

```luau
local function thumbnail(id)
    return ("rbxthumb://type=Asset&id=%d&w=420&h=420"):format(id)
end

if track.artworkAssetId then
    imageLabel.Image = thumbnail(track.artworkAssetId)
end
-- On image load failure, set imageLabel.Image to thumbnail(track.fallbackArtworkAssetId).
```

The SDK's Luau type definitions are in [`src/Types.luau`](../../src/Types.luau).
