# `Resona.Player`

```luau
Resona.Player.new(options: {
    filters: Resona.Filters?,
    volume: number?,      -- default 0.5
    autoplay: boolean?,   -- default true
}?) -> Player

Player:play() -> ()
Player:skip() -> ()
Player:stop() -> ()
Player:destroy() -> ()
Player:queue(track: Resona.Track) -> ()   -- plays before autoplay's pick, in order added
Player:getQueue() -> { Resona.Track }     -- a copy; mutating it does not change the player
Player:seek(position: number) -> ()       -- seconds into the current track
Player:setAutoplay(enabled: boolean) -> ()
Player:getBeatPhase() -> number?          -- 0..1 within the current beat

Player.TrackChanged: Signal<(track: Resona.Track)>
Player.Beat: Signal<(beat: number, track: Resona.Track)>  -- beat index from the first beat
Player.Bar: Signal<(bar: number, track: Resona.Track)>    -- every 4 beats
```

Create a music player in a LocalScript after the server calls [init](init.md). Each instance plays through a client `AudioPlayer`, so each player hears their own track.

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
    -- Drive a visual effect on each beat. track.bpm == nil means the 128 BPM default is ticking.
end)
player.Bar:Connect(function(bar, track)
    -- Fires every four beats.
end)
player:play()
```

## Autoplay

With `autoplay = true` (the default), the player starts the next track when one ends. With `autoplay = false`, it plays one track, then stops and destroys itself when that track ends; create a new player for the next one. Change it at any time with `player:setAutoplay(enabled)`.

```luau
local once = Resona.Player.new({ autoplay = false })
once:play() -- plays a single track, then cleans itself up
```

## Queueing

`queue(track)` appends a full `Resona.Track` (from [tracks](tracks.md), [get](get.md) or [search](search.md)) to a FIFO played out before autoplay's own picks. `_playNext` checks the queue first on every advance — natural end-of-track, `skip()`, and the first `play()` all drain it in order before falling back to autoplay. A queued track skips duration/BPM contribution: that reporting is tied to the server's own pick, not an explicitly requested one.

```luau
local track = Resona.get(1835133008)
if track then
    player:queue(track)
end
```

`getQueue()` returns a snapshot for UI like an "up next" list; it's a copy, so editing the returned array has no effect on playback.

## Seeking

`seek(position)` jumps to `position` seconds in the current track, clamped to its length. `Beat` and `Bar` resync to the new position without firing the skipped beats. A seek cancels a BPM analysis in progress for that track.

## Beats

The phase is `0..1` while a track plays, otherwise `nil`. `TrackChanged` fires after playback starts. `Beat` and `Bar` always fire: a track without BPM ticks at 128 BPM from offset 0, and if this client measures it, the clock switches to the measured BPM and beat offset (and sets them on `track`) mid-track. If the `genre` filter matches nothing, nothing plays and the server output warns with genres that do have tracks. Call `destroy()` when finished.

With contribution enabled in [init](init.md), the player sends observed playback duration and may analyze a missing BPM using the same audible stream. It does not send raw audio. The built-in [ReportGui](report-gui.md) can use its current track ID automatically. For one shared track that every player hears, see [ServerPlayer](server-player.md).
