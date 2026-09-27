# `Resona.ServerPlayer`

```luau
Resona.ServerPlayer.new(options: { filters: Resona.Filters?, parent: Instance?, volume: number? }?) -> ServerPlayer

-- Same methods and signals as Player:
ServerPlayer:play() / :skip() / :stop() / :destroy() -> ()
ServerPlayer:getBeatPhase() -> number?
ServerPlayer.TrackChanged / .Beat / .Bar
```

Use this older server `Sound` player when server playback is required. Initialize Resona on the server first.

```luau
local Resona = require(game.ReplicatedStorage.Packages.Resona)
local player = Resona.ServerPlayer.new({
    filters = { genre = "electronic" },
    parent = game:GetService("SoundService"),
    volume = 0.5,
})
player.TrackChanged:Connect(function(track)
    print("[Resona]", track.title, track.artist)
end)
player:play()
```

It supports `play()`, `skip()`, `stop()`, `destroy()`, `getBeatPhase()`, and `TrackChanged`, `Beat`, and `Bar` signals; a track without BPM ticks at 128 BPM. Its `Sound` reports a successful play's duration when contribution is enabled, but it cannot collect spectrum measurements for BPM. Use the client [Player](player.md) for analysis of audible playback.
