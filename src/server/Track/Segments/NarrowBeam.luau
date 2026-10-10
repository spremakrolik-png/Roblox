--!strict
-- Link segment: two narrow beams on opposite sides, joined by a small resting block.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)

local BEAM_WIDTH = 2
local REST_LENGTH = 4

return function(ctx: Types.SegmentContext)
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	local mid = (z0 + z1) / 2
	local offset = ctx.rng:NextNumber(2, (ctx.width - BEAM_WIDTH) / 2 - 1)
	local side = if ctx.rng:NextNumber() < 0.5 then -1 else 1

	SegmentKit.slab(ctx, {
		z0 = z0,
		z1 = mid - REST_LENGTH / 2,
		x = side * offset,
		width = BEAM_WIDTH,
		name = "Beam",
	})
	SegmentKit.slab(ctx, {
		z0 = mid - REST_LENGTH / 2,
		z1 = mid + REST_LENGTH / 2,
		width = offset * 2 + BEAM_WIDTH,
		name = "Rest",
	})
	SegmentKit.slab(ctx, {
		z0 = mid + REST_LENGTH / 2,
		z1 = z1,
		x = -side * offset,
		width = BEAM_WIDTH,
		name = "Beam",
	})
end
