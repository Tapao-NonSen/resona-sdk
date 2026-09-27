# Resona SDK

Resona is a Roblox music SDK for finding verified tracks, playing them, and collecting track corrections. It indexes audio already on Roblox; it does not host or upload audio.

Use it for a game radio, a genre-based playlist, beat-synced effects, or a player-facing track report form.

## Simple usage

Initialize once in a server Script. Keep your API key in a Roblox secret and enable HTTP Requests for the experience.

```luau
local HttpService = game:GetService("HttpService")
local Resona = require(game.ReplicatedStorage.Packages.Resona)

Resona.init({ apiKey = HttpService:GetSecret("resona") })
```

Play from a LocalScript:

```luau
local Resona = require(game.ReplicatedStorage.Packages.Resona)
local player = Resona.Player.new({ filters = { genre = "electronic" } })
player:play()
```

Version 0.5.0 is available on Wally as `tapao-nonsen/resona@0.5.0`. Put the package where both server and client can require it, such as `ReplicatedStorage`.

## API pages

| API | Use case |
|---|---|
| [init](api/init.md) | Configure the SDK and its server bridge |
| [tracks](api/tracks.md) | Browse a filtered, paginated catalog |
| [get](api/get.md) | Look up one audio asset ID |
| [search](api/search.md) | Find tracks by title, artist, or album |
| [random](api/random.md) | Pick a track for a station or playlist |
| [genres](api/genres.md) | Build a genre picker |
| [Player](api/player.md) | Play music for one client and sync effects to beats |
| [ServerPlayer](api/server-player.md) | One shared track every player hears |
| [checkAdd](api/check-add.md) | Check an audio ID before requesting a new catalog track |
| [report](api/report.md) | Send metadata, unavailable-audio, or Add Track reports |
| [ReportGui](api/report-gui.md) | Show the built-in report form |
| [Track, filters, and meta](api/types.md) | Read shared result fields and artwork |
