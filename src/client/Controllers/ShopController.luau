--!strict
-- Lobby buttons "МАГАЗИН" (abilities for Points or Robux, game passes, Points packs) and "НАБОР"
-- (pick which owned abilities go into the Runner and Trapper slots). The server owns the data; this
-- only shows it, sends requests and opens Roblox purchase prompts.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Icons = require(script.Parent.Parent.Util.Icons)
local UI = require(script.Parent.Parent.Util.UI)
local SoundController = require(script.Parent.SoundController)

local ROLES: { "Runner" | "Trapper" } = { "Runner", "Trapper" }
local ROLE_NAMES = { Runner = "РАННЕР", Trapper = "ТРАПЕР" }
local ROW_HEIGHT = 64
local ROBUX_COLOR = Color3.fromRGB(30, 150, 90)
local POINTS_COLOR = Color3.fromRGB(40, 110, 160)

local player = Players.LocalPlayer

local ShopController = {}

local snapshot: Types.DataSnapshot? = nil
local selectedSlot: { role: "Runner" | "Trapper", slot: number }? = nil

local openButtons: Frame
local shopPanel: Frame
local loadoutPanel: Frame
local shopList: ScrollingFrame
local loadoutList: ScrollingFrame
local pointsLabels: { TextLabel } = {}
local toast: TextLabel

local function makeButton(parent: Instance, text: string, size: UDim2, color: Color3?): TextButton
	local button = Instance.new("TextButton")
	button.Text = text
	button.Font = Enum.Font.SourceSansBold
	button.TextScaled = true
	button.TextColor3 = UI.Colors.Text
	button.BackgroundColor3 = color or Color3.fromRGB(45, 50, 66)
	button.Size = size
	button.AutoButtonColor = false
	button.TextStrokeTransparency = 0.6
	local base = button.BackgroundColor3
	UI.corner(button, 10)
	UI.gradient(button, base:Lerp(Color3.new(1, 1, 1), 0.18), base:Lerp(Color3.new(0, 0, 0), 0.22))
	UI.stroke(button, Color3.new(1, 1, 1), 1.5, 0.65)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 22
	constraint.Parent = button
	UI.pressable(button)
	button.Activated:Connect(function()
		SoundController.play("Click")
	end)
	button.Parent = parent
	return button
end

local function owns(id: string): boolean
	return snapshot ~= nil and table.find(snapshot.owned, id) ~= nil
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function makePanel(name: string, title: string, gui: ScreenGui): (Frame, ScrollingFrame)
	local panel = UI.panel(name, gui, UDim2.fromScale(0.72, 0.78), UDim2.fromScale(0.5, 0.52), Vector2.new(0.5, 0.5))
	UI.sizeLimit(panel, Vector2.new(320, 300), Vector2.new(760, 560))
	UI.padding(panel, 12)
	panel.BackgroundTransparency = 0.05
	UI.gradient(panel, Color3.fromRGB(46, 38, 76), Color3.fromRGB(16, 18, 30))
	UI.stroke(panel, Color3.fromRGB(255, 150, 200), 2.5, 0.25)
	panel.Visible = false
	UI.label({ name = "Title", parent = panel, text = title, size = UDim2.new(1, -60, 0, 36), maxTextSize = 32 })
	table.insert(
		pointsLabels,
		UI.label({
			name = "Points",
			parent = panel,
			size = UDim2.new(1, -60, 0, 24),
			position = UDim2.fromOffset(0, 38),
			color = UI.Colors.Gold,
			maxTextSize = 22,
		})
	)
	local close = makeButton(panel, "X", UDim2.fromOffset(48, 48), Color3.fromRGB(150, 50, 60))
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(0, 70)
	list.Size = UDim2.new(1, 0, 1, -70)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 8
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list
	list.Parent = panel
	return panel, list
end

local function header(parent: Instance, order: number, text: string, color: Color3)
	local label = UI.label({
		name = "Header",
		parent = parent,
		text = text,
		size = UDim2.new(1, -12, 0, 30),
		color = color,
		alignX = Enum.TextXAlignment.Left,
		maxTextSize = 26,
	})
	label.LayoutOrder = order
end

-- Shop ------------------------------------------------------------------------------

-- A card with an icon tile on the left.
local function newRow(name: string, order: number, icon: Icons.Icon): Frame
	local row = Instance.new("Frame")
	row.Name = name
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -12, 0, ROW_HEIGHT)
	row.BackgroundColor3 = Color3.fromRGB(34, 36, 54)
	row.BorderSizePixel = 0
	UI.corner(row, 10)
	UI.gradient(row, Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 215))
	UI.stroke(row, icon.color, 1.5, 0.55)
	UI.iconTile(row, icon.glyph, icon.color, UDim2.fromOffset(ROW_HEIGHT - 12, ROW_HEIGHT - 12), UDim2.fromOffset(6, 6))
	return row
end

local function rowText(row: Frame, title: string, description: string, width: number)
	UI.label({
		name = "Name",
		parent = row,
		text = title,
		size = UDim2.new(width, -ROW_HEIGHT, 0.5, 0),
		position = UDim2.fromOffset(ROW_HEIGHT, 2),
		alignX = Enum.TextXAlignment.Left,
		maxTextSize = 22,
	})
	UI.label({
		name = "Description",
		parent = row,
		text = description,
		size = UDim2.new(width, -ROW_HEIGHT, 0.45, 0),
		position = UDim2.new(0, ROW_HEIGHT, 0.5, 0),
		color = UI.Colors.Muted,
		font = Enum.Font.SourceSansSemibold,
		alignX = Enum.TextXAlignment.Left,
		maxTextSize = 18,
	})
end

-- Game passes and Points packs. Anything without a real id is not shown.
local function renderRobux(order: number): number
	local passes: { Monetization.PassDef } = {}
	for _, def in Monetization.Passes do
		if def.assetId ~= 0 then
			table.insert(passes, def)
		end
	end
	local packs: { Monetization.PointsPack } = {}
	for _, pack in Monetization.PointsPacks do
		if pack.productId ~= 0 then
			table.insert(packs, pack)
		end
	end
	local secondChance = Monetization.SecondChance
	if #passes == 0 and #packs == 0 and secondChance.productId == 0 then
		return order
	end
	order += 1
	header(shopList, order, "ROBUX", UI.Colors.Gold)
	for _, def in passes do
		order += 1
		local row = newRow(def.id, order, Icons.Passes[def.id] or Icons.Unknown)
		rowText(row, def.name, def.description, 0.65)
		local owned = player:GetAttribute(Monetization.attribute(def.id)) == true
		local button = makeButton(
			row,
			if owned then "Куплено" else `R$ {def.robux}`,
			UDim2.new(0.33, -8, 1, -12),
			if owned then Color3.fromRGB(60, 64, 76) else ROBUX_COLOR
		)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -6, 0.5, 0)
		button.AutoButtonColor = not owned
		if not owned then
			local assetId = def.assetId
			button.Activated:Connect(function()
				MarketplaceService:PromptGamePassPurchase(player, assetId)
			end)
		end
		row.Parent = shopList
	end
	for index, pack in packs do
		order += 1
		local row = newRow(`Pack{index}`, order, Icons.Points)
		rowText(row, `{pack.points} очков`, "Сразу на счёт", 0.65)
		local button = makeButton(row, `R$ {pack.robux}`, UDim2.new(0.33, -8, 1, -12), ROBUX_COLOR)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -6, 0.5, 0)
		local productId = pack.productId
		button.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
		row.Parent = shopList
	end
	if secondChance.productId ~= 0 then
		order += 1
		local row = newRow("SecondChance", order, Icons.SecondChance)
		local have = if snapshot then snapshot.secondChances else 0
		rowText(
			row,
			"Второй шанс",
			`Вернуться на чекпоинт после смерти. Есть: {have}`,
			0.65
		)
		local button = makeButton(row, `R$ {secondChance.robux}`, UDim2.new(0.33, -8, 1, -12), ROBUX_COLOR)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -6, 0.5, 0)
		button.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(player, secondChance.productId)
		end)
		row.Parent = shopList
	end
	return order
end

local function renderShop()
	clear(shopList)
	local order = renderRobux(0)
	for _, role in ROLES do
		order += 1
		header(shopList, order, ROLE_NAMES[role], if role == "Runner" then UI.Colors.Runner else UI.Colors.Trapper)
		for _, def in Abilities.list do
			if def.role ~= role then
				continue
			end
			order += 1
			local owned = owns(def.id)
			local product = Monetization.AbilityProducts[def.id]
			local robux = not owned and product ~= nil and product.productId ~= 0
			local row = newRow(def.id, order, Icons.ability(def.id))
			rowText(row, def.name, def.description, if robux then 0.5 else 0.65)
			local buy = makeButton(
				row,
				if owned then "Куплено" else `{def.price} очков`,
				UDim2.new(if robux then 0.24 else 0.33, -8, 1, -12),
				if owned then Color3.fromRGB(60, 64, 76) else POINTS_COLOR
			)
			buy.AnchorPoint = Vector2.new(1, 0.5)
			buy.Position = UDim2.new(1, -6, 0.5, 0)
			buy.AutoButtonColor = not owned
			if not owned then
				buy.Activated:Connect(function()
					Remotes.ShopRequest:FireServer("Buy", def.id)
				end)
			end
			if robux and product then
				local productId = product.productId
				local robuxButton = makeButton(row, `R$ {product.robux}`, UDim2.new(0.24, -8, 1, -12), ROBUX_COLOR)
				robuxButton.AnchorPoint = Vector2.new(1, 0.5)
				robuxButton.Position = UDim2.new(0.76, -6, 0.5, 0)
				robuxButton.Activated:Connect(function()
					MarketplaceService:PromptProductPurchase(player, productId)
				end)
			end
			row.Parent = shopList
		end
	end
end

-- Loadout ---------------------------------------------------------------------------

local function renderLoadout()
	clear(loadoutList)
	local data = snapshot
	if not data then
		return
	end
	local order = 0
	for _, role in ROLES do
		order += 1
		header(
			loadoutList,
			order,
			`{ROLE_NAMES[role]}: слоты`,
			if role == "Runner" then UI.Colors.Runner else UI.Colors.Trapper
		)

		order += 1
		local slotsRow = Instance.new("Frame")
		slotsRow.Name = `{role}Slots`
		slotsRow.LayoutOrder = order
		slotsRow.BackgroundTransparency = 1
		slotsRow.Size = UDim2.new(1, -12, 0, ROW_HEIGHT)
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 8)
		layout.Parent = slotsRow
		local loadout = Abilities.loadoutOf(data.loadouts, role)
		local current = selectedSlot
		for slot = 1, data.slots do
			local id = loadout[slot] or ""
			local def = Abilities.byId[id]
			local selected = current ~= nil and current.role == role and current.slot == slot
			local button = makeButton(
				slotsRow,
				if def then `{Icons.ability(def.id).glyph} {def.name}` else `{slot}. Пусто`,
				UDim2.new(1 / data.slots, -8, 1, 0),
				if selected then Color3.fromRGB(200, 150, 40) else Color3.fromRGB(45, 50, 66)
			)
			button.Activated:Connect(function()
				selectedSlot = { role = role, slot = slot }
				renderLoadout()
			end)
		end
		slotsRow.Parent = loadoutList

		local selection = selectedSlot
		if selection and selection.role == role then
			order += 1
			local choices = Instance.new("Frame")
			choices.Name = `{role}Choices`
			choices.LayoutOrder = order
			choices.BackgroundTransparency = 1
			choices.AutomaticSize = Enum.AutomaticSize.Y
			choices.Size = UDim2.new(1, -12, 0, 0)
			local grid = Instance.new("UIGridLayout")
			grid.CellSize = UDim2.new(0.5, -6, 0, 44)
			grid.CellPadding = UDim2.fromOffset(6, 6)
			grid.SortOrder = Enum.SortOrder.LayoutOrder
			grid.Parent = choices
			local any = false
			for _, def in Abilities.list do
				if def.role == role and owns(def.id) then
					any = true
					local choice = makeButton(
						choices,
						`{Icons.ability(def.id).glyph} {def.name}`,
						UDim2.new(),
						Icons.ability(def.id).color:Lerp(Color3.new(0, 0, 0), 0.35)
					)
					choice.Activated:Connect(function()
						Remotes.ShopRequest:FireServer("Equip", role, selection.slot, def.id)
						selectedSlot = nil
					end)
				end
			end
			local remove = makeButton(choices, "Снять", UDim2.new(), Color3.fromRGB(120, 60, 60))
			remove.LayoutOrder = 1000
			remove.Activated:Connect(function()
				Remotes.ShopRequest:FireServer("Equip", role, selection.slot, "")
				selectedSlot = nil
			end)
			if not any then
				local hint = UI.label({
					name = "Hint",
					parent = choices,
					text = "Купи способности в магазине",
					size = UDim2.new(),
					color = UI.Colors.Muted,
				})
				hint.LayoutOrder = 999
			end
			choices.Parent = loadoutList
		end
	end
end

local function render()
	local points = if snapshot then snapshot.points else 0
	for _, label in pointsLabels do
		label.Text = `Очки: {points}`
	end
	renderShop()
	renderLoadout()
end

local function showToast(ok: boolean, message: string)
	toast.Text = message
	toast.TextColor3 = if ok then UI.Colors.Runner else UI.Colors.Death
	toast.Visible = true
	local shown = message
	task.delay(2.5, function()
		if toast.Text == shown then
			toast.Visible = false
		end
	end)
end

function ShopController.start()
	local gui = UI.screen("Shop", 9)

	openButtons = Instance.new("Frame")
	openButtons.Name = "OpenButtons"
	openButtons.BackgroundTransparency = 1
	openButtons.AnchorPoint = Vector2.new(0, 0.5)
	openButtons.Position = UDim2.new(0, 12, 0.55, 0)
	openButtons.Size = UDim2.fromOffset(150, 130)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.Parent = openButtons
	openButtons.Parent = gui
	local shopButton = makeButton(openButtons, "МАГАЗИН", UDim2.fromOffset(150, 56), Color3.fromRGB(40, 170, 90))
	local loadoutButton = makeButton(openButtons, "НАБОР", UDim2.fromOffset(150, 56), Color3.fromRGB(60, 120, 220))

	shopPanel, shopList = makePanel("ShopPanel", "Магазин способностей", gui)
	loadoutPanel, loadoutList = makePanel("LoadoutPanel", "Набор способностей", gui)

	toast = UI.label({
		name = "Toast",
		parent = gui,
		size = UDim2.new(0.6, 0, 0, 36),
		position = UDim2.fromScale(0.5, 0.1),
		anchor = Vector2.new(0.5, 0),
		maxTextSize = 28,
	})
	toast.Visible = false
	gui.Parent = player:WaitForChild("PlayerGui")

	shopButton.Activated:Connect(function()
		loadoutPanel.Visible = false
		shopPanel.Visible = not shopPanel.Visible
		if shopPanel.Visible then
			UI.popIn(shopPanel)
		end
	end)
	loadoutButton.Activated:Connect(function()
		shopPanel.Visible = false
		selectedSlot = nil
		renderLoadout()
		loadoutPanel.Visible = not loadoutPanel.Visible
		if loadoutPanel.Visible then
			UI.popIn(loadoutPanel)
		end
	end)

	Remotes.PlayerData.OnClientEvent:Connect(function(data: Types.DataSnapshot)
		snapshot = data
		render()
	end)
	Remotes.ShopResult.OnClientEvent:Connect(function(ok: boolean, message: string)
		showToast(ok, message)
	end)
	player.AttributeChanged:Connect(function(name: string)
		if string.sub(name, 1, 5) == "Pass_" then
			renderShop()
		end
	end)

	-- The shop is for the lobby: hidden while the player has a role in a round.
	task.spawn(function()
		while true do
			local busy = GameState.getRole(player) ~= "None"
			openButtons.Visible = not busy
			if busy then
				shopPanel.Visible = false
				loadoutPanel.Visible = false
			end
			task.wait(0.25)
		end
	end)
	render()
end

return ShopController
