local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local Client = _G.Dar4xClient
if not Client then return end

local player = Players.LocalPlayer

-- ====== НАСТРОЙКИ ТРЕКА ======
local TRACK_ID     = "crystal_blue"
local TRACK_NAME   = "Crystal Blue"
local ARTIST       = "Dar3x Client"
local COVER_ID     = "rbxassetid://116483545078964"
local SOUND_ID     = "rbxassetid://126311422940815"
local SKIP_SECONDS = 10
local START_Y      = 210
local GUI_NAME     = "BR_MusicPlayer2"
local SOUND_NAME   = "BR_Sound2"
-- =============================

Client.State.SongManager = Client.State.SongManager or {
	ActiveTrackId = nil,
	Tracks = {},
	SortList = function() end,
	NotifyBusy = function(activeName)
		local mainGui = Client.State.MainGui
		if not mainGui then return end

		local oldToast = mainGui:FindFirstChild("SongSingleToast")
		if oldToast then oldToast:Destroy() end

		local toast = Instance.new("Frame")
		toast.Name = "SongSingleToast"
		toast.Size = UDim2.new(0, 310, 0, 36)
		toast.AnchorPoint = Vector2.new(0.5, 0)
		toast.Position = UDim2.new(0.5, 0, 0, 6)
		toast.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		toast.BackgroundTransparency = 1
		toast.BorderSizePixel = 0
		toast.ClipsDescendants = true
		toast.ZIndex = 99
		toast.Parent = mainGui
		Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Transparency = 1
		stroke.Thickness = 1.2
		stroke.Parent = toast

		local uiScale = Instance.new("UIScale")
		uiScale.Scale = 0.9
		uiScale.Parent = toast

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -16, 1, 0)
		label.Position = UDim2.new(0, 8, 0, 0)
		label.BackgroundTransparency = 1
		label.RichText = true
		label.Font = Enum.Font.Ubuntu
		label.TextSize = 13
		label.TextTransparency = 1
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.Text = '<font color="rgb(245,245,245)">Сначала выключите </font><font color="rgb(255,65,65)">' .. tostring(activeName) .. '</font>'
		label.ZIndex = 100
		label.Parent = toast

		TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0, 14),
			BackgroundTransparency = 0.25
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Transparency = 0.55
		}):Play()
		TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Scale = 1
		}):Play()
		TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			TextTransparency = 0
		}):Play()

		task.delay(2.2, function()
			if not toast or not toast.Parent then return end
			local outBg = TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0, 6),
				BackgroundTransparency = 1
			})
			TweenService:Create(stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
				Transparency = 1
			}):Play()
			TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
				Scale = 0.9
			}):Play()
			TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
				TextTransparency = 1
			}):Play()

			outBg:Play()
			outBg.Completed:Connect(function()
				if toast and toast.Parent then
					toast:Destroy()
				end
			end)
		end)
	end
}

local SongManager = Client.State.SongManager

local function newObj(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function initCrystalBlueSong()
	local cfg = Client.Config
	local mainGui = Client.State.MainGui
	local pageFrame = Client.State.Pages and Client.State.Pages["Song"]
	if not mainGui or not pageFrame then return end

	local menuHeight = cfg.MenuHeight
	local menuWidth = cfg.MenuWidth
	local gapBetween = cfg.GapBetween
	local panelWidth = cfg.PlayerListWidth

	local parentGui
	pcall(function() if gethui then parentGui = gethui() end end)
	if not parentGui then
		local ok, cg = pcall(function() return game:GetService("CoreGui") end)
		if ok and cg then parentGui = cg end
	end
	if not parentGui then
		parentGui = player:WaitForChild("PlayerGui")
	end

	for _, p in ipairs({ parentGui, player:FindFirstChild("PlayerGui") }) do
		local old = p and p:FindFirstChild(GUI_NAME)
		if old then old:Destroy() end
	end
	local oldSound = SoundService:FindFirstChild(SOUND_NAME)
	if oldSound then oldSound:Destroy() end

	local sound = newObj("Sound", {
		Name = SOUND_NAME,
		SoundId = SOUND_ID,
		Volume = 1,
		Looped = true,
	}, SoundService)
	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync({ sound }) end)
	end)

	local conns = {}
	local function connect(sig, fn)
		local c = sig:Connect(fn)
		table.insert(conns, c)
		return c
	end

	local WHITE = Color3.new(1, 1, 1)
	local GRAY = Color3.fromRGB(150, 150, 156)
	local W, H = 320, 156
	local ROW_Y = 126

	local isEnabled = false
	local isFavorite = false
	local playerScale = 1.0
	local playing = false
	local busy = false
	local muted = false

	local gui = newObj("ScreenGui", {
		Name = GUI_NAME,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 999,
	}, parentGui)

	local frame = newObj("Frame", {
		Size = UDim2.new(0, W, 0, H),
		Position = UDim2.new(0.5, -W / 2, 0, START_Y),
		BackgroundColor3 = Color3.fromRGB(26, 26, 28),
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	newObj("UICorner", { CornerRadius = UDim.new(0, 24) }, frame)
	local frameStroke = newObj("UIStroke", { Color = WHITE, Transparency = 0.85, Thickness = 1 }, frame)

	local uiScale = newObj("UIScale", { Scale = 0.85 }, frame)

	local dragArea = newObj("Frame", {
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundTransparency = 1,
		Active = true,
	}, frame)

	local cover = newObj("ImageLabel", {
		Size = UDim2.new(0, 56, 0, 56),
		Position = UDim2.new(0, 14, 0, 14),
		BackgroundColor3 = Color3.fromRGB(40, 40, 44),
		Image = COVER_ID,
		ScaleType = Enum.ScaleType.Crop,
	}, frame)
	newObj("UICorner", { CornerRadius = UDim.new(0, 8) }, cover)

	newObj("TextLabel", {
		Size = UDim2.new(1, -150, 0, 24),
		Position = UDim2.new(0, 80, 0, 16),
		BackgroundTransparency = 1,
		Text = TRACK_NAME,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.GothamBold,
		TextSize = 17,
	}, frame)

	local subtitle = newObj("TextLabel", {
		Size = UDim2.new(1, -150, 0, 20),
		Position = UDim2.new(0, 80, 0, 40),
		BackgroundTransparency = 1,
		Text = ARTIST,
		TextColor3 = GRAY,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.Gotham,
		TextSize = 14,
	}, frame)

	local wave = newObj("Frame", {
		Size = UDim2.new(0, 22, 0, 24),
		Position = UDim2.new(1, -38, 0, 18),
		BackgroundTransparency = 1,
	}, frame)
	local bars = {}
	for i = 0, 4 do
		local b = newObj("Frame", {
			Size = UDim2.new(0, 2, 0, 2),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, i * 5, 0.5, 0),
			BackgroundColor3 = GRAY,
			BorderSizePixel = 0,
		}, wave)
		newObj("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
		table.insert(bars, b)
	end

	local track = newObj("Frame", {
		Size = UDim2.new(0, W - 28, 0, 4),
		Position = UDim2.new(0, 14, 0, 84),
		BackgroundColor3 = Color3.fromRGB(70, 70, 76),
		BorderSizePixel = 0,
	}, frame)
	newObj("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	local fill = newObj("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(235, 235, 240),
		BorderSizePixel = 0,
	}, track)
	newObj("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

	local tLeft = newObj("TextLabel", {
		Size = UDim2.new(0, 60, 0, 14),
		Position = UDim2.new(0, 14, 0, 92),
		BackgroundTransparency = 1,
		Text = "0:00",
		TextColor3 = GRAY,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = 11,
	}, frame)
	local tRight = newObj("TextLabel", {
		Size = UDim2.new(0, 60, 0, 14),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 92),
		BackgroundTransparency = 1,
		Text = "-0:00",
		TextColor3 = GRAY,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.Gotham,
		TextSize = 11,
	}, frame)

	local seekArea = newObj("Frame", {
		Size = UDim2.new(0, W - 28, 0, 28),
		Position = UDim2.new(0, 14, 0, 72),
		BackgroundTransparency = 1,
		Active = true,
	}, frame)

	local function triangle(parent, x, w, h, dir)
		for i = 0, w - 1 do
			local frac = (i + 0.5) / w
			local hh = (dir == "right") and h * (1 - frac) or h * frac
			hh = math.max(hh, 1)
			newObj("Frame", {
				Size = UDim2.new(0, 1, 0, hh),
				Position = UDim2.new(0, x + i, 0.5, -hh / 2),
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
			}, parent)
		end
	end

	local function iconHolder(cx, w, h)
		return newObj("Frame", {
			Size = UDim2.new(0, w, 0, h),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(cx, 0, 0, ROW_Y),
			BackgroundTransparency = 1,
		}, frame)
	end

	local function hitButton(cx, size)
		return newObj("TextButton", {
			Size = UDim2.new(0, size, 0, size),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(cx, 0, 0, ROW_Y),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 5,
		}, frame)
	end

	local pressCircle = newObj("Frame", {
		Size = UDim2.new(0, 56, 0, 56),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, ROW_Y),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, frame)
	newObj("UICorner", { CornerRadius = UDim.new(1, 0) }, pressCircle)

	local star = newObj("TextLabel", {
		Size = UDim2.new(0, 30, 0, 30),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.1, 0, 0, ROW_Y),
		BackgroundTransparency = 1,
		Text = "☆",
		TextColor3 = GRAY,
		Font = Enum.Font.GothamBold,
		TextSize = 26,
	}, frame)
	local starBtn = hitButton(0.1, 44)

	local rewIcon = iconHolder(0.3, 32, 20)
	triangle(rewIcon, 0, 16, 20, "left")
	triangle(rewIcon, 16, 16, 20, "left")
	local rewBtn = hitButton(0.3, 48)

	local playIcon = iconHolder(0.5, 24, 28)
	triangle(playIcon, 2, 22, 28, "right")
	local pauseIcon = iconHolder(0.5, 24, 28)
	for _, x in ipairs({ 3, 14 }) do
		local bar = newObj("Frame", {
			Size = UDim2.new(0, 7, 1, 0),
			Position = UDim2.new(0, x, 0, 0),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		}, pauseIcon)
		newObj("UICorner", { CornerRadius = UDim.new(0, 2) }, bar)
	end
	pauseIcon.Visible = false
	local playBtn = hitButton(0.5, 60)

	local fwdIcon = iconHolder(0.7, 32, 20)
	triangle(fwdIcon, 0, 16, 20, "right")
	triangle(fwdIcon, 16, 16, 20, "right")
	local fwdBtn = hitButton(0.7, 48)

	local spkIcon = iconHolder(0.9, 28, 20)
	newObj("Frame", {
		Size = UDim2.new(0, 6, 0, 8),
		Position = UDim2.new(0, 0, 0.5, -4),
		BackgroundColor3 = GRAY,
		BorderSizePixel = 0,
	}, spkIcon)
	triangle(spkIcon, 6, 9, 20, "left")
	local spkWave = newObj("Frame", {
		Size = UDim2.new(0, 2, 0, 10),
		Position = UDim2.new(0, 20, 0.5, -5),
		BackgroundColor3 = GRAY,
		BorderSizePixel = 0,
	}, spkIcon)
	newObj("UICorner", { CornerRadius = UDim.new(1, 0) }, spkWave)
	for _, d in ipairs(spkIcon:GetChildren()) do
		if d:IsA("Frame") and d ~= spkWave then d.BackgroundColor3 = GRAY end
	end
	local spkBtn = hitButton(0.9, 44)

	local function setPlaying(state)
		playing = state
		playIcon.Visible = not state
		pauseIcon.Visible = state
	end

	local function fmt(s)
		s = math.max(0, math.floor(s))
		return string.format("%d:%02d", s // 60, s % 60)
	end

	connect(playBtn.Activated, function()
		if not isEnabled then return end
		pressCircle.BackgroundTransparency = 0.85
		TweenService:Create(pressCircle, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()

		if busy then return end
		if not playing then
			busy = true
			sound:Play()
			local t = 0
			while not sound.IsLoaded and t < 6 do
				task.wait(0.25)
				t += 0.25
			end
			busy = false
			if not isEnabled then
				sound:Stop()
				setPlaying(false)
				return
			end
			if sound.IsLoaded and sound.TimeLength > 0 then
				subtitle.Text = ARTIST
				setPlaying(true)
			else
				sound:Stop()
				subtitle.Text = "Audio unavailable"
				setPlaying(false)
			end
		else
			sound:Pause()
			setPlaying(false)
		end
	end)

	connect(rewBtn.Activated, function()
		if not isEnabled then return end
		sound.TimePosition = math.max(0, sound.TimePosition - SKIP_SECONDS)
	end)

	connect(fwdBtn.Activated, function()
		if not isEnabled then return end
		local len = sound.TimeLength
		if len > 0 then
			sound.TimePosition = math.min(len - 0.1, sound.TimePosition + SKIP_SECONDS)
		end
	end)

	connect(spkBtn.Activated, function()
		if not isEnabled then return end
		muted = not muted
		sound.Volume = muted and 0 or 1
		spkWave.Visible = not muted
	end)

	local seeking = false
	local function seekTo(x)
		if not isEnabled then return end
		local len = sound.TimeLength
		if len <= 0 then return end
		local r = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		sound.TimePosition = r * len
	end

	local function isPointer(i)
		return i.UserInputType == Enum.UserInputType.Touch
			or i.UserInputType == Enum.UserInputType.MouseButton1
	end

	connect(seekArea.InputBegan, function(i)
		if isPointer(i) then
			seeking = true
			seekTo(i.Position.X)
		end
	end)

	local dragging, dragStart, startPos
	connect(dragArea.InputBegan, function(i)
		if isPointer(i) then
			dragging = true
			dragStart = i.Position
			startPos = frame.Position
		end
	end)

	connect(UserInputService.InputChanged, function(i)
		if i.UserInputType == Enum.UserInputType.Touch
			or i.UserInputType == Enum.UserInputType.MouseMovement then
			if seeking then
				seekTo(i.Position.X)
			elseif dragging then
				local d = i.Position - dragStart
				frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
					startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end
	end)

	connect(UserInputService.InputEnded, function(i)
		if isPointer(i) then
			seeking = false
			dragging = false
		end
	end)

	connect(RunService.RenderStepped, function()
		if not isEnabled then return end
		local len, pos = sound.TimeLength, sound.TimePosition
		local ratio = (len > 0) and math.clamp(pos / len, 0, 1) or 0
		fill.Size = UDim2.new(ratio, 0, 1, 0)
		tLeft.Text = fmt(pos)
		tRight.Text = "-" .. fmt(len - pos)

		local now = os.clock()
		for i, b in ipairs(bars) do
			local h = 2
			if playing then
				h = 4 + math.abs(math.sin(now * 7 + i * 1.7)) * 16
			end
			b.Size = UDim2.new(0, 2, 0, h)
			b.BackgroundColor3 = playing and WHITE or GRAY
		end
	end)

	connect(gui.Destroying, function()
		for _, c in ipairs(conns) do
			pcall(function() c:Disconnect() end)
		end
	end)

	local songList = pageFrame:FindFirstChild("SongList")
	if not songList then
		songList = Instance.new("ScrollingFrame")
		songList.Name = "SongList"
		songList.Size = UDim2.new(1, 0, 1, 0)
		songList.BackgroundTransparency = 1
		songList.BorderSizePixel = 0
		songList.ScrollBarThickness = 3
		songList.CanvasSize = UDim2.new(0, 0, 0, 0)
		songList.AutomaticCanvasSize = Enum.AutomaticSize.Y
		songList.ZIndex = 3
		songList.Parent = pageFrame

		local songLayout = Instance.new("UIListLayout")
		songLayout.Name = "SongLayout"
		songLayout.Padding = UDim.new(0, 8)
		songLayout.SortOrder = Enum.SortOrder.LayoutOrder
		songLayout.Parent = songList
	end

	local songLayout = songList:FindFirstChild("SongLayout")

	local card = Instance.new("Frame")
	card.Name = "SongCard_CrystalBlue"
	card.Size = UDim2.new(1, 0, 0, 50)
	card.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	card.BackgroundTransparency = 0.5
	card.BorderSizePixel = 0
	card.ZIndex = 4
	card.Parent = songList
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(255, 255, 255)
	cardStroke.Transparency = 0.7
	cardStroke.Thickness = 1
	cardStroke.Parent = card

	local favCardBtn = Instance.new("TextButton")
	favCardBtn.Size = UDim2.fromOffset(24, 24)
	favCardBtn.Position = UDim2.new(0, 8, 0.5, -12)
	favCardBtn.BackgroundTransparency = 1
	favCardBtn.Text = "☆"
	favCardBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
	favCardBtn.TextSize = 16
	favCardBtn.Font = Enum.Font.GothamBold
	favCardBtn.ZIndex = 5
	favCardBtn.Parent = card

	local cardTitle = Instance.new("TextLabel")
	cardTitle.Size = UDim2.new(1, -124, 0, 20)
	cardTitle.Position = UDim2.new(0, 36, 0, 6)
	cardTitle.BackgroundTransparency = 1
	cardTitle.Font = Enum.Font.Ubuntu
	cardTitle.Text = TRACK_NAME
	cardTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
	cardTitle.TextSize = 14
	cardTitle.TextXAlignment = Enum.TextXAlignment.Left
	cardTitle.ZIndex = 5
	cardTitle.Parent = card

	local cardDesc = Instance.new("TextLabel")
	cardDesc.Size = UDim2.new(1, -124, 0, 18)
	cardDesc.Position = UDim2.new(0, 36, 0, 26)
	cardDesc.BackgroundTransparency = 1
	cardDesc.Font = Enum.Font.Ubuntu
	cardDesc.Text = ARTIST
	cardDesc.TextColor3 = Color3.fromRGB(150, 150, 150)
	cardDesc.TextSize = 11
	cardDesc.TextXAlignment = Enum.TextXAlignment.Left
	cardDesc.ZIndex = 5
	cardDesc.Parent = card

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.fromOffset(36, 24)
	toggleBtn.Position = UDim2.new(1, -86, 0.5, -12)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	toggleBtn.BackgroundTransparency = 0.3
	toggleBtn.Text = ""
	toggleBtn.ZIndex = 5
	toggleBtn.Parent = card
	Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.fromOffset(18, 18)
	indicator.Position = UDim2.new(0, 3, 0.5, -9)
	indicator.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
	indicator.BorderSizePixel = 0
	indicator.ZIndex = 6
	indicator.Parent = toggleBtn
	Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)

	local arrowBtn = Instance.new("TextButton")
	arrowBtn.Size = UDim2.fromOffset(32, 32)
	arrowBtn.Position = UDim2.new(1, -40, 0.5, -16)
	arrowBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	arrowBtn.BackgroundTransparency = 0.5
	arrowBtn.Text = "<"
	arrowBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	arrowBtn.Font = Enum.Font.Ubuntu
	arrowBtn.TextSize = 16
	arrowBtn.ZIndex = 5
	arrowBtn.Parent = card
	Instance.new("UICorner", arrowBtn).CornerRadius = UDim.new(0, 8)

	SongManager.SortList = function()
		if not songLayout then return end
		local favs, normal = {}, {}
		for _, entry in ipairs(SongManager.Tracks) do
			if entry.IsFavorite() then
				table.insert(favs, entry)
			else
				table.insert(normal, entry)
			end
		end
		table.sort(favs, function(a, b) return a.FavOrder < b.FavOrder end)
		table.sort(normal, function(a, b) return a.BaseOrder < b.BaseOrder end)

		local orderIdx = 1
		for _, entry in ipairs(favs) do
			entry.Card.LayoutOrder = orderIdx
			orderIdx += 1
		end
		for _, entry in ipairs(normal) do
			entry.Card.LayoutOrder = orderIdx
			orderIdx += 1
		end
	end

	local trackEntry = {
		Id = TRACK_ID,
		Name = TRACK_NAME,
		Card = card,
		BaseOrder = #SongManager.Tracks + 1,
		FavOrder = 0,
		IsFavorite = function() return isFavorite end
	}
	table.insert(SongManager.Tracks, trackEntry)

	local function refreshStarVisual()
		local sym = isFavorite and "★" or "☆"
		favCardBtn.Text = sym
		star.Text = sym
		favCardBtn.TextColor3 = isFavorite and Color3.fromRGB(255, 215, 70) or Color3.fromRGB(220, 220, 220)
		star.TextColor3 = isFavorite and WHITE or GRAY
	end

	local function toggleFavorite()
		isFavorite = not isFavorite
		if isFavorite then
			local maxFav = 0
			for _, other in ipairs(SongManager.Tracks) do
				if other.IsFavorite() and other.FavOrder > maxFav then
					maxFav = other.FavOrder
				end
			end
			trackEntry.FavOrder = maxFav + 1
		else
			trackEntry.FavOrder = 0
		end
		refreshStarVisual()
		SongManager.SortList()
	end

	favCardBtn.MouseButton1Click:Connect(toggleFavorite)
	starBtn.Activated:Connect(toggleFavorite)

	local function setSwitchVisual(active)
		TweenService:Create(indicator, TweenInfo.new(0.2), {
			Position = active and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
			BackgroundColor3 = active and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(180, 180, 180)
		}):Play()
	end

	local function setSongState(enable)
		if enable then
			if SongManager.ActiveTrackId and SongManager.ActiveTrackId ~= TRACK_ID then
				local busyTrack = nil
				for _, t in ipairs(SongManager.Tracks) do
					if t.Id == SongManager.ActiveTrackId then
						busyTrack = t.Name
						break
					end
				end
				SongManager.NotifyBusy(busyTrack or SongManager.ActiveTrackId)
				return
			end
			if isEnabled then return end
			isEnabled = true
			SongManager.ActiveTrackId = TRACK_ID
			setSwitchVisual(true)

			frame.Visible = true
			uiScale.Scale = math.clamp(playerScale * 0.85, 0.4, 1.35)
			frame.BackgroundTransparency = 0.85
			frameStroke.Transparency = 1
			TweenService:Create(uiScale, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = playerScale }):Play()
			TweenService:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundTransparency = 0.05 }):Play()
			TweenService:Create(frameStroke, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Transparency = 0.85 }):Play()
		else
			if not isEnabled then return end
			isEnabled = false
			if SongManager.ActiveTrackId == TRACK_ID then
				SongManager.ActiveTrackId = nil
			end
			setSwitchVisual(false)
			setPlaying(false)
			sound:Stop()
			sound.TimePosition = 0
			fill.Size = UDim2.new(0, 0, 1, 0)
			tLeft.Text = "0:00"
			tRight.Text = "-0:00"

			local outScale = TweenService:Create(uiScale, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Scale = math.clamp(playerScale * 0.85, 0.4, 1.35) })
			local outBg = TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
			local outStroke = TweenService:Create(frameStroke, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Transparency = 1 })
			outScale:Play()
			outBg:Play()
			outStroke:Play()
			outBg.Completed:Connect(function()
				if not isEnabled then
					frame.Visible = false
				end
			end)
		end
	end

	toggleBtn.MouseButton1Click:Connect(function()
		setSongState(not isEnabled)
	end)

	local sideFrame = Instance.new("Frame")
	sideFrame.Name = "CrystalBlueSizeMenu"
	sideFrame.Size = UDim2.new(0, 0, 0, menuHeight)
	sideFrame.AnchorPoint = Vector2.new(0, 0.5)
	sideFrame.Position = UDim2.new(0.5, (menuWidth / 2) + gapBetween, 0.5, 0)
	sideFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	sideFrame.BackgroundTransparency = 1
	sideFrame.BorderSizePixel = 0
	sideFrame.ClipsDescendants = true
	sideFrame.Visible = false
	sideFrame.Parent = mainGui
	Instance.new("UICorner", sideFrame).CornerRadius = UDim.new(0, 16)

	local sideStroke = Instance.new("UIStroke")
	sideStroke.Color = Color3.fromRGB(255, 255, 255)
	sideStroke.Transparency = 0.5
	sideStroke.Thickness = 1.5
	sideStroke.Parent = sideFrame

	local panelTitle = Instance.new("TextLabel")
	panelTitle.Size = UDim2.new(1, -16, 0, 22)
	panelTitle.Position = UDim2.new(0, 8, 0, 10)
	panelTitle.BackgroundTransparency = 1
	panelTitle.Font = Enum.Font.Ubuntu
	panelTitle.Text = "Размер меню"
	panelTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
	panelTitle.TextSize = 13
	panelTitle.TextXAlignment = Enum.TextXAlignment.Left
	panelTitle.ZIndex = 12
	panelTitle.Parent = sideFrame

	local sizeValLabel = Instance.new("TextLabel")
	sizeValLabel.Size = UDim2.new(1, -16, 0, 20)
	sizeValLabel.Position = UDim2.new(0, 8, 0, 36)
	sizeValLabel.BackgroundTransparency = 1
	sizeValLabel.Font = Enum.Font.Ubuntu
	sizeValLabel.Text = "Масштаб: 100%"
	sizeValLabel.TextColor3 = Color3.fromRGB(215, 215, 225)
	sizeValLabel.TextSize = 12
	sizeValLabel.TextXAlignment = Enum.TextXAlignment.Left
	sizeValLabel.ZIndex = 12
	sizeValLabel.Parent = sideFrame

	local sliderArea = Instance.new("TextButton")
	sliderArea.Size = UDim2.new(1, -16, 0, 34)
	sliderArea.Position = UDim2.new(0, 8, 0, 66)
	sliderArea.BackgroundTransparency = 1
	sliderArea.Text = ""
	sliderArea.AutoButtonColor = false
	sliderArea.ZIndex = 13
	sliderArea.Parent = sideFrame

	local trackSlider = Instance.new("Frame")
	trackSlider.Size = UDim2.new(1, 0, 0, 8)
	trackSlider.AnchorPoint = Vector2.new(0, 0.5)
	trackSlider.Position = UDim2.new(0, 0, 0.5, 0)
	trackSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
	trackSlider.BorderSizePixel = 0
	trackSlider.ZIndex = 13
	trackSlider.Parent = sliderArea
	Instance.new("UICorner", trackSlider).CornerRadius = UDim.new(1, 0)

	local minScale, maxScale = 0.4, 1.35
	local initRatio = math.clamp((playerScale - minScale) / (maxScale - minScale), 0, 1)

	local fillSlider = Instance.new("Frame")
	fillSlider.Size = UDim2.new(initRatio, 0, 1, 0)
	fillSlider.BackgroundColor3 = Color3.fromRGB(235, 235, 245)
	fillSlider.BorderSizePixel = 0
	fillSlider.ZIndex = 14
	fillSlider.Parent = trackSlider
	Instance.new("UICorner", fillSlider).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(16, 16)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(initRatio, 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.ZIndex = 15
	knob.Parent = trackSlider
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local sliding = false
	local function applyScaleFromX(x)
		local rel = math.clamp((x - trackSlider.AbsolutePosition.X) / math.max(1, trackSlider.AbsoluteSize.X), 0, 1)
		local sc = math.floor((minScale + (maxScale - minScale) * rel) * 100 + 0.5) / 100
		playerScale = sc
		sizeValLabel.Text = "Масштаб: " .. tostring(math.floor(sc * 100 + 0.5)) .. "%"
		fillSlider.Size = UDim2.new(rel, 0, 1, 0)
		knob.Position = UDim2.new(rel, 0, 0.5, 0)
		if isEnabled then
			uiScale.Scale = playerScale
		end
	end

	sliderArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = true
			applyScaleFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if sliding and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType.MouseMovement) then
			applyScaleFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType.MouseButton1 then
			sliding = false
		end
	end)

	local isPanelOpen = false
	local function closeSidePanel()
		if not isPanelOpen then return end
		isPanelOpen = false
		sliding = false
		TweenService:Create(arrowBtn, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		arrowBtn.Text = "<"
		TweenService:Create(sideFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, menuHeight),
			BackgroundTransparency = 1
		}):Play()
		task.wait(0.25)
		sideFrame.Visible = false
	end

	Client.State.CloseSidePanels = Client.State.CloseSidePanels or {}
	table.insert(Client.State.CloseSidePanels, closeSidePanel)

	table.insert(Client.State.OnTabChanged, function(tabName)
		if tabName ~= "Song" and isPanelOpen then
			closeSidePanel()
		end
	end)

	arrowBtn.MouseButton1Click:Connect(function()
		if isPanelOpen then
			closeSidePanel()
		else
			Client.CloseAllSidePanels()
			isPanelOpen = true
			sideFrame.Visible = true
			sideFrame.Size = UDim2.new(0, 0, 0, menuHeight)
			sideFrame.BackgroundTransparency = 1
			TweenService:Create(arrowBtn, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = 180 }):Play()
			arrowBtn.Text = ">"
			TweenService:Create(sideFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, panelWidth, 0, menuHeight),
				BackgroundTransparency = 0.35
			}):Play()
		end
	end)
end

Client.State.OnReady = Client.State.OnReady or {}
table.insert(Client.State.OnReady, initCrystalBlueSong)
