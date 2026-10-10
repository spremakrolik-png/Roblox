--!strict
-- The card that opens at an ability stand in the lobby: what the ability does, its price, and
-- buttons to buy it (Points or Robux) or put it into a slot.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Icons = require(script.Parent.Parent.Util.Icons)
local UI = require(script.Parent.Parent.Util.UI)

local player = Players.LocalPlayer

local AbilityCardController = {}

local card: Frame
local content: Frame
local snapshot: Types.DataSnapshot? = nil
local shownId: string? = nil

local KIND_TEXT: { [Types.AbilityKind]: string } = {
	Active = "Активная",
	Passive = "Работает всегда",
	OncePerRound = "Раз за раунд",
	OncePassive = "Срабатывает сама, раз за раунд",
}

local function button(parent: Instance, text: string, color: Color3, order: number, onClick: () -> ())
	local b = Instance.new("TextButton")
	b.Text = text
	b.Font = Enum.Font.SourceSansBold
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color
	b.AutoButtonColor = false
	b.LayoutOrder = order
	b.Size = UDim2.new(1, 0, 0, 48)
	UI.corner(b, 12)
	UI.gradient(b, color:Lerp(Color3.new(1, 1, 1), 0.18), color:Lerp(Color3.new(0, 0, 0), 0.2))
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 24
	limit.Parent = b
	UI.pressable(b)
	b.Activated:Connect(function()
		onClick()
	end)
	b.Parent = parent
end

local function render()
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local id = shownId
	local def = if id then Abilities.byId[id] else nil
	if not def then
		card.Visible = false
		return
	end
	local icon = Icons.ability(def.id)
	UI.iconTile(content, icon.glyph, icon.color, UDim2.fromOffset(84, 84), UDim2.fromOffset(0, 0))
	UI.label({
		name = "Name",
		parent = content,
		text = def.name,
		size = UDim2.new(1, -96, 0, 40),
		position = UDim2.fromOffset(96, 2),
		alignX = Enum.TextXAlignment.Left,
		maxTextSize = 34,
	})
	UI.label({
		name = "Role",
		parent = content,
		text = if def.role == "Runner"
			then "Способность раннера"
			else "Способность трапера",
		size = UDim2.new(1, -96, 0, 26),
		position = UDim2.fromOffset(96, 44),
		alignX = Enum.TextXAlignment.Left,
		color = if def.role == "Runner" then UI.Colors.Runner else UI.Colors.Trapper,
		maxTextSize = 22,
	})
	local description = UI.label({
		name = "Description",
		parent = content,
		text = def.description,
		size = UDim2.new(1, 0, 0, 52),
		position = UDim2.fromOffset(0, 94),
		alignX = Enum.TextXAlignment.Left,
		color = UI.Colors.Text,
		font = Enum.Font.SourceSansSemibold,
		maxTextSize = 22,
	})
	description.TextWrapped = true
	local details = KIND_TEXT[def.kind]
	if def.kind == "Active" and def.cooldown > 0 then
		details ..= ` · перезарядка {def.cooldown} с`
	end
	if def.lobbyUse then
		details ..= " · работает и в лобби"
	end
	UI.label({
		name = "Details",
		parent = content,
		text = details,
		size = UDim2.new(1, 0, 0, 24),
		position = UDim2.fromOffset(0, 150),
		alignX = Enum.TextXAlignment.Left,
		color = UI.Colors.Muted,
		font = Enum.Font.SourceSansSemibold,
		maxTextSize = 20,
	})

	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.BackgroundTransparency = 1
	actions.Position = UDim2.fromOffset(0, 184)
	actions.Size = UDim2.new(1, 0, 1, -184)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = actions
	actions.Parent = content

	local data = snapshot
	local owned = data ~= nil and table.find(data.owned, def.id) ~= nil
	if not owned then
		local enough = data ~= nil and data.points >= def.price
		button(
			actions,
			`Купить за {def.price} очков`,
			if enough then Color3.fromRGB(60, 130, 220) else Color3.fromRGB(90, 94, 110),
			1,
			function()
				Remotes.ShopRequest:FireServer("Buy", def.id)
			end
		)
		local product = Monetization.AbilityProducts[def.id]
		if product and product.productId ~= 0 then
			button(actions, `Купить за R$ {product.robux}`, Color3.fromRGB(30, 150, 90), 2, function()
				MarketplaceService:PromptProductPurchase(player, product.productId)
			end)
		end
	elseif data then
		local loadout = Abilities.loadoutOf(data.loadouts, def.role)
		local slot = table.find(loadout, def.id)
		if slot then
			UI.label({
				name = "Equipped",
				parent = actions,
				text = `Надето: слот {slot}`,
				size = UDim2.new(1, 0, 0, 40),
				color = Color3.fromRGB(130, 230, 150),
				maxTextSize = 26,
			})
		else
			local free = table.find(loadout, "") or 1
			button(actions, `Надеть в слот {free}`, Color3.fromRGB(200, 130, 40), 1, function()
				Remotes.ShopRequest:FireServer("Equip", def.role, free, def.id)
			end)
		end
	end
end

local function open(id: string)
	shownId = id
	render()
	card.Visible = true
	UI.popIn(card)
end

function AbilityCardController.start()
	local gui = UI.screen("AbilityCard", 12)
	card = UI.panel("Card", gui, UDim2.fromScale(0.42, 0.52), UDim2.fromScale(0.5, 0.52), Vector2.new(0.5, 0.5))
	UI.sizeLimit(card, Vector2.new(320, 340), Vector2.new(460, 400))
	UI.padding(card, 16)
	card.BackgroundTransparency = 0.05
	UI.gradient(card, Color3.fromRGB(52, 44, 86), Color3.fromRGB(18, 18, 30))
	UI.stroke(card, Color3.fromRGB(255, 190, 220), 2.5, 0.25)
	card.Visible = false
	content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = card
	local close = Instance.new("TextButton")
	close.Text = "✕"
	close.Font = Enum.Font.SourceSansBold
	close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1)
	close.BackgroundColor3 = Color3.fromRGB(170, 70, 90)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 6, 0, -6)
	close.Size = UDim2.fromOffset(40, 40)
	close.ZIndex = 3
	UI.corner(close, 20)
	UI.pressable(close)
	close.Activated:Connect(function()
		card.Visible = false
		shownId = nil
	end)
	close.Parent = card
	gui.Parent = player:WaitForChild("PlayerGui")

	Remotes.PlayerData.OnClientEvent:Connect(function(data: Types.DataSnapshot)
		snapshot = data
		if card.Visible then
			render()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local id = prompt:GetAttribute("AbilityCard")
		if typeof(id) == "string" then
			open(id)
		end
	end)
end

return AbilityCardController
