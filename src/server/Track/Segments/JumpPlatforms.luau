--!strict
-- Link segment: hop across square platforms that drift left and right.
-- params: size (platform width), gapShare (gap as a share of the safe jump).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)

return function(ctx: Types.SegmentContext)
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local size = SegmentDefs.param(ctx.def, "size", 6)
	local gap = JumpMath.maxGap() * SegmentDefs.param(ctx.def, "gapShare", 0.6)
	local z0, z1 = SegmentKit.innerSpan(ctx)
	local count, length = SegmentKit.layout(z1 - z0, size, gap)
	local maxShift = (ctx.width - size) / 2
	local x = 0
	for i = 1, count do
		local start = z0 + gap * i + length * (i - 1)
		-- Drift sideways by at most half a platform, so neighbours always overlap and the jump stays straight.
		x = math.clamp(x + ctx.rng:NextNumber(-size / 2, size / 2), -maxShift, maxShift)
		SegmentKit.slab(ctx, {
			z0 = start,
			z1 = start + length,
			x = x,
			width = size,
			name = "Platform",
		})
	end
end
