local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Client = _G.Dar4xClient
if not Client then return end

local player = Players.LocalPlayer

-- Координаты карты для Anti-Fling
local POINT_A = Vector3.new(3174.8, 2456.9, -3332.6)
local POINT_B = Vector3.new(-3198.2, -30.5, 3153.4)
local EDGE_MARGIN = 15
local VOID_EXTRA_DROP = 35
local TICK_INTERVAL = 0.08
local MAX_HORIZ_FLING_SPEED = 165
local MAX_UPWARD_FLING_SPEED = 175
local MAX_STEP_JUMP = 95
local MAX_SLOTS = 5

local BOUNDS = {
	minX = math.min(POINT_A.X, POINT_B.X) + EDGE_MARGIN,
	maxX = math.max(POINT_A.X, POINT_B.X) - EDGE_MARGIN,
	minY = math.min(POINT_A.Y, POINT_B.Y) - VOID_EXTRA_DROP,
	maxY = math.max(POINT_A.Y, POINT_B.Y) - EDGE_MARGIN,
	minZ = math.min(POINT_A.Z, POINT_B.Z) + EDGE_MARGIN,
	maxZ = math.max(POINT_A.Z, POINT_B.Z) - EDGE_MARGIN,
}

local function initTrolling()
	local cfg = Client.Config
	local mainGui = Client.State.MainGui
	local pageFrame = Client.State.Pages["Trolling"]
	if not mainGui or not pageFrame then return end

	local menuHeight = cfg.MenuHeight
	local menuWidth = cfg.MenuWidth
	local gapBetween = cfg.GapBetween
	local playerListWidth = cfg.PlayerListWidth
	local antiFlingPanelWidth = cfg.AntiFlingPanelWidth

	local headsitTarget = nil
	local isHeadsitActive = false
	local headsitConnection = nil
	local jumpConnection = nil
	local sitAnimationTrack = nil

	local sexAuraTarget = nil
	local isSexAuraActive = false
	local sexAuraConnection = nil

	local flingEnabled = false
	local radius = 22
	local minRadius, maxRadius = 8, 60
	local ringSegmentsCount = 72
	local ringThickness = 0.45
	local isBusyFlinging = false
	local farDistance = 9000
	local aboveHeightOffset = 45
	local defaultSafePlatformY = -350
	local whiteColor = Color3.fromRGB(255, 255, 255)
	local redColor = Color3.fromRGB(255, 45, 45)
	local currentRingColor = whiteColor

	local isAntiSitActive = false
	local antiSitConnections = {}
	local antiSitHeartbeatConn = nil

	local antiFlingEnabled = false
	local savedPoints = {}
	local activeSlot = 1
	local lastPos = nil
	local isRecovering = false
	local waitingForFirstHome = false

	-- Анти-Сит логика
	local function clearAntiSitConnections()
		for _, conn in ipairs(antiSitConnections) do
			conn:Disconnect()
		end
		table.clear(antiSitConnections)
		if antiSitHeartbeatConn then
			antiSitHeartbeatConn:Disconnect()
			antiSitHeartbeatConn = nil
		end
	end

	local function bindAntiSitCharacter(character)
		clearAntiSitConnections()
		if not character or not isAntiSitActive then return end
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then return end

		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
		end)

		table.insert(antiSitConnections, humanoid.StateChanged:Connect(function(_, newState)
			if not isAntiSitActive then return end
			if newState == Enum.HumanoidStateType.Seated then
				humanoid.Sit = false
				local nextState = humanoid.FloorMaterial == Enum.Material.Air and Enum.HumanoidStateType.Freefall or Enum.HumanoidStateType.Running
				humanoid:ChangeState(nextState)
			end
		end))

		table.insert(antiSitConnections, humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
			if isAntiSitActive and humanoid.Sit then
				humanoid.Sit = false
			end
		end))

		antiSitHeartbeatConn = RunService.Heartbeat:Connect(function()
			if not isAntiSitActive or not humanoid.Parent then return end
			if humanoid.Sit then humanoid.Sit = false end
			if humanoid:GetState() == Enum.HumanoidStateType.Seated then
				local nextState = humanoid.FloorMaterial == Enum.Material.Air and Enum.HumanoidStateType.Freefall or Enum.HumanoidStateType.Running
				humanoid:ChangeState(nextState)
			end
		end)
	end

	local function setAntiSitState(enable)
		isAntiSitActive = enable
		if enable then
			if player.Character then
				task.spawn(function() bindAntiSitCharacter(player.Character) end)
			end
		else
			clearAntiSitConnections()
			local humanoid = Client.GetHum(player.Character)
			if humanoid then
				pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end)
			end
		end
	end

	player.CharacterAdded:Connect(function(newChar)
		if isAntiSitActive then bindAntiSitCharacter(newChar) end
	end)

	-- Сейф-платформа и обруч Fling
	local safePlatform = Instance.new("Part")
	safePlatform.Name = "FlingSafePlatform"
	safePlatform.Size = Vector3.new(18, 2, 18)
	safePlatform.Anchored = true
	safePlatform.CanCollide = true
	safePlatform.Transparency = 0.65
	safePlatform.Material = Enum.Material.SmoothPlastic
	safePlatform.Color = Color3.fromRGB(220, 220, 230)
	safePlatform.Position = Vector3.new(0, defaultSafePlatformY, 0)
	safePlatform.Parent = nil

	local function placeOnSafePlatform(char, x, z, customY)
		local root = Client.GetRoot(char)
		local hum = Client.GetHum(char)
		if not root or not hum or hum.Health <= 0 then return end

		local platY = customY or defaultSafePlatformY
		safePlatform.Position = Vector3.new(x, platY, z)
		safePlatform.Parent = workspace
		Client.ZeroVelocities(char, true)

		local standY = platY + (safePlatform.Size.Y * 0.5) + 3.0
		root.Anchored = true
		root.CFrame = CFrame.new(x, standY, z)
		task.wait(0.05)
		root.Anchored = false

		hum.PlatformStand = false
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
	end

	local ringFolder = Instance.new("Folder")
	ringFolder.Name = "FlingHoopFolder"
	local hoopSegments = {}
	for i = 1, ringSegmentsCount do
		local seg = Instance.new("Part")
		seg.Name = "HoopSeg_" .. i
		seg.Material = Enum.Material.Neon
		seg.Color = whiteColor
		seg.Transparency = 0.25
		seg.Anchored = true
		seg.CanCollide = false
		seg.CastShadow = false
		seg.Parent = ringFolder
		table.insert(hoopSegments, seg)
	end

	local function setHoopVisible(visible)
		ringFolder.Parent = visible and workspace or nil
	end

	local function updateHoopVisual(dt, hasTargetInside)
		local char = player.Character
		local root = Client.GetRoot(char)
		local hum = Client.GetHum(char)
		if not flingEnabled or not root or not hum or hum.Health <= 0 then
			setHoopVisible(false)
			return
		end
		setHoopVisible(true)

		local targetColor = hasTargetInside and redColor or whiteColor
		currentRingColor = currentRingColor:Lerp(targetColor, math.clamp(dt * 9, 0, 1))

		local y = root.Position.Y - 2.5
		local cx, cz = root.Position.X, root.Position.Z

		for i, seg in ipairs(hoopSegments) do
			local a1 = ((i - 1) / ringSegmentsCount) * math.pi * 2
			local a2 = (i / ringSegmentsCount) * math.pi * 2
			local p1 = Vector3.new(cx + math.cos(a1) * radius, y, cz + math.sin(a1) * radius)
			local p2 = Vector3.new(cx + math.cos(a2) * radius, y, cz + math.sin(a2) * radius)
			local midPos = (p1 + p2) * 0.5
			local segLen = (p2 - p1).Magnitude + 0.08
			seg.Size = Vector3.new(ringThickness, 0.22, segLen)
			seg.CFrame = CFrame.lookAt(midPos, p2)
			seg.Color = currentRingColor
		end
	end

	local function safeTeleportAndAnchor(char, targetCFrame)
		local root = Client.GetRoot(char)
		local hum = Client.GetHum(char)
		if not root or not hum or hum.Health <= 0 then return end

		Client.ZeroVelocities(char, true)
		root.Anchored = true
		root.CFrame = targetCFrame
		Client.ZeroVelocities(char, true)

		hum.PlatformStand = false
		local state = hum:GetState()
		if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.FallingDown then
			pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
		end

		task.wait(0.05)
		Client.ZeroVelocities(char, true)
		root.Anchored = false
		Client.ZeroVelocities(char, true)
		safePlatform.Parent = nil
	end

	local function flingTargetOutOfBounds(targetPlayer)
		if isBusyFlinging then return end
		local char = player.Character
		local root = Client.GetRoot(char)
		local hum = Client.GetHum(char)
		if not root or not hum or hum.Health <= 0 then return end

		isBusyFlinging = true
		local originCFrame = root.CFrame
		local originPos = originCFrame.Position
		local dirXZ = Vector3.new(1, 0, 1).Unit
		local targetFarPos = Vector3.new(
			originPos.X + dirXZ.X * farDistance,
			originPos.Y + aboveHeightOffset,
			originPos.Z + dirXZ.Z * farDistance
		)

		local tRoot = targetPlayer.Character and Client.GetRoot(targetPlayer.Character)
		if tRoot then
			Client.ZeroVelocities(char, true)
			root.CFrame = CFrame.new(tRoot.Position)
			root.AssemblyAngularVelocity = Vector3.new(0, 260, 0)
			root.AssemblyLinearVelocity = Vector3.new(dirXZ.X * 600, 120, dirXZ.Z * 600)
			task.wait(0.08)

			pcall(function()
				tRoot.CFrame = CFrame.new(targetFarPos)
				tRoot.AssemblyLinearVelocity = Vector3.new(dirXZ.X * 450, 80, dirXZ.Z * 450)
				tRoot.AssemblyAngularVelocity = Vector3.new(180, 180, 180)
			end)
		end

		placeOnSafePlatform(char, originPos.X - dirXZ.X * 1200, originPos.Z - dirXZ.Z * 1200)
		task.wait(1.5)

		char = player.Character
		hum = Client.GetHum(char)
		if char and hum and hum.Health > 0 and char:FindFirstChildOfClass("Tool") then
			pcall(function() hum:UnequipTools() end)
		end

		task.wait(1.3)

		char = player.Character
		hum = Client.GetHum(char)
		if char and hum and hum.Health > 0 then
			safeTeleportAndAnchor(char, originCFrame)
			pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
		end

		task.wait(0.6)
		isBusyFlinging = false
	end

	local function checkHoopTargets()
		local char = player.Character
		local root = Client.GetRoot(char)
		local hum = Client.GetHum(char)
		if not flingEnabled or not root or not hum or hum.Health <= 0 then
			return false, nil
		end

		local anyInside = false
		local seatedTarget = nil
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and other.Character then
				local oRoot = Client.GetRoot(other.Character)
				local oHum = Client.GetHum(other.Character)
				if oRoot and oHum and oHum.Health > 0 then
					local myXZ = Vector3.new(root.Position.X, 0, root.Position.Z)
					local oXZ = Vector3.new(oRoot.Position.X, 0, oRoot.Position.Z)
					if (oXZ - myXZ).Magnitude <= radius then
						anyInside = true
						if oHum.Sit or (oHum:GetState() == Enum.HumanoidStateType.Seated) then
							seatedTarget = other
							break
						end
					end
				end
			end
		end
		return anyInside, seatedTarget
	end

	-- Логика Anti-Fling
	local function isInsideMap(pos)
		return pos.X >= BOUNDS.minX and pos.X <= BOUNDS.maxX
			and pos.Y >= BOUNDS.minY and pos.Y <= BOUNDS.maxY
			and pos.Z >= BOUNDS.minZ and pos.Z <= BOUNDS.maxZ
	end

	local function hasAnyPoint()
		for i = 1, MAX_SLOTS do
			if savedPoints[i] then return true end
		end
		return false
	end

	local function getTargetHomeCFrame()
		if savedPoints[activeSlot] then return savedPoints[activeSlot] end
		for i = 1, MAX_SLOTS do
			if savedPoints[i] then
				activeSlot = i
				return savedPoints[i]
			end
		end
		return nil
	end

	local function teleportToTarget(char, hrp, humanoid, targetCF)
		if isRecovering then return end
		isRecovering = true

		Client.ZeroVelocities(char, false)
		hrp.Anchored = true
		hrp.CFrame = targetCF
		Client.ZeroVelocities(char, false)

		task.wait(0.06)

		if hrp and hrp.Parent then
			hrp.Anchored = false
			Client.ZeroVelocities(char, false)
			if humanoid and humanoid.Health > 0 then
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
			lastPos = hrp.Position
		end
		isRecovering = false
	end

	-- Список карточек Trolling
	local trollingList = Instance.new("ScrollingFrame")
	trollingList.Name = "TrollingList"
	trollingList.Size = UDim2.new(1, 0, 1, 0)
	trollingList.BackgroundTransparency = 1
	trollingList.BorderSizePixel = 0
	trollingList.ScrollBarThickness = 3
	trollingList.CanvasSize = UDim2.new(0, 0, 0, 0)
	trollingList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	trollingList.ZIndex = 3
	trollingList.Parent = pageFrame

	local trollingLayout = Instance.new("UIListLayout")
	trollingLayout.Padding = UDim.new(0, 8)
	trollingLayout.SortOrder = Enum.SortOrder.LayoutOrder
	trollingLayout.Parent = trollingList

	local function createCard(name, titleText, descText, hasToggle, hasArrow)
		local card = Instance.new("Frame")
		card.Name = name
		card.Size = UDim2.new(1, 0, 0, 50)
		card.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		card.BackgroundTransparency = 0.5
		card.BorderSizePixel = 0
		card.ZIndex = 4
		card.Parent = trollingList
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
		title.Text = titleText
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
		desc.Text = descText
		desc.TextColor3 = Color3.fromRGB(150, 150, 150)
		desc.TextSize = 11
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.ZIndex = 5
		desc.Parent = card

		local toggleBtn, indicator, arrowBtn
		if hasToggle then
			local toggleX = hasArrow and -90 or -46
			toggleBtn = Instance.new("TextButton")
			toggleBtn.Size = UDim2.new(0, 36, 0, 24)
			toggleBtn.Position = UDim2.new(1, toggleX, 0.5, -12)
			toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			toggleBtn.BackgroundTransparency = 0.3
			toggleBtn.Text = ""
			toggleBtn.ZIndex = 5
			toggleBtn.Parent = card
			Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

			indicator = Instance.new("Frame")
			indicator.Size = UDim2.new(0, 18, 0, 18)
			indicator.Position = UDim2.new(0, 3, 0.5, -9)
			indicator.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
			indicator.BorderSizePixel = 0
			indicator.ZIndex = 6
			indicator.Parent = toggleBtn
			Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)
		end

		if hasArrow then
			arrowBtn = Instance.new("TextButton")
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
		end

		return card, desc, toggleBtn, indicator, arrowBtn
	end

	local function createSideFrame(name, width)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.Size = UDim2.new(0, 0, 0, menuHeight)
		frame.AnchorPoint = Vector2.new(0, 0.5)
		frame.Position = UDim2.new(0.5, (menuWidth / 2) + gapBetween, 0.5, 0)
		frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.ClipsDescendants = true
		frame.Visible = false
		frame.Parent = mainGui
		Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Transparency = 0.5
		stroke.Thickness = 1.5
		stroke.Parent = frame
		return frame, width
	end

	local function setSwitchVisual(indicator, active)
		TweenService:Create(indicator, TweenInfo.new(0.2), {
			Position = active and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
			BackgroundColor3 = active and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(180, 180, 180)
		}):Play()
	end

	-- 1. Barrier Bypass
	local bypassBtn, _, _, _, _ = createCard("BarrierBypassButton", "Barrier Bypass", "Убирает барьеры и красные купола домов", false, false)
	local bypassClickBtn = Instance.new("TextButton")
	bypassClickBtn.Size = UDim2.new(1, 0, 1, 0)
	bypassClickBtn.BackgroundTransparency = 1
	bypassClickBtn.Text = ""
	bypassClickBtn.ZIndex = 7
	bypassClickBtn.Parent = bypassBtn

	local isBypassing = false
	bypassClickBtn.MouseButton1Click:Connect(function()
		if isBypassing then return end
		isBypassing = true
		TweenService:Create(bypassBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(70, 70, 70), BackgroundTransparency = 0.2 }):Play()

		task.spawn(function()
			pcall(function()
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("BasePart") then
						local name = obj.Name:lower()
						local c = obj.Color
						local isRed = (c.R > 0.6 and c.G < 0.3 and c.B < 0.3)
						if name:find("barrier") or name:find("banned") or name:find("dome") or name:find("zone") or (isRed and obj.Transparency > 0 and obj.Transparency < 0.95) then
							obj.CanCollide = false
							obj.Transparency = 1
							obj.LocalTransparencyModifier = 1
						end
					elseif obj:IsA("Highlight") then
						obj.Enabled = false
					end
				end
			end)
		end)

		task.wait(0.3)
		TweenService:Create(bypassBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(30, 30, 30), BackgroundTransparency = 0.5 }):Play()
		task.wait(0.7)
		isBypassing = false
	end)

	-- 2. Headsit
	local _, headsitDesc, toggleHeadsitBtn, hsIndicator, hsArrowBtn = createCard("HeadsitCard", "Headsit", "Жертва: Не выбрана", true, true)
	local hsListFrame, _ = createSideFrame("PlayerListMenu", playerListWidth)
	local hsScroll = Instance.new("ScrollingFrame")
	hsScroll.Size = UDim2.new(1, -12, 1, -12)
	hsScroll.Position = UDim2.new(0, 6, 0, 6)
	hsScroll.BackgroundTransparency = 1
	hsScroll.BorderSizePixel = 0
	hsScroll.ScrollBarThickness = 3
	hsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	hsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	hsScroll.Parent = hsListFrame

	local hsLayout = Instance.new("UIListLayout")
	hsLayout.Padding = UDim.new(0, 6)
	hsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hsLayout.Parent = hsScroll

	local isPlayerListOpen = false
	local function closePlayerList()
		if not isPlayerListOpen then return end
		isPlayerListOpen = false
		TweenService:Create(hsArrowBtn, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		hsArrowBtn.Text = "<"
		TweenService:Create(hsListFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 0, menuHeight), BackgroundTransparency = 1 }):Play()
		task.wait(0.25)
		hsListFrame.Visible = false
	end
	table.insert(Client.State.CloseSidePanels, closePlayerList)

	local function stopHeadsit()
		isHeadsitActive = false
		if headsitConnection then headsitConnection:Disconnect() headsitConnection = nil end
		if jumpConnection then jumpConnection:Disconnect() jumpConnection = nil end
		if sitAnimationTrack then sitAnimationTrack:Stop() sitAnimationTrack = nil end
		setSwitchVisual(hsIndicator, false)

		pcall(function()
			local char = player.Character
			if char then
				local humanoid = Client.GetHum(char)
				if humanoid then
					humanoid.PlatformStand = false
					humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
				end
				Client.ZeroVelocities(char, false)
			end
		end)
	end

	local function startHeadsit()
		if not headsitTarget or not headsitTarget.Character then
			headsitDesc.Text = "Жертва: Не выбрана!"
			return
		end
		isHeadsitActive = true
		setSwitchVisual(hsIndicator, true)

		local char = player.Character or player.CharacterAdded:Wait()
		local humanoid = char:WaitForChild("Humanoid")
		local animator = humanoid:FindFirstChildOfClass("Animator")
		humanoid.PlatformStand = true
		humanoid:ChangeState(Enum.HumanoidStateType.Seated)

		if animator then
			pcall(function()
				local sitAnim = Instance.new("Animation")
				sitAnim.AnimationId = "rbxassetid://2506281703"
				sitAnimationTrack = animator:LoadAnimation(sitAnim)
				sitAnimationTrack:Play()
			end)
		end

		jumpConnection = humanoid.Jumping:Connect(stopHeadsit)
		headsitConnection = RunService.Heartbeat:Connect(function()
			pcall(function()
				if not isHeadsitActive or not headsitTarget or not headsitTarget.Character then
					stopHeadsit()
					return
				end
				local targetHead = headsitTarget.Character:FindFirstChild("Head")
				local myHrp = Client.GetRoot(player.Character)
				if targetHead and myHrp then
					myHrp.CFrame = targetHead.CFrame * CFrame.new(0, 0.5, 0)
					Client.ZeroVelocities(player.Character, false)
				end
			end)
		end)
	end

	toggleHeadsitBtn.MouseButton1Click:Connect(function()
		if not isHeadsitActive then startHeadsit() else stopHeadsit() end
	end)

	-- 3. Sex Aura
	local _, sexAuraDesc, toggleSexAuraBtn, saIndicator, saArrowBtn = createCard("SexAuraCard", "Sex Aura", "Жертва: Не выбрана", true, true)
	local saListFrame, _ = createSideFrame("SexAuraListMenu", playerListWidth)
	local saScroll = Instance.new("ScrollingFrame")
	saScroll.Size = UDim2.new(1, -12, 1, -12)
	saScroll.Position = UDim2.new(0, 6, 0, 6)
	saScroll.BackgroundTransparency = 1
	saScroll.BorderSizePixel = 0
	saScroll.ScrollBarThickness = 3
	saScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	saScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	saScroll.Parent = saListFrame

	local saLayout = Instance.new("UIListLayout")
	saLayout.Padding = UDim.new(0, 6)
	saLayout.SortOrder = Enum.SortOrder.LayoutOrder
	saLayout.Parent = saScroll

	local isSexAuraListOpen = false
	local function closeSexAuraList()
		if not isSexAuraListOpen then return end
		isSexAuraListOpen = false
		TweenService:Create(saArrowBtn, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		saArrowBtn.Text = "<"
		TweenService:Create(saListFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 0, menuHeight), BackgroundTransparency = 1 }):Play()
		task.wait(0.25)
		saListFrame.Visible = false
	end
	table.insert(Client.State.CloseSidePanels, closeSexAuraList)

	local function stopSexAura()
		isSexAuraActive = false
		if sexAuraConnection then sexAuraConnection:Disconnect() sexAuraConnection = nil end
		setSwitchVisual(saIndicator, false)
		pcall(function() Client.ZeroVelocities(player.Character, false) end)
	end

	local function startSexAura()
		if not sexAuraTarget or not sexAuraTarget.Character then
			sexAuraDesc.Text = "Жертва: Не выбрана!"
			return
		end
		isSexAuraActive = true
		setSwitchVisual(saIndicator, true)

		sexAuraConnection = RunService.Heartbeat:Connect(function()
			pcall(function()
				if not isSexAuraActive or not sexAuraTarget or not sexAuraTarget.Character then
					stopSexAura()
					return
				end
				local targetHrp = Client.GetRoot(sexAuraTarget.Character)
				local myHrp = Client.GetRoot(player.Character)
				if targetHrp and myHrp then
					local distance = 1.3 + math.sin(tick() * 12) * 0.9
					myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, distance)
					Client.ZeroVelocities(player.Character, false)
				end
			end)
		end)
	end

	toggleSexAuraBtn.MouseButton1Click:Connect(function()
		if not isSexAuraActive then startSexAura() else stopSexAura() end
	end)

	-- 4. Fling player
	local _, _, toggleFlingBtn, flIndicator, flArrowBtn = createCard("FlingPlayerCard", "Fling player", "Выкидывает сидящих игроков за карту", true, true)
	local fsFrame, _ = createSideFrame("FlingSettingsMenu", playerListWidth)

	local fsHeader = Instance.new("TextLabel")
	fsHeader.Size = UDim2.new(1, -16, 0, 24)
	fsHeader.Position = UDim2.new(0, 8, 0, 10)
	fsHeader.BackgroundTransparency = 1
	fsHeader.Font = Enum.Font.Ubuntu
	fsHeader.Text = "Fling Settings"
	fsHeader.TextColor3 = Color3.fromRGB(245, 245, 245)
	fsHeader.TextSize = 13
	fsHeader.TextXAlignment = Enum.TextXAlignment.Left
	fsHeader.ZIndex = 12
	fsHeader.Parent = fsFrame

	local radiusLabel = Instance.new("TextLabel")
	radiusLabel.Size = UDim2.new(1, -16, 0, 20)
	radiusLabel.Position = UDim2.new(0, 8, 0, 44)
	radiusLabel.BackgroundTransparency = 1
	radiusLabel.Font = Enum.Font.Ubuntu
	radiusLabel.Text = "Радиус: " .. tostring(radius)
	radiusLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
	radiusLabel.TextSize = 12
	radiusLabel.TextXAlignment = Enum.TextXAlignment.Left
	radiusLabel.ZIndex = 12
	radiusLabel.Parent = fsFrame

	local sliderHitbox = Instance.new("TextButton")
	sliderHitbox.Size = UDim2.new(1, -16, 0, 28)
	sliderHitbox.Position = UDim2.new(0, 8, 0, 68)
	sliderHitbox.BackgroundTransparency = 1
	sliderHitbox.Text = ""
	sliderHitbox.AutoButtonColor = false
	sliderHitbox.ZIndex = 13
	sliderHitbox.Parent = fsFrame

	local sliderTrack = Instance.new("Frame")
	sliderTrack.Size = UDim2.new(1, 0, 0, 10)
	sliderTrack.AnchorPoint = Vector2.new(0, 0.5)
	sliderTrack.Position = UDim2.new(0, 0, 0.5, 0)
	sliderTrack.BackgroundColor3 = Color3.fromRGB(50, 50, 56)
	sliderTrack.BorderSizePixel = 0
	sliderTrack.ZIndex = 13
	sliderTrack.Parent = sliderHitbox
	Instance.new("UICorner", sliderTrack).CornerRadius = UDim.new(1, 0)

	local initAlpha = math.clamp((radius - minRadius) / (maxRadius - minRadius), 0, 1)
	local sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.fromScale(initAlpha, 1)
	sliderFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sliderFill.BorderSizePixel = 0
	sliderFill.ZIndex = 14
	sliderFill.Parent = sliderTrack
	Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

	local function setRadiusFromAlpha(alpha)
		alpha = math.clamp(alpha, 0, 1)
		radius = math.floor(minRadius + (maxRadius - minRadius) * alpha + 0.5)
		sliderFill.Size = UDim2.fromScale(alpha, 1)
		radiusLabel.Text = "Радиус: " .. tostring(radius)
	end

	local draggingSlider = false
	sliderHitbox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingSlider = true
			local alpha = (input.Position.X - sliderTrack.AbsolutePosition.X) / math.max(sliderTrack.AbsoluteSize.X, 1)
			setRadiusFromAlpha(alpha)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if draggingSlider and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local alpha = (input.Position.X - sliderTrack.AbsolutePosition.X) / math.max(sliderTrack.AbsoluteSize.X, 1)
			setRadiusFromAlpha(alpha)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingSlider = false
		end
	end)

	local isFlingSettingsOpen = false
	local function closeFlingSettings()
		if not isFlingSettingsOpen then return end
		isFlingSettingsOpen = false
		draggingSlider = false
		TweenService:Create(flArrowBtn, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		flArrowBtn.Text = "<"
		TweenService:Create(fsFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 0, menuHeight), BackgroundTransparency = 1 }):Play()
		task.wait(0.25)
		fsFrame.Visible = false
	end
	table.insert(Client.State.CloseSidePanels, closeFlingSettings)

	toggleFlingBtn.MouseButton1Click:Connect(function()
		flingEnabled = not flingEnabled
		if flingEnabled then currentRingColor = whiteColor else setHoopVisible(false) end
		setSwitchVisual(flIndicator, flingEnabled)
	end)

	RunService.RenderStepped:Connect(function(dt)
		pcall(function()
			local hasInside, seatedTarget = checkHoopTargets()
			updateHoopVisual(dt, hasInside)
			if flingEnabled and hasInside and seatedTarget and not isBusyFlinging then
				task.spawn(function() pcall(function() flingTargetOutOfBounds(seatedTarget) end) end)
			end
		end)
	end)

	-- 5. Anti-Sit
	local _, _, toggleAntiSitBtn, asIndicator, _ = createCard("AntiSitCard", "Anti-Sit", "Запрещает садиться на сиденья и в авто", true, false)
	setAntiSitState(false)
	toggleAntiSitBtn.MouseButton1Click:Connect(function()
		local nextState = not isAntiSitActive
		setAntiSitState(nextState)
		setSwitchVisual(asIndicator, nextState)
	end)

	-- 6. Anti-Fling
	local _, _, toggleAntiFlingBtn, afIndicator, afArrowBtn = createCard("AntiFlingCard", "Anti-Fling", "Возврат на точку при флинге", true, true)
	local afPanelFrame, _ = createSideFrame("AntiFlingPanelMenu", antiFlingPanelWidth)

	local afpHeader = Instance.new("TextLabel")
	afpHeader.Size = UDim2.new(1, -16, 0, 22)
	afpHeader.Position = UDim2.new(0, 8, 0, 8)
	afpHeader.BackgroundTransparency = 1
	afpHeader.Font = Enum.Font.Ubuntu
	afpHeader.Text = "Anti-Fling • 5 точек"
	afpHeader.TextColor3 = Color3.fromRGB(245, 245, 245)
	afpHeader.TextSize = 13
	afpHeader.TextXAlignment = Enum.TextXAlignment.Left
	afpHeader.ZIndex = 12
	afpHeader.Parent = afPanelFrame

	local slotsRow = Instance.new("Frame")
	slotsRow.Size = UDim2.new(1, -16, 0, 28)
	slotsRow.Position = UDim2.new(0, 8, 0, 34)
	slotsRow.BackgroundTransparency = 1
	slotsRow.ZIndex = 12
	slotsRow.Parent = afPanelFrame

	local slotButtons = {}
	for i = 1, MAX_SLOTS do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.18, 0, 1, 0)
		b.Position = UDim2.new((i - 1) * 0.205, 0, 0, 0)
		b.Text = tostring(i)
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.TextSize = 12
		b.Font = Enum.Font.Ubuntu
		b.ZIndex = 13
		b.Parent = slotsRow
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
		slotButtons[i] = b
	end

	local saveSlotBtn = Instance.new("TextButton")
	saveSlotBtn.Size = UDim2.new(0.47, 0, 0, 30)
	saveSlotBtn.Position = UDim2.new(0, 8, 0, 70)
	saveSlotBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
	saveSlotBtn.Text = "Записать"
	saveSlotBtn.TextColor3 = Color3.fromRGB(245, 245, 245)
	saveSlotBtn.TextSize = 11
	saveSlotBtn.Font = Enum.Font.Ubuntu
	saveSlotBtn.ZIndex = 13
	saveSlotBtn.Parent = afPanelFrame
	Instance.new("UICorner", saveSlotBtn).CornerRadius = UDim.new(0, 8)

	local tpSlotBtn = Instance.new("TextButton")
	tpSlotBtn.Size = UDim2.new(0.47, 0, 0, 30)
	tpSlotBtn.Position = UDim2.new(0.51, 0, 0, 70)
	tpSlotBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
	tpSlotBtn.Text = "ТП в слот"
	tpSlotBtn.TextColor3 = Color3.fromRGB(245, 245, 245)
	tpSlotBtn.TextSize = 11
	tpSlotBtn.Font = Enum.Font.Ubuntu
	tpSlotBtn.ZIndex = 13
	tpSlotBtn.Parent = afPanelFrame
	Instance.new("UICorner", tpSlotBtn).CornerRadius = UDim.new(0, 8)

	local activePointLabel = Instance.new("TextLabel")
	activePointLabel.Size = UDim2.new(1, -16, 0, 34)
	activePointLabel.Position = UDim2.new(0, 8, 0, 108)
	activePointLabel.BackgroundTransparency = 1
	activePointLabel.Font = Enum.Font.Ubuntu
	activePointLabel.Text = "Точка #1: пусто"
	activePointLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
	activePointLabel.TextSize = 11
	activePointLabel.TextWrapped = true
	activePointLabel.TextXAlignment = Enum.TextXAlignment.Left
	activePointLabel.TextYAlignment = Enum.TextYAlignment.Top
	activePointLabel.ZIndex = 12
	activePointLabel.Parent = afPanelFrame

	local afStatusLabel = Instance.new("TextLabel")
	afStatusLabel.Size = UDim2.new(1, -16, 0, 40)
	afStatusLabel.Position = UDim2.new(0, 8, 0, 146)
	afStatusLabel.BackgroundTransparency = 1
	afStatusLabel.Font = Enum.Font.Ubuntu
	afStatusLabel.Text = "Статус: ВЫКЛ"
	afStatusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
	afStatusLabel.TextSize = 11
	afStatusLabel.TextWrapped = true
	afStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
	afStatusLabel.TextYAlignment = Enum.TextYAlignment.Top
	afStatusLabel.ZIndex = 12
	afStatusLabel.Parent = afPanelFrame

	local promptOverlay = Instance.new("Frame")
	promptOverlay.Name = "AntiFlingPrompt"
	promptOverlay.Size = UDim2.new(0, 270, 0, 145)
	promptOverlay.AnchorPoint = Vector2.new(0.5, 0.5)
	promptOverlay.Position = UDim2.new(0.5, 0, 0.5, 0)
	promptOverlay.BackgroundColor3 = Color3.fromRGB(22, 22, 25)
	promptOverlay.BackgroundTransparency = 0.1
	promptOverlay.BorderSizePixel = 0
	promptOverlay.Visible = false
	promptOverlay.ZIndex = 30
	promptOverlay.Parent = mainGui
	Instance.new("UICorner", promptOverlay).CornerRadius = UDim.new(0, 14)

	local promptStroke = Instance.new("UIStroke", promptOverlay)
	promptStroke.Color = Color3.fromRGB(255, 255, 255)
	promptStroke.Transparency = 0.5
	promptStroke.Thickness = 1.5

	local promptText = Instance.new("TextLabel")
	promptText.Size = UDim2.new(1, -20, 0, 68)
	promptText.Position = UDim2.new(0, 10, 0, 10)
	promptText.BackgroundTransparency = 1
	promptText.Text = "Встань на карте и сохрани 1-ю точку возврата (позже можно добавить ещё до 4 точек):"
	promptText.TextColor3 = Color3.fromRGB(240, 245, 255)
	promptText.TextSize = 12
	promptText.Font = Enum.Font.Ubuntu
	promptText.TextWrapped = true
	promptText.ZIndex = 31
	promptText.Parent = promptOverlay

	local confirmHomeBtn = Instance.new("TextButton")
	confirmHomeBtn.Size = UDim2.new(0.56, 0, 0, 38)
	confirmHomeBtn.Position = UDim2.new(0, 10, 1, -48)
	confirmHomeBtn.BackgroundColor3 = Color3.fromRGB(45, 130, 75)
	confirmHomeBtn.Text = "Сохранить #1"
	confirmHomeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmHomeBtn.TextSize = 12
	confirmHomeBtn.Font = Enum.Font.Ubuntu
	confirmHomeBtn.ZIndex = 31
	confirmHomeBtn.Parent = promptOverlay
	Instance.new("UICorner", confirmHomeBtn).CornerRadius = UDim.new(0, 8)

	local cancelPromptBtn = Instance.new("TextButton")
	cancelPromptBtn.Size = UDim2.new(0.34, 0, 0, 38)
	cancelPromptBtn.Position = UDim2.new(0.66, -10, 1, -48)
	cancelPromptBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 62)
	cancelPromptBtn.Text = "Отмена"
	cancelPromptBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
	cancelPromptBtn.TextSize = 12
	cancelPromptBtn.Font = Enum.Font.Ubuntu
	cancelPromptBtn.ZIndex = 31
	cancelPromptBtn.Parent = promptOverlay
	Instance.new("UICorner", cancelPromptBtn).CornerRadius = UDim.new(0, 8)

	local function refreshAntiFlingUI()
		for i = 1, MAX_SLOTS do
			local btn = slotButtons[i]
			if i == activeSlot then
				btn.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
				btn.TextColor3 = Color3.fromRGB(15, 15, 15)
			elseif savedPoints[i] then
				btn.BackgroundColor3 = Color3.fromRGB(55, 95, 70)
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				btn.BackgroundColor3 = Color3.fromRGB(42, 42, 48)
				btn.TextColor3 = Color3.fromRGB(200, 200, 200)
			end
		end

		local cf = savedPoints[activeSlot]
		if cf then
			local p = cf.Position
			activePointLabel.Text = string.format("Точка #%d: %.0f, %.0f, %.0f", activeSlot, p.X, p.Y, p.Z)
		else
			activePointLabel.Text = "Точка #" .. activeSlot .. ": не задана"
		end

		setSwitchVisual(afIndicator, antiFlingEnabled)
		if antiFlingEnabled then
			afStatusLabel.Text = "Статус: ВКЛ (слот #" .. activeSlot .. ")"
		elseif not afStatusLabel.Text:find("Ошибка") and not afStatusLabel.Text:find("границ") then
			afStatusLabel.Text = "Статус: ВЫКЛ"
		end
	end

	for i = 1, MAX_SLOTS do
		slotButtons[i].MouseButton1Click:Connect(function()
			activeSlot = i
			afStatusLabel.Text = "Выбран слот #" .. i
			refreshAntiFlingUI()
		end)
	end

	saveSlotBtn.MouseButton1Click:Connect(function()
		local hrp = Client.GetRoot(player.Character)
		if not hrp then afStatusLabel.Text = "Ошибка: нет персонажа" return end
		if not isInsideMap(hrp.Position) then afStatusLabel.Text = "Встань внутрь границ карты!" return end
		savedPoints[activeSlot] = hrp.CFrame
		afStatusLabel.Text = "Точка #" .. activeSlot .. " сохранена!"
		refreshAntiFlingUI()
	end)

	tpSlotBtn.MouseButton1Click:Connect(function()
		local cf = savedPoints[activeSlot]
		if not cf then afStatusLabel.Text = "Слот #" .. activeSlot .. " пуст!" return end
		local char = player.Character
		local hrp = Client.GetRoot(char)
		local humanoid = Client.GetHum(char)
		if hrp and humanoid then
			task.spawn(function() teleportToTarget(char, hrp, humanoid, cf) end)
			afStatusLabel.Text = "Телепорт в точку #" .. activeSlot
		end
	end)

	toggleAntiFlingBtn.MouseButton1Click:Connect(function()
		if antiFlingEnabled then
			antiFlingEnabled = false
			afStatusLabel.Text = "Статус: ВЫКЛ"
			refreshAntiFlingUI()
			return
		end
		if not hasAnyPoint() then
			if waitingForFirstHome then return end
			waitingForFirstHome = true
			promptOverlay.Visible = true
			afStatusLabel.Text = "Сохрани 1-ю точку"
			return
		end
		local hrp = Client.GetRoot(player.Character)
		lastPos = hrp and hrp.Position or nil
		antiFlingEnabled = true
		afStatusLabel.Text = "Статус: ВКЛ (слот #" .. activeSlot .. ")"
		refreshAntiFlingUI()
	end)

	confirmHomeBtn.MouseButton1Click:Connect(function()
		local hrp = Client.GetRoot(player.Character)
		if not hrp then promptText.Text = "Ошибка: персонаж не найден. Попробуй снова:" return end
		if not isInsideMap(hrp.Position) then promptText.Text = "Ты вне границ карты! Встань внутри карты и нажми Сохранить #1:" return end
		savedPoints[1] = hrp.CFrame
		activeSlot = 1
		lastPos = hrp.Position
		waitingForFirstHome = false
		promptOverlay.Visible = false
		antiFlingEnabled = true
		promptText.Text = "Встань на карте и сохрани 1-ю точку возврата (позже можно добавить ещё до 4 точек):"
		afStatusLabel.Text = "Точка #1 сохранена • ВКЛ"
		refreshAntiFlingUI()
	end)

	cancelPromptBtn.MouseButton1Click:Connect(function()
		waitingForFirstHome = false
		promptOverlay.Visible = false
		afStatusLabel.Text = "Отменено"
		refreshAntiFlingUI()
	end)

	local isAntiFlingPanelOpen = false
	local function closeAntiFlingPanel()
		if not isAntiFlingPanelOpen then return end
		isAntiFlingPanelOpen = false
		TweenService:Create(afArrowBtn, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		afArrowBtn.Text = "<"
		TweenService:Create(afPanelFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 0, menuHeight), BackgroundTransparency = 1 }):Play()
		task.wait(0.25)
		afPanelFrame.Visible = false
	end
	table.insert(Client.State.CloseSidePanels, closeAntiFlingPanel)

	local function populatePlayers(scrollFrame, onSelect)
		for _, child in ipairs(scrollFrame:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				local pBtn = Instance.new("TextButton")
				pBtn.Size = UDim2.new(1, 0, 0, 32)
				pBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
				pBtn.BackgroundTransparency = 0.5
				pBtn.Text = "  " .. p.Name
				pBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
				pBtn.Font = Enum.Font.Ubuntu
				pBtn.TextSize = 12
				pBtn.TextXAlignment = Enum.TextXAlignment.Left
				pBtn.ZIndex = 12
				pBtn.Parent = scrollFrame
				Instance.new("UICorner", pBtn).CornerRadius = UDim.new(0, 6)
				pBtn.MouseButton1Click:Connect(function() onSelect(p) end)
			end
		end
	end

	local function openSidePanel(frame, arrowBtn, width, flagSetter, onOpen)
		Client.CloseAllSidePanels()
		if onOpen then onOpen() end
		flagSetter(true)
		frame.Visible = true
		frame.Size = UDim2.new(0, 0, 0, menuHeight)
		frame.BackgroundTransparency = 1
		TweenService:Create(arrowBtn, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = 180 }):Play()
		arrowBtn.Text = ">"
		TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, width, 0, menuHeight),
			BackgroundTransparency = 0.35
		}):Play()
	end

	hsArrowBtn.MouseButton1Click:Connect(function()
		if isPlayerListOpen then
			closePlayerList()
		else
			openSidePanel(hsListFrame, hsArrowBtn, playerListWidth, function(v) isPlayerListOpen = v end, function()
				populatePlayers(hsScroll, function(p)
					headsitTarget = p
					headsitDesc.Text = "Жертва: " .. p.Name
					closePlayerList()
				end)
			end)
		end
	end)

	saArrowBtn.MouseButton1Click:Connect(function()
		if isSexAuraListOpen then
			closeSexAuraList()
		else
			openSidePanel(saListFrame, saArrowBtn, playerListWidth, function(v) isSexAuraListOpen = v end, function()
				populatePlayers(saScroll, function(p)
					sexAuraTarget = p
					sexAuraDesc.Text = "Жертва: " .. p.Name
					closeSexAuraList()
				end)
			end)
		end
	end)

	flArrowBtn.MouseButton1Click:Connect(function()
		if isFlingSettingsOpen then
			closeFlingSettings()
		else
			openSidePanel(fsFrame, flArrowBtn, playerListWidth, function(v) isFlingSettingsOpen = v end)
		end
	end)

	afArrowBtn.MouseButton1Click:Connect(function()
		if isAntiFlingPanelOpen then
			closeAntiFlingPanel()
		else
			openSidePanel(afPanelFrame, afArrowBtn, antiFlingPanelWidth, function(v) isAntiFlingPanelOpen = v end, refreshAntiFlingUI)
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		if not antiFlingEnabled or isRecovering then return end
		elapsed += dt
		if elapsed < TICK_INTERVAL then return end
		elapsed = 0

		local targetCF = getTargetHomeCFrame()
		if not targetCF then return end

		local char = player.Character
		local humanoid = Client.GetHum(char)
		local hrp = Client.GetRoot(char)
		if not hrp or not humanoid or humanoid.Health <= 0 then return end

		local pos = hrp.Position
		local vel = hrp.AssemblyLinearVelocity
		local horizSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local stepJump = lastPos and (pos - lastPos).Magnitude or 0
		lastPos = pos

		local outOfBounds = not isInsideMap(pos)
		local flungHoriz = horizSpeed > MAX_HORIZ_FLING_SPEED
		local flungUp = vel.Y > MAX_UPWARD_FLING_SPEED
		local suddenJump = stepJump > MAX_STEP_JUMP and horizSpeed > 90

		if outOfBounds or flungHoriz or flungUp or suddenJump then
			task.spawn(function() teleportToTarget(char, hrp, humanoid, targetCF) end)
		end
	end)

	refreshAntiFlingUI()
end

Client.State.OnReady = Client.State.OnReady or {}
table.insert(Client.State.OnReady, initTrolling)
