local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Client = _G.Dar4xClient
if not Client then return end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = workspace.CurrentCamera
end)

local Config = {
	-- 1/4: Основное кольцо при смерти
	Segments = 64,
	StartRadius = 1.5,
	MaxRadius = 65,
	Duration = 1.45,
	LineThickness = 0.25,
	LineHeight = 0.15,
	Color = Color3.fromRGB(255, 255, 255),
	InitialTransparency = 0.05,

	-- 2/4: Второе внутреннее кольцо (двойной контур)
	SecondRingDelay = 0.18,
	SecondRingMaxRadius = 46,
	SecondRingDuration = 1.35,
	SecondRingThickness = 0.16,
	SecondRingTransparency = 0.25,

	-- 3/4: Плавный «выдох» камеры (FOV)
	EnableCameraBreath = true,
	FovDelta = 7,
	FovOutTime = 0.35,
	FovBackTime = 0.95,

	-- 4/4: Мягкое появление нового персонажа с лёгким свечением
	EnableSpawnGlow = true,
	SpawnFadeDuration = 0.85,
	SpawnStartModifier = 0.65,
	GlowDuration = 1.15,
	GlowFillStart = 0.72,
	GlowOutlineStart = 0.25
}

local function initVisual()
	local pageFrame = Client.State.Pages and Client.State.Pages["Visual"]
	if not pageFrame then return end

	local dieVisualEnabled = false
	local sessionToken = 0

	local activeFolders = {}
	local activeRingConns = {}
	local activeRingTweens = {}
	local activeSpawnConns = {}
	local activeSpawnTweens = {}
	local characterHookConn = nil

	local activeFovOutTween = nil
	local activeFovBackTween = nil
	local savedBaseFov = nil

	local function trackFolder(folder)
		table.insert(activeFolders, folder)
	end

	local function untrackFolder(folder)
		local idx = table.find(activeFolders, folder)
		if idx then table.remove(activeFolders, idx) end
	end

	local function resetCharacterVisuals(char)
		if not char then return end
		local glow = char:FindFirstChild("Dar3x_SpawnGlow")
		if glow then glow:Destroy() end

		for _, desc in ipairs(char:GetDescendants()) do
			if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" then
				desc.LocalTransparencyModifier = 0
			end
		end
	end

	local function cleanupAllVisualEffects()
		sessionToken += 1

		for _, conn in ipairs(activeRingConns) do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(activeRingConns)

		for _, tw in ipairs(activeRingTweens) do
			pcall(function() tw:Cancel() end)
		end
		table.clear(activeRingTweens)

		for _, conn in ipairs(activeSpawnConns) do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(activeSpawnConns)

		for _, tw in ipairs(activeSpawnTweens) do
			pcall(function() tw:Cancel() end)
		end
		table.clear(activeSpawnTweens)

		for _, folder in ipairs(activeFolders) do
			if folder and folder.Parent then
				folder:Destroy()
			end
		end
		table.clear(activeFolders)

		for _, name in ipairs({ "Dar3x_DeathRing_Main", "Dar3x_DeathRing_Inner" }) do
			local old = workspace:FindFirstChild(name)
			if old then old:Destroy() end
		end

		if activeFovOutTween then
			pcall(function() activeFovOutTween:Cancel() end)
			activeFovOutTween = nil
		end
		if activeFovBackTween then
			pcall(function() activeFovBackTween:Cancel() end)
			activeFovBackTween = nil
		end
		if savedBaseFov and camera then
			camera.FieldOfView = savedBaseFov
			savedBaseFov = nil
		end

		if player.Character then
			resetCharacterVisuals(player.Character)
		end
	end

	local function spawnRing(
		originPos,
		fromRadius,
		toRadius,
		duration,
		thickness,
		startTransparency,
		fadeStartAlpha,
		easingStyle,
		easingDirection,
		namePrefix,
		token
	)
		if not dieVisualEnabled or token ~= sessionToken then return end

		local folder = Instance.new("Folder")
		folder.Name = namePrefix
		folder.Parent = workspace
		trackFolder(folder)

		local segments = {}
		local stepAngle = (math.pi * 2) / Config.Segments

		for i = 1, Config.Segments do
			local part = Instance.new("Part")
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
			part.Material = Enum.Material.Neon
			part.Color = Config.Color
			part.Transparency = startTransparency
			part.Parent = folder

			segments[i] = {
				part = part,
				angle = stepAngle * i
			}
		end

		local function updateRing(radius, transparency)
			local segLength = (2 * math.pi * math.max(radius, 0.5) / Config.Segments) * 1.08

			for _, item in ipairs(segments) do
				if item.part and item.part.Parent then
					local angle = item.angle
					local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
					local pos = originPos + offset

					item.part.Size = Vector3.new(thickness, Config.LineHeight, segLength)
					item.part.CFrame = CFrame.lookAt(pos, originPos) * CFrame.Angles(0, math.rad(90), 0)
					item.part.Transparency = transparency
				end
			end
		end

		local progress = Instance.new("NumberValue")
		progress.Value = 0

		local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection)
		local conn
		local tween

		local function finishRing()
			if conn then
				conn:Disconnect()
				local cIdx = table.find(activeRingConns, conn)
				if cIdx then table.remove(activeRingConns, cIdx) end
			end
			if tween then
				local tIdx = table.find(activeRingTweens, tween)
				if tIdx then table.remove(activeRingTweens, tIdx) end
			end
			if progress and progress.Parent then
				progress:Destroy()
			end
			untrackFolder(folder)
			if folder and folder.Parent then
				folder:Destroy()
			end
		end

		conn = RunService.RenderStepped:Connect(function()
			if not dieVisualEnabled or token ~= sessionToken then
				finishRing()
				return
			end

			local alpha = progress.Value
			local currentRadius = fromRadius + (toRadius - fromRadius) * alpha

			local denom = math.max(1 - fadeStartAlpha, 0.01)
			local fadeAlpha = math.clamp((alpha - fadeStartAlpha) / denom, 0, 1)
			local currentTrans = startTransparency + (1 - startTransparency) * fadeAlpha

			updateRing(currentRadius, currentTrans)
		end)
		table.insert(activeRingConns, conn)

		tween = TweenService:Create(progress, tweenInfo, { Value = 1 })
		table.insert(activeRingTweens, tween)
		tween:Play()

		tween.Completed:Connect(function()
			finishRing()
		end)
	end

	local function playCameraBreath(token)
		if not dieVisualEnabled or token ~= sessionToken then return end
		if not Config.EnableCameraBreath or not camera then return end

		if activeFovOutTween then activeFovOutTween:Cancel() end
		if activeFovBackTween then activeFovBackTween:Cancel() end

		local baseFov = savedBaseFov or camera.FieldOfView
		savedBaseFov = baseFov
		local targetFov = math.clamp(baseFov + Config.FovDelta, 35, 110)

		local outInfo = TweenInfo.new(Config.FovOutTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		local backInfo = TweenInfo.new(Config.FovBackTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

		activeFovOutTween = TweenService:Create(camera, outInfo, { FieldOfView = targetFov })
		activeFovBackTween = TweenService:Create(camera, backInfo, { FieldOfView = baseFov })

		activeFovOutTween.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed and dieVisualEnabled and token == sessionToken and camera then
				activeFovBackTween:Play()
			elseif camera then
				camera.FieldOfView = savedBaseFov or camera.FieldOfView
				savedBaseFov = nil
			end
		end)

		activeFovBackTween.Completed:Connect(function()
			savedBaseFov = nil
		end)

		activeFovOutTween:Play()
	end

	local function playSoftSpawnEffect(character, token)
		if not dieVisualEnabled or token ~= sessionToken then return end
		if not Config.EnableSpawnGlow then return end

		character:WaitForChild("HumanoidRootPart", 10)
		if not dieVisualEnabled or token ~= sessionToken or character ~= player.Character then return end

		local oldGlow = character:FindFirstChild("Dar3x_SpawnGlow")
		if oldGlow then oldGlow:Destroy() end

		local highlight = Instance.new("Highlight")
		highlight.Name = "Dar3x_SpawnGlow"
		highlight.Adornee = character
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.FillColor = Config.Color
		highlight.OutlineColor = Config.Color
		highlight.FillTransparency = Config.GlowFillStart
		highlight.OutlineTransparency = Config.GlowOutlineStart
		highlight.Parent = character

		local glowTween = TweenService:Create(
			highlight,
			TweenInfo.new(Config.GlowDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{
				FillTransparency = 1,
				OutlineTransparency = 1
			}
		)
		table.insert(activeSpawnTweens, glowTween)
		glowTween:Play()
		glowTween.Completed:Connect(function()
			local gIdx = table.find(activeSpawnTweens, glowTween)
			if gIdx then table.remove(activeSpawnTweens, gIdx) end
			if highlight and highlight.Parent then
				highlight:Destroy()
			end
		end)

		local trackedParts = {}
		local function registerPart(obj)
			if not dieVisualEnabled or token ~= sessionToken then return end
			if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
				obj.LocalTransparencyModifier = Config.SpawnStartModifier
				table.insert(trackedParts, obj)
			end
		end

		for _, desc in ipairs(character:GetDescendants()) do
			registerPart(desc)
		end

		local descConn = character.DescendantAdded:Connect(registerPart)
		table.insert(activeSpawnConns, descConn)

		local elapsed = 0
		local fadeConn

		local function stopSpawnFade(restoreFull)
			if fadeConn then
				fadeConn:Disconnect()
				local fIdx = table.find(activeSpawnConns, fadeConn)
				if fIdx then table.remove(activeSpawnConns, fIdx) end
			end
			if descConn then
				descConn:Disconnect()
				local dIdx = table.find(activeSpawnConns, descConn)
				if dIdx then table.remove(activeSpawnConns, dIdx) end
			end
			if restoreFull then
				for _, part in ipairs(trackedParts) do
					if part and part.Parent then
						part.LocalTransparencyModifier = 0
					end
				end
			end
		end

		fadeConn = RunService.RenderStepped:Connect(function(dt)
			if not dieVisualEnabled or token ~= sessionToken or character ~= player.Character then
				stopSpawnFade(true)
				return
			end

			elapsed += dt
			local alpha = math.clamp(elapsed / Config.SpawnFadeDuration, 0, 1)
			local eased = 1 - ((1 - alpha) ^ 2)
			local modifier = Config.SpawnStartModifier * (1 - eased)

			for i = #trackedParts, 1, -1 do
				local part = trackedParts[i]
				if part and part.Parent then
					part.LocalTransparencyModifier = modifier
				else
					table.remove(trackedParts, i)
				end
			end

			if alpha >= 1 then
				stopSpawnFade(true)
			end
		end)
		table.insert(activeSpawnConns, fadeConn)
	end

	local function onPlayerDied(deathPos, token)
		if not dieVisualEnabled or token ~= sessionToken then return end

		spawnRing(
			deathPos,
			Config.StartRadius,
			Config.MaxRadius,
			Config.Duration,
			Config.LineThickness,
			Config.InitialTransparency,
			0.15,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out,
			"Dar3x_DeathRing_Main",
			token
		)

		task.delay(Config.SecondRingDelay, function()
			if not dieVisualEnabled or token ~= sessionToken then return end
			spawnRing(
				deathPos,
				Config.StartRadius,
				Config.SecondRingMaxRadius,
				Config.SecondRingDuration,
				Config.SecondRingThickness,
				Config.SecondRingTransparency,
				0.1,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.Out,
				"Dar3x_DeathRing_Inner",
				token
			)
		end)

		playCameraBreath(token)
	end

	local function hookCharacter(character)
		if not dieVisualEnabled then return end
		local currentToken = sessionToken

		task.spawn(playSoftSpawnEffect, character, currentToken)

		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not dieVisualEnabled or currentToken ~= sessionToken then return end

		humanoid.Died:Connect(function()
			if not dieVisualEnabled or currentToken ~= sessionToken then return end
			local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChildWhichIsA("BasePart")
			if root then
				local pos = root.Position - Vector3.new(0, 2.5, 0)
				onPlayerDied(pos, currentToken)
			end
		end)
	end

	-- UI карточки Die Visual в разделе Visual
	local visualList = Instance.new("ScrollingFrame")
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

	local card = Instance.new("Frame")
	card.Name = "DieVisualCard"
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
	title.Size = UDim2.new(1, -70, 0, 20)
	title.Position = UDim2.new(0, 10, 0, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Ubuntu
	title.Text = "Die Visual"
	title.TextColor3 = Color3.fromRGB(240, 240, 240)
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 5
	title.Parent = card

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -70, 0, 18)
	desc.Position = UDim2.new(0, 10, 0, 26)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.Ubuntu
	desc.Text = "Эффект колец, камеры и свечения при смерти"
	desc.TextColor3 = Color3.fromRGB(150, 150, 150)
	desc.TextSize = 11
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.ZIndex = 5
	desc.Parent = card

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.new(0, 36, 0, 24)
	toggleBtn.Position = UDim2.new(1, -46, 0.5, -12)
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

	local function setSwitchVisual(active)
		TweenService:Create(indicator, TweenInfo.new(0.2), {
			Position = active and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
			BackgroundColor3 = active and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(180, 180, 180)
		}):Play()
	end

	local function setDieVisualState(enable)
		if dieVisualEnabled == enable then return end
		dieVisualEnabled = enable
		setSwitchVisual(enable)

		if enable then
			sessionToken += 1
			if not characterHookConn then
				characterHookConn = player.CharacterAdded:Connect(function(newChar)
					if dieVisualEnabled then
						task.spawn(hookCharacter, newChar)
					end
				end)
			end
			if player.Character then
				task.spawn(hookCharacter, player.Character)
			end
		else
			cleanupAllVisualEffects()
		end
	end

	setSwitchVisual(false)

	toggleBtn.MouseButton1Click:Connect(function()
		setDieVisualState(not dieVisualEnabled)
	end)
end

Client.State.OnReady = Client.State.OnReady or {}
table.insert(Client.State.OnReady, initVisual)
