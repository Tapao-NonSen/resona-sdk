# `Resona.report`

```luau
Resona.report(assetId: number, kind: Resona.ReportKind, note: string?, suggested: Resona.ReportSuggestion?)
    -> (accepted: boolean, message: string?) -- message is returned to LocalScript callers only
```

Send a track correction or Add Track request from a LocalScript or server Script after [init](init.md). Client calls pass through the game server; the API key stays private.

```luau
local Resona = require(game.ReplicatedStorage.Packages.Resona)
local accepted, message = Resona.report(audioAssetId, "metadata", "Wrong genre", {
    genre = "drum & bass",
    artworkAssetId = uploadedImageAssetId, -- optional
})

Resona.report(brokenAudioAssetId, "unavailable")
Resona.report(newAudioAssetId, "add", nil, {
    title = "Track title",
    artist = "Artist name",
})
```

`report(assetId, kind, note?, suggested?)` accepts `"metadata"`, `"unavailable"`, or `"add"`. Metadata suggestions can contain a corrected `genre`, an exact uploaded `artworkAssetId`, or both. Add suggestions keep `title` and `artist` separate. Use [checkAdd](check-add.md) to prefill and edit them; Add Track eligibility is checked again on submission. Suggestions are review data and do not overwrite verified Roblox metadata automatically.

From a LocalScript, returns `accepted: boolean, message: string`. `accepted` means queued on this game server for later API delivery and review; it does not mean a catalog edit is complete. Client reports are limited to one per player every 10 seconds and 10 per session. Server Script calls return a boolean. Use [ReportGui](report-gui.md) if you want the built-in form.
