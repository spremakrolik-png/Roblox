--!strict
-- Decoration for the placeholder lobby: pastel floor tiles, neon trims, corner towers with lights,
-- light columns over the role circles, a title sign and floating shapes. Purely visual: nothing here
-- collides with players except the floor tiles, which are flush with the floor.

local CollectionService = game:GetService("CollectionService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Build = require(script.Parent.Build)

local LobbyConfig = GameConfig.Lobby

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local TILE_COLORS = {
	Color3.fromRGB(62, 58, 92),
	Color3.fromRGB(52, 66, 96),
}
local CANDY = {
	Color3.fromRGB(255, 120, 170),
	Color3.fromRGB(255, 205, 90),
	Color3.fromRGB(120, 215, 255),
	Color3.fromRGB(150, 235, 160),
	Color3.fromRGB(200, 150, 255),
}

local LobbyDecor = {}

local function deco(props: Build.PartProps): Part
	props.canCollide = if props.canCollide == nil then false else props.canCollide
	props.canTouch = false
	props.canQuery = false
	return Build.part(props)
end

local function floorTiles(model: Model, origin: Vector3, size: number)
	local count = 7
	local tile = size / count
	for x = 0, count - 1 do
		for z = 0, count - 1 do
			local center = origin + Vector3.new(-size / 2 + tile * (x + 0.5), 0.01, -size / 2 + tile * (z + 0.5))
			deco({
				name = "Tile",
				size = Vector3.new(tile - 0.6, 0.05, tile - 0.6),
				cframe = CFrame.new(center),
				color = TILE_COLORS[(x + z) % 2 + 1],
				material = Enum.Material.SmoothPlastic,
				castShadow = false,
				parent = model,
			})
		end
	end
end

local function wallTrims(model: Model, origin: Vector3, size: number, height: number)
	for index, side in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local alongX = side.Z ~= 0
		local color = CANDY[(index - 1) % #CANDY + 1]
		for _, y in { 0.6, height - 0.6 } do
			deco({
				name = "Trim",
				size = if alongX then Vector3.new(size, 0.6, 0.4) else Vector3.new(0.4, 0.6, size),
				cframe = CFrame.new(origin + side * (size / 2 - 0.2) + Vector3.new(0, y, 0)),
				color = color,
				material = Enum.Material.Neon,
				castShadow = false,
				parent = model,
			})
		end
	end
end

local function towers(model: Model, origin: Vector3, size: number, height: number)
	local half = size / 2 - 3
	for index, corner in
		{
			Vector3.new(half, 0, half),
			Vector3.new(-half, 0, half),
			Vector3.new(half, 0, -half),
			Vector3.new(-half, 0, -half),
		}
	do
		local color = CANDY[index]
		local base = CFrame.new(origin + corner)
		Build.pillar(
			"Tower",
			base,
			height + 4,
			5,
			height + 4,
			Color3.fromRGB(240, 240, 250),
			Enum.Material.SmoothPlastic,
			model
		)
		for stripe = 1, 4 do
			deco({
				name = "Stripe",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(1, 5.2, 5.2),
				cframe = base * CFrame.new(0, stripe * (height / 4), 0) * CFrame.Angles(0, 0, math.pi / 2),
				color = color,
				material = Enum.Material.SmoothPlastic,
				parent = model,
			})
		end
		local cap = deco({
			name = "TowerLight",
			shape = Enum.PartType.Ball,
			size = Vector3.one * 4,
			cframe = base * CFrame.new(0, height + 6, 0),
			color = color,
			material = Enum.Material.Neon,
			castShadow = false,
			parent = model,
		})
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 40
		light.Brightness = 2
		light.Parent = cap
	end
end

-- A soft light column and rising sparkles over a role circle.
local function circleGlow(model: Model, center: Vector3, radius: number, color: Color3)
	deco({
		name = "CircleRing",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.3, radius * 2 + 1.6, radius * 2 + 1.6),
		cframe = CFrame.new(center + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color = Color3.new(1, 1, 1),
		material = Enum.Material.Neon,
		castShadow = false,
		parent = model,
	})
	local column = deco({
		name = "LightColumn",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(22, radius * 2, radius * 2),
		cframe = CFrame.new(center + Vector3.new(0, 11, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color = color,
		material = Enum.Material.Neon,
		transparency = 0.9,
		castShadow = false,
		parent = model,
	})
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = SPARKLES
	sparkles.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	sparkles.LightEmission = 1
	sparkles.Rate = 18
	sparkles.Lifetime = NumberRange.new(1.5, 2.5)
	sparkles.Speed = NumberRange.new(3, 6)
	sparkles.Size = NumberSequence.new(0.7, 0)
	sparkles.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis points up
	sparkles.SpreadAngle = Vector2.new(15, 15)
	sparkles.Parent = column
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 24
	light.Brightness = 1.5
	light.Parent = column
end

local function titleSign(model: Model, origin: Vector3, size: number)
	local sign = deco({
		name = "TitleSign",
		size = Vector3.new(60, 12, 1),
		cframe = CFrame.new(origin + Vector3.new(0, LobbyConfig.WallHeight - 8, -size / 2 + 1.5)),
		color = Color3.fromRGB(30, 26, 48),
		material = Enum.Material.SmoothPlastic,
		parent = model,
	})
	local label = Build.sign(sign, Enum.NormalId.Back, "TRAP RUNNER", Color3.fromRGB(255, 220, 90))
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(255, 90, 150)
	label.Font = Enum.Font.FredokaOne
	deco({
		name = "SignGlow",
		size = Vector3.new(62, 14, 0.4),
		cframe = sign.CFrame * CFrame.new(0, 0, -0.7), -- behind the sign, towards the wall
		color = Color3.fromRGB(255, 120, 170),
		material = Enum.Material.Neon,
		castShadow = false,
		parent = model,
	})
end

-- Shapes floating high over the lobby; clients spin and bob them (tag "LobbySpin", speed in "Spin").
local function floaters(model: Model, origin: Vector3, size: number)
	local shapes = {
		Enum.PartType.Ball,
		Enum.PartType.Block,
		Enum.PartType.Ball,
		Enum.PartType.Block,
		Enum.PartType.Ball,
		Enum.PartType.Block,
	}
	for index, shape in shapes do
		local angle = (index / #shapes) * math.pi * 2
		local radius = size * 0.32
		local part = deco({
			name = "Floater",
			shape = shape,
			size = Vector3.one * (if shape == Enum.PartType.Ball then 4 else 3.2),
			cframe = CFrame.new(
				origin + Vector3.new(math.cos(angle) * radius, LobbyConfig.WallHeight - 4, math.sin(angle) * radius)
			) * CFrame.Angles(0.6, angle, 0.3),
			color = CANDY[(index - 1) % #CANDY + 1],
			material = Enum.Material.Neon,
			castShadow = false,
			parent = model,
		})
		part:SetAttribute("Spin", 0.6 + (index % 3) * 0.3)
		CollectionService:AddTag(part, "LobbySpin")
	end
end

function LobbyDecor.decorate(model: Model)
	local origin = LobbyConfig.Origin
	local size = LobbyConfig.FloorSize
	local height = LobbyConfig.WallHeight
	floorTiles(model, origin, size)
	wallTrims(model, origin, size, height)
	towers(model, origin, size, height)
	circleGlow(model, origin + LobbyConfig.RunnerCircleOffset, LobbyConfig.CircleRadius, LobbyConfig.RunnerColor)
	circleGlow(model, origin + LobbyConfig.TrapperCircleOffset, LobbyConfig.CircleRadius, LobbyConfig.TrapperColor)
	titleSign(model, origin, size)
	floaters(model, origin, size)
end

return LobbyDecor
