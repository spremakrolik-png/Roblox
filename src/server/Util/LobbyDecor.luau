--!strict
-- Decoration for the placeholder lobby in soft pastel colours: floor tiles, a stripe along the
-- walls, striped corner towers with lamps, rims around the role circles and slowly spinning shapes.
-- Purely visual: nothing here collides except the towers in the far corners.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Build = require(script.Parent.Build)

local LobbyConfig = GameConfig.Lobby

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local TILE_COLORS = {
	Color3.fromRGB(236, 232, 245),
	Color3.fromRGB(222, 228, 243),
}
local PASTEL = {
	Color3.fromRGB(255, 176, 200),
	Color3.fromRGB(255, 222, 150),
	Color3.fromRGB(160, 214, 255),
	Color3.fromRGB(176, 230, 186),
	Color3.fromRGB(206, 182, 255),
}

local LobbyDecor = {}

local function deco(props: Build.PartProps): Part
	props.canCollide = if props.canCollide == nil then false else props.canCollide
	props.canTouch = false
	props.canQuery = false
	props.material = props.material or Enum.Material.SmoothPlastic
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
				size = Vector3.new(tile - 0.3, 0.05, tile - 0.3),
				cframe = CFrame.new(center),
				color = TILE_COLORS[(x + z) % 2 + 1],
				castShadow = false,
				parent = model,
			})
		end
	end
end

local function wallStripes(model: Model, origin: Vector3, size: number, height: number)
	for index, side in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local alongX = side.Z ~= 0
		local color = PASTEL[(index - 1) % #PASTEL + 1]
		for _, spec in { { y = 1.5, h = 3 }, { y = height - 1, h = 2 } } do
			deco({
				name = "WallStripe",
				size = if alongX then Vector3.new(size, spec.h, 0.3) else Vector3.new(0.3, spec.h, size),
				cframe = CFrame.new(origin + side * (size / 2 - 0.15) + Vector3.new(0, spec.y, 0)),
				color = color,
				castShadow = false,
				parent = model,
			})
		end
	end
end

local function towers(model: Model, origin: Vector3, size: number, height: number)
	local half = size / 2 - 3
	local corners = {
		Vector3.new(half, 0, half),
		Vector3.new(-half, 0, half),
		Vector3.new(half, 0, -half),
		Vector3.new(-half, 0, -half),
	}
	for index, corner in corners do
		local color = PASTEL[index]
		local base = CFrame.new(origin + corner)
		Build.pillar(
			"Tower",
			base,
			height + 4,
			5,
			height + 4,
			Color3.fromRGB(250, 248, 252),
			Enum.Material.SmoothPlastic,
			model
		)
		for stripe = 1, 4 do
			deco({
				name = "Stripe",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(1.2, 5.2, 5.2),
				cframe = base * CFrame.new(0, stripe * (height / 4), 0) * CFrame.Angles(0, 0, math.pi / 2),
				color = color,
				parent = model,
			})
		end
		local lamp = deco({
			name = "TowerLamp",
			shape = Enum.PartType.Ball,
			size = Vector3.one * 3,
			cframe = base * CFrame.new(0, height + 5.5, 0),
			color = color,
			castShadow = false,
			parent = model,
		})
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 20
		light.Brightness = 0.8
		light.Parent = lamp
	end
end

-- A white rim and a few drifting sparkles around a role circle.
local function circleRim(model: Model, center: Vector3, radius: number, color: Color3)
	deco({
		name = "CircleRim",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.3, radius * 2 + 1.2, radius * 2 + 1.2),
		cframe = CFrame.new(center + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color = Color3.new(1, 1, 1),
		castShadow = false,
		parent = model,
	})
	local emitter = deco({
		name = "CircleSparkles",
		size = Vector3.new(radius * 1.6, 0.2, radius * 1.6),
		cframe = CFrame.new(center + Vector3.new(0, 0.5, 0)),
		transparency = 1,
		castShadow = false,
		parent = model,
	})
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = SPARKLES
	sparkles.Color = ColorSequence.new(color)
	sparkles.LightEmission = 0.3
	sparkles.Rate = 5
	sparkles.Lifetime = NumberRange.new(1.5, 2.5)
	sparkles.Speed = NumberRange.new(1.5, 3)
	sparkles.Size = NumberSequence.new(0.4, 0)
	sparkles.Transparency = NumberSequence.new(0.3, 1)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.SpreadAngle = Vector2.new(10, 10)
	sparkles.Parent = emitter
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
		local radius = size * 0.3
		local part = deco({
			name = "Floater",
			shape = shape,
			size = Vector3.one * (if shape == Enum.PartType.Ball then 3.5 else 2.8),
			cframe = CFrame.new(
				origin + Vector3.new(math.cos(angle) * radius, LobbyConfig.WallHeight - 5, math.sin(angle) * radius)
			) * CFrame.Angles(0.6, angle, 0.3),
			color = PASTEL[(index - 1) % #PASTEL + 1],
			castShadow = false,
			parent = model,
		})
		part:SetAttribute("Spin", 0.4 + (index % 3) * 0.2)
		CollectionService:AddTag(part, "LobbySpin")
	end
end

function LobbyDecor.decorate(model: Model)
	local origin = LobbyConfig.Origin
	local size = LobbyConfig.FloorSize
	local height = LobbyConfig.WallHeight
	floorTiles(model, origin, size)
	wallStripes(model, origin, size, height)
	towers(model, origin, size, height)
	circleRim(model, origin + LobbyConfig.RunnerCircleOffset, LobbyConfig.CircleRadius, LobbyConfig.RunnerColor)
	circleRim(model, origin + LobbyConfig.TrapperCircleOffset, LobbyConfig.CircleRadius, LobbyConfig.TrapperColor)
	floaters(model, origin, size)
end

-- Shared look for lobby furniture (stands, boards, the wardrobe).
LobbyDecor.Pastel = PASTEL
LobbyDecor.part = deco

return LobbyDecor
