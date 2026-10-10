--!strict
-- Small display models of the abilities for the lobby stands, built from primitives. Each model is
-- about 4 studs across, anchored, with its pivot at its centre.

local AbilityModels = {}

type Builder = (model: Model, at: CFrame) -> ()

local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- cylinders run along their local X
local FORWARD = CFrame.Angles(0, math.pi / 2, 0) -- a cylinder pointing along -Z

local function piece(
	model: Model,
	cframe: CFrame,
	size: Vector3,
	color: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = "Piece"
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function wedge(model: Model, cframe: CFrame, size: Vector3, color: Color3): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = "Piece"
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = model
	return p
end

local BUILDERS: { [string]: Builder } = {
	FeatherFall = function(model, at)
		local canopy = piece(model, at * CFrame.new(0, 1.2, 0), Vector3.one, Color3.fromRGB(255, 150, 190))
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(4, 1.4, 4)
		mesh.Parent = canopy
		for _, x in { -1.3, 1.3 } do
			for _, z in { -1.3, 1.3 } do
				local from = Vector3.new(x * 0.2, -1.2, z * 0.2)
				local to = Vector3.new(x, 0.9, z)
				local length = (to - from).Magnitude
				piece(
					model,
					at * CFrame.lookAt((from + to) / 2, to),
					Vector3.new(0.06, 0.06, length),
					Color3.new(1, 1, 1)
				)
			end
		end
		piece(model, at * CFrame.new(0, -1.4, 0), Vector3.new(0.7, 0.6, 0.5), Color3.fromRGB(150, 110, 80))
	end,
	SpeedBurst = function(model, at)
		local color = Color3.fromRGB(255, 215, 80)
		piece(model, at * CFrame.new(0.35, 1, 0) * CFrame.Angles(0, 0, -0.5), Vector3.new(0.6, 2, 0.5), color)
		piece(model, at * CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 1.1), Vector3.new(0.5, 1.6, 0.5), color)
		piece(model, at * CFrame.new(-0.35, -1, 0) * CFrame.Angles(0, 0, -0.5), Vector3.new(0.6, 2, 0.5), color)
	end,
	DoubleJump = function(model, at)
		for index = 0, 4 do
			piece(
				model,
				at * CFrame.new(0, -1.4 + index * 0.6, 0) * UPRIGHT,
				Vector3.new(0.2, 1.6, 1.6),
				if index % 2 == 0 then Color3.fromRGB(120, 220, 150) else Color3.fromRGB(200, 240, 210),
				Enum.PartType.Cylinder
			)
		end
		piece(model, at * CFrame.new(0, 1.5, 0), Vector3.new(2, 0.3, 2), Color3.fromRGB(90, 190, 120))
	end,
	Dash = function(model, at)
		local color = Color3.fromRGB(160, 170, 255)
		piece(model, at * CFrame.new(0, 0, 0.6), Vector3.new(0.6, 0.6, 2.4), color)
		wedge(model, at * CFrame.new(0, 0.45, -1.1) * CFrame.Angles(0, math.pi, 0), Vector3.new(0.6, 0.9, 1.2), color)
		wedge(model, at * CFrame.new(0, -0.45, -1.1) * CFrame.Angles(math.pi, 0, 0), Vector3.new(0.6, 0.9, 1.2), color)
		for index = 1, 3 do
			piece(
				model,
				at * CFrame.new(0, (index - 2) * 0.5, 2.3 + index * 0.25),
				Vector3.new(0.15, 0.15, 0.6),
				Color3.new(1, 1, 1)
			)
		end
	end,
	Shield = function(model, at)
		piece(model, at * FORWARD, Vector3.new(0.35, 3, 3), Color3.fromRGB(255, 205, 80), Enum.PartType.Cylinder)
		piece(
			model,
			at * CFrame.new(0, 0, -0.2) * FORWARD,
			Vector3.new(0.3, 2.2, 2.2),
			Color3.fromRGB(240, 240, 250),
			Enum.PartType.Cylinder
		)
		piece(model, at * CFrame.new(0, 0, -0.35), Vector3.new(0.4, 1.6, 0.1), Color3.fromRGB(230, 80, 90))
		piece(model, at * CFrame.new(0, 0.1, -0.35), Vector3.new(1.4, 0.4, 0.1), Color3.fromRGB(230, 80, 90))
	end,
	Sprint = function(model, at)
		piece(model, at * CFrame.new(0, -0.6, 0), Vector3.new(1.2, 0.35, 2.8), Color3.new(1, 1, 1))
		piece(model, at * CFrame.new(0, 0, 0.5), Vector3.new(1.1, 0.9, 1.6), Color3.fromRGB(240, 90, 90))
		wedge(model, at * CFrame.new(0, -0.05, -0.75), Vector3.new(1.1, 0.75, 1), Color3.fromRGB(240, 90, 90))
		piece(model, at * CFrame.new(0, 0.7, 0.9), Vector3.new(1, 0.6, 0.6), Color3.fromRGB(240, 90, 90))
		piece(model, at * CFrame.new(0.57, 0.1, 0.3), Vector3.new(0.05, 0.12, 1.3), Color3.new(1, 1, 1))
	end,
	BlindFlash = function(model, at)
		piece(model, at, Vector3.one * 1.6, Color3.fromRGB(255, 245, 190), Enum.PartType.Ball, Enum.Material.Neon)
		for index = 0, 7 do
			local angle = index / 8 * math.pi * 2
			piece(
				model,
				at * CFrame.Angles(0, 0, angle) * CFrame.new(0, 1.5, 0),
				Vector3.new(0.18, 0.8, 0.18),
				Color3.fromRGB(255, 225, 120)
			)
		end
	end,
	RemoteTrigger = function(model, at)
		piece(model, at * CFrame.new(0, -0.3, 0), Vector3.new(1.4, 2.4, 0.5), Color3.fromRGB(60, 62, 76))
		piece(
			model,
			at * CFrame.new(0, 0.3, -0.3) * FORWARD,
			Vector3.new(0.2, 0.7, 0.7),
			Color3.fromRGB(230, 70, 80),
			Enum.PartType.Cylinder
		)
		piece(
			model,
			at * CFrame.new(0.4, 1.6, 0) * UPRIGHT,
			Vector3.new(1.4, 0.12, 0.12),
			Color3.fromRGB(180, 180, 190),
			Enum.PartType.Cylinder
		)
		piece(
			model,
			at * CFrame.new(0.4, 2.35, 0),
			Vector3.one * 0.3,
			Color3.fromRGB(200, 130, 255),
			Enum.PartType.Ball
		)
		for index = 0, 2 do
			piece(
				model,
				at * CFrame.new(-0.35 + index * 0.35, -0.9, -0.28),
				Vector3.new(0.22, 0.22, 0.1),
				Color3.fromRGB(200, 200, 210)
			)
		end
	end,
	TrapRecharge = function(model, at)
		piece(model, at * UPRIGHT, Vector3.new(2.4, 1.3, 1.3), Color3.fromRGB(255, 165, 70), Enum.PartType.Cylinder)
		piece(
			model,
			at * CFrame.new(0, 1.35, 0) * UPRIGHT,
			Vector3.new(0.3, 0.5, 0.5),
			Color3.fromRGB(200, 200, 210),
			Enum.PartType.Cylinder
		)
		piece(
			model,
			at * CFrame.new(0, -0.3, 0) * UPRIGHT,
			Vector3.new(0.9, 1.34, 1.34),
			Color3.fromRGB(120, 220, 140),
			Enum.PartType.Cylinder
		)
	end,
	SlowCannon = function(model, at)
		local metal = Color3.fromRGB(70, 76, 96)
		piece(
			model,
			at * CFrame.new(0, 0.3, -0.3) * FORWARD,
			Vector3.new(3, 1, 1),
			metal,
			Enum.PartType.Cylinder,
			Enum.Material.Metal
		)
		piece(
			model,
			at * CFrame.new(0, 0.3, -1.8) * FORWARD,
			Vector3.new(0.3, 1.15, 1.15),
			Color3.fromRGB(110, 210, 255),
			Enum.PartType.Cylinder
		)
		piece(model, at * CFrame.new(0, 0.3, 1.2), Vector3.one * 1.2, metal, Enum.PartType.Ball, Enum.Material.Metal)
		for _, side in { -1, 1 } do
			piece(
				model,
				at * CFrame.new(side * 0.7, -0.6, 0.2),
				Vector3.new(0.25, 1.3, 1.3),
				Color3.fromRGB(150, 100, 70),
				Enum.PartType.Cylinder
			)
		end
	end,
}

-- Builds the display model for `abilityId` centred at `at` (nil if there is no design for it).
function AbilityModels.build(abilityId: string, at: CFrame, parent: Instance): Model?
	local builder = BUILDERS[abilityId]
	if not builder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = `Display_{abilityId}`
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- spun as a whole on clients
	builder(model, at)
	model.WorldPivot = at
	model.Parent = parent
	return model
end

return AbilityModels
