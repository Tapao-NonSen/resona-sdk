# Track, filters, and result metadata

Catalog calls return track data and a separate `meta` table. A track includes `id`, `title`, `artist`, `genre`, and `duration` in seconds. Optional fields include `featuring`, `album`, `mood`, `tags`, `bpm`, `bpmConfidence`, `energy`, `firstBeatOffset`, `explicit`, `instrumental`, `kind`, `artworkAssetId`, and `fallbackArtworkAssetId`. Some verified tracks have no BPM or energy yet.

`meta.source` is `"network"`, `"cache"`, `"stale"`, or `"seed"`; `meta.error` may describe a failed request. A `seed` result is fallback data, so check the source if current catalog data matters. For `http_disabled`, enable HTTP Requests; for `unauthorized`, check the server secret and API key.

Most catalog calls accept filters such as `genre`, `mood`, `bpmMin`, `bpmMax`, `energyMin`, `durationMax`, and `kind`. [tracks](tracks.md) also accepts `cursor` and `limit`. See each API page for its supported filters.

For cover art, try `artworkAssetId` first. If the image fails to load, use `fallbackArtworkAssetId`:

```luau
local function thumbnail(id)
    return ("rbxthumb://type=Asset&id=%d&w=420&h=420"):format(id)
end

if track.artworkAssetId then
    imageLabel.Image = thumbnail(track.artworkAssetId)
end
-- On image load failure, set imageLabel.Image to thumbnail(track.fallbackArtworkAssetId).
```

The SDK's Luau type definitions are in [`src/Types.luau`](../../src/Types.luau).
