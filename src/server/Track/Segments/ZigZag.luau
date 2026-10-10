--!strict
-- Link segment: narrow platforms alternating left and right; every jump is diagonal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)

local PLATFORM_WIDTH = 5
local PLATFORM_LENGTH = 7
local LATERAL_OFFSET = 3.5 -- platform centre distance from the track centre
local GAP_SHARE = 0.7

return function(ctx: Types.SegmentContext)
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	-- Keep the corner-to-corner distance (forward gap + sideways gap) within the safe jump.
	local diagonalLimit = JumpMath.maxGap() * GAP_SHARE
	local sideGap = math.max(0, LATERAL_OFFSET * 2 - PLATFORM_WIDTH)
	local forwardLimit = math.sqrt(math.max(diagonalLimit * diagonalLimit - sideGap * sideGap, 1))
	local count, gap = SegmentKit.fit(z0, z1, PLATFORM_LENGTH, forwardLimit)

	local side = if ctx.rng:NextNumber() < 0.5 then -1 else 1
	for i = 1, count do
		local start = z0 + gap * i + PLATFORM_LENGTH * (i - 1)
		SegmentKit.slab(ctx, {
			z0 = start,
			z1 = start + PLATFORM_LENGTH,
			x = side * LATERAL_OFFSET,
			width = PLATFORM_WIDTH,
			name = "Platform",
		})
		side = -side
	end
end
