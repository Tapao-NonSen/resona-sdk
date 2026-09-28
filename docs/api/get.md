# `Resona.get`

```luau
Resona.get(id: number) -> (Resona.Track?, Resona.Meta)
Resona.get(ids: { number }) -> ({ Resona.Track? }, Resona.Meta)
```

Look up one or many Roblox audio asset IDs, from a server Script after [initialization](init.md) or from a LocalScript once the server has initialized. Client calls cross the server bridge and are rate-limited per player (30 catalog lookups per session, 1/second — a batch call counts once, regardless of how many ids it carries).

```luau
local Resona = require(game.ReplicatedStorage.Packages.Resona)
local track, meta = Resona.get(1835133008)
if track then
    print("[Resona]", track.title, track.artist)
end
```

Returns `Track?` and [meta](types.md) for a single ID. An unknown or unavailable ID can return `nil`; inspect `meta.source` and `meta.error` if you need to distinguish fallback data from a current API result. See [Track fields](types.md) for artwork and other metadata.

## Batching

Pass a list of IDs to fetch them in one request (one D1 query on the API side, not one HTTP call per ID):

```luau
local tracks, meta = Resona.get({ 1835133008, 1837318773, 999 })
for i, id in { 1835133008, 1837318773, 999 } do
    print(id, tracks[i] and tracks[i].title or "not found")
end
```

`tracks` is index-aligned with the `ids` you passed — a miss is a `nil` hole at that position, so index by position (`tracks[i]` for `i` from 1 to `#ids`) rather than iterating the array or trusting `#tracks`, which is unreliable once a hole exists. A batch is capped at 50 ids; a larger request is rejected (`meta.error` set, every id falls back to seed data if a matching one exists).
