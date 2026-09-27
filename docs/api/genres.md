# `Resona.genres`

```luau
Resona.genres() -> ({ Resona.GenreCount }, Resona.Meta)
```

Build a genre selector from a server Script after [initialization](init.md).

```luau
local Resona = require(game.ReplicatedStorage.Packages.Resona)
local genres, meta = Resona.genres()
for _, item in genres do
    print("[Resona]", item.genre, item.n)
end
```

Returns `{ { genre = string, n = number } }` and [meta](types.md). `n` is the number of matching catalog tracks. Use a selected genre with [tracks](tracks.md), [random](random.md), or [Player](player.md).
