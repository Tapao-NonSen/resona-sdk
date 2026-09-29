# Resona SDK

**Stop searching for Roblox music IDs.** Ask for music like "house, 124–132 BPM, energetic" and get tracks
that are verified playable, with a real title and artist, genre, mood, BPM and energy.

Resona only indexes audio that already lives on Roblox. It never hosts, downloads or re-uploads audio.

> **Status:** early development (v0.6.1).

See the [documentation index](docs/index.md) for a quick start and a separate page for each SDK API.

## Install
- **Wally:** `resona = "tapao-nonsen/resona@0.6.1"`.
- **Creator Store model:** coming with v1.

You need a free API key. Store it with `HttpService:GetSecret`, never in a script. Put the package where both server and client can require it, such as `ReplicatedStorage`.

## Usage
```luau
-- ServerScriptService (server Script)
local HttpService = game:GetService("HttpService")
local Resona = require(path.to.Resona)
Resona.init({ apiKey = HttpService:GetSecret("resona"), httpBudgetPerMin = 20 })

local tracks, meta = Resona.search("energetic", { genre = "dance", bpmMin = 124, bpmMax = 132 })
local track = Resona.random({ genre = "electronic" }) -- picks happen locally from a prefetched pool

-- Show track.artworkAssetId first; use track.fallbackArtworkAssetId if the image fails to load.
-- A creator can suggest an exact cover, a corrected genre, or both:
Resona.report(track.id, "metadata", "Cover and genre correction", {
    artworkAssetId = 123456789,
    genre = "drum & bass",
})
```

```luau
-- StarterPlayerScripts (LocalScript)
local Resona = require(path.to.Resona)
local player = Resona.Player.new({ volume = 0.5 })
player:play()
```

## Track reports and add requests

Set `showReportGui = true` in the **server** `Resona.init` config to show the built-in Report button when a client creates `Resona.Player`. The panel uses native Roblox UI. It is off by default. If your game does not use `Resona.Player`, call `Resona.ReportGui.mount()` from a LocalScript to show it explicitly. The current SDK player's audio ID fills automatically for track reports. Players choose a report type, then see only its relevant fields. Add Track first checks a public audio ID, then loads separate editable title and artist fields from Roblox. Reports are queued on the game server for later delivery and review; they do not edit the catalog immediately.

For your own UI, leave `showReportGui` off and submit from a LocalScript:

```luau
local Resona = require(path.to.Resona)
local accepted, message = Resona.report(audioAssetId, "metadata", "Genre correction", {
    genre = "drum & bass",
    artworkAssetId = uploadedImageAssetId, -- optional
})
-- Resona.report(newAudioAssetId, "add", nil, { title = "Track title", artist = "Artist name" })
-- Resona.checkAdd(newAudioAssetId) returns eligible, message, public asset metadata
-- Resona.report(brokenAudioAssetId, "unavailable")
-- Show message to the player. accepted means queued on this game server.
```

Before an Add Track report is queued, the server checks the exact asset ID in Roblox's public Creator Store and requires Music with a duration of at least 60 seconds. If the check cannot run, the report is not queued and the player can try later. Suggested title and artist are stored separately for review; they do not automatically overwrite verified Roblox metadata. Client reports use the SDK's server bridge, so the API key remains on the server. The bridge accepts one report per player every 10 seconds, up to 10 per session. `Resona.report` also works in a server Script.

## Beat sync and dataset contribution
```luau
-- In the same LocalScript
local player = Resona.Player.new()
player.Beat:Connect(function() light.Brightness = 4 end)
player.Bar:Connect(function(bar) light.Color = colors[bar % #colors + 1] end)
player:play()
-- player:getBeatPhase() returns 0..1 for smooth animation between beats.
```

`Resona.Player` uses a client `AudioPlayer` for audible playback. When the server issues a verified track, the client reports whether it loads and its observed duration. If the track has no BPM, at most one client per server measures up to 24 seconds of the **same audible stream** and sends BPM, beat offset, confidence, and compact spectral summaries. A server starts at most one analysis every five minutes and tries each track only once per session. Spectrum sampling is capped near 30 Hz, and the BPM search yields across frames. Until then `Beat`/`Bar` tick at a default 128 BPM; the measuring client switches to its estimate as soon as it is ready, and the server serves that estimate for later plays of the track in the same session. The server validates the issued track and forwards results in batches. Measurements are untrusted candidates; a track with no BPM gets one only after 3 or more games agree within ±1.5 BPM and ±0.1 s beat offset. `Resona.ServerPlayer` plays one shared track for everyone from a server `AudioPlayer`; servers render no audio, so it cannot measure a spectrum.

**Contribution is on by default.** This data contains a Roblox audio asset ID, observed duration, optional BPM/beat/features, API-key hash and game universe ID. It does not contain player identity, microphone input, raw audio, or a frame-by-frame spectrum. The SDK sends at most one observation per track and API key, in batches; the API caps each key at 50 new observations per day and all keys at 5000 per day. Game creators can turn off all automatic contribution with `Resona.init({ apiKey = ..., contribute = false })`; music playback still works. Tell your players in your game's privacy notice if your game contributes playback measurements.

## Project structure

- `src/init.luau` is the public facade.
- `src/Http/` contains the request pipeline and Roblox HTTP adapter.
- `src/Catalog.luau`, `Pool.luau`, `Reporter.luau`, and `Player.luau` provide the SDK features.
- `tests/` contains deterministic Lune specs and fakes.

## Built to respect your HTTP budget
Roblox gives each game server 500 HTTP requests per minute, **shared with your own game**. Resona aims for
**≤5 requests/minute** at steady state:
- Responses are cached for 1h, and concurrent identical calls share one request (single-flight).
- Random/station calls fetch a pool of 50 and refill in the background.
- A token bucket enforces `httpBudgetPerMin`. Over budget, you get cached data, not an error.
- On rate limits or server errors it backs off (1s → 60s, honoring `Retry-After`) and **never throws**.
- A bundled seed list keeps music playing when HttpEnabled is off or the API is unreachable.

## Development
```sh
aftman install
wally install
lune run tests/run
```

## License
MIT. See [LICENSE](LICENSE).
