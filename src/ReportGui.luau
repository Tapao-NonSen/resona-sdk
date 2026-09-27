--!strict
-- Optional in-game report panel. Native Roblox UI, with no UI framework dependency.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ReportClient = require("./ReportClient")
local ReportGui = {}
local current: any = nil
local latestTrack: any = nil

local INK = Color3.fromRGB(29, 32, 34)
local SURFACE = Color3.fromRGB(39, 43, 45)
local LINE = Color3.fromRGB(113, 122, 124)
local TEXT = Color3.fromRGB(235, 239, 238)
local MUTED = Color3.fromRGB(180, 191, 190)
local ACCENT = Color3.fromRGB(147, 231, 177)
local ERROR = Color3.fromRGB(255, 173, 163)
local OPTIONS = {
	{ label = "Genre or artwork", kind = "metadata", genre = true },
	{ label = "Other track details", kind = "metadata", details = true },
	{ label = "Audio won't play", kind = "unavailable" },
	{ label = "Add a track", kind = "add", add = true },
}

local function make(class: string, properties: { [string]: any }, parent: Instance): Instance
	local object = Instance.new(class)
	for key, value in properties do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

local function label(
	parent: Instance,
	value: string,
	position: UDim2,
	size: UDim2,
	color: Color3?,
	fontSize: number?
): TextLabel
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		Text = value,
		TextColor3 = color or TEXT,
		TextSize = fontSize or 14,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Code,
	}, parent) :: TextLabel
end

local function button(parent: Instance, value: string, position: UDim2, size: UDim2): TextButton
	return make("TextButton", {
		Position = position,
		Size = size,
		Text = value,
		BackgroundColor3 = SURFACE,
		BorderColor3 = LINE,
		BorderSizePixel = 1,
		TextColor3 = TEXT,
		TextSize = 14,
		Font = Enum.Font.Code,
		AutoButtonColor = true,
		Selectable = true,
	}, parent) :: TextButton
end

local function field(
	parent: Instance,
	title: string,
	hint: string,
	order: number,
	multiline: boolean?
): (Frame, TextBox)
	local group = make("Frame", {
		Name = title,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, if multiline then 80 else 60),
	}, parent) :: Frame
	label(group, title, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 14), MUTED, 12)
	local box = make("TextBox", {
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, if multiline then 64 else 44),
		BackgroundColor3 = SURFACE,
		BorderColor3 = LINE,
		BorderSizePixel = 1,
		Text = "",
		PlaceholderText = hint,
		PlaceholderColor3 = MUTED,
		TextColor3 = TEXT,
		TextSize = 14,
		Font = Enum.Font.Code,
		TextWrapped = multiline == true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = if multiline then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
		MultiLine = multiline == true,
		ClearTextOnFocus = false,
	}, group) :: TextBox
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, if multiline then 8 else 0),
	}, box)
	return group, box
end

local function trimmed(value: string): string
	return value:match("^%s*(.-)%s*$") or ""
end

local function assetId(raw: string): number?
	local value = trimmed(raw)
	if not value:match("^%d+$") then
		return nil
	end
	local id = tonumber(value)
	if not id or id <= 0 or id > 9007199254740991 then
		return nil
	end
	return id
end

function ReportGui.mount()
	if not RunService:IsClient() then
		return nil
	end
	local bridge = ReplicatedStorage:WaitForChild("ResonaBridge", 10)
	if not bridge then
		return nil
	end
	if current and current.gui.Parent then
		return current
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = make("ScreenGui", {
		Name = "ResonaReportGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui) :: ScreenGui
	local open = button(gui, "REPORT A TRACK", UDim2.new(1, -188, 1, -64), UDim2.fromOffset(168, 44))
	open.BackgroundColor3 = INK
	local panel = make("Frame", {
		Name = "Panel",
		Size = UDim2.new(1, -24, 1, -24),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.25,
		BorderColor3 = LINE,
		BorderSizePixel = 1,
		Visible = false,
	}, gui) :: Frame
	local panelBounds = make("UISizeConstraint", { MaxSize = Vector2.new(490, 420) }, panel) :: UISizeConstraint
	local content = make("ScrollingFrame", {
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = LINE,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
	}, panel) :: ScrollingFrame
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 24),
		PaddingRight = UDim.new(0, 24),
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
	}, content)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, content)
	local header = make(
		"Frame",
		{ Name = "Header", BackgroundTransparency = 1, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 54) },
		content
	) :: Frame
	label(header, "RESONA / TRACK FEEDBACK", UDim2.fromOffset(0, 1), UDim2.new(1, -76, 0, 29), TEXT, 19)
	local nowPlaying = label(
		header,
		"No track playing. Enter an audio ID below.",
		UDim2.fromOffset(0, 29),
		UDim2.new(1, 0, 0, 25),
		MUTED,
		12
	)
	nowPlaying.TextWrapped = false
	nowPlaying.TextTruncate = Enum.TextTruncate.AtEnd
	local close = button(header, "CLOSE", UDim2.new(1, -68, 0, 0), UDim2.fromOffset(68, 44))
	close.BackgroundTransparency = 1
	local typeGroup = make(
		"Frame",
		{ Name = "ReportType", BackgroundTransparency = 1, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 60) },
		content
	) :: Frame
	label(typeGroup, "REPORT TYPE", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 14), MUTED, 12)
	local selector = button(typeGroup, "Genre or artwork  v", UDim2.fromOffset(0, 16), UDim2.new(1, 0, 0, 44))
	selector.Name = "ReportTypeSelector"
	selector.TextXAlignment = Enum.TextXAlignment.Left
	make("UIPadding", { PaddingLeft = UDim.new(0, 12) }, selector)
	local menu = make("Frame", {
		Name = "Options",
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, #OPTIONS * 44),
		BackgroundTransparency = 1,
		Visible = false,
	}, typeGroup) :: Frame
	local idGroup, idBox = field(content, "ROBLOX AUDIO ASSET ID", "Paste the audio ID", 4)
	local usePlaying = button(idGroup, "USE PLAYING ID", UDim2.new(1, -136, 0, 16), UDim2.fromOffset(136, 44))
	usePlaying.Name = "UsePlayingId"
	usePlaying.Visible = false
	local checkPublic = button(idGroup, "CHECK PUBLIC", UDim2.new(1, -136, 0, 16), UDim2.fromOffset(136, 44))
	checkPublic.Name = "CheckPublic"
	checkPublic.Visible = false
	local publicStatus = label(idGroup, "", UDim2.fromOffset(0, 62), UDim2.new(1, 0, 0, 32), MUTED, 12)
	publicStatus.Name = "PublicStatus"
	publicStatus.Visible = false
	local genreGroup, genreBox = field(content, "CORRECT GENRE", "e.g. drum & bass", 5)
	local coverGroup, coverBox =
		field(content, "EXACT COVER IMAGE ID", "Upload the image first, then paste its asset ID", 6)
	local titleGroup, titleBox = field(content, "SUGGESTED TRACK TITLE", "Track title", 7)
	local artistGroup, artistBox = field(content, "SUGGESTED ARTIST", "Artist name", 8)
	local noteGroup, noteBox = field(content, "DETAILS / OPTIONAL", "Tell reviewers what should change", 9, true)
	local submit = button(content, "SEND REPORT", UDim2.new(), UDim2.new(1, 0, 0, 44))
	submit.Name = "SubmitReport"
	submit.LayoutOrder = 10
	submit.TextColor3 = ACCENT
	local status = label(content, "", UDim2.new(), UDim2.new(1, 0, 0, 26), MUTED, 12)
	status.LayoutOrder = 11
	local selected = OPTIONS[1]
	local busy = false
	local checking = false
	local validatedId: number? = nil
	local function fillPlayingId()
		if latestTrack and type(latestTrack.id) == "number" then
			idBox.Text = tostring(latestTrack.id)
		end
	end
	local function resetStatus()
		status.Text = ""
		status.TextColor3 = MUTED
	end
	local function setMenu(value: boolean)
		menu.Visible = value
		typeGroup.Size = UDim2.new(1, 0, 0, if value then 60 + #OPTIONS * 44 else 60)
		panelBounds.MaxSize = Vector2.new(490, if value or not selected.add or validatedId then 420 else 330)
	end
	local function selectOption(option: any)
		local wasAdd = selected.add == true
		selected = option
		validatedId = nil
		if option.add and not wasAdd then
			idBox.Text = ""
		end
		if wasAdd and not option.add then
			fillPlayingId()
		end
		selector.Text = option.label .. "  v"
		genreGroup.Visible = option.genre == true
		coverGroup.Visible = option.genre == true
		titleGroup.Visible = false
		artistGroup.Visible = false
		noteGroup.Visible = option.details == true or option.kind == "unavailable"
		usePlaying.Visible = latestTrack ~= nil and option.add ~= true
		checkPublic.Visible = option.add == true
		publicStatus.Visible = option.add == true
		publicStatus.Text = if option.add then "Check this ID before entering title and artist." else ""
		publicStatus.TextColor3 = MUTED
		idGroup.Size = UDim2.new(1, 0, 0, if option.add then 96 else 60)
		idBox.Size = UDim2.new(1, if usePlaying.Visible or option.add then -144 else 0, 0, 44)
		idBox.PlaceholderText = if option.add
			then "Paste a public Music audio ID"
			else "Auto-filled from the SDK player"
		setMenu(false)
		resetStatus()
	end
	selectOption(selected)
	usePlaying.Activated:Connect(fillPlayingId)
	checkPublic.Activated:Connect(function()
		if checking then
			return
		end
		local id = assetId(idBox.Text)
		if not id then
			publicStatus.Text = "Enter a valid audio ID first."
			publicStatus.TextColor3 = ERROR
			return
		end
		checking = true
		checkPublic.Text = "CHECKING..."
		publicStatus.Text = "Checking the public Creator Store listing..."
		publicStatus.TextColor3 = MUTED
		local eligible, message, asset = ReportClient.checkAdd(id)
		checking = false
		checkPublic.Text = "CHECK PUBLIC"
		if not selected.add or assetId(idBox.Text) ~= id then
			return
		end
		if not eligible then
			publicStatus.Text = message
			publicStatus.TextColor3 = ERROR
			return
		end
		validatedId = id
		panelBounds.MaxSize = Vector2.new(490, 420)
		publicStatus.Text = "Public Music confirmed. Review title and artist."
		publicStatus.TextColor3 = ACCENT
		titleBox.Text = if type(asset) == "table" and type(asset.title) == "string" then asset.title else ""
		artistBox.Text = if type(asset) == "table" and type(asset.artist) == "string" then asset.artist else ""
		titleGroup.Visible = true
		artistGroup.Visible = true
	end)
	selector.Activated:Connect(function()
		setMenu(not menu.Visible)
	end)
	for index, option in OPTIONS do
		local choice = button(menu, option.label, UDim2.fromOffset(0, (index - 1) * 44), UDim2.new(1, 0, 0, 44))
		choice.Name = "Option" .. tostring(index)
		choice.TextXAlignment = Enum.TextXAlignment.Left
		make("UIPadding", { PaddingLeft = UDim.new(0, 12) }, choice)
		choice.Activated:Connect(function()
			selectOption(option)
		end)
	end
	idBox:GetPropertyChangedSignal("Text"):Connect(function()
		if selected.add and validatedId ~= assetId(idBox.Text) then
			validatedId = nil
			panelBounds.MaxSize = Vector2.new(490, if menu.Visible then 420 else 330)
			titleGroup.Visible = false
			artistGroup.Visible = false
			titleBox.Text = ""
			artistBox.Text = ""
			publicStatus.Text = "Check this ID before entering title and artist."
			publicStatus.TextColor3 = MUTED
		end
	end)
	for _, box in { idBox, genreBox, coverBox, titleBox, artistBox, noteBox } do
		box:GetPropertyChangedSignal("Text"):Connect(resetStatus)
	end
	local function setOpen(value: boolean)
		panel.Visible = value
		open.Visible = not value
		if not value then
			setMenu(false)
		end
	end
	open.Activated:Connect(function()
		setOpen(true)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	submit.Activated:Connect(function()
		if busy then
			return
		end
		setMenu(false)
		local id = assetId(idBox.Text)
		if not id then
			status.Text = "Enter a valid Roblox audio asset ID."
			status.TextColor3 = ERROR
			return
		end
		local note = trimmed(noteBox.Text)
		if noteGroup.Visible and #note > 500 then
			status.Text = "Keep details under 500 characters."
			status.TextColor3 = ERROR
			return
		end
		local suggested = nil
		if selected.genre then
			local genre = trimmed(genreBox.Text)
			local cover = trimmed(coverBox.Text)
			if #genre > 60 then
				status.Text = "Keep genre under 60 characters."
				status.TextColor3 = ERROR
				return
			end
			local coverId = if cover ~= "" then assetId(cover) else nil
			if cover ~= "" and not coverId then
				status.Text = "Enter a valid cover image ID."
				status.TextColor3 = ERROR
				return
			end
			if genre == "" and not coverId then
				status.Text = "Enter a corrected genre or cover ID."
				status.TextColor3 = ERROR
				return
			end
			suggested = { genre = if genre ~= "" then genre else nil, artworkAssetId = coverId }
		elseif selected.details and note == "" then
			status.Text = "Describe the title, artist, or other error."
			status.TextColor3 = ERROR
			return
		elseif selected.add then
			if validatedId ~= id then
				status.Text = "Check the public audio ID first."
				status.TextColor3 = ERROR
				return
			end
			local title, artist = trimmed(titleBox.Text), trimmed(artistBox.Text)
			if title == "" or artist == "" then
				status.Text = "Enter both a track title and artist."
				status.TextColor3 = ERROR
				return
			end
			if #title > 120 or #artist > 120 or title:find("%c") or artist:find("%c") then
				status.Text = "Keep title and artist under 120 characters."
				status.TextColor3 = ERROR
				return
			end
			suggested = { title = title, artist = artist }
		end
		busy = true
		submit.Text = "SENDING..."
		local accepted, message = ReportClient.submit(
			id,
			selected.kind :: any,
			if noteGroup.Visible and note ~= "" then note else nil,
			suggested
		)
		status.Text = message
		status.TextColor3 = if accepted then ACCENT else ERROR
		submit.Text = "SEND REPORT"
		busy = false
	end)
	current = {
		gui = gui,
		setTrack = function(_, track)
			local playing = type(track) == "table" and type(track.id) == "number"
			nowPlaying.Text = if playing
				then "PLAYING / " .. tostring(track.title or "Unknown title") .. " - " .. tostring(
					track.artist or "Unknown artist"
				)
				else "No track playing. Enter an audio ID below."
			usePlaying.Visible = playing and selected.add ~= true
			idBox.Size = UDim2.new(1, if usePlaying.Visible then -144 else 0, 0, 44)
			if playing and not panel.Visible and not selected.add then
				fillPlayingId()
			end
		end,
	}
	gui.Destroying:Connect(function()
		current = nil
	end)
	current:setTrack(latestTrack)
	return current
end

function ReportGui.setTrack(track: any)
	latestTrack = track
	if current then
		current:setTrack(track)
	end
end

return ReportGui
