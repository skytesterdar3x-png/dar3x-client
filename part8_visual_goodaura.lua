local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Client = _G.Dar4xClient
if not Client then return end

local localPlayer = Players.LocalPlayer
local AURA_ASSET_ID = "rbxassetid://10748799551"

local partMapping = {
	["Head"] = { "Head" },
	["Torso"] = { "UpperTorso", "Torso", "HumanoidRootPart" },
	["UpperTorso"] = { "UpperTorso", "Torso" },
	["LowerTorso"] = { "LowerTorso", "Torso" },
	["HumanoidRootPart"] = { "HumanoidRootPart", "LowerTorso", "Torso" },
	["Left Arm"] = { "LeftUpperArm", "Left Arm", "LeftLowerArm" },
	["Right Arm"] = { "RightUpperArm", "Right Arm", "RightLowerArm" },
	["Left Leg"] = { "LeftUpperLeg", "Left Leg", "LeftLowerLeg" },
	["Right Leg"] = { "RightUpperLeg", "Right Leg", "RightLowerLeg" },
	["LeftUpperArm"] = { "LeftUpperArm", "Left Arm" },
	["RightUpperArm"] = { "RightUpperArm", "Right Arm" },
	["LeftLowerArm"] = { "LeftLowerArm", "Left Arm" },
	["RightLowerArm"] = { "RightLowerArm", "Right Arm" },
	["LeftHand"] = { "LeftHand", "Left Arm" },
	["RightHand"] = { "RightHand", "Right Arm" },
	["LeftUpperLeg"] = { "LeftUpperLeg", "Left Leg" },
	["RightUpperLeg"] = { "RightUpperLeg", "Right Leg" },
	["LeftLowerLeg"] = { "LeftLowerLeg", "Left Leg" },
	["RightLowerLeg"] = { "RightLowerLeg", "Right Leg" },
	["LeftFoot"] = { "LeftFoot", "Left Leg" },
	["RightFoot"] = { "RightFoot", "Right Leg" }
}

local bodyNames = {
	Head = true, Torso = true, UpperTorso = true, LowerTorso = true, HumanoidRootPart = true,
	["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
	LeftUpperArm = true, RightUpperArm = true, LeftLowerArm = true, RightLowerArm = true,
	LeftHand = true, RightHand = true, LeftUpperLeg = true, RightUpperLeg = true,
	LeftLowerLeg = true, RightLowerLeg = true, LeftFoot = true, RightFoot = true
}

local function findTargetBodyPart(character, sourcePartName)
	local candidates = partMapping[sourcePartName]
	if candidates then
		for _, name in ipairs(candidates) do
			local found = character:FindFirstChild(name)
			if found and found:IsA("BasePart") then
				return found
			end
		end
	end
	return character:FindFirstChild(sourcePartName)
		or character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
end

local function initGoodAura()
	local pageFrame = Client.State.Pages and Client.State.Pages["Visual"]
	if not pageFrame then return end

	local goodAuraEnabled = false
	local sessionToken = 0
	local auraWorldFolder = nil
	local appliedInstances = {}
	local followConnections = {}
	local charAddedConn = nil

	local function clearAppliedAura()
		for _, conn in ipairs(followConnections) do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(followConnections)

		for _, inst in ipairs(appliedInstances) do
			if inst and inst.Parent then
				inst:Destroy()
			end
		end
		table.clear(appliedInstances)

		local oldFolder = workspace:FindFirstChild("VisualGoodAuraFolder")
		if oldFolder then
			oldFolder:Destroy()
		end
		auraWorldFolder = nil
	end

	local function ensureWorldFolder()
		if auraWorldFolder and auraWorldFolder.Parent then
			return auraWorldFolder
		end
		local folder = Instance.new("Folder")
		folder.Name = "VisualGoodAuraFolder"
		folder.Parent = workspace
		auraWorldFolder = folder
		return folder
	end

	local function applyGoodAura(character, token)
		if not goodAuraEnabled or token ~= sessionToken or not character then return end

		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root or not goodAuraEnabled or token ~= sessionToken then return end

		local ok, objects = pcall(function()
			return game:GetObjects(AURA_ASSET_ID)
		end)

		if not goodAuraEnabled or token ~= sessionToken then
			if ok and objects then
				for _, obj in ipairs(objects) do
					pcall(function() obj:Destroy() end)
				end
			end
			return
		end

		if not ok or not objects or #objects == 0 then
			warn("[Good Aura] Не удалось загрузить модель по ID:", AURA_ASSET_ID)
			return
		end

		local worldFolder = ensureWorldFolder()

		for _, loadedObj in ipairs(objects) do
			for _, desc in ipairs(loadedObj:GetDescendants()) do
				if desc:IsA("LuaSourceContainer") then
					desc:Destroy()
				end
			end

			for _, desc in ipairs(loadedObj:GetDescendants()) do
				if desc:IsA("Attachment") then
					local parentPart = desc.Parent
					if parentPart and parentPart:IsA("BasePart") then
						local targetPart = findTargetBodyPart(character, parentPart.Name)
						if targetPart then
							local clonedAtt = desc:Clone()
							clonedAtt.Parent = targetPart
							table.insert(appliedInstances, clonedAtt)
						end
					end
				elseif desc:IsA("ParticleEmitter") or desc:IsA("Beam") or desc:IsA("Trail") or desc:IsA("Light") then
					local parentObj = desc.Parent
					if parentObj and parentObj:IsA("BasePart") then
						local targetPart = findTargetBodyPart(character, parentObj.Name)
						if targetPart then
							local clonedFx = desc:Clone()
							if clonedFx:IsA("ParticleEmitter") then
								clonedFx.Enabled = true
							end
							clonedFx.Parent = targetPart
							table.insert(appliedInstances, clonedFx)
						end
					end
				end
			end

			local sourceRoot = loadedObj:FindFirstChild("HumanoidRootPart")
				or loadedObj:FindFirstChild("Torso")
				or loadedObj:FindFirstChild("UpperTorso")
				or loadedObj:FindFirstChildWhichIsA("BasePart", true)

			for _, desc in ipairs(loadedObj:GetDescendants()) do
				if desc:IsA("BasePart") and not bodyNames[desc.Name] then
					local clonedPart = desc:Clone()
					clonedPart.Anchored = true
					clonedPart.CanCollide = false
					clonedPart.CanQuery = false
					clonedPart.CanTouch = false
					clonedPart.CastShadow = false
					clonedPart.Parent = worldFolder
					table.insert(appliedInstances, clonedPart)

					local relOffset = sourceRoot and sourceRoot.CFrame:ToObjectSpace(desc.CFrame) or CFrame.new()
					local conn = RunService.RenderStepped:Connect(function()
						if not goodAuraEnabled or token ~= sessionToken then return end
						if root and root.Parent and clonedPart and clonedPart.Parent then
							clonedPart.CFrame = root.CFrame * relOffset
						end
					end)
					table.insert(followConnections, conn)
				end
			end

			loadedObj:Destroy()
		end
	end

	-- UI карточки Good Aura в разделе Visual
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
	card.Name = "GoodAuraCard"
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
	title.Text = "Good Aura"
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
	desc.Text = "Визуальная аура на персонаже"
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

	local function setGoodAuraState(enable)
		if goodAuraEnabled == enable then return end
		goodAuraEnabled = enable
		setSwitchVisual(enable)

		if enable then
			clearAppliedAura()
			goodAuraEnabled = true
			sessionToken += 1
			local token = sessionToken

			if not charAddedConn then
				charAddedConn = localPlayer.CharacterAdded:Connect(function(newChar)
					if goodAuraEnabled and token == sessionToken then
						task.wait(0.2)
						if goodAuraEnabled and token == sessionToken then
							clearAppliedAura()
							goodAuraEnabled = true
							applyGoodAura(newChar, token)
						end
					end
				end)
			end

			if localPlayer.Character then
				task.spawn(function()
					applyGoodAura(localPlayer.Character, token)
				end)
			end
		else
			sessionToken += 1
			if charAddedConn then
				pcall(function() charAddedConn:Disconnect() end)
				charAddedConn = nil
			end
			clearAppliedAura()
		end
	end

	setSwitchVisual(false)
	toggleBtn.MouseButton1Click:Connect(function()
		setGoodAuraState(not goodAuraEnabled)
	end)
end

Client.State.OnReady = Client.State.OnReady or {}
table.insert(Client.State.OnReady, initGoodAura)
