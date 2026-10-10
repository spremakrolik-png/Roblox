--!strict
-- Link segment: floating steps that climb above the exit height, then drop onto the exit pad.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)

local STEP_LENGTH = 5
local STEP_SHARE = 0.4 -- step height as a share of the max safe rise

return function(ctx: Types.SegmentContext)
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	local stepHeight = JumpMath.maxRise() * STEP_SHARE
	local peak = math.max(ctx.def.rise, 0) + stepHeight
	local count = math.ceil(peak / stepHeight)
	local rise = peak / count
	local gap = (z1 - z0 - count * STEP_LENGTH) / (count + 1)
	assert(gap >= 0, `StepStairs: segment {ctx.def.id} is too short for {count} steps`)
	assert(gap <= JumpMath.maxGap(rise), `StepStairs: gap {gap} is not jumpable`)

	for i = 1, count do
		local start = z0 + gap * i + STEP_LENGTH * (i - 1)
		SegmentKit.slab(ctx, {
			z0 = start,
			z1 = start + STEP_LENGTH,
			top = rise * i,
			thickness = 2,
			name = "Step",
		})
	end
end
