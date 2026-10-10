--!strict
-- Link segment: a row of round pillars over the void.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)

local DIAMETER = 4
local MAX_SIDE_JITTER = 1.5
local GAP_SHARE = 0.65

return function(ctx: Types.SegmentContext)
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	-- Sideways jitter lengthens the jump a little, so budget it out of the gap.
	local count, gap = SegmentKit.fit(z0, z1, DIAMETER, JumpMath.maxGap() * GAP_SHARE - MAX_SIDE_JITTER)
	for i = 1, count do
		local z = z0 + gap * i + DIAMETER * (i - 0.5)
		local x = ctx.rng:NextNumber(-MAX_SIDE_JITTER, MAX_SIDE_JITTER)
		SegmentKit.pillar(ctx, x, z, 0, DIAMETER)
	end
end
