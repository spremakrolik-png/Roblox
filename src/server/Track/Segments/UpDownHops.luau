--!strict
-- Link segment: platforms that alternate between floor height and a raised hop.
-- params: size, hopShare (hop height as a share of the safe rise), gapShare.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)

return function(ctx: Types.SegmentContext)
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local size = SegmentDefs.param(ctx.def, "size", 5)
	local hop = JumpMath.maxRise() * SegmentDefs.param(ctx.def, "hopShare", 0.4)
	-- The upward jumps are the hard ones, so size every gap from the jump onto a raised platform.
	local gap = JumpMath.maxGap(hop) * SegmentDefs.param(ctx.def, "gapShare", 0.5)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	local count, length = SegmentKit.layout(z1 - z0, size, gap)
	local x = 0
	for i = 1, count do
		local start = z0 + gap * i + length * (i - 1)
		x = math.clamp(x + ctx.rng:NextNumber(-1, 1), -(ctx.width - size) / 2, (ctx.width - size) / 2)
		SegmentKit.slab(ctx, {
			z0 = start,
			z1 = start + length,
			x = x,
			width = size,
			top = if i % 2 == 1 then hop else 0,
			thickness = 2,
			name = "Hop",
		})
	end
end
