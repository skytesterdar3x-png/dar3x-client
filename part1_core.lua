local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

_G.Dar4xClient = _G.Dar4xClient or {}
local Client = _G.Dar4xClient

Client.Config = {
	ClientName = "Dar4x Client",
	LogoId = "rbxassetid://77813700068224",
	MenuBgId = "rbxassetid://130522533521223",
	MenuWidth = 468,
	MenuHeight = 248,
	SidebarWidth = 54,
	PlayerListWidth = 130,
	AntiFlingPanelWidth = 170,
	GapBetween = 10,
	Tabs = {
		{ name = "Home", id = "rbxassetid://130250475069907" },
		{ name = "Visual", id = "rbxassetid://137656729276085" },
		{ name = "Song", id = "rbxassetid://104993995054886" },
		{ name = "Trolling", id = "rbxassetid://89069984083872" }
	}
}

Client.State = {
	ActiveTab = "Home",
	IsOpen = false,
	IsAnimating = false,
	Pages = {},
	TabButtons = {},
	OnTabChanged = {},
	OnMenuStateChanged = {},
	CloseSidePanels = {}
}

function Client.GetRoot(char)
	return char and char:FindFirstChild("HumanoidRootPart")
end

function Client.GetHum(char)
	return char and char:FindFirstChildOfClass("Humanoid")
end

function Client.ZeroVelocities(char, destroyMovers)
	if not char then return end
	for _, obj in ipairs(char:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.AssemblyLinearVelocity = Vector3.zero
			obj.AssemblyAngularVelocity = Vector3.zero
			obj.RotVelocity = Vector3.zero
			obj.Velocity = Vector3.zero
		elseif destroyMovers and (obj:IsA("BodyMover") or obj:IsA("LinearVelocity") or obj:IsA("AngularVelocity") or obj:IsA("VectorForce")) then
			obj:Destroy()
		end
	end
end

function Client.CloseAllSidePanels()
	for _, fn in ipairs(Client.State.CloseSidePanels) do
		pcall(fn)
	end
end

-- Очистка старых GUI при перезапуске
for _, name in ipairs({ "Dar4xClientLoading", "Dar4xClientNotification", "Dar4xClientMain", "FlingMenuGui" }) do
	if playerGui:FindFirstChild(name) then
		playerGui[name]:Destroy()
	end
end
for _, objName in ipairs({ "FlingHoopFolder", "FlingSafePlatform" }) do
	if workspace:FindFirstChild(objName) then
		workspace[objName]:Destroy()
	end
end

local function playLoadingScreen(onDone)
	local cfg = Client.Config
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Dar4xClientLoading"
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 999999
	screenGui.Parent = playerGui

	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	background.BackgroundTransparency = 1
	background.BorderSizePixel = 0
	background.Parent = screenGui

	local logo = Instance.new("ImageLabel")
	logo.Size = UDim2.new(0, 140, 0, 140)
	logo.Position = UDim2.new(0.5, -70, 0.38, -70)
	logo.BackgroundTransparency = 1
	logo.Image = cfg.LogoId
	logo.ImageTransparency = 1
	logo.Parent = screenGui

	local textContainer = Instance.new("Frame")
	textContainer.Size = UDim2.new(0, 520, 0, 48)
	textContainer.Position = UDim2.new(0.5, -260, 0.72, 0)
	textContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	textContainer.BackgroundTransparency = 1
	textContainer.BorderSizePixel = 0
	textContainer.Parent = screenGui
	Instance.new("UICorner", textContainer).CornerRadius = UDim.new(0, 12)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Ubuntu
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(240, 240, 240)
	label.TextTransparency = 1
	label.Parent = textContainer

	local phrases = {
		cfg.ClientName .. " — Делай Правильный Выбор",
		cfg.ClientName .. " — Выбор Сильнейших",
		cfg.ClientName .. " — Когда другие клиенты не справляются",
		cfg.ClientName .. " — Путь сильнейших"
	}

	math.randomseed(tick())
	label.Text = phrases[math.random(1, #phrases)]

	local animTime = 1.0
	local displayTime = 2.0

	task.spawn(function()
		task.wait(0.2)
		local t1 = TweenService:Create(background, TweenInfo.new(animTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0 })
		t1:Play()
		t1.Completed:Wait()

		local t2 = TweenService:Create(logo, TweenInfo.new(animTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { ImageTransparency = 0 })
		t2:Play()
		t2.Completed:Wait()

		textContainer.Position = UDim2.new(0.5, -260, 0.72, 20)
		local t3 = TweenService:Create(textContainer, TweenInfo.new(animTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.7, Position = UDim2.new(0.5, -260, 0.72, 0) })
		local t4 = TweenService:Create(label, TweenInfo.new(animTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 })
		t3:Play()
		t4:Play()
		t4.Completed:Wait()

		task.wait(displayTime)

		local t5 = TweenService:Create(textContainer, TweenInfo.new(animTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
		local t6 = TweenService:Create(label, TweenInfo.new(animTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })
		t5:Play()
		t6:Play()
		t6.Completed:Wait()

		local t7 = TweenService:Create(logo, TweenInfo.new(animTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { ImageTransparency = 1 })
		t7:Play()
		t7.Completed:Wait()

		local t8 = TweenService:Create(background, TweenInfo.new(animTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
		t8:Play()
		t8.Completed:Wait()

		screenGui:Destroy()
		if onDone then onDone() end
	end)
end

local function showNotificationAndReset(onFinish)
	local cfg = Client.Config
	local notifGui = Instance.new("ScreenGui")
	notifGui.Name = "Dar4xClientNotification"
	notifGui.IgnoreGuiInset = true
	notifGui.DisplayOrder = 999998
	notifGui.Parent = playerGui

	local container = Instance.new("Frame")
	container.Size = UDim2.new(0, 360, 0, 60)
	container.Position = UDim2.new(1, -385, 1, -85)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = notifGui

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 50, 0, 50)
	icon.Position = UDim2.new(1, -50, 0.5, -25)
	icon.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	icon.BackgroundTransparency = 1
	icon.Image = cfg.LogoId
	icon.ImageTransparency = 1
	icon.BorderSizePixel = 0
	icon.Parent = container
	Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)

	local textBubble = Instance.new("Frame")
	textBubble.Size = UDim2.new(0, 0, 0, 50)
	textBubble.AnchorPoint = Vector2.new(1, 0.5)
	textBubble.Position = UDim2.new(1, -55, 0.5, 0)
	textBubble.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	textBubble.BackgroundTransparency = 1
	textBubble.ClipsDescendants = true
	textBubble.BorderSizePixel = 0
	textBubble.Parent = container
	Instance.new("UICorner", textBubble).CornerRadius = UDim.new(0, 12)

	local notifLabel = Instance.new("TextLabel")
	notifLabel.Size = UDim2.new(0, 290, 1, 0)
	notifLabel.Position = UDim2.new(0, 10, 0, 0)
	notifLabel.BackgroundTransparency = 1
	notifLabel.Font = Enum.Font.Ubuntu
	notifLabel.Text = "Вы ресетнитесь, это необходимо для плавной игры с клиентом"
	notifLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	notifLabel.TextSize = 13
	notifLabel.TextWrapped = true
	notifLabel.TextTransparency = 1
	notifLabel.Parent = textBubble

	task.spawn(function()
		TweenService:Create(icon, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { ImageTransparency = 0, BackgroundTransparency = 0.4 }):Play()
		task.wait(0.3)

		local expandTween = TweenService:Create(textBubble, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 300, 0, 50),
			BackgroundTransparency = 0.4
		})
		TweenService:Create(notifLabel, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
		expandTween:Play()
		expandTween.Completed:Wait()

		task.wait(3.0)

		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.Health = 0 end

		task.wait(1.5)

		local collapseTween = TweenService:Create(textBubble, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 50),
			BackgroundTransparency = 1
		})
		TweenService:Create(notifLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		collapseTween:Play()
		collapseTween.Completed:Wait()

		TweenService:Create(icon, TweenInfo.new(0.3), { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.wait(0.3)

		notifGui:Destroy()
		if onFinish then onFinish() end
	end)
end

local function createMainInterface()
	local cfg = Client.Config
	local st = Client.State

	local mainGui = Instance.new("ScreenGui")
	mainGui.Name = "Dar4xClientMain"
	mainGui.IgnoreGuiInset = true
	mainGui.ResetOnSpawn = false
	mainGui.Parent = playerGui
	st.MainGui = mainGui

	local barWidth, barHeight = 175, 3
	local barIdleTransparency, barActiveTransparency = 0.65, 0.35

	local menuSize = UDim2.new(0, cfg.MenuWidth, 0, cfg.MenuHeight)
	local menuClosedSize = UDim2.new(0, cfg.MenuWidth - 36, 0, cfg.MenuHeight - 36)
	local sidebarSize = UDim2.new(0, cfg.SidebarWidth, 0, cfg.MenuHeight)
	local sidebarClosedSize = UDim2.new(0, cfg.SidebarWidth - 10, 0, cfg.MenuHeight - 36)

	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleBar"
	toggleButton.Size = UDim2.new(0, barWidth, 0, barHeight)
	toggleButton.AnchorPoint = Vector2.new(0.5, 1)
	toggleButton.Position = UDim2.new(0.5, 0, 1, -10)
	toggleButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	toggleButton.BackgroundTransparency = 1
	toggleButton.BorderSizePixel = 0
	toggleButton.Text = ""
	toggleButton.AutoButtonColor = false
	toggleButton.Parent = mainGui
	Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(1, 0)

	local sidebarFrame = Instance.new("Frame")
	sidebarFrame.Name = "SidebarDock"
	sidebarFrame.Size = sidebarSize
	sidebarFrame.AnchorPoint = Vector2.new(1, 0.5)
	sidebarFrame.Position = UDim2.new(0.5, -(cfg.MenuWidth / 2) - cfg.GapBetween, 0.5, 0)
	sidebarFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	sidebarFrame.BackgroundTransparency = 0.35
	sidebarFrame.BorderSizePixel = 0
	sidebarFrame.ClipsDescendants = true
	sidebarFrame.Visible = false
	sidebarFrame.Parent = mainGui
	Instance.new("UICorner", sidebarFrame).CornerRadius = UDim.new(0, 16)

	local sidebarStroke = Instance.new("UIStroke")
	sidebarStroke.Transparency = 0.5
	sidebarStroke.Color = Color3.fromRGB(255, 255, 255)
	sidebarStroke.Thickness = 1.5
	sidebarStroke.Parent = sidebarFrame

	local sidebarLayout = Instance.new("UIListLayout")
	sidebarLayout.FillDirection = Enum.FillDirection.Vertical
	sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sidebarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	sidebarLayout.Padding = UDim.new(0, 12)
	sidebarLayout.Parent = sidebarFrame

	local menuFrame = Instance.new("Frame")
	menuFrame.Name = "GlassMenu"
	menuFrame.Size = menuSize
	menuFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	menuFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	menuFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	menuFrame.BackgroundTransparency = 0.35
	menuFrame.BorderSizePixel = 0
	menuFrame.ClipsDescendants = true
	menuFrame.Visible = false
	menuFrame.Parent = mainGui
	Instance.new("UICorner", menuFrame).CornerRadius = UDim.new(0, 16)

	local menuStroke = Instance.new("UIStroke")
	menuStroke.Transparency = 0.5
	menuStroke.Color = Color3.fromRGB(255, 255, 255)
	menuStroke.Thickness = 1.5
	menuStroke.Parent = menuFrame

	local menuBg = Instance.new("ImageLabel")
	menuBg.Name = "MenuBackground"
	menuBg.Size = UDim2.new(1, 0, 1, 0)
	menuBg.BackgroundTransparency = 1
	menuBg.Image = cfg.MenuBgId
	menuBg.ImageTransparency = 0.55
	menuBg.ScaleType = Enum.ScaleType.Crop
	menuBg.ZIndex = 0
	menuBg.Parent = menuFrame
	Instance.new("UICorner", menuBg).CornerRadius = UDim.new(0, 16)

	local function applyTabVisuals(duration)
		for name, btnData in pairs(st.TabButtons) do
			local bgT = (not st.IsOpen) and 1 or ((name == st.ActiveTab) and 0.25 or 0.75)
			local icT = (not st.IsOpen) and 1 or ((name == st.ActiveTab) and 0 or 0.35)
			TweenService:Create(btnData.button, TweenInfo.new(duration), { BackgroundTransparency = bgT }):Play()
			TweenService:Create(btnData.icon, TweenInfo.new(duration), { ImageTransparency = icT }):Play()
		end
	end

	local activePageTween = nil
	local function selectTab(tabName)
		if st.ActiveTab == "Trolling" and tabName ~= "Trolling" then
			Client.CloseAllSidePanels()
		end
		if activePageTween then activePageTween:Cancel() end
		st.ActiveTab = tabName

		for name, page in pairs(st.Pages) do
			if name == tabName then
				page.Visible = true
				page.Position = UDim2.new(0, 10, 0, 12)
				page.GroupTransparency = 1
				activePageTween = TweenService:Create(page, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Position = UDim2.new(0, 12, 0, 12),
					GroupTransparency = 0
				})
				activePageTween:Play()
			else
				page.Visible = false
				page.GroupTransparency = 1
			end
		end

		applyTabVisuals(0.2)
		for _, cb in ipairs(st.OnTabChanged) do
			pcall(cb, tabName, st.IsOpen)
		end
	end

	for _, tab in ipairs(cfg.Tabs) do
		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = tab.name .. "TabButton"
		tabBtn.Size = UDim2.new(0, 38, 0, 38)
		tabBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		tabBtn.BackgroundTransparency = 1
		tabBtn.BorderSizePixel = 0
		tabBtn.ClipsDescendants = true
		tabBtn.Text = ""
		tabBtn.AutoButtonColor = false
		tabBtn.Parent = sidebarFrame
		Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(1, 0)

		local iconImg = Instance.new("ImageLabel")
		iconImg.Name = "Icon"
		iconImg.Size = UDim2.new(0, 24, 0, 24)
		iconImg.AnchorPoint = Vector2.new(0.5, 0.5)
		iconImg.Position = UDim2.new(0.5, 0, 0.5, 0)
		iconImg.BackgroundTransparency = 1
		iconImg.ClipsDescendants = true
		iconImg.Image = tab.id
		iconImg.ImageTransparency = 1
		iconImg.ScaleType = Enum.ScaleType.Crop
		iconImg.Parent = tabBtn
		Instance.new("UICorner", iconImg).CornerRadius = UDim.new(1, 0)

		local pageFrame = Instance.new("CanvasGroup")
		pageFrame.Name = tab.name .. "Page"
		pageFrame.Size = UDim2.new(1, -24, 1, -24)
		pageFrame.Position = UDim2.new(0, 12, 0, 12)
		pageFrame.BackgroundTransparency = 1
		pageFrame.GroupTransparency = tab.name == st.ActiveTab and 0 or 1
		pageFrame.Visible = (tab.name == st.ActiveTab)
		pageFrame.ZIndex = 2
		pageFrame.Parent = menuFrame

		st.Pages[tab.name] = pageFrame
		st.TabButtons[tab.name] = { button = tabBtn, icon = iconImg }

		tabBtn.MouseButton1Click:Connect(function()
			selectTab(tab.name)
		end)
	end

	TweenService:Create(toggleButton, TweenInfo.new(0.8), { BackgroundTransparency = barIdleTransparency }):Play()

	toggleButton.MouseButton1Click:Connect(function()
		if st.IsAnimating then return end
		st.IsAnimating = true
		local animInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

		if not st.IsOpen then
			st.IsOpen = true
			menuFrame.Visible = true
			sidebarFrame.Visible = true

			menuFrame.Size = menuClosedSize
			menuFrame.BackgroundTransparency = 1
			menuBg.ImageTransparency = 1
			menuStroke.Transparency = 1

			sidebarFrame.Size = sidebarClosedSize
			sidebarFrame.BackgroundTransparency = 1
			sidebarStroke.Transparency = 1

			TweenService:Create(toggleButton, TweenInfo.new(0.2), { Size = UDim2.new(0, barWidth - 15, 0, barHeight), BackgroundTransparency = barActiveTransparency }):Play()

			local openMenuTween = TweenService:Create(menuFrame, animInfo, { Size = menuSize, BackgroundTransparency = 0.35 })
			local openSidebarTween = TweenService:Create(sidebarFrame, animInfo, { Size = sidebarSize, BackgroundTransparency = 0.35 })

			TweenService:Create(menuBg, animInfo, { ImageTransparency = 0.55 }):Play()
			TweenService:Create(menuStroke, animInfo, { Transparency = 0.5 }):Play()
			TweenService:Create(sidebarStroke, animInfo, { Transparency = 0.5 }):Play()
			applyTabVisuals(0.3)

			openMenuTween:Play()
			openSidebarTween:Play()
			openMenuTween.Completed:Wait()

			for _, cb in ipairs(st.OnMenuStateChanged) do
				pcall(cb, true, st.ActiveTab)
			end
		else
			st.IsOpen = false
			Client.CloseAllSidePanels()
			for _, cb in ipairs(st.OnMenuStateChanged) do
				pcall(cb, false, st.ActiveTab)
			end

			local closeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			local closeMenuTween = TweenService:Create(menuFrame, closeInfo, { Size = menuClosedSize, BackgroundTransparency = 1 })
			local closeSidebarTween = TweenService:Create(sidebarFrame, closeInfo, { Size = sidebarClosedSize, BackgroundTransparency = 1 })

			TweenService:Create(menuBg, closeInfo, { ImageTransparency = 1 }):Play()
			TweenService:Create(menuStroke, closeInfo, { Transparency = 1 }):Play()
			TweenService:Create(sidebarStroke, closeInfo, { Transparency = 1 }):Play()
			applyTabVisuals(0.25)

			TweenService:Create(toggleButton, TweenInfo.new(0.2), { Size = UDim2.new(0, barWidth, 0, barHeight), BackgroundTransparency = barIdleTransparency }):Play()

			closeMenuTween:Play()
			closeSidebarTween:Play()
			closeMenuTween.Completed:Wait()

			menuFrame.Visible = false
			sidebarFrame.Visible = false
		end

		st.IsAnimating = false
	end)

	st.Ready = true
	if st.OnReady then
		for _, cb in ipairs(st.OnReady) do
			pcall(cb)
		end
	end
end

function Client.Start()
	playLoadingScreen(function()
		showNotificationAndReset(function()
			createMainInterface()
		end)
	end)
end
