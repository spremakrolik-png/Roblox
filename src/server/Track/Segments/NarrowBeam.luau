--!strict
-- Link segment: two narrow beams on opposite sides, joined by a small resting block.
-- params: beamWidth, breaks (gaps cut into the beams), gapShare (size of those gaps).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)

local REST_LENGTH = 4

-- One beam from z0 to z1 at x, cut by `breaks` gaps.
local function beam(
	ctx: Types.SegmentContext,
	z0: number,
	z1: number,
	x: number,
	width: number,
	breaks: number,
	gap: number
)
	local pieces = breaks + 1
	local pieceLength = (z1 - z0 - breaks * gap) / pieces
	assert(pieceLength >= 2, `NarrowBeam: {ctx.def.id} is too short for {breaks} breaks`)
	for i = 0, breaks do
		local start = z0 + i * (pieceLength + gap)
		SegmentKit.slab(ctx, { z0 = start, z1 = start + pieceLength, x = x, width = width, name = "Beam" })
	end
end

return function(ctx: Types.SegmentContext)
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local width = SegmentDefs.param(ctx.def, "beamWidth", 2)
	local breaks = SegmentDefs.param(ctx.def, "breaks", 0)
	local gap = JumpMath.maxGap() * SegmentDefs.param(ctx.def, "gapShare", 0.5)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	local mid = (z0 + z1) / 2
	local offset = ctx.rng:NextNumber(2, (ctx.width - width) / 2 - 1)
	local side = if ctx.rng:NextNumber() < 0.5 then -1 else 1

	beam(ctx, z0, mid - REST_LENGTH / 2, side * offset, width, math.ceil(breaks / 2), gap)
	SegmentKit.slab(ctx, {
		z0 = mid - REST_LENGTH / 2,
		z1 = mid + REST_LENGTH / 2,
		width = offset * 2 + width,
		name = "Rest",
	})
	beam(ctx, mid + REST_LENGTH / 2, z1, -side * offset, width, math.floor(breaks / 2), gap)
end
