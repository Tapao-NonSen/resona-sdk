# `Resona.random`

Get one track for a station or playlist from a server Script after [initialization](init.md).

```luau
local Resona = require(game.ReplicatedStorage.Packages.Resona)
local track, meta = Resona.random({ genre = "electronic", mood = "energetic" })
if track then
    print("[Resona]", track.title, track.artist)
end
```

Returns `Track?` and [meta](types.md). The SDK fetches a pool and makes picks locally, reducing API requests. Pool entries are refilled as needed. Pass the same [catalog filters](tracks.md) for consistent station picks. For actual playback, [Player](player.md) handles choosing and advancing tracks.
