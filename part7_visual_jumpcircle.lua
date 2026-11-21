local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Client = _G.Dar4xClient
if not Client then return end

local localPlayer = Players.LocalPlayer

local config = {
	StartSize = 1.2,
	EndSize = 6.7,
	Duration = 0.42,
	Cooldown = 0.25,
	RingThickness = 4,
	Color = Color3.fromRGB(255, 255, 255),
	YOffset = 0.08
}

local minEndSize, maxEndSize = 3, 14

local function initJumpCircle()
	local cfg = Client.Config
	local mainGui = Client.State.MainGui
	local pageFrame = Client.State.Pages and Client.State.Pages["Visual"]
	if not mainGui or not pageFrame then return end

	local menuHeight = cfg.MenuHeight
	local menuWidth = cfg.MenuWidth
	local gapBetween = cfg.GapBetween
	local panelWidth = cfg.PlayerListWidth

	local jumpCircleEnabled = false
	local sessionToken = 0
	local lastSpawnTime = 0
	local isAirborne = false
	local effectsFolder = nil
	local activeConnections = {}
	local charAddedConn = nil
	local activeTweens = {}

	local function trackTween(tw)
		table.insert(activeTweens, tw)
		tw.Completed:Connect(function()
			local idx = table.find(activeTweens, tw)
			if idx then table.remove(activeTweens, idx) end
		end)
		return tw
	end

	local function clearCharacterConnections()
		for _, conn in ipairs(activeConnections) do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(activeConnections)
	end

	local function cleanupJumpCircles()
		sessionToken += 1
		isAirborne = false
		clearCharacterConnections()

		if charAddedConn then
			pcall(function() charAddedConn:Disconnect() end)
			charAddedConn = nil
		end

		for _, tw in ipairs(activeTweens) do
			pcall(function() tw:Cancel() end)
		end
		table.clear(activeTweens)

		local oldFolder = workspace:FindFirstChild("VisualJumpCircleFolder")
		if oldFolder then
			oldFolder:Destroy()
		end
		effectsFolder = nil
	end

	local function ensureEffectsFolder()
		if effectsFolder and effectsFolder.Parent then
			return effectsFolder
		end
		local folder = Instance.new("Folder")
		folder.Name = "VisualJumpCircleFolder"
		folder.Parent = workspace
		effectsFolder = folder
		return folder
	end

	local function getGroundPosition(character)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then return nil end

		local folder = ensureEffectsFolder()
		local rayOrigin = root.Position
		local rayDirection = Vector3.new(0, -10, 0)

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, folder }

		local result = workspace:Raycast(rayOrigin, rayDirection, params)
		if result then
			return result.Position
		end

		return Vector3.new(root.Position.X, root.Position.Y - 3, root.Position.Z)
	end

	local function spawnJumpCircle(originPos, token)
		if not jumpCircleEnabled or token ~= sessionToken or not originPos then return end

		local now = os.clock()
		if (now - lastSpawnTime) < config.Cooldown then
			return
		end
		lastSpawnTime = now

		local folder = ensureEffectsFolder()

		local anchor = Instance.new("Part")
		anchor.Name = "JumpCircleRing"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(config.StartSize, 0.05, config.StartSize)
		anchor.CFrame = CFrame.new(originPos.X, originPos.Y + config.YOffset, originPos.Z)
		anchor.Parent = folder

		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Face = Enum.NormalId.Top
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surfaceGui.PixelsPerStud = 50
		surfaceGui.AlwaysOnTop = false
		surfaceGui.LightInfluence = 0
		surfaceGui.Parent = anchor

		local ringFrame = Instance.new("Frame")
		ringFrame.Name = "RingOutline"
		ringFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		ringFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		ringFrame.Size = UDim2.new(1, 0, 1, 0)
		ringFrame.BackgroundTransparency = 1
		ringFrame.BorderSizePixel = 0
		ringFrame.Parent = surfaceGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = ringFrame

		local stroke = Instance.new("UIStroke")
		stroke.Color = config.Color
		stroke.Thickness = config.RingThickness
		stroke.Transparency = 0.05
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = ringFrame

		local tweenInfo = TweenInfo.new(
			config.Duration,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)

		local sizeTween = trackTween(TweenService:Create(anchor, tweenInfo, {
			Size = Vector3.new(config.EndSize, 0.05, config.EndSize)
		}))

		local strokeTween = trackTween(TweenService:Create(stroke, tweenInfo, {
			Transparency = 1
		}))

		sizeTween:Play()
		strokeTween:Play()

		sizeTween.Completed:Connect(function()
			if anchor and anchor.Parent then
				anchor:Destroy()
			end
		end)
	end

	local function hookCharacter(character, token)
		clearCharacterConnections()
		isAirborne = false
		if not jumpCircleEnabled or token ~= sessionToken or not character then return end

		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not jumpCircleEnabled or token ~= sessionToken then return end

		local jumpConn = humanoid.Jumping:Connect(function(isJumping)
			if isJumping and jumpCircleEnabled and token == sessionToken and not isAirborne then
				isAirborne = true
				local pos = getGroundPosition(character)
				spawnJumpCircle(pos, token)
			end
		end)

		local stateConn = humanoid.StateChanged:Connect(function(_, newState)
			if not jumpCircleEnabled or token ~= sessionToken then return end
			if newState == Enum.HumanoidStateType.Freefall or newState == Enum.HumanoidStateType.Jumping then
				isAirborne = true
			elseif newState == Enum.HumanoidStateType.Landed then
				if isAirborne then
					local pos = getGroundPosition(character)
					spawnJumpCircle(pos, token)
				end
				isAirborne = false
			elseif newState == Enum.HumanoidStateType.Running or newState == Enum.HumanoidStateType.Seated then
				isAirborne = false
			end
		end)

		table.insert(activeConnections, jumpConn)
		table.insert(activeConnections, stateConn)
	end

	-- UI в разделе Visual
	local visualList = pageFrame:FindFirstChild("VisualList")
	if not visualList then
		visualList = Instance.new("ScrollingFrame")
		visualList.Name = "VisualList"
		visualList.Size = UDim2.new(1, 0, 1, 0)
		visualList.BackgroundTransparency = 1
		visualList.BorderSizePixel = 0
		visualList.ScrollBarThickness = 3
		visualList.CanvasSize = UDim2.new(0, 0, 0, 0)
		visualList.AutomaticCanvasSize = Enum.AutomaticSize.Y
		visualList.ZIndex = 3
		visualList.Parent = pageFrame

		local visualLayout = Instance.new("UIListLayout")
		visualLayout.Padding = UDim.new(0, 8)
		visualLayout.SortOrder = Enum.SortOrder.LayoutOrder
		visualLayout.Parent = visualList
	end

	local card = Instance.new("Frame")
	card.Name = "JumpCircleCard"
	card.Size = UDim2.new(1, 0, 0, 50)
	card.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	card.BackgroundTransparency = 0.5
	card.BorderSizePixel = 0
	card.ZIndex = 4
	card.Parent = visualList
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.7
	stroke.Thickness = 1
	stroke.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -100, 0, 20)
	title.Position = UDim2.new(0, 10, 0, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Ubuntu
	title.Text = "JumpCircle"
	title.TextColor3 = Color3.fromRGB(240, 240, 240)
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 5
	title.Parent = card

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -100, 0, 18)
	desc.Position = UDim2.new(0, 10, 0, 26)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.Ubuntu
	desc.Text = "Кольцо под ногами при прыжке"
	desc.TextColor3 = Color3.fromRGB(150, 150, 150)
	desc.TextSize = 11
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.ZIndex = 5
	desc.Parent = card

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.new(0, 36, 0, 24)
	toggleBtn.Position = UDim2.new(1, -90, 0.5, -12)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	toggleBtn.BackgroundTransparency = 0.3
	toggleBtn.Text = ""
	toggleBtn.ZIndex = 5
	toggleBtn.Parent = card
	Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0, 18, 0, 18)
	indicator.Position = UDim2.new(0, 3, 0.5, -9)
	indicator.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
	indicator.BorderSizePixel = 0
	indicator.ZIndex = 6
	indicator.Parent = toggleBtn
	Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)

	local arrowBtn = Instance.new("TextButton")
	arrowBtn.Size = UDim2.new(0, 32, 0, 32)
	arrowBtn.Position = UDim2.new(1, -42, 0.5, -16)
	arrowBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	arrowBtn.BackgroundTransparency = 0.5
	arrowBtn.Text = "<"
	arrowBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	arrowBtn.Font = Enum.Font.Ubuntu
	arrowBtn.TextSize = 16
	arrowBtn.ZIndex = 5
	arrowBtn.Parent = card
	Instance.new("UICorner", arrowBtn).CornerRadius = UDim.new(0, 8)

	local function setSwitchVisual(active)
		TweenService:Create(indicator, TweenInfo.new(0.2), {
			Position = active and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
			BackgroundColor3 = active and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(180, 180, 180)
		}):Play()
	end

	-- Боковая панель настроек JumpCircle
	local sideFrame = Instance.new("Frame")
	sideFrame.Name = "JumpCircleSettingsMenu"
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

	local panelHeader = Instance.new("TextLabel")
	panelHeader.Size = UDim2.new(1, -16, 0, 22)
	panelHeader.Position = UDim2.new(0, 8, 0, 10)
	panelHeader.BackgroundTransparency = 1
	panelHeader.Font = Enum.Font.Ubuntu
	panelHeader.Text = "JumpCircle"
	panelHeader.TextColor3 = Color3.fromRGB(245, 245, 245)
	panelHeader.TextSize = 13
	panelHeader.TextXAlignment = Enum.TextXAlignment.Left
	panelHeader.ZIndex = 12
	panelHeader.Parent = sideFrame

	local sizeLabel = Instance.new("TextLabel")
	sizeLabel.Size = UDim2.new(1, -16, 0, 22)
	sizeLabel.Position = UDim2.new(0, 8, 0, 38)
	sizeLabel.BackgroundTransparency = 1
	sizeLabel.Font = Enum.Font.Ubuntu
	sizeLabel.Text = "Размер: " .. tostring(config.EndSize)
	sizeLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
	sizeLabel.TextSize = 12
	sizeLabel.TextXAlignment = Enum.TextXAlignment.Left
	sizeLabel.ZIndex = 12
	sizeLabel.Parent = sideFrame

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Size = UDim2.new(1, -16, 0, 16)
	hintLabel.Position = UDim2.new(0, 8, 0, 60)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.Ubuntu
	hintLabel.Text = "< Меньше   Больше >"
	hintLabel.TextColor3 = Color3.fromRGB(160, 160, 170)
	hintLabel.TextSize = 10
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.ZIndex = 12
	hintLabel.Parent = sideFrame

	local sliderArea = Instance.new("TextButton")
	sliderArea.Name = "SliderArea"
	sliderArea.Size = UDim2.new(1, -16, 0, 34)
	sliderArea.Position = UDim2.new(0, 8, 0, 82)
	sliderArea.BackgroundTransparency = 1
	sliderArea.Text = ""
	sliderArea.AutoButtonColor = false
	sliderArea.ZIndex = 13
	sliderArea.Parent = sideFrame

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, 0, 0, 8)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 0, 0.5, 0)
	track.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
	track.BorderSizePixel = 0
	track.ZIndex = 13
	track.Parent = sliderArea
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local initRatio = math.clamp((config.EndSize - minEndSize) / (maxEndSize - minEndSize), 0, 1)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(initRatio, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(220, 220, 235)
	fill.BorderSizePixel = 0
	fill.ZIndex = 14
	fill.Parent = track
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(initRatio, 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.ZIndex = 15
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local sliding = false

	local function setSizeFromPos(pos)
		local rel = math.clamp((pos.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		local val = math.floor((minEndSize + (maxEndSize - minEndSize) * rel) * 10 + 0.5) / 10
		config.EndSize = val
		sizeLabel.Text = "Размер: " .. tostring(val)
		TweenService:Create(fill, TweenInfo.new(0.08), { Size = UDim2.new(rel, 0, 1, 0) }):Play()
		TweenService:Create(knob, TweenInfo.new(0.08), { Position = UDim2.new(rel, 0, 0.5, 0) }):Play()
	end

	sliderArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = true
			setSizeFromPos(input.Position)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if sliding and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
			setSizeFromPos(input.Position)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
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
		if tabName ~= "Visual" and isPanelOpen then
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

	local function setJumpCircleState(enable)
		if jumpCircleEnabled == enable then return end
		jumpCircleEnabled = enable
		setSwitchVisual(enable)

		if enable then
			cleanupJumpCircles()
			jumpCircleEnabled = true
			local token = sessionToken
			ensureEffectsFolder()

			charAddedConn = localPlayer.CharacterAdded:Connect(function(newChar)
				if jumpCircleEnabled and token == sessionToken then
					task.spawn(hookCharacter, newChar, token)
				end
			end)

			if localPlayer.Character then
				task.spawn(hookCharacter, localPlayer.Character, token)
			end
		else
			cleanupJumpCircles()
		end
	end

	setSwitchVisual(false)
	toggleBtn.MouseButton1Click:Connect(function()
		setJumpCircleState(not jumpCircleEnabled)
	end)
end

Client.State.OnReady = Client.State.OnReady or {}
table.insert(Client.State.OnReady, initJumpCircle)
