local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Client = _G.Dar4xClient
if not Client then return end

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = workspace.CurrentCamera
end)

local CONFIG = {
	DomeCenter = Vector3.new(129.1, 5.0, -207.0),
	DomeRadius = 4200,

	CloudImageID = "rbxassetid://93857925152835",
	SoundID = "rbxassetid://1516791621",
	SoundVolume = 0.65,

	WetGroundEnabled = true,
	PlayerReflectionEnabled = true,

	-- Белый туман
	FogEnabled = true,
	FogColor = Color3.fromRGB(235, 240, 245),
	FogRadius = 260,
	MinFogRadius = 40,
	MaxFogRadius = 900,

	-- Дождь
	DropsPerFrame = 3,
	MaxActiveDrops = 55,
	SpawnRadius = 55,
	SpawnHeight = 38,
	DropSpeed = 95,
	WindAngle = Vector3.new(4.5, 0, 2),

	-- Обручи
	HoopDuration = 0.45,
	HoopSpawnInterval = 0.22,
	HoopSegments = 8
}

local OriginalAtmosphere = {
	FogStart = Lighting.FogStart,
	FogEnd = Lighting.FogEnd,
	FogColor = Lighting.FogColor,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	Brightness = Lighting.Brightness,
	EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
}

local function initRainAtmosphere()
	local cfg = Client.Config
	local mainGui = Client.State.MainGui
	local pageFrame = Client.State.Pages and Client.State.Pages["Visual"]
	if not mainGui or not pageFrame then return end

	local menuHeight = cfg.MenuHeight
	local menuWidth = cfg.MenuWidth
	local gapBetween = cfg.GapBetween
	local panelWidth = cfg.PlayerListWidth

	local rainActive = false
	local sessionToken = 0
	local visualFolder = nil
	local reflectionFolder = nil
	local reflectionParts = {}
	local hoopPool = {}
	local activeHoops = 0
	local maxHoops = 14
	local dropPool = {}
	local activeDrops = 0
	local modifiedGroundParts = {}
	local activeTweens = {}
	local charAddedConn = nil
	local renderConn = nil
	local loopThread = nil

	local function trackTween(tw)
		table.insert(activeTweens, tw)
		tw.Completed:Connect(function()
			local idx = table.find(activeTweens, tw)
			if idx then table.remove(activeTweens, idx) end
		end)
		return tw
	end

	local function updateFog()
		if rainActive and CONFIG.FogEnabled then
			Lighting.FogColor = CONFIG.FogColor
			Lighting.FogEnd = CONFIG.FogRadius
			Lighting.FogStart = math.max(8, CONFIG.FogRadius * 0.25)
		else
			Lighting.FogColor = OriginalAtmosphere.FogColor
			Lighting.FogStart = OriginalAtmosphere.FogStart
			Lighting.FogEnd = OriginalAtmosphere.FogEnd
		end
	end

	local function restoreLightingAndGround()
		Lighting.FogColor = OriginalAtmosphere.FogColor
		Lighting.FogStart = OriginalAtmosphere.FogStart
		Lighting.FogEnd = OriginalAtmosphere.FogEnd
		Lighting.Ambient = OriginalAtmosphere.Ambient
		Lighting.OutdoorAmbient = OriginalAtmosphere.OutdoorAmbient
		Lighting.Brightness = OriginalAtmosphere.Brightness
		Lighting.EnvironmentSpecularScale = OriginalAtmosphere.EnvironmentSpecularScale

		for part, origRef in pairs(modifiedGroundParts) do
			if part and part.Parent then
				pcall(function()
					part.Reflectance = origRef
					part:SetAttribute("OrigReflectance", nil)
				end)
			end
		end
		table.clear(modifiedGroundParts)
	end

	local function cleanupRainWorld()
		sessionToken += 1
		if renderConn then
			renderConn:Disconnect()
			renderConn = nil
		end
		if charAddedConn then
			charAddedConn:Disconnect()
			charAddedConn = nil
		end
		for _, tw in ipairs(activeTweens) do
			pcall(function() tw:Cancel() end)
		end
		table.clear(activeTweens)

		local oldSound = workspace:FindFirstChild("VisualRainSound")
		if oldSound then oldSound:Destroy() end

		local oldContainer = workspace:FindFirstChild("RainVisualContainer")
		if oldContainer then oldContainer:Destroy() end

		visualFolder = nil
		reflectionFolder = nil
		table.clear(reflectionParts)
		table.clear(hoopPool)
		table.clear(dropPool)
		activeHoops = 0
		activeDrops = 0

		restoreLightingAndGround()
	end

	local function createSmoothCloudDome()
		local dome = Instance.new("Part")
		dome.Name = "SmoothRainCloudDome"
		dome.Anchored = true
		dome.CanCollide = false
		dome.CanQuery = false
		dome.CanTouch = false
		dome.CastShadow = false
		dome.Material = Enum.Material.SmoothPlastic
		dome.Color = Color3.fromRGB(165, 175, 185)
		dome.Transparency = 0
		dome.Size = Vector3.new(1, 1, 1)
		dome.Position = CONFIG.DomeCenter
		dome.Parent = visualFolder

		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		local diameter = CONFIG.DomeRadius * 2
		mesh.Scale = Vector3.new(-diameter, -diameter, -diameter)
		mesh.TextureId = CONFIG.CloudImageID
		mesh.VertexColor = Vector3.new(0.85, 0.88, 0.92)
		mesh.Parent = dome

		local faces = {
			Enum.NormalId.Top,
			Enum.NormalId.Front,
			Enum.NormalId.Back,
			Enum.NormalId.Left,
			Enum.NormalId.Right
		}
		for _, face in ipairs(faces) do
			local decal = Instance.new("Decal")
			decal.Face = face
			decal.Texture = CONFIG.CloudImageID
			decal.Color3 = Color3.fromRGB(210, 218, 228)
			decal.Parent = dome
		end

		Lighting.Ambient = Color3.fromRGB(135, 142, 152)
		Lighting.OutdoorAmbient = Color3.fromRGB(140, 148, 158)
		Lighting.Brightness = 1.4
		Lighting.EnvironmentSpecularScale = 1.0
	end

	local function rebuildReflectionRig(char)
		if not reflectionFolder or not reflectionFolder.Parent then return end
		reflectionFolder:ClearAllChildren()
		table.clear(reflectionParts)
		if not char then return end

		for _, obj in ipairs(char:GetDescendants()) do
			if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
				local refPart = Instance.new("Part")
				refPart.Name = "Ref_" .. obj.Name
				refPart.Anchored = true
				refPart.CanCollide = false
				refPart.CanQuery = false
				refPart.CanTouch = false
				refPart.CastShadow = false
				refPart.Material = Enum.Material.SmoothPlastic
				refPart.Color = Color3.fromRGB(165, 190, 220)
				refPart.Transparency = 1
				refPart.Size = obj.Size
				refPart.Parent = reflectionFolder

				table.insert(reflectionParts, {
					Source = obj,
					Ref = refPart
				})
			end
		end
	end

	local function setupSound()
		local old = workspace:FindFirstChild("VisualRainSound")
		if old then old:Destroy() end

		local sound = Instance.new("Sound")
		sound.Name = "VisualRainSound"
		sound.SoundId = CONFIG.SoundID
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = workspace
		sound:Play()

		trackTween(TweenService:Create(sound, TweenInfo.new(2, Enum.EasingStyle.Sine), {
			Volume = CONFIG.SoundVolume
		})):Play()
	end

	local function isRoofAbove(pos, height, char)
		if not visualFolder then return false end
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { char, visualFolder }

		local upHit = workspace:Raycast(pos + Vector3.new(0, 1.5, 0), Vector3.new(0, height, 0), rayParams)
		if upHit and upHit.Instance and upHit.Instance.CanCollide then
			return true
		end
		return false
	end

	local function getHoopFromPool()
		if not visualFolder then return nil end
		for _, hoop in ipairs(hoopPool) do
			if not hoop.InUse then
				hoop.InUse = true
				return hoop
			end
		end
		if #hoopPool >= maxHoops then return nil end

		local segments = {}
		for i = 1, CONFIG.HoopSegments do
			local seg = Instance.new("Part")
			seg.Anchored = true
			seg.CanCollide = false
			seg.CanQuery = false
			seg.CanTouch = false
			seg.CastShadow = false
			seg.Material = Enum.Material.Neon
			seg.Color = Color3.fromRGB(225, 240, 255)
			seg.Transparency = 1
			seg.Size = Vector3.new(0.1, 0.03, 0.03)
			seg.Parent = visualFolder
			segments[i] = seg
		end

		local entry = { Segments = segments, InUse = true }
		table.insert(hoopPool, entry)
		return entry
	end

	local function playHoopAt(position, normal, token)
		if not rainActive or token ~= sessionToken or activeHoops >= maxHoops then return end
		local hoop = getHoopFromPool()
		if not hoop then return end

		activeHoops += 1
		local segCount = #hoop.Segments
		local startRadius = 0.14
		local endRadius = 1.35
		local thickness = 0.035

		local up = (normal and normal.Magnitude > 0.01) and normal.Unit or Vector3.new(0, 1, 0)
		local refAxis = math.abs(up:Dot(Vector3.new(0, 1, 0))) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
		local right = up:Cross(refAxis).Unit
		local forward = right:Cross(up).Unit
		local centerPos = position + up * 0.03

		local arcStart = (2 * math.pi * startRadius) / segCount
		local arcEnd = (2 * math.pi * endRadius) / segCount
		local tweenInfo = TweenInfo.new(CONFIG.HoopDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		for i = 1, segCount do
			local angle = ((i - 1) / segCount) * math.pi * 2
			local dir = (right * math.cos(angle) + forward * math.sin(angle)).Unit
			local tangent = (-right * math.sin(angle) + forward * math.cos(angle)).Unit
			local seg = hoop.Segments[i]

			seg.Size = Vector3.new(arcStart * 1.15, thickness, thickness)
			seg.Transparency = 0.2
			seg.CFrame = CFrame.fromMatrix(centerPos + dir * startRadius, tangent, up, -dir)

			local endCF = CFrame.fromMatrix(centerPos + dir * endRadius, tangent, up, -dir)
			trackTween(TweenService:Create(seg, tweenInfo, {
				CFrame = endCF,
				Size = Vector3.new(arcEnd * 1.15, thickness, thickness),
				Transparency = 1
			})):Play()
		end

		task.delay(CONFIG.HoopDuration + 0.03, function()
			for _, seg in ipairs(hoop.Segments) do
				if seg and seg.Parent then seg.Transparency = 1 end
			end
			hoop.InUse = false
			activeHoops = math.max(0, activeHoops - 1)
		end)
	end

	local function getDropFromPool()
		if not visualFolder then return nil end
		for _, item in ipairs(dropPool) do
			if not item.InUse then
				item.InUse = true
				return item
			end
		end
		if #dropPool >= CONFIG.MaxActiveDrops then return nil end

		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(185, 215, 250)
		part.Transparency = 1
		part.Parent = visualFolder

		local entry = { Part = part, InUse = true }
		table.insert(dropPool, entry)
		return entry
	end

	local function spawnRainDrop(token)
		if not rainActive or token ~= sessionToken or not visualFolder or activeDrops >= CONFIG.MaxActiveDrops then return end

		local char = Player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local centerPos = root and root.Position or Camera.CFrame.Position

		local startPos = centerPos + Vector3.new(
			math.random(-CONFIG.SpawnRadius, CONFIG.SpawnRadius),
			CONFIG.SpawnHeight,
			math.random(-CONFIG.SpawnRadius, CONFIG.SpawnRadius)
		)

		local wind = CONFIG.WindAngle + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
		local fallVector = Vector3.new(wind.X, -CONFIG.DropSpeed, wind.Z)
		local maxFallDist = CONFIG.SpawnHeight + 20

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { char, visualFolder }

		local rayResult = workspace:Raycast(startPos, fallVector.Unit * maxFallDist, rayParams)
		local hitCollidable = rayResult and rayResult.Instance and rayResult.Instance.CanCollide

		if hitCollidable and rayResult.Position.Y > centerPos.Y + 2 and (startPos.Y - rayResult.Position.Y) > 12 then
			return
		end

		local endPos = hitCollidable and rayResult.Position or (startPos + fallVector.Unit * maxFallDist)
		local distance = (endPos - startPos).Magnitude
		if distance < 1 then return end

		local item = getDropFromPool()
		if not item then return end

		activeDrops += 1
		local duration = distance / CONFIG.DropSpeed

		local part = item.Part
		part.Size = Vector3.new(0.04, math.random(28, 45) / 10, 0.04)
		part.Transparency = math.random(55, 78) / 100
		part.CFrame = CFrame.lookAt(startPos, startPos + fallVector) * CFrame.Angles(math.rad(90), 0, 0)

		local targetCF = CFrame.lookAt(endPos, endPos + fallVector) * CFrame.Angles(math.rad(90), 0, 0)
		local tween = trackTween(TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
			CFrame = targetCF
		}))

		tween:Play()
		tween.Completed:Connect(function()
			if part and part.Parent then part.Transparency = 1 end
			item.InUse = false
			activeDrops = math.max(0, activeDrops - 1)
		end)
	end

	local function startRainWorld()
		cleanupRainWorld()
		local token = sessionToken

		local container = Instance.new("Folder")
		container.Name = "RainVisualContainer"
		container.Parent = workspace
		visualFolder = container

		local refFolder = Instance.new("Folder")
		refFolder.Name = "PlayerWaterReflection"
		refFolder.Parent = visualFolder
		reflectionFolder = refFolder

		createSmoothCloudDome()
		updateFog()
		setupSound()

		if Player.Character then
			rebuildReflectionRig(Player.Character)
		end
		charAddedConn = Player.CharacterAdded:Connect(function(newChar)
			if not rainActive or token ~= sessionToken then return end
			task.wait(0.5)
			if rainActive and token == sessionToken then
				rebuildReflectionRig(newChar)
			end
		end)

		renderConn = RunService.RenderStepped:Connect(function()
			if not rainActive or token ~= sessionToken then return end
			for _ = 1, CONFIG.DropsPerFrame do
				spawnRainDrop(token)
			end
		end)

		loopThread = task.spawn(function()
			local tickAccumulator = 0
			local groundAccumulator = 0
			local reflectionAccumulator = 0

			while rainActive and token == sessionToken do
				local dt = task.wait(0.06)
				if not rainActive or token ~= sessionToken then break end

				tickAccumulator += dt
				groundAccumulator += dt
				reflectionAccumulator += dt

				local char = Player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")

				if tickAccumulator >= CONFIG.HoopSpawnInterval then
					tickAccumulator = 0
					if root and visualFolder then
						local rx = math.random(-26, 26)
						local rz = math.random(-26, 26)
						local samplePos = root.Position + Vector3.new(rx, 0, rz)
						if not isRoofAbove(samplePos, CONFIG.SpawnHeight, char) then
							local rayParams = RaycastParams.new()
							rayParams.FilterType = Enum.RaycastFilterType.Exclude
							rayParams.FilterDescendantsInstances = { char, visualFolder }
							local hit = workspace:Raycast(samplePos + Vector3.new(0, 8, 0), Vector3.new(0, -35, 0), rayParams)
							if hit and hit.Instance and hit.Instance.CanCollide then
								playHoopAt(hit.Position, hit.Normal, token)
							end
						end
					end
				end

				if CONFIG.WetGroundEnabled and groundAccumulator >= 4 then
					groundAccumulator = 0
					if root and visualFolder then
						local overlapParams = OverlapParams.new()
						overlapParams.FilterType = Enum.RaycastFilterType.Exclude
						overlapParams.FilterDescendantsInstances = { char, visualFolder }
						local parts = workspace:GetPartBoundsInRadius(root.Position, 75, overlapParams)
						local count = 0
						for _, part in ipairs(parts) do
							if count > 45 then break end
							if part:IsA("BasePart") and part.Anchored and part.Transparency == 0 then
								if part.Size.X > 6 and part.Size.Z > 6 and part.Position.Y <= root.Position.Y + 2 then
									if modifiedGroundParts[part] == nil then
										modifiedGroundParts[part] = part.Reflectance
										part.Reflectance = 0.28
										count += 1
									end
								end
							end
						end
					end
				end

				if reflectionAccumulator >= 0.06 then
					reflectionAccumulator = 0
					if CONFIG.PlayerReflectionEnabled and root and visualFolder then
						local rayParams = RaycastParams.new()
						rayParams.FilterType = Enum.RaycastFilterType.Exclude
						rayParams.FilterDescendantsInstances = { char, visualFolder }
						local floorHit = workspace:Raycast(root.Position + Vector3.new(0, 1, 0), Vector3.new(0, -10, 0), rayParams)
						local showRef = false
						local floorY = 0
						if floorHit and floorHit.Instance then
							local surfacePart = floorHit.Instance
							local isHorizontal = floorHit.Normal.Y > 0.75
							local isWetOrRoad = surfacePart.Reflectance > 0.05
								or surfacePart.Material == Enum.Material.Asphalt
								or surfacePart.Material == Enum.Material.Slate
								or surfacePart.Material == Enum.Material.Concrete
							if isHorizontal and isWetOrRoad then
								showRef = true
								floorY = floorHit.Position.Y
							end
						end

						for _, pair in ipairs(reflectionParts) do
							local src = pair.Source
							local ref = pair.Ref
							if src and src.Parent and ref and ref.Parent then
								if showRef then
									local localY = src.Position.Y - floorY
									local mirroredY = floorY - math.max(0.05, localY * 0.85)
									local mirroredPos = Vector3.new(src.Position.X, mirroredY, src.Position.Z)
									local _, yRot, _ = src.CFrame:ToOrientation()
									ref.Size = src.Size
									ref.CFrame = CFrame.new(mirroredPos) * CFrame.Angles(0, yRot, math.pi)
									ref.Transparency = 0.65
								else
									ref.Transparency = 1
								end
							end
						end
					else
						for _, pair in ipairs(reflectionParts) do
							if pair.Ref and pair.Ref.Parent then
								pair.Ref.Transparency = 1
							end
						end
					end
				end
			end
		end)
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
	card.Name = "RainAtmosphereCard"
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
	title.Text = "Rain Atmosphere"
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
	desc.Text = "Дождь, купол, звук и туман"
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

	local function setSwitchVisual(ind, active)
		TweenService:Create(ind, TweenInfo.new(0.2), {
			Position = active and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
			BackgroundColor3 = active and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(180, 180, 180)
		}):Play()
	end

	-- Боковая панель настроек (ширина как у Fling Settings / списка игроков)
	local sideFrame = Instance.new("Frame")
	sideFrame.Name = "RainAtmosphereSettingsMenu"
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
	panelHeader.Text = "Rain Settings"
	panelHeader.TextColor3 = Color3.fromRGB(245, 245, 245)
	panelHeader.TextSize = 13
	panelHeader.TextXAlignment = Enum.TextXAlignment.Left
	panelHeader.ZIndex = 12
	panelHeader.Parent = sideFrame

	local fogToggleBtn = Instance.new("TextButton")
	fogToggleBtn.Size = UDim2.new(1, -16, 0, 28)
	fogToggleBtn.Position = UDim2.new(0, 8, 0, 38)
	fogToggleBtn.BackgroundColor3 = CONFIG.FogEnabled and Color3.fromRGB(55, 95, 70) or Color3.fromRGB(45, 45, 50)
	fogToggleBtn.Text = CONFIG.FogEnabled and "Туман: ВКЛ" or "Туман: ВЫКЛ"
	fogToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	fogToggleBtn.Font = Enum.Font.Ubuntu
	fogToggleBtn.TextSize = 12
	fogToggleBtn.ZIndex = 13
	fogToggleBtn.Parent = sideFrame
	Instance.new("UICorner", fogToggleBtn).CornerRadius = UDim.new(0, 8)

	local fogDistLabel = Instance.new("TextLabel")
	fogDistLabel.Size = UDim2.new(1, -16, 0, 20)
	fogDistLabel.Position = UDim2.new(0, 8, 0, 74)
	fogDistLabel.BackgroundTransparency = 1
	fogDistLabel.Font = Enum.Font.Ubuntu
	fogDistLabel.Text = "Дистанция: " .. tostring(CONFIG.FogRadius)
	fogDistLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
	fogDistLabel.TextSize = 11
	fogDistLabel.TextXAlignment = Enum.TextXAlignment.Left
	fogDistLabel.ZIndex = 12
	fogDistLabel.Parent = sideFrame

	local fogHintLabel = Instance.new("TextLabel")
	fogHintLabel.Size = UDim2.new(1, -16, 0, 16)
	fogHintLabel.Position = UDim2.new(0, 8, 0, 92)
	fogHintLabel.BackgroundTransparency = 1
	fogHintLabel.Font = Enum.Font.Ubuntu
	fogHintLabel.Text = "< Ближе   Дальше >"
	fogHintLabel.TextColor3 = Color3.fromRGB(160, 160, 170)
	fogHintLabel.TextSize = 10
	fogHintLabel.TextXAlignment = Enum.TextXAlignment.Left
	fogHintLabel.ZIndex = 12
	fogHintLabel.Parent = sideFrame

	local sliderHitbox = Instance.new("TextButton")
	sliderHitbox.Size = UDim2.new(1, -16, 0, 28)
	sliderHitbox.Position = UDim2.new(0, 8, 0, 112)
	sliderHitbox.BackgroundTransparency = 1
	sliderHitbox.Text = ""
	sliderHitbox.AutoButtonColor = false
	sliderHitbox.ZIndex = 13
	sliderHitbox.Parent = sideFrame

	local sliderTrack = Instance.new("Frame")
	sliderTrack.Size = UDim2.new(1, 0, 0, 10)
	sliderTrack.AnchorPoint = Vector2.new(0, 0.5)
	sliderTrack.Position = UDim2.new(0, 0, 0.5, 0)
	sliderTrack.BackgroundColor3 = Color3.fromRGB(50, 50, 56)
	sliderTrack.BorderSizePixel = 0
	sliderTrack.ZIndex = 13
	sliderTrack.Parent = sliderHitbox
	Instance.new("UICorner", sliderTrack).CornerRadius = UDim.new(1, 0)

	local initAlpha = math.clamp(
		(CONFIG.FogRadius - CONFIG.MinFogRadius) / (CONFIG.MaxFogRadius - CONFIG.MinFogRadius),
		0,
		1
	)
	local sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.fromScale(initAlpha, 1)
	sliderFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sliderFill.BorderSizePixel = 0
	sliderFill.ZIndex = 14
	sliderFill.Parent = sliderTrack
	Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

	local function setFogFromAlpha(alpha)
		alpha = math.clamp(alpha, 0, 1)
		local radius = math.floor(CONFIG.MinFogRadius + (CONFIG.MaxFogRadius - CONFIG.MinFogRadius) * alpha + 0.5)
		CONFIG.FogRadius = radius
		sliderFill.Size = UDim2.fromScale(alpha, 1)
		fogDistLabel.Text = "Дистанция: " .. tostring(radius)
		updateFog()
	end

	local draggingSlider = false
	sliderHitbox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingSlider = true
			local alpha = (input.Position.X - sliderTrack.AbsolutePosition.X) / math.max(sliderTrack.AbsoluteSize.X, 1)
			setFogFromAlpha(alpha)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if draggingSlider and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local alpha = (input.Position.X - sliderTrack.AbsolutePosition.X) / math.max(sliderTrack.AbsoluteSize.X, 1)
			setFogFromAlpha(alpha)
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

	fogToggleBtn.MouseButton1Click:Connect(function()
		CONFIG.FogEnabled = not CONFIG.FogEnabled
		fogToggleBtn.Text = CONFIG.FogEnabled and "Туман: ВКЛ" or "Туман: ВЫКЛ"
		fogToggleBtn.BackgroundColor3 = CONFIG.FogEnabled and Color3.fromRGB(55, 95, 70) or Color3.fromRGB(45, 45, 50)
		updateFog()
	end)

	local function setRainAtmosphereState(enable)
		if rainActive == enable then return end
		rainActive = enable
		setSwitchVisual(indicator, enable)

		if enable then
			startRainWorld()
		else
			cleanupRainWorld()
		end
	end

	setSwitchVisual(indicator, false)
	toggleBtn.MouseButton1Click:Connect(function()
		setRainAtmosphereState(not rainActive)
	end)
end

Client.State.OnReady = Client.State.OnReady or {}
table.insert(Client.State.OnReady, initRainAtmosphere)
