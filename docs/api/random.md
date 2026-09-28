# `Resona.random`

```luau
Resona.random(filters: Resona.Filters?) -> (Resona.Track?, Resona.Meta)
```

Get one track for a station or playlist, from a server Script after [initialization](init.md) or from a LocalScript once the server has initialized. Client calls cross the server bridge and are rate-limited per player (30 catalog lookups per session, 1/second); each pick still draws from the server's own pool.

```luau
local Resona = require(game.ReplicatedStorage.Packages.Resona)
local track, meta = Resona.random({ genre = "electronic", mood = "energetic" })
if track then
    print("[Resona]", track.title, track.artist)
end
```

Returns `Track?` and [meta](types.md). The SDK fetches a pool and makes picks locally, reducing API requests. Pool entries are refilled as needed. Pass the same [catalog filters](tracks.md) for consistent station picks. For actual playback, [Player](player.md) handles choosing and advancing tracks. If the genre matches nothing, the track is `nil` and `meta.suggestedGenres` lists genres that do have tracks.
