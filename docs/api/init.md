# `Resona.init`

```luau
Resona.init(config: Resona.ConfigInput) -> ()
```

Call `Resona.init(config)` once from a server Script before clients create players or send reports. It starts the server bridge and holds the API key on the server. Enable HTTP Requests in the experience.

```luau
local HttpService = game:GetService("HttpService")
local Resona = require(game.ReplicatedStorage.Packages.Resona)

Resona.init({
    apiKey = HttpService:GetSecret("resona"),
    httpBudgetPerMin = 20,
    showReportGui = true,
})
```

| Option | Default | Purpose |
|---|---|---|
| `apiKey` | required | API key as a server-side string or Roblox `Secret` |
| `baseUrl` | `https://resona.nyxbot.app` | API base URL |
| `httpBudgetPerMin` | `20` | SDK request token bucket per game server |
| `cacheTtl` | `3600` seconds | Catalog response cache lifetime |
| `contribute` | `true` | Automatic playback observations |
| `showReportGui` | `false` | Show the report button with a client `Player` |
| `disallow` | none | Tracks this game must never receive; see below |

## Disallowing tracks

```luau
Resona.init({
    apiKey = HttpService:GetSecret("resona"),
    disallow = {
        genres = { "phonk", "drill" },    -- case-insensitive
        uploaderIds = { 123456789 },      -- Creator Store uploader user IDs (max 100)
        assetIds = { 1835133008 },        -- specific audio IDs (max 10000)
    },
})
```

Every catalog call, `Player`, and `ServerPlayer` skip disallowed tracks. `get` returns `nil` for a disallowed track, and `genres` leaves disallowed genres out. Genres and audio IDs are filtered in the SDK, including the offline seed fallback. Uploader IDs are sent to the API, which filters by them without ever returning uploader IDs; seed fallback tracks carry no uploader, so they are not uploader-filtered. Filtering happens after a pool is fetched, so a long disallow list can make pools smaller.

The SDK caches responses, shares concurrent identical requests, and backs off on rate limits. Catalog calls return a result and [source metadata](types.md) for network failures. Use `contribute = false` to disable automatic observations while keeping playback and manual reports.

## Contribution disclosure

With contribution enabled, SDK playback can submit the Roblox audio ID and observed duration. For tracks without BPM, one client per server may analyze up to 24 seconds of the same audible audio and submit BPM, beat offset, confidence, and compact features. The API stores an API-key hash and game universe ID with accepted observations. The SDK does not send player identity, microphone input, raw audio, or a frame-by-frame spectrum. A track with no BPM gets one only after 3 or more games agree within ±1.5 BPM and ±0.1 s beat offset. Tell players in your game's privacy notice if your game contributes measurements.

See [Player](player.md) for playback and [ReportGui](report-gui.md) for the optional form.
