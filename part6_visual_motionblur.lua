local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Client = _G.Dar4xClient
if not Client then return end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = workspace.CurrentCamera
end)

local minVal = 0
local maxVal = 35
local defaultMultiplier = 12
local maxBlurSize = 24
local smoothing = 0.25

local function initMotionBlur()
	local cfg = Client.Config
	local mainGui = Client.State.MainGui
	local pageFrame = Client.State.Pages and Client.State.Pages["Visual"]
	if not mainGui or not pageFrame then return end

	local menuHeight = cfg.MenuHeight
	local menuWidth = cfg.MenuWidth
	local gapBetween = cfg.GapBetween
	local panelWidth = cfg.PlayerListWidth

	local motionBlurEnabled = false
	local blurMultiplier = defaultMultiplier
	local currentBlur = 0
	local lastLookVector = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)

	local blurEffect = Lighting:FindFirstChild("VisualClientMotionBlur")
	if not blurEffect then
		blurEffect = Instance.new("BlurEffect")
		blurEffect.Name = "VisualClientMotionBlur"
		blurEffect.Size = 0
		blurEffect.Enabled = false
		blurEffect.Parent = Lighting
	else
		blurEffect.Size = 0
		blurEffect.Enabled = false
	end

	local function resetBlurEffect()
		currentBlur = 0
		if camera then
			lastLookVector = camera.CFrame.LookVector
		end
		if blurEffect and blurEffect.Parent then
			blurEffect.Size = 0
			blurEffect.Enabled = false
		end
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
	card.Name = "MotionBlurCard"
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
	title.Text = "Motion Blur"
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
	desc.Text = "Размытие в движении камеры"
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

	-- Боковая панель настроек Motion Blur
	local sideFrame = Instance.new("Frame")
	sideFrame.Name = "MotionBlurSettingsMenu"
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
	panelHeader.Text = "Motion Blur"
	panelHeader.TextColor3 = Color3.fromRGB(245, 245, 245)
	panelHeader.TextSize = 13
	panelHeader.TextXAlignment = Enum.TextXAlignment.Left
	panelHeader.ZIndex = 12
	panelHeader.Parent = sideFrame

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(1, -16, 0, 22)
	valueLabel.Position = UDim2.new(0, 8, 0, 38)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Font = Enum.Font.Ubuntu
	valueLabel.Text = "Сила: " .. tostring(blurMultiplier)
	valueLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
	valueLabel.TextSize = 12
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.ZIndex = 12
	valueLabel.Parent = sideFrame

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

	local sliderTouchArea = Instance.new("TextButton")
	sliderTouchArea.Name = "SliderArea"
	sliderTouchArea.Size = UDim2.new(1, -16, 0, 34)
	sliderTouchArea.Position = UDim2.new(0, 8, 0, 82)
	sliderTouchArea.BackgroundTransparency = 1
	sliderTouchArea.Text = ""
	sliderTouchArea.AutoButtonColor = false
	sliderTouchArea.ZIndex = 13
	sliderTouchArea.Parent = sideFrame

	local sliderTrack = Instance.new("Frame")
	sliderTrack.Name = "Track"
	sliderTrack.Size = UDim2.new(1, 0, 0, 8)
	sliderTrack.AnchorPoint = Vector2.new(0, 0.5)
	sliderTrack.Position = UDim2.new(0, 0, 0.5, 0)
	sliderTrack.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
	sliderTrack.BorderSizePixel = 0
	sliderTrack.ZIndex = 13
	sliderTrack.Parent = sliderTouchArea
	Instance.new("UICorner", sliderTrack).CornerRadius = UDim.new(1, 0)

	local initRatio = math.clamp((blurMultiplier - minVal) / (maxVal - minVal), 0, 1)

	local sliderFill = Instance.new("Frame")
	sliderFill.Name = "Fill"
	sliderFill.Size = UDim2.new(initRatio, 0, 1, 0)
	sliderFill.BackgroundColor3 = Color3.fromRGB(220, 220, 235)
	sliderFill.BorderSizePixel = 0
	sliderFill.ZIndex = 14
	sliderFill.Parent = sliderTrack
	Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(initRatio, 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.ZIndex = 15
	knob.Parent = sliderTrack
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local draggingSlider = false

	local function updateSliderFromX(inputX)
		local trackPos = sliderTrack.AbsolutePosition.X
		local trackSize = math.max(1, sliderTrack.AbsoluteSize.X)
		local relativeX = math.clamp((inputX - trackPos) / trackSize, 0, 1)

		blurMultiplier = math.floor(minVal + (maxVal - minVal) * relativeX + 0.5)
		valueLabel.Text = (blurMultiplier == 0) and "Сила: OFF" or ("Сила: " .. tostring(blurMultiplier))

		TweenService:Create(sliderFill, TweenInfo.new(0.08), { Size = UDim2.new(relativeX, 0, 1, 0) }):Play()
		TweenService:Create(knob, TweenInfo.new(0.08), { Position = UDim2.new(relativeX, 0, 0.5, 0) }):Play()
	end

	sliderTouchArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingSlider = true
			updateSliderFromX(input.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if draggingSlider and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
			updateSliderFromX(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingSlider = false
		end
	end)

	local isPanelOpen = false
	local function closeSidePanel()
		if not isPanelOpen then return end
		isPanelOpen = false
		draggingSlider = false
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

	local function setMotionBlurState(enable)
		if motionBlurEnabled == enable then return end
		motionBlurEnabled = enable
		setSwitchVisual(enable)

		if enable then
			if camera then
				lastLookVector = camera.CFrame.LookVector
			end
			currentBlur = 0
			if blurEffect and blurEffect.Parent then
				blurEffect.Size = 0
				blurEffect.Enabled = blurMultiplier > 0
			end
		else
			resetBlurEffect()
		end
	end

	setSwitchVisual(false)
	toggleBtn.MouseButton1Click:Connect(function()
		setMotionBlurState(not motionBlurEnabled)
	end)

	RunService.RenderStepped:Connect(function(dt)
		if not camera then
			camera = workspace.CurrentCamera
			return
		end

		if not motionBlurEnabled then
			if blurEffect and blurEffect.Parent and (blurEffect.Enabled or blurEffect.Size ~= 0) then
				resetBlurEffect()
			end
			return
		end

		local currentLookVector = camera.CFrame.LookVector
		local deltaAngle = (currentLookVector - lastLookVector).Magnitude
		lastLookVector = currentLookVector

		if not blurEffect or not blurEffect.Parent then
			blurEffect = Instance.new("BlurEffect")
			blurEffect.Name = "VisualClientMotionBlur"
			blurEffect.Parent = Lighting
		end

		if blurMultiplier <= 0 then
			currentBlur = 0
			blurEffect.Size = 0
			blurEffect.Enabled = false
			return
		end

		blurEffect.Enabled = true
		local fpsFactor = math.clamp(1 / math.max(dt, 0.001) / 60, 0.5, 2)
		local targetBlur = math.clamp(deltaAngle * blurMultiplier * 8 * fpsFactor, 0, maxBlurSize)

		currentBlur = currentBlur + (targetBlur - currentBlur) * smoothing
		blurEffect.Size = currentBlur
	end)
end

Client.State.OnReady = Client.State.OnReady or {}
table.insert(Client.State.OnReady, initMotionBlur)
