# `Resona.genres`

```luau
Resona.genres() -> ({ Resona.GenreCount }, Resona.Meta)
```

Build a genre selector, from a server Script after [initialization](init.md) or from a LocalScript once the server has initialized. Client calls cross the server bridge and are rate-limited per player (30 catalog lookups per session, 1/second).

```luau
local Resona = require(game.ReplicatedStorage.Packages.Resona)
local genres, meta = Resona.genres()
for _, item in genres do
    print("[Resona]", item.genre, item.n)
end
```

Returns `{ { genre = string, n = number } }` and [meta](types.md). `n` is the number of matching catalog tracks; spellings that differ only by case are merged. Use these values for `genre` filters. Use a selected genre with [tracks](tracks.md), [random](random.md), or [Player](player.md).
