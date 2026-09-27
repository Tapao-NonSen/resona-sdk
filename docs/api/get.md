# `Resona.get`

```luau
Resona.get(id: number) -> (Resona.Track?, Resona.Meta)
```

Look up a single Roblox audio asset ID from a server Script after [initialization](init.md).

```luau
local Resona = require(game.ReplicatedStorage.Packages.Resona)
local track, meta = Resona.get(1835133008)
if track then
    print("[Resona]", track.title, track.artist)
end
```

Returns `Track?` and [meta](types.md). An unknown or unavailable ID can return `nil`; inspect `meta.source` and `meta.error` if you need to distinguish fallback data from a current API result. See [Track fields](types.md) for artwork and other metadata.
