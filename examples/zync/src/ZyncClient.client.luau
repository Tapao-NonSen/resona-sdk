local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Resona = require(ReplicatedStorage:WaitForChild("Resona"))

local player = Resona.Player.new({ volume = 0.35 })
local lights = workspace:WaitForChild("ZyncLights")
local tiles = {}
for i = 1, 8 do
	tiles[i] = lights:WaitForChild(string.format("Tile%02d", i))
end
local base = Color3.fromRGB(37, 56, 69)
local colors = {
	Color3.fromRGB(105, 233, 201),
	Color3.fromRGB(118, 147, 255),
	Color3.fromRGB(248, 112, 174),
	Color3.fromRGB(255, 197, 97),
}
local accent = colors[1]

local gui = Instance.new("ScreenGui")
gui.Name = "ZyncNowPlaying"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(450, 132)
panel.Position = UDim2.fromOffset(20, 20)
panel.BackgroundColor3 = Color3.fromRGB(22, 27, 39)
panel.BackgroundTransparency = 0.12
panel.Parent = gui

local cover = Instance.new("ImageLabel")
cover.Size = UDim2.fromOffset(86, 86)
cover.Position = UDim2.fromOffset(12, 12)
cover.BackgroundColor3 = Color3.fromRGB(36, 43, 60)
cover.Parent = panel

local function label(text, y, size)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = UDim2.fromOffset(110, y)
	item.Size = UDim2.fromOffset(300, size)
	item.Font = Enum.Font.Gotham
	item.TextSize = if size > 25 then 18 else 13
	item.TextColor3 = Color3.fromRGB(240, 246, 251)
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextTruncate = Enum.TextTruncate.AtEnd
	item.Text = text
	item.Parent = panel
	return item
end

local title = label("RESONA", 14, 30)
local artist = label("Finding music...", 45, 22)
local detail = label("", 73, 22)
detail.Size = UDim2.fromOffset(235, 22)
detail.TextColor3 = Color3.fromRGB(181, 195, 208)
local privacy = label("Playback stats may improve Resona. No voice or player identity is sent.", 108, 18)
privacy.Position = UDim2.fromOffset(12, 108)
privacy.Size = UDim2.fromOffset(430, 18)
privacy.TextSize = 11
privacy.TextColor3 = Color3.fromRGB(181, 195, 208)

local skip = Instance.new("TextButton")
skip.Name = "Skip"
skip.Size = UDim2.fromOffset(75, 32)
skip.Position = UDim2.new(1, -95, 0, 67)
skip.BackgroundColor3 = Color3.fromRGB(55, 72, 91)
skip.TextColor3 = Color3.fromRGB(240, 246, 251)
skip.Font = Enum.Font.GothamBold
skip.TextSize = 12
skip.Text = "SKIP"
skip.Parent = panel
skip.Activated:Connect(function()
	player:skip()
end)

local artworkGeneration = 0
local function thumbnail(id)
	return ("rbxthumb://type=Asset&id=%d&w=420&h=420"):format(id)
end

player.TrackChanged:Connect(function(track)
	title.Text = track.title
	artist.Text = track.artist
	detail.Text = if track.bpm then string.format("%s / %.0f BPM", track.genre, track.bpm) else track.genre
	artworkGeneration += 1
	local generation = artworkGeneration
	local id = track.artworkAssetId or track.fallbackArtworkAssetId
	cover.Image = if id then thumbnail(id) else ""
	if id and track.fallbackArtworkAssetId and id ~= track.fallbackArtworkAssetId then
		task.spawn(function()
			local loaded = false
			pcall(function()
				ContentProvider:PreloadAsync({ cover }, function(_, status)
					if status == Enum.AssetFetchStatus.Success then
						loaded = true
					end
				end)
			end)
			if generation == artworkGeneration and not loaded then
				cover.Image = thumbnail(track.fallbackArtworkAssetId)
			end
		end)
	end
end)

player.Bar:Connect(function(bar)
	accent = colors[(bar - 1) % #colors + 1]
end)
player.Beat:Connect(function(beat)
	local tile = tiles[(beat - 1) % #tiles + 1]
	if not tile then
		return
	end
	tile.Color = accent
	task.delay(0.18, function()
		if tile.Parent then
			tile.Color = base
		end
	end)
end)

player:play()
