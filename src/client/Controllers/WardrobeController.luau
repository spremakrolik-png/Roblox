--!strict
-- The wardrobe: trails, hats and auras for Points. Opens from the "ГАРДЕРОБ" button in the lobby or
-- at the wardrobe booth. Items show on the character for everyone as soon as they are worn.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Config.Cosmetics)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local UI = require(script.Parent.Parent.Util.UI)

local CARD_HEIGHT = 150

local player = Players.LocalPlayer

local WardrobeController = {}

local panel: Frame
local grid: ScrollingFrame
local pointsLabel: TextLabel
local tabButtons: { [Cosmetics.CosmeticKind]: TextButton } = {}
local openButton: TextButton
local snapshot: Types.DataSnapshot? = nil
local tab: Cosmetics.CosmeticKind = "Trail"

local function pill(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Text = text
	b.Font = Enum.Font.SourceSansBold
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color
	b.AutoButtonColor = false
	b.Size = size
	b.Position = position
	UI.corner(b, 10)
	UI.gradient(b, color:Lerp(Color3.new(1, 1, 1), 0.18), color:Lerp(Color3.new(0, 0, 0), 0.2))
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 22
	limit.Parent = b
	UI.pressable(b)
	b.Parent = parent
	return b
end

local function equippedId(kind: Cosmetics.CosmeticKind): string
	local data = snapshot
	if not data then
		return ""
	end
	return (data.cosmetics.equipped :: any)[kind] or ""
end

local function render()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local data = snapshot
	pointsLabel.Text = `Очки: {if data then data.points else 0}`
	for kind, b in tabButtons do
		b.BackgroundColor3 = if kind == tab then Color3.fromRGB(220, 120, 170) else Color3.fromRGB(80, 78, 104)
	end
	local order = 0
	for _, def in Cosmetics.list do
		if def.kind ~= tab then
			continue
		end
		order += 1
		local owned = data ~= nil and table.find(data.cosmetics.owned, def.id) ~= nil
		local worn = equippedId(def.kind) == def.id
		local card = Instance.new("Frame")
		card.Name = def.id
		card.LayoutOrder = order
		card.BackgroundColor3 = Color3.fromRGB(46, 44, 66)
		card.BorderSizePixel = 0
		UI.corner(card, 12)
		UI.stroke(
			card,
			if worn then UI.Colors.Gold else def.colors[1],
			if worn then 3 else 1.5,
			if worn then 0 else 0.5
		)
		-- A colour strip shows the item's colours.
		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.new(1, -16, 0, 10)
		swatch.Position = UDim2.fromOffset(8, 8)
		swatch.BorderSizePixel = 0
		swatch.BackgroundColor3 = Color3.new(1, 1, 1)
		UI.corner(swatch, 5)
		local gradient = Instance.new("UIGradient")
		if #def.colors > 1 then
			local points = {}
			for index, color in def.colors do
				table.insert(points, ColorSequenceKeypoint.new((index - 1) / (#def.colors - 1), color))
			end
			gradient.Color = ColorSequence.new(points)
		else
			gradient.Color = ColorSequence.new(def.colors[1])
		end
		gradient.Parent = swatch
		swatch.Parent = card
		UI.label({
			name = "Glyph",
			parent = card,
			text = def.glyph,
			size = UDim2.new(1, 0, 0, 44),
			position = UDim2.fromOffset(0, 22),
			maxTextSize = 40,
		})
		UI.label({
			name = "Name",
			parent = card,
			text = def.name,
			size = UDim2.new(1, -12, 0, 26),
			position = UDim2.fromOffset(6, 68),
			maxTextSize = 22,
		})
		local actionText: string
		local actionColor: Color3
		if worn then
			actionText = "Снять"
			actionColor = Color3.fromRGB(120, 80, 90)
		elseif owned then
			actionText = "Надеть"
			actionColor = Color3.fromRGB(200, 130, 40)
		else
			actionText = `{def.price} очков`
			actionColor = if data and data.points >= def.price
				then Color3.fromRGB(60, 130, 220)
				else Color3.fromRGB(90, 94, 110)
		end
		local action = pill(card, actionText, actionColor, UDim2.new(1, -16, 0, 40), UDim2.new(0, 8, 1, -48))
		action.Activated:Connect(function()
			if worn then
				Remotes.ShopRequest:FireServer("EquipCosmetic", def.kind, "")
			elseif owned then
				Remotes.ShopRequest:FireServer("EquipCosmetic", def.kind, def.id)
			else
				Remotes.ShopRequest:FireServer("BuyCosmetic", def.id)
			end
		end)
		card.Parent = grid
	end
end

local function toggle(visible: boolean?)
	panel.Visible = if visible ~= nil then visible else not panel.Visible
	if panel.Visible then
		render()
		UI.popIn(panel)
	end
end

function WardrobeController.start()
	local gui = UI.screen("Wardrobe", 9)
	panel = UI.panel("Panel", gui, UDim2.fromScale(0.72, 0.78), UDim2.fromScale(0.5, 0.52), Vector2.new(0.5, 0.5))
	UI.sizeLimit(panel, Vector2.new(320, 320), Vector2.new(760, 560))
	UI.padding(panel, 12)
	panel.BackgroundTransparency = 0.05
	UI.gradient(panel, Color3.fromRGB(70, 44, 80), Color3.fromRGB(20, 18, 30))
	UI.stroke(panel, Color3.fromRGB(255, 170, 210), 2.5, 0.25)
	panel.Visible = false
	UI.label({
		name = "Title",
		parent = panel,
		text = "Гардероб",
		size = UDim2.new(1, -60, 0, 36),
		maxTextSize = 32,
	})
	pointsLabel = UI.label({
		name = "Points",
		parent = panel,
		size = UDim2.new(1, -60, 0, 22),
		position = UDim2.fromOffset(0, 36),
		color = UI.Colors.Gold,
		maxTextSize = 20,
	})
	local close = pill(panel, "✕", Color3.fromRGB(170, 70, 90), UDim2.fromOffset(44, 44), UDim2.new(1, -44, 0, 0))
	close.Activated:Connect(function()
		toggle(false)
	end)
	for index, kind in Cosmetics.Kinds do
		local b = pill(
			panel,
			Cosmetics.KindNames[kind],
			Color3.fromRGB(80, 78, 104),
			UDim2.new(1 / #Cosmetics.Kinds, -8, 0, 40),
			UDim2.new((index - 1) / #Cosmetics.Kinds, 4, 0, 64)
		)
		b.Activated:Connect(function()
			tab = kind
			render()
		end)
		tabButtons[kind] = b
	end
	grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(0, 114)
	grid.Size = UDim2.new(1, 0, 1, -114)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ScrollBarThickness = 8
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(140, CARD_HEIGHT)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	grid.Parent = panel

	-- Lobby button under МАГАЗИН / НАБОР.
	openButton = pill(
		gui,
		"ГАРДЕРОБ",
		Color3.fromRGB(210, 100, 160),
		UDim2.fromOffset(150, 56),
		UDim2.new(0, 12, 0.55, 75)
	)
	openButton.Activated:Connect(function()
		toggle()
	end)
	gui.Parent = player:WaitForChild("PlayerGui")

	Remotes.PlayerData.OnClientEvent:Connect(function(data: Types.DataSnapshot)
		snapshot = data
		if panel.Visible then
			render()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt:GetAttribute("Wardrobe") then
			toggle(true)
		end
	end)
	-- Like the shop, the wardrobe is for the lobby.
	task.spawn(function()
		while true do
			local busy = GameState.getRole(player) ~= "None"
			openButton.Visible = not busy
			if busy and panel.Visible then
				toggle(false)
			end
			task.wait(0.25)
		end
	end)
end

return WardrobeController
