--!strict
-- Lobby furniture: a stand for every ability (a spinning display model, its name and price, a
-- prompt that opens its card), the top-100 boards, the wardrobe booth and the personal stats board.
-- Boards and prompts carry tags/attributes; the clients draw the screens and open the windows.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local AbilityModels = require(script.Parent.AbilityModels)
local Build = require(script.Parent.Build)
local LobbyDecor = require(script.Parent.LobbyDecor)

local LobbyConfig = GameConfig.Lobby
local deco = LobbyDecor.part
local PASTEL = LobbyDecor.Pastel

local LobbyFurniture = {}

local WOOD = Color3.fromRGB(196, 160, 125)
local WHITE = Color3.fromRGB(250, 248, 252)

-- A prompt players use to open a window on their screen (the client reacts to the attributes).
local function prompt(parent: BasePart, action: string, object: string, attribute: string, value: string)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p:SetAttribute(attribute, value)
	p.Parent = parent
end

-- Ability stands -------------------------------------------------------------------------------

local function abilityStand(model: Model, def: any, at: CFrame, accent: Color3)
	-- `at` is the floor point; its look vector faces the lobby centre.
	Build.pillar("StandBase", at, 0.6, 7, 0.6, WHITE, Enum.Material.SmoothPlastic, model)
	local column = Build.pillar("StandColumn", at, 3.2, 4, 2.6, accent, Enum.Material.SmoothPlastic, model)
	Build.pillar("StandTop", at, 3.5, 5, 0.3, WHITE, Enum.Material.SmoothPlastic, model)
	local display = AbilityModels.build(def.id, at * CFrame.new(0, 6, 0), model)
	if display then
		display:SetAttribute("Spin", 0.8)
		CollectionService:AddTag(display, "LobbySpinModel")
	end
	local billboard = Build.billboard(column, 7.6, Vector2.new(8, 2.6))
	billboard.MaxDistance = 60
	Build.textLabel("Name", billboard, def.name, Color3.new(1, 1, 1), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.6))
	Build.textLabel(
		"Price",
		billboard,
		`{def.price} очков`,
		Color3.fromRGB(255, 220, 120),
		UDim2.fromScale(0, 0.6),
		UDim2.fromScale(1, 0.4)
	)
	prompt(column, "Посмотреть", def.name, "AbilityCard", def.id)
end

local function abilityStands(model: Model, origin: Vector3)
	for _, role in { "Runner", "Trapper" } do
		local side = if role == "Runner" then -1 else 1
		local accent = if role == "Runner" then Color3.fromRGB(150, 205, 255) else Color3.fromRGB(255, 165, 165)
		local index = 0
		for _, def in Abilities.list do
			if def.role == role then
				local position = origin
					+ Vector3.new(
						side * LobbyConfig.AbilityStandX,
						0,
						LobbyConfig.AbilityStandFirstZ + index * LobbyConfig.AbilityStandSpacing
					)
				local facing = position + Vector3.new(-side, 0, 0)
				abilityStand(model, def, CFrame.lookAt(position, facing), accent)
				index += 1
			end
		end
		-- A sign over the row.
		local sign = deco({
			name = "RowSign",
			size = Vector3.new(0.5, 4, 24),
			cframe = CFrame.new(origin + Vector3.new(side * (LobbyConfig.FloorSize / 2 - 0.6), 15, -2)),
			color = accent,
			parent = model,
		})
		Build.sign(
			sign,
			if side < 0 then Enum.NormalId.Right else Enum.NormalId.Left,
			if role == "Runner"
				then "СПОСОБНОСТИ РАННЕРА"
				else "СПОСОБНОСТИ ТРАПЕРА",
			Color3.fromRGB(60, 60, 80)
		)
	end
end

-- Boards ------------------------------------------------------------------------------------------

-- A framed screen standing on two legs, facing +Z (facing = 1) or -Z (facing = -1). The client
-- draws on the "Screen" part; its attribute "Face" names the side to draw on.
local function board(
	model: Model,
	origin: Vector3,
	offset: Vector3,
	tag: string,
	kind: string,
	color: Color3,
	facing: number
): BasePart
	local center = origin + offset + Vector3.new(0, 15, 0)
	for _, x in { -10, 10 } do
		deco({
			name = "Leg",
			size = Vector3.new(1, 15, 1),
			cframe = CFrame.new(origin + offset + Vector3.new(x, 7.5, 0)),
			color = WHITE,
			canCollide = true,
			parent = model,
		})
	end
	deco({
		name = "Frame",
		size = Vector3.new(23, 25, 1),
		cframe = CFrame.new(center),
		color = color,
		canCollide = true,
		parent = model,
	})
	local screen = deco({
		name = "Screen",
		size = Vector3.new(21, 23, 0.2),
		cframe = CFrame.new(center + Vector3.new(0, 0, 0.6 * facing)),
		color = Color3.fromRGB(34, 32, 48),
		parent = model,
	})
	screen:SetAttribute("Kind", kind)
	screen:SetAttribute("Face", if facing > 0 then "Back" else "Front")
	CollectionService:AddTag(screen, tag)
	return screen
end

-- Wardrobe booth ------------------------------------------------------------------------------------

local function wardrobe(model: Model, origin: Vector3)
	local base = CFrame.lookAt(origin + LobbyConfig.WardrobeOffset, origin) -- opens towards the centre
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	deco({
		name = "Back",
		size = Vector3.new(14, 12, 0.8),
		cframe = at(0, 6, 4),
		color = WOOD,
		canCollide = true,
		parent = model,
	})
	for _, x in { -7, 7 } do
		deco({
			name = "Side",
			size = Vector3.new(0.8, 12, 8),
			cframe = at(x, 6, 0.4),
			color = WOOD,
			canCollide = true,
			parent = model,
		})
	end
	deco({
		name = "Roof",
		size = Vector3.new(15.6, 0.8, 9),
		cframe = at(0, 12.4, 0.4),
		color = PASTEL[1],
		parent = model,
	})
	deco({
		name = "Rail",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(12, 0.3, 0.3),
		cframe = at(0, 9.5, 2.5),
		color = Color3.fromRGB(200, 200, 210),
		parent = model,
	})
	-- Shirts hanging on the rail.
	for index, color in { PASTEL[2], PASTEL[3], PASTEL[4], PASTEL[5] } do
		local x = -4.5 + (index - 1) * 3
		deco({ name = "Shirt", size = Vector3.new(2, 2.6, 0.3), cframe = at(x, 8, 2.5), color = color, parent = model })
		deco({
			name = "Sleeves",
			size = Vector3.new(3, 0.8, 0.3),
			cframe = at(x, 8.9, 2.5),
			color = color,
			parent = model,
		})
	end
	local mirror = deco({
		name = "Mirror",
		size = Vector3.new(3.4, 6, 0.2),
		cframe = at(-5, 4, 3.5),
		color = Color3.fromRGB(200, 225, 240),
		parent = model,
	})
	mirror.Material = Enum.Material.Glass
	mirror.Reflectance = 0.4
	local sign = deco({
		name = "WardrobeSign",
		size = Vector3.new(10, 2.2, 0.4),
		cframe = at(0, 14, -3.5),
		color = WHITE,
		parent = model,
	})
	Build.sign(sign, Enum.NormalId.Front, "ГАРДЕРОБ", Color3.fromRGB(200, 90, 140))
	local counter = deco({
		name = "Counter",
		size = Vector3.new(6, 3, 2),
		cframe = at(2.5, 1.5, 1),
		color = PASTEL[3],
		canCollide = true,
		parent = model,
	})
	prompt(counter, "Открыть", "Гардероб", "Wardrobe", "Open")
end

function LobbyFurniture.build(model: Model)
	local origin = LobbyConfig.Origin
	abilityStands(model, origin)
	board(model, origin, LobbyConfig.PointsBoardOffset, "Leaderboard", "Points", PASTEL[2], 1)
	board(model, origin, LobbyConfig.WinsBoardOffset, "Leaderboard", "Wins", PASTEL[3], 1)
	board(model, origin, LobbyConfig.StatsBoardOffset, "StatsBoard", "Stats", PASTEL[4], -1)
	wardrobe(model, origin)
end

return LobbyFurniture
