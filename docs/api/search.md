# `Resona.search`

```luau
Resona.search(text: string, filters: Resona.Filters?) -> ({ Resona.Track }, Resona.Meta)
```

Find tracks by title, artist, or album prefix, from a server Script after [initialization](init.md) or from a LocalScript once the server has initialized (e.g. a search box UI). Client calls cross the server bridge and are rate-limited per player (30 catalog lookups per session, 1/second).

```luau
local Resona = require(game.ReplicatedStorage.Packages.Resona)
local matches, meta = Resona.search("artist or title", { kind = "song" })
for _, track in matches do
    print("[Resona]", track.title, track.artist)
end
```

Returns an array of `Track` and [meta](types.md). The API search accepts `kind` and `limit`; see [tracks](tracks.md) for catalog filtering by genre, mood, BPM, and duration. When the API is unavailable, seed fallback results are not a text search; check `meta.source` before showing them as matches.
