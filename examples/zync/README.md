# ZYNC nightclub demo

A small Rojo place showing Resona music playback, beat-synced floor tiles, cover art, a Skip button, and the built-in report form. It maps the SDK source from this repository directly, so no Wally install is needed for the example.

1. Create a Roblox API key and store it as the experience secret `resona`.
2. Enable **HTTP Requests** in the experience and tell players in its privacy notice that playback measurements may be contributed to Resona. To disable contribution, add `contribute = false` to `Resona.init` in `src/ZyncServer.server.luau`.
3. From this directory, run `rojo serve default.project.json` and connect the Rojo Studio plugin to an empty place. Save or publish the place when ready.
4. Play. The example plays the verified-song catalog. The Report button appears when the client player starts.

The example uses only built-in Roblox parts and UI. It creates a small floor and eight neon tiles at runtime. The tiles pulse on `Player.Beat` and change color on `Player.Bar` when a track has BPM data. For a game-ready integration, use the [SDK API docs](../../docs/index.md) and adapt the player, UI, and privacy notice to your own place.
