local TweenService = game:GetService("TweenService")
local Client = _G.Dar4xClient
if not Client then return end

local HOME_PHRASES = {
	"Dar4x Client был создан командой K9tiki systemDLC v7.8",
	"Мы не пытаемся оскорбить другие скрипты",
	"Dar4x Client — динамичный клиент",
	"Dar4x Client — это скрипт, подстроенный для игры в Brookhaven RP",
	"Dar4x Client для игры с комфортом"
}

local function initHome()
	local pageFrame = Client.State.Pages["Home"]
	if not pageFrame then return end

	local homeBanner = Instance.new("Frame")
	homeBanner.Name = "HomeIntroBanner"
	homeBanner.Size = UDim2.new(1, -20, 0, 54)
	homeBanner.AnchorPoint = Vector2.new(0.5, 0.5)
	homeBanner.Position = UDim2.new(0.5, 0, 0.5, 0)
	homeBanner.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	homeBanner.BackgroundTransparency = 1
	homeBanner.BorderSizePixel = 0
	homeBanner.ZIndex = 3
	homeBanner.Parent = pageFrame
	Instance.new("UICorner", homeBanner).CornerRadius = UDim.new(0, 12)

	local homeBannerStroke = Instance.new("UIStroke")
	homeBannerStroke.Color = Color3.fromRGB(255, 255, 255)
	homeBannerStroke.Thickness = 1
	homeBannerStroke.Transparency = 1
	homeBannerStroke.Parent = homeBanner

	local homeIntroLabel = Instance.new("TextLabel")
	homeIntroLabel.Name = "HomeIntroLabel"
	homeIntroLabel.Size = UDim2.new(1, -24, 1, 0)
	homeIntroLabel.Position = UDim2.new(0, 12, 0, 0)
	homeIntroLabel.BackgroundTransparency = 1
	homeIntroLabel.Font = Enum.Font.Ubuntu
	homeIntroLabel.Text = HOME_PHRASES[1]
	homeIntroLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
	homeIntroLabel.TextSize = 14
	homeIntroLabel.TextWrapped = true
	homeIntroLabel.TextTransparency = 1
	homeIntroLabel.ZIndex = 4
	homeIntroLabel.Parent = homeBanner

	local homeLoopToken = 0
	local activeFadeInTween, activeStrokeInTween, activeTextInTween = nil, nil, nil
	local activeFadeOutTween, activeStrokeOutTween, activeTextOutTween = nil, nil, nil

	local function cancelActiveHomeTweens()
		if activeFadeInTween then activeFadeInTween:Cancel() end
		if activeStrokeInTween then activeStrokeInTween:Cancel() end
		if activeTextInTween then activeTextInTween:Cancel() end
		if activeFadeOutTween then activeFadeOutTween:Cancel() end
		if activeStrokeOutTween then activeStrokeOutTween:Cancel() end
		if activeTextOutTween then activeTextOutTween:Cancel() end
	end

	local function startHomeIntroLoop()
		homeLoopToken += 1
		local currentToken = homeLoopToken
		cancelActiveHomeTweens()

		task.spawn(function()
			local phraseIndex = 1
			while homeLoopToken == currentToken do
				if not Client.State.IsOpen or Client.State.ActiveTab ~= "Home" then
					task.wait(0.15)
					continue
				end

				homeIntroLabel.Text = HOME_PHRASES[phraseIndex]
				homeBanner.Position = UDim2.new(0.5, 0, 0.5, 8)
				homeBanner.BackgroundTransparency = 1
				homeBannerStroke.Transparency = 1
				homeIntroLabel.TextTransparency = 1

				local inInfo = TweenInfo.new(0.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				activeFadeInTween = TweenService:Create(homeBanner, inInfo, { Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 0.45 })
				activeStrokeInTween = TweenService:Create(homeBannerStroke, inInfo, { Transparency = 0.65 })
				activeTextInTween = TweenService:Create(homeIntroLabel, inInfo, { TextTransparency = 0 })

				activeFadeInTween:Play()
				activeStrokeInTween:Play()
				activeTextInTween:Play()
				task.wait(0.75)

				if homeLoopToken ~= currentToken or not Client.State.IsOpen or Client.State.ActiveTab ~= "Home" then break end
				task.wait(2.2)
				if homeLoopToken ~= currentToken or not Client.State.IsOpen or Client.State.ActiveTab ~= "Home" then break end

				local outInfo = TweenInfo.new(0.65, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
				activeFadeOutTween = TweenService:Create(homeBanner, outInfo, { Position = UDim2.new(0.5, 0, 0.5, -8), BackgroundTransparency = 1 })
				activeStrokeOutTween = TweenService:Create(homeBannerStroke, outInfo, { Transparency = 1 })
				activeTextOutTween = TweenService:Create(homeIntroLabel, outInfo, { TextTransparency = 1 })

				activeFadeOutTween:Play()
				activeStrokeOutTween:Play()
				activeTextOutTween:Play()
				task.wait(0.65)

				phraseIndex = (phraseIndex % #HOME_PHRASES) + 1
				task.wait(0.35)
			end
		end)
	end

	table.insert(Client.State.OnTabChanged, function(tabName, isOpen)
		if tabName == "Home" and isOpen then
			startHomeIntroLoop()
		else
			homeLoopToken += 1
			cancelActiveHomeTweens()
		end
	end)

	table.insert(Client.State.OnMenuStateChanged, function(isOpen, activeTab)
		if isOpen and activeTab == "Home" then
			startHomeIntroLoop()
		elseif not isOpen then
			homeLoopToken += 1
			cancelActiveHomeTweens()
		end
	end)
end

Client.State.OnReady = Client.State.OnReady or {}
table.insert(Client.State.OnReady, initHome)
