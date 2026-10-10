--!strict
-- Link segment: narrow platforms alternating left and right; every jump is diagonal.
-- params: width (platform width), gapShare (corner-to-corner jump as a share of the safe jump).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)

local PLATFORM_LENGTH = 7

return function(ctx: Types.SegmentContext)
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local width = SegmentDefs.param(ctx.def, "width", 5)
	local lateral = width * 0.7 -- platform centre distance from the track centre
	-- Keep the corner-to-corner distance (forward gap + sideways gap) at the requested jump.
	local diagonal = JumpMath.maxGap() * SegmentDefs.param(ctx.def, "gapShare", 0.7)
	local sideGap = math.max(0, lateral * 2 - width)
	local forward = math.sqrt(math.max(diagonal * diagonal - sideGap * sideGap, 1))

	local z0, z1 = SegmentKit.innerSpan(ctx)
	local count, length = SegmentKit.layout(z1 - z0, PLATFORM_LENGTH, forward)
	local side = if ctx.rng:NextNumber() < 0.5 then -1 else 1
	for i = 1, count do
		local start = z0 + forward * i + length * (i - 1)
		SegmentKit.slab(ctx, {
			z0 = start,
			z1 = start + length,
			x = side * lateral,
			width = width,
			name = "Platform",
		})
		side = -side
	end
end
