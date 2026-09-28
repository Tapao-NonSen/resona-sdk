# `Resona.ServerPlayer`

```luau
-- Server Script: owns playback
Resona.ServerPlayer.new(options: {
    filters: Resona.Filters?,
    parent: Instance?,    -- default SoundService
    volume: number?,      -- default 0.5
    autoplay: boolean?,   -- default true
}?) -> ServerPlayer

ServerPlayer:play() -> ()
ServerPlayer:skip() -> ()
ServerPlayer:stop() -> ()
ServerPlayer:destroy() -> ()
ServerPlayer:queue(track: Resona.Track) -> ()   -- plays before autoplay's pick, in order added
ServerPlayer:getQueue() -> { Resona.Track }     -- server only; always empty on a following client
ServerPlayer:seek(position: number) -> ()       -- seconds; every player follows
ServerPlayer:setAutoplay(enabled: boolean) -> ()
ServerPlayer:getBeatPhase() -> number?

ServerPlayer.TrackChanged: Signal<(track: Resona.Track)>
ServerPlayer.Beat: Signal<(beat: number, track: Resona.Track)>
ServerPlayer.Bar: Signal<(bar: number, track: Resona.Track)>

-- LocalScript: follows the server's track with the same signals
Resona.ServerPlayer.new(options: { parent: Instance? }?) -> ServerPlayer
```

Plays one shared track that every player hears, in sync. The server plays an `AudioPlayer` wired to an `AudioDeviceOutput` in a `ResonaServerPlayer` folder under `parent`. Create one per `parent`. Initialize Resona on the server first.

```luau
-- Server Script
local Resona = require(game.ReplicatedStorage.Packages.Resona)
local player = Resona.ServerPlayer.new({
    filters = { genre = "electronic" },
    volume = 0.5,
})
player:play()
```

## Connecting from clients

Beat-driven visuals usually run in a LocalScript. Call `Resona.ServerPlayer.new()` on the client to follow the server's player. It gets the same `TrackChanged`, `Beat` and `Bar` signals and `getBeatPhase()`, timed against the audio that player hears. It waits for the server player to exist, goes quiet when it is destroyed, and attaches to the next one. Playback methods (`play`, `skip`, `stop`, `seek`, `setAutoplay`, `queue`) do nothing on the client; control stays on the server. The built-in [ReportGui](report-gui.md) uses the shared track when `showReportGui` is on.

```luau
-- LocalScript
local Resona = require(game.ReplicatedStorage.Packages.Resona)
local shared = Resona.ServerPlayer.new()
shared.TrackChanged:Connect(function(track)
    nowPlaying.Text = track.title .. " - " .. track.artist
end)
shared.Beat:Connect(function()
    light.Brightness = 4
end)
```

## Autoplay and seeking

With `autoplay = true` (the default), the next track starts when one ends. With `autoplay = false`, the player stops and destroys itself when its track ends. Change it with `setAutoplay(enabled)`. `seek(position)` jumps every player to `position` seconds in the current track. `queue(track)` appends a track that plays, for everyone, before autoplay resumes picking — see [Player](player.md#queueing) for details, which apply the same way here.

A track without BPM ticks at 128 BPM. The player reports a successful play's duration when contribution is enabled. Servers render no audio, so it cannot measure BPM; use the client [Player](player.md) for that.
