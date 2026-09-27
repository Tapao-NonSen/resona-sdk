# Resona SDK

**Stop searching for Roblox music IDs.** Ask for music like "house, 124–132 BPM, energetic" and get tracks
that are verified playable, with a real title and artist, genre, mood, BPM and energy.

Resona only indexes audio that already lives on Roblox. It never hosts, downloads or re-uploads audio.

> **Status:** early development (v0.2.0).

## Install
- **Wally:** `resona = "tapao-nonsen/resona@0.2.0"`
- **Creator Store model:** coming with v1.

You need a free API key. Store it with `HttpService:GetSecret`, never in a script.

## Usage
```luau
local Resona = require(path.to.Resona)

Resona.init({ apiKey = HttpService:GetSecret("resona"), httpBudgetPerMin = 20 })

local tracks, meta = Resona.search("energetic", { genre = "dance", bpmMin = 124, bpmMax = 132 })
local track = Resona.random({ genre = "electronic" }) -- picks happen locally from a prefetched pool
```

## Beat sync
```luau
local player = Resona.Player.new()
player.Beat:Connect(function() light.Brightness = 4 end)
player.Bar:Connect(function(bar) light.Color = colors[bar % #colors + 1] end)
player:play()
-- player:getBeatPhase() returns 0..1 for smooth animation between beats.
```

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
