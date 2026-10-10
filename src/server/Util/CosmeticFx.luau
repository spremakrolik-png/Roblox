--!strict
-- Builds wardrobe items on a character: hats welded to the head, a trail behind the body and an
-- aura of particles. Every item is a child named "Cosmetic_<Kind>" so it can be swapped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Config.Cosmetics)

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"

local CosmeticFx = {}

local function part(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function wedge(name: string, size: Vector3, color: Color3): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function weld(p: BasePart, base: BasePart, offset: CFrame, parent: Instance)
	p.CFrame = base.CFrame * offset
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = base
	constraint.Part1 = p
	constraint.Parent = p
	p.Parent = parent
end

-- A cylinder standing upright (cylinders run along their local X).
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

-- Hats --------------------------------------------------------------------------------------------

type HatBuilder = (head: BasePart, model: Model, colors: { Color3 }) -> ()

local top = function(head: BasePart): number
	return head.Size.Y / 2
end

local HATS: { [string]: HatBuilder } = {
	HatCrown = function(head, model, colors)
		local y = top(head)
		weld(
			part("Band", Vector3.new(0.5, 1.5, 1.5), colors[1], Enum.PartType.Cylinder),
			head,
			CFrame.new(0, y + 0.25, 0) * UPRIGHT,
			model
		)
		for index = 0, 4 do
			local angle = index / 5 * math.pi * 2
			local spike = wedge("Spike", Vector3.new(0.15, 0.5, 0.3), colors[1])
			weld(spike, head, CFrame.Angles(0, angle, 0) * CFrame.new(0, y + 0.75, -0.68), model)
			local gem = part("Gem", Vector3.one * 0.18, colors[2], Enum.PartType.Ball)
			weld(gem, head, CFrame.Angles(0, angle, 0) * CFrame.new(0, y + 0.25, -0.76), model)
		end
	end,
	HatTopHat = function(head, model, colors)
		local y = top(head)
		weld(
			part("Brim", Vector3.new(0.12, 1.9, 1.9), colors[1], Enum.PartType.Cylinder),
			head,
			CFrame.new(0, y + 0.06, 0) * UPRIGHT,
			model
		)
		weld(
			part("Crown", Vector3.new(1.2, 1.25, 1.25), colors[1], Enum.PartType.Cylinder),
			head,
			CFrame.new(0, y + 0.66, 0) * UPRIGHT,
			model
		)
		weld(
			part("Ribbon", Vector3.new(0.22, 1.28, 1.28), colors[2], Enum.PartType.Cylinder),
			head,
			CFrame.new(0, y + 0.25, 0) * UPRIGHT,
			model
		)
	end,
	HatParty = function(head, model, colors)
		local y = top(head)
		for tier = 0, 4 do
			local width = 1.1 - tier * 0.2
			weld(
				part("Tier", Vector3.new(0.32, width, width), colors[(tier % 2) + 1], Enum.PartType.Cylinder),
				head,
				CFrame.new(0, y + 0.16 + tier * 0.3, 0) * UPRIGHT,
				model
			)
		end
		weld(
			part("Pompom", Vector3.one * 0.35, Color3.new(1, 1, 1), Enum.PartType.Ball),
			head,
			CFrame.new(0, y + 1.7, 0),
			model
		)
	end,
	HatHalo = function(head, model, colors)
		local y = top(head)
		for index = 0, 11 do
			local angle = index / 12 * math.pi * 2
			local bead = part("Bead", Vector3.one * 0.28, colors[1], Enum.PartType.Ball)
			bead.Material = Enum.Material.Neon
			weld(bead, head, CFrame.new(math.cos(angle) * 0.75, y + 0.9, math.sin(angle) * 0.75), model)
		end
	end,
	HatHorns = function(head, model, colors)
		local y = top(head)
		for _, side in { -1, 1 } do
			local base = part("HornBase", Vector3.new(0.35, 0.4, 0.35), colors[1])
			weld(base, head, CFrame.new(side * 0.45, y + 0.15, 0) * CFrame.Angles(0, 0, -side * 0.35), model)
			local tip = wedge("HornTip", Vector3.new(0.25, 0.45, 0.3), colors[1])
			weld(tip, head, CFrame.new(side * 0.58, y + 0.5, 0) * CFrame.Angles(0, math.pi / 2, -side * 0.5), model)
		end
	end,
	HatCatEars = function(head, model, colors)
		local y = top(head)
		for _, side in { -1, 1 } do
			local outer = wedge("Ear", Vector3.new(0.18, 0.6, 0.5), colors[2])
			weld(outer, head, CFrame.new(side * 0.42, y + 0.28, 0) * CFrame.Angles(0, math.pi / 2, side * 0.2), model)
			local inner = wedge("EarInner", Vector3.new(0.2, 0.4, 0.32), colors[1])
			weld(
				inner,
				head,
				CFrame.new(side * 0.42, y + 0.22, -0.03) * CFrame.Angles(0, math.pi / 2, side * 0.2),
				model
			)
		end
	end,
}

-- Trails and auras -------------------------------------------------------------------------------

local function sequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local points = {}
	for index, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(points)
end

local function addTrail(root: BasePart, model: Model, colors: { Color3 })
	local a0 = Instance.new("Attachment")
	a0.Name = "CosmeticTrailTop"
	a0.Position = Vector3.new(0, 0.9, 0.4)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "CosmeticTrailBottom"
	a1.Position = Vector3.new(0, -1.6, 0.4)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = sequence(colors)
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.Lifetime = 0.6
	trail.MinLength = 0.2
	trail.Parent = model
	-- The attachments live on the root; remove them with the item.
	model.Destroying:Connect(function()
		a0:Destroy()
		a1:Destroy()
	end)
end

local function addAura(root: BasePart, model: Model, def: Cosmetics.CosmeticDef)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "CosmeticAura"
	emitter.Texture = SPARKLES
	emitter.Color = sequence(def.colors)
	emitter.LightEmission = 0.2
	emitter.Rate = 10
	emitter.Lifetime = NumberRange.new(1, 1.6)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.Size = NumberSequence.new(0.35, 0)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.SpreadAngle = Vector2.new(180, 180)
	if def.id == "AuraFrost" or def.id == "AuraLeaves" then
		emitter.Acceleration = Vector3.new(0, -3, 0)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-90, 90)
	else
		emitter.Acceleration = Vector3.new(0, 1.5, 0)
	end
	local holder = Instance.new("Attachment")
	holder.Name = "CosmeticAuraAttachment"
	holder.Parent = root
	emitter.Parent = holder
	model.Destroying:Connect(function()
		holder:Destroy()
	end)
end

-- Puts `id` (or nothing, for "") of the given kind on the character, replacing the old item.
function CosmeticFx.apply(character: Model, kind: Cosmetics.CosmeticKind, id: string)
	local name = `Cosmetic_{kind}`
	local old = character:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local def = Cosmetics.byId[id]
	if not def or def.kind ~= kind then
		return
	end
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not head or not head:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return
	end
	local model = Instance.new("Model")
	model.Name = name
	if kind == "Hat" then
		local builder = HATS[def.id]
		if builder then
			builder(head, model, def.colors)
		end
	elseif kind == "Trail" then
		addTrail(root, model, def.colors)
	else
		addAura(root, model, def)
	end
	model.Parent = character
end

return CosmeticFx
