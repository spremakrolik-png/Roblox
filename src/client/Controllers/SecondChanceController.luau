--!strict
-- The "second chance" card a runner sees right after dying: come back at the last checkpoint for
-- Robux, with a saved token, or (in Studio) for free. The server decides; this only shows the offer.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameState = require(ReplicatedStorage.Shared.GameState)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Icons = require(script.Parent.Parent.Util.Icons)
local UI = require(script.Parent.Parent.Util.UI)

local player = Players.LocalPlayer

local SecondChanceController = {}

local card: Frame
local timerFill: Frame
local buttons: Frame
local heart: Frame
local token = 0

local function hide()
	token += 1
	card.Visible = false
end

local function addButton(text: string, color: Color3, order: number, onClick: () -> ())
	local button = Instance.new("TextButton")
	button.Text = text
	button.Font = Enum.Font.SourceSansBold
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.BackgroundColor3 = color
	button.AutoButtonColor = false
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 52)
	UI.corner(button, 12)
	UI.gradient(button, color:Lerp(Color3.new(1, 1, 1), 0.2), color:Lerp(Color3.new(0, 0, 0), 0.2))
	UI.stroke(button, Color3.new(1, 1, 1), 2, 0.6)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 26
	limit.Parent = button
	UI.pressable(button)
	button.Activated:Connect(function()
		onClick()
	end)
	button.Parent = buttons
end

local function show(offer: Types.SecondChanceOffer)
	token += 1
	local current = token
	for _, child in buttons:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	if offer.robux > 0 then
		addButton(`Вернуться за R$ {offer.robux}`, Color3.fromRGB(30, 160, 90), 1, function()
			MarketplaceService:PromptProductPurchase(player, Monetization.SecondChance.productId)
		end)
	end
	if offer.tokens > 0 then
		addButton(`Использовать жетон ({offer.tokens})`, Color3.fromRGB(200, 120, 30), 2, function()
			Remotes.SecondChanceRequest:FireServer("Use")
			hide()
		end)
	end
	if offer.free then
		addButton(
			"Вернуться бесплатно (тест в Studio)",
			Color3.fromRGB(70, 110, 200),
			3,
			function()
				Remotes.SecondChanceRequest:FireServer("Free")
				hide()
			end
		)
	end
	addButton("Нет, спасибо", Color3.fromRGB(80, 84, 100), 4, function()
		Remotes.SecondChanceRequest:FireServer("Decline")
		hide()
	end)

	card.Visible = true
	UI.popIn(card)
	timerFill.Size = UDim2.fromScale(1, 1)
	TweenService:Create(timerFill, TweenInfo.new(offer.seconds, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(0, 1),
	}):Play()

	-- Closes on time-out, revive, or the end of the round. A purchase in progress keeps it a bit longer.
	task.spawn(function()
		local deadline = os.clock() + offer.seconds
		local beat = 0
		while current == token do
			beat += 1
			local heartScale = heart:FindFirstChildOfClass("UIScale")
			if heartScale then
				heartScale.Scale = if beat % 6 < 3 then 1.12 else 1
			end
			local stillDead = GameState.getStatus(player) == "Eliminated" and GameState.phase() == "Round"
			if not stillDead or os.clock() > deadline + 1 then
				hide()
				return
			end
			task.wait(0.1)
		end
	end)
end

function SecondChanceController.start()
	local gui = UI.screen("SecondChance", 15)
	card = UI.panel("Card", gui, UDim2.fromScale(0.42, 0.5), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	UI.sizeLimit(card, Vector2.new(300, 300), Vector2.new(440, 420))
	UI.gradient(card, Color3.fromRGB(60, 24, 40), Color3.fromRGB(18, 14, 26))
	UI.stroke(card, Color3.fromRGB(255, 110, 140), 3, 0.1)
	UI.padding(card, 14)
	card.Visible = false

	heart = UI.iconTile(
		card,
		Icons.SecondChance.glyph,
		Icons.SecondChance.color,
		UDim2.fromOffset(64, 64),
		UDim2.new(0.5, -32, 0, 0)
	)
	local heartScale = Instance.new("UIScale")
	heartScale.Parent = heart
	UI.label({
		name = "Title",
		parent = card,
		text = "ВТОРОЙ ШАНС!",
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.fromOffset(0, 68),
		color = Color3.fromRGB(255, 150, 170),
		maxTextSize = 38,
	})
	UI.label({
		name = "Subtitle",
		parent = card,
		text = "Вернись на последний чекпоинт и беги дальше",
		size = UDim2.new(1, 0, 0, 24),
		position = UDim2.fromOffset(0, 108),
		color = UI.Colors.Muted,
		font = Enum.Font.SourceSansSemibold,
		maxTextSize = 20,
	})
	local timer = Instance.new("Frame")
	timer.Name = "Timer"
	timer.Size = UDim2.new(1, 0, 0, 8)
	timer.Position = UDim2.fromOffset(0, 138)
	timer.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
	timer.BorderSizePixel = 0
	UI.corner(timer, 4)
	timerFill = Instance.new("Frame")
	timerFill.BackgroundColor3 = Color3.fromRGB(255, 110, 140)
	timerFill.BorderSizePixel = 0
	UI.corner(timerFill, 4)
	timerFill.Parent = timer
	timer.Parent = card

	buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.BackgroundTransparency = 1
	buttons.Position = UDim2.fromOffset(0, 156)
	buttons.Size = UDim2.new(1, 0, 1, -156)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = buttons
	buttons.Parent = card
	gui.Parent = player:WaitForChild("PlayerGui")

	Remotes.SecondChanceOffer.OnClientEvent:Connect(function(offer: Types.SecondChanceOffer)
		show(offer)
	end)
end

return SecondChanceController
