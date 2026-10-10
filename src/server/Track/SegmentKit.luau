--!strict
-- Building blocks shared by segment modules. Coordinates are local to the segment:
-- `z` is the distance forward from the entry, `x` is to the right, `y` is up from the entry floor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Build = require(script.Parent.Parent.Util.Build)

local SegmentKit = {}

export type SlabOptions = {
	z0: number,
	z1: number,
	x: number?,
	width: number?,
	top: number?,
	thickness: number?,
	name: string?,
	color: Color3?,
	material: Enum.Material?,
	collide: boolean?,
}

-- Local position -> world CFrame (same orientation as the entry).
function SegmentKit.at(ctx: Types.SegmentContext, x: number, y: number, z: number): CFrame
	return ctx.entry * CFrame.new(x, y, -z)
end

-- A flat slab whose top surface is at `top`, covering forward distances [z0, z1].
function SegmentKit.slab(ctx: Types.SegmentContext, options: SlabOptions): Part
	local thickness = options.thickness or 1
	local length = options.z1 - options.z0
	assert(length > 0, "slab needs z1 > z0")
	local top = options.top or 0
	return Build.part({
		name = options.name or "Floor",
		size = Vector3.new(options.width or ctx.width, thickness, length),
		cframe = SegmentKit.at(ctx, options.x or 0, top - thickness / 2, options.z0 + length / 2),
		color = options.color or ctx.theme.floorColor,
		material = options.material or ctx.theme.floorMaterial,
		physics = ctx.theme.floorPhysics,
		canCollide = options.collide,
		parent = ctx.parent,
	})
end

-- Full-width floor at the start of the segment (height 0).
function SegmentKit.entryPad(ctx: Types.SegmentContext): Part
	return SegmentKit.slab(ctx, { z0 = 0, z1 = ctx.padLength, name = "EntryPad" })
end

-- Full-width floor at the end of the segment (height def.rise).
function SegmentKit.exitPad(ctx: Types.SegmentContext): Part
	local length = ctx.def.length
	return SegmentKit.slab(ctx, {
		z0 = length - ctx.padLength,
		z1 = length,
		top = ctx.def.rise,
		name = "ExitPad",
	})
end

-- Span between the two pads where the obstacles go.
function SegmentKit.innerSpan(ctx: Types.SegmentContext): (number, number)
	return ctx.padLength, ctx.def.length - ctx.padLength
end

-- Lays `count` items of `itemLength` evenly inside [z0, z1] and returns the gap between them.
-- Picks the smallest count whose gaps do not exceed `maxGap`.
function SegmentKit.fit(z0: number, z1: number, itemLength: number, maxGap: number): (number, number)
	local span = z1 - z0
	local count = 1
	while true do
		local gap = (span - count * itemLength) / (count + 1)
		if gap <= maxGap or gap <= 0 then
			return count, math.max(gap, 0)
		end
		count += 1
	end
end

-- Lays items with gaps of exactly `gap` inside a span, stretching or shrinking the items a little
-- so the gap (and therefore the difficulty) is what the segment asked for. Returns count and item length.
function SegmentKit.layout(span: number, itemLength: number, gap: number): (number, number)
	local count = math.max(1, math.floor((span - gap) / (itemLength + gap) + 0.5))
	local length = (span - (count + 1) * gap) / count
	assert(length > 0.5, `layout: span {span} cannot fit items with gap {gap}`)
	return count, length
end

-- A vertical pillar whose top surface is at local (x, top, z).
function SegmentKit.pillar(ctx: Types.SegmentContext, x: number, z: number, top: number, diameter: number): Part
	return Build.pillar(
		"Pillar",
		SegmentKit.at(ctx, x, 0, z),
		top,
		diameter,
		24,
		ctx.theme.floorColor,
		ctx.theme.floorMaterial,
		ctx.parent,
		ctx.theme.floorPhysics
	)
end

return SegmentKit
