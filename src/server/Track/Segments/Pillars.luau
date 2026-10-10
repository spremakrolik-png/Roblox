--!strict
-- Link segment: a row of round pillars over the void.
-- params: diameter, gapShare.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)

local MAX_SIDE_JITTER = 1.5
local JITTER_ALLOWANCE = 0.3 -- round pillars: 1.5 studs sideways adds at most ~0.2 studs to the jump
local MIN_DIAMETER_SHARE = 0.8

return function(ctx: Types.SegmentContext)
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local diameter = SegmentDefs.param(ctx.def, "diameter", 4)
	local gap = JumpMath.maxGap() * SegmentDefs.param(ctx.def, "gapShare", 0.65) - JITTER_ALLOWANCE
	local z0, z1 = SegmentKit.innerSpan(ctx)
	local span = z1 - z0
	-- Exact gaps; the pillar size flexes a little instead, but never shrinks below 80%.
	local count, size = SegmentKit.layout(span, diameter, gap)
	while count > 1 and size < diameter * MIN_DIAMETER_SHARE do
		count -= 1
		size = (span - (count + 1) * gap) / count
	end
	for i = 1, count do
		local z = z0 + gap * i + size * (i - 0.5)
		local x = ctx.rng:NextNumber(-MAX_SIDE_JITTER, MAX_SIDE_JITTER)
		SegmentKit.pillar(ctx, x, z, 0, size)
	end
end
