local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Resona = require(ReplicatedStorage:WaitForChild("Resona"))

local spawn = Instance.new("SpawnLocation")
spawn.Name = "ZyncSpawn"
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, 0.5, 20)
spawn.Anchored = true
spawn.Neutral = true
spawn.Transparency = 1
spawn.Parent = workspace

local lights = Instance.new("Folder")
lights.Name = "ZyncLights"
lights.Parent = workspace
for i = 1, 8 do
	local tile = Instance.new("Part")
	tile.Name = string.format("Tile%02d", i)
	tile.Size = Vector3.new(9, 0.2, 9)
	tile.Position = Vector3.new(((i - 1) % 4 - 1.5) * 11, 0.12, (math.floor((i - 1) / 4) - 0.5) * 11 - 10)
	tile.Anchored = true
	tile.Material = Enum.Material.Neon
	tile.Color = Color3.fromRGB(37, 56, 69)
	tile.Parent = lights
end

Lighting.Ambient = Color3.fromRGB(45, 51, 78)
Lighting.OutdoorAmbient = Color3.fromRGB(20, 25, 45)
Lighting.ClockTime = 0

Resona.init({
	apiKey = HttpService:GetSecret("resona"),
	showReportGui = true,
	-- Contribution defaults on. Tell players in your game's privacy notice.
})
