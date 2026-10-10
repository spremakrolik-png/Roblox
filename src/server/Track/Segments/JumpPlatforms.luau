--!strict
-- Link segment: hop across square platforms that drift left and right.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)

local PLATFORM_SIZE = 6
local GAP_SHARE = 0.6 -- share of the max safe jump gap

return function(ctx: Types.SegmentContext)
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	local count, gap = SegmentKit.fit(z0, z1, PLATFORM_SIZE, JumpMath.maxGap() * GAP_SHARE)
	local maxShift = (ctx.width - PLATFORM_SIZE) / 2
	local x = 0
	for i = 1, count do
		local start = z0 + gap * i + PLATFORM_SIZE * (i - 1)
		-- Drift sideways by at most half a platform, so neighbours always overlap and the jump stays straight.
		x = math.clamp(x + ctx.rng:NextNumber(-PLATFORM_SIZE / 2, PLATFORM_SIZE / 2), -maxShift, maxShift)
		SegmentKit.slab(ctx, {
			z0 = start,
			z1 = start + PLATFORM_SIZE,
			x = x,
			width = PLATFORM_SIZE,
			name = "Platform",
		})
	end
end
