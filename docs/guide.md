# Resona SDK guide

Resona finds verified Roblox music, plays it, and lets players report catalog problems. The SDK needs one server setup and, for client playback, one LocalScript. Version 0.3.0 is currently in the repository; the Wally package for this version has not been published yet.

## Set up

Put the SDK where server and client scripts can require the same package, such as `ReplicatedStorage`. Enable **HTTP Requests** in your Roblox experience. Create an API key with Resona, store it as a Roblox secret named `resona`, and initialize once on the server:

```luau
-- ServerScriptService/ResonaSetup.server.luau
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Resona = require(ReplicatedStorage.Packages.Resona)

Resona.init({
    apiKey = HttpService:GetSecret("resona"),
    httpBudgetPerMin = 20,
    showReportGui = true, -- optional; defaults to false
})
```

Keep the API key in a server secret. `Resona.init` creates the server bridge used by client playback and reports. Call it before clients create players. Once v0.3.0 is published to Wally, the dependency will be `resona = "tapao-nonsen/resona@0.3.0"`.

## Play music

```luau
-- StarterPlayerScripts/Music.client.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Resona = require(ReplicatedStorage.Packages.Resona)

local player = Resona.Player.new({
    filters = { genre = "electronic", bpmMin = 120, bpmMax = 140 },
    volume = 0.5,
})

player.TrackChanged:Connect(function(track)
    print("[Resona]", track.title, track.artist, track.id)
end)
player.Beat:Connect(function(beat, track)
    -- Sync an effect to a track that has BPM data.
end)
player.Bar:Connect(function(bar, track)
    -- A bar event is emitted every four beats.
end)
player:play()

-- Later: player:skip(), player:stop(), player:destroy()
-- player:getBeatPhase() returns 0..1 when the current track has BPM data.
```

`Resona.Player` uses a client `AudioPlayer`, advances when a track ends, and skips tracks that fail to load. Its `TrackChanged`, `Beat`, and `Bar` signals can drive your own UI. Call `destroy()` when the player is no longer needed. The older `Resona.ServerPlayer` uses a server `Sound` and supports `parent` in its options; it cannot collect spectrum measurements.

## Query the catalog

These calls run on the server after `Resona.init`:

```luau
local page, meta = Resona.tracks({ genre = "dance", limit = 20 })
local nextPage = page.next and Resona.tracks({ genre = "dance", limit = 20, cursor = page.next })
local track, getMeta = Resona.get(1835133008)
local matches, searchMeta = Resona.search("artist or title", { genre = "electronic" })
local randomTrack, randomMeta = Resona.random({ mood = "energetic" })
local genres, genresMeta = Resona.genres()
```

`tracks` returns `{ tracks, next }`; pass `next` as `cursor` until it is `nil`. `get` returns a track or `nil`; `search` returns an array; `random` returns one track; `genres` returns `{ genre, n }` entries. Each call also returns `meta.source` (`network`, `cache`, `stale`, or `seed`) and possibly `meta.error`. A `seed` result is fallback data when the API is unavailable, so check `meta` if freshness matters.

Filters include `genre`, `mood`, `bpmMin`, `bpmMax`, `energyMin`, `durationMax`, and `kind`. `tracks` also accepts `cursor` and `limit`. A track has `id`, `title`, `artist`, `genre`, `duration`, and optional BPM, energy, mood, tags, and artwork fields. Some verified tracks have no BPM or energy yet.

For cover art, try `track.artworkAssetId` first and use `track.fallbackArtworkAssetId` if that image fails to load:

```luau
local function thumbnail(id)
    return ("rbxthumb://type=Asset&id=%d&w=420&h=420"):format(id)
end

if track.artworkAssetId then imageLabel.Image = thumbnail(track.artworkAssetId) end
-- Switch to thumbnail(track.fallbackArtworkAssetId) on an image load failure.
```

## Built-in reports or your own UI

Set `showReportGui = true` in the server config to show the built-in Report button when a client creates `Resona.Player`. For another player, call `Resona.ReportGui.mount()` from a LocalScript. The panel offers genre/artwork, other details, unavailable audio, and Add Track reports. It fills the current SDK audio ID when available.

For a custom LocalScript UI, keep `showReportGui` false and call the SDK directly:

```luau
local eligible, message, publicAsset = Resona.checkAdd(audioAssetId)
if eligible then
    local accepted, resultMessage = Resona.report(audioAssetId, "add", nil, {
        title = publicAsset.title,
        artist = publicAsset.artist,
    })
    -- Show resultMessage to the player. Let them edit title and artist first.
end

local accepted, resultMessage = Resona.report(playingAudioId, "metadata", "Wrong genre", {
    genre = "drum & bass",
    artworkAssetId = uploadedImageAssetId, -- optional
})
-- Resona.report(playingAudioId, "unavailable")
```

`checkAdd` requires an exact public Creator Store Music audio ID with a duration of at least 60 seconds. `report(..., "add", ...)` checks it again before queueing. Title and artist are separate review suggestions; they do not replace verified Roblox metadata automatically. For artwork corrections, upload the exact cover image first and submit its image asset ID. A successful report means it was queued by the game server for delivery and review, not that the catalog changed immediately. Client reports pass through the server; the API key stays there. The bridge limits each player to one report every 10 seconds and 10 reports per session.

## Contribution and privacy

Automatic dataset contribution defaults to **on**. During SDK playback, the client can send the current audio asset ID and observed duration. For tracks without BPM, one client per server can analyze up to 24 seconds of the same audible audio and submit BPM, beat offset, confidence, and compact features. The SDK does not send raw audio, microphone input, player identity, or a frame-by-frame spectrum. The API stores the game universe ID and API-key hash with accepted measurements. These measurements are review candidates and do not change public BPM automatically.

Tell players in your game's privacy notice if you use contribution. To disable automatic contribution while keeping playback and manual reports:

```luau
Resona.init({ apiKey = HttpService:GetSecret("resona"), contribute = false })
```

## Configuration

| Option | Default | Purpose |
|---|---|---|
| `apiKey` | required | Server-side string or Roblox `Secret` |
| `baseUrl` | `https://resona.nyxbot.app` | API base URL |
| `httpBudgetPerMin` | `20` | SDK request token bucket per game server |
| `cacheTtl` | `3600` seconds | Catalog response cache lifetime |
| `contribute` | `true` | Automatic playback measurements |
| `showReportGui` | `false` | Built-in client report button |

The SDK caches catalog responses, shares concurrent identical requests, and backs off on rate limits. It returns metadata and fallback results instead of throwing for ordinary network failures.

## Troubleshooting

- `meta.error == "http_disabled"`: enable HTTP Requests in the experience.
- `meta.error == "unauthorized"`: check the secret and API key.
- Client player reports no bridge: initialize Resona on the server before creating a client player.
- Add Track check fails: confirm the ID is a public **Music** audio asset at least 60 seconds long; retry later if the public check is unavailable.
- No beat events: the current track needs valid BPM data.
- Use `[Resona]` console messages to find SDK runtime warnings.
