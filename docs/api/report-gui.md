# `Resona.ReportGui`

The built-in client report form supports genre/artwork, other track details, unavailable audio, and Add Track requests. It auto-fills the current [Player](player.md) audio ID when one is playing.

Enable its button when a client creates `Resona.Player`:

```luau
-- Server Script
local HttpService = game:GetService("HttpService")
local Resona = require(game.ReplicatedStorage.Packages.Resona)
Resona.init({ apiKey = HttpService:GetSecret("resona"), showReportGui = true })
```

Or mount it explicitly from a LocalScript after server initialization:

```luau
local Resona = require(game.ReplicatedStorage.Packages.Resona)
Resona.ReportGui.mount()
```

`showReportGui` defaults to `false`. The Add Track form checks public Music eligibility before revealing separate editable title and artist fields. Reports are queued for review. To build your own UI, leave the built-in GUI off and use [checkAdd](check-add.md) and [report](report.md).
