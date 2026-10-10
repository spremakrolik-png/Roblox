--!strict
-- Link segment: small stepping stones scattered across the width. Each stone is placed relative
-- to the previous one, so the path is always within the safe jump.
-- params: size (stone width and length), gapShare.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)

return function(ctx: Types.SegmentContext)
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local size = SegmentDefs.param(ctx.def, "size", 3)
	local limit = JumpMath.maxGap() * SegmentDefs.param(ctx.def, "gapShare", 0.7)
	local maxX = (ctx.width - size) / 2

	local z0, z1 = SegmentKit.innerSpan(ctx)
	local cursor = z0 -- far edge of the last thing stood on
	local x: number? = nil -- centre of the last stone (nil = the full-width entry pad)
	while z1 - cursor > limit do
		local nextX = if x
			then math.clamp(x + ctx.rng:NextNumber(-size * 1.6, size * 1.6), -maxX, maxX)
			else ctx.rng:NextNumber(-maxX, maxX)
		local sideGap = if x then math.max(0, math.abs(nextX - x) - size) else 0
		local forward = math.sqrt(math.max(limit * limit - sideGap * sideGap, 0)) * ctx.rng:NextNumber(0.75, 1)
		-- Never leave a last stretch to the exit pad that is longer than the limit.
		forward = math.min(forward, z1 - cursor - size - 0.5)
		forward = math.max(forward, 0.5)
		SegmentKit.slab(ctx, {
			z0 = cursor + forward,
			z1 = cursor + forward + size,
			x = nextX,
			width = size,
			name = "Stone",
		})
		cursor += forward + size
		x = nextX
	end
end
