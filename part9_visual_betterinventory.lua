local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local Client = _G.Dar4xClient
if not Client then return end

local lp = Players.LocalPlayer

local SPEED = 18
local PAD = 2
local THICK = 3
local COLOR = Color3.new(1, 1, 1)
local OFFSET_Y = 0

local function getHotbar()
	local rg = CoreGui:FindFirstChild("RobloxGui")
	local bp = rg and rg:FindFirstChild("Backpack")
	return bp and bp:FindFirstChild("Hotbar")
end

local function findSlot(tool)
	local hb = getHotbar()
	if not hb then return end
	for _, slot in ipairs(hb:GetChildren()) do
		if slot:IsA("GuiObject") then
			for _, d in ipairs(slot:GetDescendants()) do
				if d:IsA("TextLabel") and d.Text == tool.Name then
					return slot
				end
			end
		end
	end
end

local function isBlue(c)
	return c.B > c.R + 0.2 and c.B > c.G + 0.08
end

local function hideBlue(o)
	if o:IsA("UIStroke") then
		if isBlue(o.Color) then o.Transparency = 1 end
	elseif o:IsA("ImageLabel") or o:IsA("ImageButton") then
		if isBlue(o.ImageColor3) then o.ImageTransparency = 1 end
		if isBlue(o.BackgroundColor3) then o.BackgroundTransparency = 1 end
	elseif o:IsA("GuiObject") then
		if isBlue(o.BackgroundColor3) then o.BackgroundTransparency = 1 end
		if isBlue(o.BorderColor3) then o.BorderSizePixel = 0 end
	end
end

local function hideDefault()
	local hb = getHotbar()
	if not hb then return end
	for _, slot in ipairs(hb:GetChildren()) do
		hideBlue(slot)
		for _, d in ipairs(slot:GetDescendants()) do
			hideBlue(d)
		end
	end
end

local function initBetterInventory()
	local pageFrame = Client.State.Pages and Client.State.Pages["Visual"]
	if not pageFrame then return end

	local oldGui = (gethui and gethui():FindFirstChild("SmoothHotbar")) or CoreGui:FindFirstChild("SmoothHotbar")
	if oldGui then
		oldGui:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SmoothHotbar"
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999
	gui.Parent = (gethui and gethui()) or CoreGui

	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Visible = false
	box.Parent = gui
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR
	stroke.Thickness = THICK
	stroke.Transparency = 1
	stroke.Parent = box

	local betterInvEnabled = true
	local pos, size
	local fade = TweenInfo.new(0.15)
	local bindName = "Dar4x_SmoothHotbar"

	pcall(function()
		RunService:UnbindFromRenderStep(bindName)
	end)

	local function stopSmoothHotbar()
		pcall(function()
			RunService:UnbindFromRenderStep(bindName)
		end)
		pos, size = nil, nil
		box.Visible = false
		stroke.Transparency = 1
	end

	local function startSmoothHotbar()
		pcall(function()
			RunService:UnbindFromRenderStep(bindName)
		end)
		pos, size = nil, nil

		RunService:BindToRenderStep(bindName, Enum.RenderPriority.Last.Value, function(dt)
			if not betterInvEnabled then return end
			hideDefault()

			local char = lp.Character
			local tool = char and char:FindFirstChildOfClass("Tool")
			local slot = tool and findSlot(tool)

			if not slot then
				TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
				pos, size = nil, nil
				return
			end

			local tPos = slot.AbsolutePosition - Vector2.new(PAD, PAD - OFFSET_Y)
			local tSize = slot.AbsoluteSize + Vector2.new(PAD * 2, PAD * 2)

			if not pos then
				pos, size = tPos, tSize
				box.Visible = true
			end

			local a = 1 - math.exp(-dt * SPEED)
			pos = pos:Lerp(tPos, a)
			size = size:Lerp(tSize, a)

			box.Position = UDim2.fromOffset(pos.X, pos.Y)
			box.Size = UDim2.fromOffset(size.X, size.Y)
			TweenService:Create(stroke, fade, { Transparency = 0 }):Play()
		end)
	end

	-- UI карточки Better Inventory в разделе Visual
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
	card.Name = "BetterInventoryCard"
	card.Size = UDim2.new(1, 0, 0, 50)
	card.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	card.BackgroundTransparency = 0.5
	card.BorderSizePixel = 0
	card.ZIndex = 4
	card.Parent = visualList
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

	local strokeCard = Instance.new("UIStroke")
	strokeCard.Color = Color3.fromRGB(255, 255, 255)
	strokeCard.Transparency = 0.7
	strokeCard.Thickness = 1
	strokeCard.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -70, 0, 20)
	title.Position = UDim2.new(0, 10, 0, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Ubuntu
	title.Text = "Better Inventory"
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
	desc.Text = "Плавная рамка слотов инвентаря"
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
	indicator.Position = UDim2.new(1, -21, 0.5, -9)
	indicator.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
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

	local function setBetterInventoryState(enable)
		betterInvEnabled = enable
		setSwitchVisual(enable)
		if enable then
			startSmoothHotbar()
		else
			stopSmoothHotbar()
		end
	end

	-- Включаем сразу при запуске клиента
	setSwitchVisual(true)
	startSmoothHotbar()

	toggleBtn.MouseButton1Click:Connect(function()
		setBetterInventoryState(not betterInvEnabled)
	end)
end

Client.State.OnReady = Client.State.OnReady or {}
table.insert(Client.State.OnReady, initBetterInventory)
