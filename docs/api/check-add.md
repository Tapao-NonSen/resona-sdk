# `Resona.checkAdd`

Check a Roblox audio ID before showing an Add Track form. Call from a LocalScript or server Script after [init](init.md).

```luau
local Resona = require(game.ReplicatedStorage.Packages.Resona)
local eligible, message, asset = Resona.checkAdd(audioAssetId)
if eligible then
    titleBox.Text = asset.title
    artistBox.Text = asset.artist
else
    statusLabel.Text = message
end
```

Returns `eligible: boolean`, a player-readable `message`, and an optional asset with `title` and `artist`. The API checks the exact public Creator Store ID and requires a **Music** asset of at least 60 seconds. An unavailable check returns `false`; retry later. Client checks are limited to 10 per player session and spaced at least two seconds apart.

Let the player edit title and artist separately, then call [report](report.md) with kind `"add"`. The report path checks eligibility again before queueing.
