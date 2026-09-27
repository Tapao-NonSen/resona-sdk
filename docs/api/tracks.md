# `Resona.tracks`

Browse verified tracks from a server Script after [initialization](init.md).

```luau
local Resona = require(game.ReplicatedStorage.Packages.Resona)
local page, meta = Resona.tracks({ genre = "dance", bpmMin = 120, limit = 20 })
for _, track in page.tracks do
    print("[Resona]", track.title, track.artist)
end

if page.next then
    local nextPage, nextMeta = Resona.tracks({ genre = "dance", bpmMin = 120, limit = 20, cursor = page.next })
end
```

Returns `page = { tracks = { Track }, next = number? }` and [meta](types.md). Pass `next` as `cursor` with the same filters until it is `nil`. Filters: `genre`, `mood`, `bpmMin`, `bpmMax`, `energyMin`, `durationMax`, `kind`, `cursor`, and `limit`. `kind = "library"` includes production library tracks; the default is songs. Some verified tracks have no BPM or energy yet, so numeric filters can exclude them.

See [Track fields](types.md) and [random](random.md) for station playback.
