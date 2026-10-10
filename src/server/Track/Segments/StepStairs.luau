--!strict
-- Link segment: floating steps. With a positive rise they climb above the exit height and drop
-- onto the exit pad; with a negative rise they step down to it.
-- params: stepShare (step height as a share of the safe rise), stepLength.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)

return function(ctx: Types.SegmentContext)
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local rise = ctx.def.rise
	local stepLength = SegmentDefs.param(ctx.def, "stepLength", 5)
	local stepHeight = JumpMath.maxRise() * SegmentDefs.param(ctx.def, "stepShare", 0.4)

	local tops: { number } = {}
	if rise >= 0 then
		local peak = rise + stepHeight
		local count = math.ceil(peak / stepHeight)
		for i = 1, count do
			tops[i] = peak * i / count
		end
	else
		local count = math.max(2, math.ceil(-rise / stepHeight))
		for i = 1, count do
			tops[i] = rise * i / (count + 1)
		end
	end

	local z0, z1 = SegmentKit.innerSpan(ctx)
	local count = #tops
	local gap = (z1 - z0 - count * stepLength) / (count + 1)
	assert(gap >= 0, `StepStairs: segment {ctx.def.id} is too short for {count} steps`)
	local climb = math.max(0, tops[1], if count > 1 then tops[2] - tops[1] else 0)
	assert(gap <= JumpMath.maxGap(climb), `StepStairs: {ctx.def.id} gap {gap} is not jumpable`)

	for i, top in tops do
		local start = z0 + gap * i + stepLength * (i - 1)
		SegmentKit.slab(ctx, {
			z0 = start,
			z1 = start + stepLength,
			top = top,
			thickness = 2,
			name = "Step",
		})
	end
end
