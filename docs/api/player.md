# `Resona.Player`

Create a music player in a LocalScript after the server calls [init](init.md). Each instance plays through a client `AudioPlayer` and advances when a track ends.

```luau
local Resona = require(game.ReplicatedStorage.Packages.Resona)
local player = Resona.Player.new({
    filters = { genre = "electronic", bpmMin = 120, bpmMax = 140 },
    volume = 0.5,
})

player.TrackChanged:Connect(function(track)
    print("[Resona]", track.title, track.artist)
end)
player.Beat:Connect(function(beat, track)
    -- Drive a visual effect on each beat when the track has BPM data.
end)
player.Bar:Connect(function(bar, track)
    -- Fires every four beats.
end)
player:play()
```

`new` accepts `filters` and `volume` (default `0.5`). Methods: `play()`, `skip()`, `stop()`, `destroy()`, and `getBeatPhase()`. The phase is `0..1` while a track with BPM data plays, otherwise `nil`. `TrackChanged` fires after playback starts; `Beat` and `Bar` fire only when BPM is available. Call `destroy()` when finished.

With contribution enabled in [init](init.md), the player sends observed playback duration and may analyze a missing BPM using the same audible stream. It does not send raw audio. The built-in [ReportGui](report-gui.md) can use its current track ID automatically. For server `Sound` playback, see [ServerPlayer](server-player.md).
