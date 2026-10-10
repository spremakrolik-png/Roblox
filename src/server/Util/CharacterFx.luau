--!strict
-- Visual effects attached to characters, built on the server so every player sees them: the Slow
-- Cannon on the shoulder, speed trails, the Feather Fall parachute, the frost of a cannon hit.
-- All parts are massless and non-colliding, so they never change how a character moves.

local Debris = game:GetService("Debris")

local CharacterFx = {}

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local CANNON_NAME = "SlowCannonFx"
local CANNON_METAL = Color3.fromRGB(52, 58, 76)
local CANNON_GLOW = Color3.fromRGB(80, 200, 255)

local function root(character: Model): BasePart?
	local part = character:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

local function fxPart(name: string, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Places `part` at `offset` from `base` and welds it there.
local function weldTo(part: BasePart, base: BasePart, offset: CFrame, parent: Instance)
	part.CFrame = base.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = part
	weld.Parent = part
	part.Parent = parent
end

-- Cannon ----------------------------------------------------------------------------------

-- A chunky cannon on the right shoulder, pointing forward, with a "Muzzle" attachment at its tip.
function CharacterFx.attachCannon(character: Model)
	local base = root(character)
	if not base or character:FindFirstChild(CANNON_NAME) then
		return
	end
	local model = Instance.new("Model")
	model.Name = CANNON_NAME
	local mount = CFrame.new(1.7, 1.2, -0.2)
	-- Cylinders run along their local X; turn the barrel to point along -Z (forward).
	local alongZ = CFrame.Angles(0, math.pi / 2, 0)
	local barrel = fxPart("Barrel", Vector3.new(3.2, 1, 1), CANNON_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	weldTo(barrel, base, mount * CFrame.new(0, 0, -0.6) * alongZ, model)
	local ring =
		fxPart("Ring", Vector3.new(0.3, 1.15, 1.15), CANNON_GLOW, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	weldTo(ring, base, mount * CFrame.new(0, 0, -2.1) * alongZ, model)
	local back = fxPart("Back", Vector3.new(0.9, 1.3, 1.3), CANNON_METAL, Enum.Material.Metal, Enum.PartType.Ball)
	weldTo(back, base, mount * CFrame.new(0, 0, 1), model)
	local strap = fxPart("Strap", Vector3.new(0.3, 0.5, 1.2), Color3.fromRGB(90, 60, 40), Enum.Material.Fabric)
	weldTo(strap, base, mount * CFrame.new(-0.55, -0.55, 0), model)
	local sight = fxPart("Sight", Vector3.new(0.25, 0.35, 0.6), CANNON_GLOW, Enum.Material.SmoothPlastic)
	weldTo(sight, base, mount * CFrame.new(0, 0.6, -0.4), model)
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Parent = barrel
	-- Set in world space, so it does not depend on how the barrel cylinder is turned.
	muzzle.WorldPosition = (base.CFrame * mount * CFrame.new(0, 0, -2.4)).Position
	model.Parent = character
end

function CharacterFx.removeCannon(character: Model)
	local cannon = character:FindFirstChild(CANNON_NAME)
	if cannon then
		cannon:Destroy()
	end
end

-- World position of the cannon muzzle, if the character carries one.
function CharacterFx.muzzle(character: Model): Vector3?
	local cannon = character:FindFirstChild(CANNON_NAME)
	local barrel = cannon and cannon:FindFirstChild("Barrel")
	local muzzle = barrel and barrel:FindFirstChild("Muzzle")
	return if muzzle and muzzle:IsA("Attachment") then muzzle.WorldPosition else nil
end

-- A flash and a puff at the muzzle when a shot leaves.
function CharacterFx.muzzleFlash(position: Vector3, parent: Instance)
	local flash = fxPart("MuzzleFlash", Vector3.one * 1, CANNON_GLOW, Enum.Material.Neon, Enum.PartType.Ball)
	flash.Anchored = true
	flash.Position = position
	flash.Transparency = 0.4
	flash.Parent = parent
	Debris:AddItem(flash, 0.08)
end

-- A glowing trail behind a moving part (the cannon shot).
function CharacterFx.tracer(part: BasePart, color: Color3)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.45, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.45, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Lifetime = 0.25
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = part
end

-- Movement trails -------------------------------------------------------------------------

-- A ribbon behind the character for `seconds` (Speed Burst, Sprint, Dash).
function CharacterFx.speedTrail(character: Model, color: Color3, seconds: number, width: number?)
	local base = root(character)
	if not base then
		return
	end
	local half = (width or 2.2) / 2
	local top = Instance.new("Attachment")
	top.Name = "SpeedTrailTop"
	top.Position = Vector3.new(0, half, 0.6)
	top.Parent = base
	local bottom = Instance.new("Attachment")
	bottom.Name = "SpeedTrailBottom"
	bottom.Position = Vector3.new(0, -half, 0.6)
	bottom.Parent = base
	local trail = Instance.new("Trail")
	trail.Name = "SpeedTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.35
	trail.LightEmission = 0.8
	trail.Parent = base

	local wind = Instance.new("ParticleEmitter")
	wind.Name = "SpeedSparks"
	wind.Texture = SPARKLES
	wind.Color = ColorSequence.new(color)
	wind.LightEmission = 1
	wind.Rate = 30
	wind.Lifetime = NumberRange.new(0.2, 0.4)
	wind.Speed = NumberRange.new(2, 5)
	wind.Size = NumberSequence.new(0.5, 0)
	wind.SpreadAngle = Vector2.new(30, 30)
	wind.EmissionDirection = Enum.NormalId.Back
	wind.Parent = top

	for _, item in { top, bottom, trail, wind } :: { Instance } do
		Debris:AddItem(item, seconds + 0.4)
	end
	task.delay(seconds, function()
		wind.Enabled = false
	end)
end

-- Feather Fall ------------------------------------------------------------------------------

local CANOPY_COLORS = {
	Color3.fromRGB(255, 120, 170),
	Color3.fromRGB(255, 220, 110),
	Color3.fromRGB(120, 210, 255),
}

-- A little parachute above the head while the fall is slowed.
function CharacterFx.parachute(character: Model, seconds: number)
	local base = root(character)
	if not base or character:FindFirstChild("ParachuteFx") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "ParachuteFx"
	local canopy = fxPart("Canopy", Vector3.new(1, 1, 1), CANOPY_COLORS[1], Enum.Material.Fabric)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(8, 2.6, 8)
	mesh.Parent = canopy
	weldTo(canopy, base, CFrame.new(0, 6.2, 0), model)
	for index, color in CANOPY_COLORS do
		local band = fxPart(`Band{index}`, Vector3.new(1, 1, 1), color, Enum.Material.Fabric)
		local bandMesh = Instance.new("SpecialMesh")
		bandMesh.MeshType = Enum.MeshType.Sphere
		bandMesh.Scale = Vector3.new(8.1 - index * 1.9, 2.75 - index * 0.25, 8.1 - index * 1.9)
		bandMesh.Parent = band
		weldTo(band, base, CFrame.new(0, 6.25 + index * 0.18, 0), model)
	end
	for _, corner in
		{ Vector3.new(2.6, 0, 2.6), Vector3.new(-2.6, 0, 2.6), Vector3.new(2.6, 0, -2.6), Vector3.new(-2.6, 0, -2.6) }
	do
		local from = Vector3.new(corner.X * 0.15, 1.2, corner.Z * 0.15)
		local to = Vector3.new(corner.X, 5.6, corner.Z)
		local line = fxPart(
			"Line",
			Vector3.new(0.08, 0.08, (to - from).Magnitude),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic
		)
		weldTo(line, base, CFrame.lookAt((from + to) / 2, to), model)
	end
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = SPARKLES
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 240, 250))
	sparkles.LightEmission = 0.6
	sparkles.Rate = 14
	sparkles.Lifetime = NumberRange.new(0.6, 1)
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.Size = NumberSequence.new(0.6, 0)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = canopy
	model.Parent = character
	Debris:AddItem(model, seconds)
end

-- Slow Cannon hit -------------------------------------------------------------------------------

-- Icy glow and snowflakes on a slowed character.
function CharacterFx.frost(character: Model, seconds: number)
	local base = root(character)
	if not base then
		return
	end
	local old = character:FindFirstChild("FrostFx")
	if old then
		old:Destroy()
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "FrostFx"
	highlight.FillColor = Color3.fromRGB(120, 210, 255)
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
	local snow = Instance.new("ParticleEmitter")
	snow.Name = "FrostSnow"
	snow.Texture = SPARKLES
	snow.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
	snow.LightEmission = 0.5
	snow.Rate = 25
	snow.Lifetime = NumberRange.new(0.6, 1.1)
	snow.Speed = NumberRange.new(0.5, 1.5)
	snow.Acceleration = Vector3.new(0, -4, 0)
	snow.Size = NumberSequence.new(0.5, 0.1)
	snow.SpreadAngle = Vector2.new(180, 180)
	snow.Parent = base
	Debris:AddItem(highlight, seconds)
	Debris:AddItem(snow, seconds)
end

-- Shield: a golden outline while the grace period lasts.
function CharacterFx.shieldGlow(character: Model, seconds: number)
	local highlight = Instance.new("Highlight")
	highlight.Name = "ShieldFx"
	highlight.FillColor = Color3.fromRGB(255, 210, 80)
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = Color3.fromRGB(255, 240, 160)
	highlight.Parent = character
	Debris:AddItem(highlight, seconds)
end

return CharacterFx
