--!strict
-- Trap segment: the floor blinks red, then turns to lava for a few seconds. Raised safe blocks
-- stand above the lava; runners on them survive.
-- params: safeBlocks (how many safe blocks).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local TrapsConfig = require(ReplicatedStorage.Shared.Config.Traps)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)
local TrapKit = require(script.Parent.Parent.TrapKit)

local SAFE_BLOCK_SIZE = 3

return function(ctx: Types.SegmentContext): Types.TrapHandle
	local config = TrapsConfig.LavaFloor
	local info = TrapsConfig.info("LavaFloor")
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	local floor = SegmentKit.slab(ctx, { z0 = z0, z1 = z1, name = "LavaFloor" })

	local half = ctx.width / 2
	local count = SegmentDefs.param(ctx.def, "safeBlocks", 3)
	for i = 1, count do
		local z = z0 + (z1 - z0) * i / (count + 1)
		SegmentKit.slab(ctx, {
			z0 = z - SAFE_BLOCK_SIZE / 2,
			z1 = z + SAFE_BLOCK_SIZE / 2,
			x = ctx.rng:NextNumber(-half + 2, half - 2),
			width = SAFE_BLOCK_SIZE,
			top = config.SafeBlockHeight,
			thickness = config.SafeBlockHeight,
			name = "SafeBlock",
			color = ctx.theme.accentColor,
		})
	end

	local burn = TrapKit.box(ctx, -half - 1, half + 1, -3, config.LethalHeight, z0, z1)

	return {
		zone = TrapKit.segmentZone(ctx),
		activate = function(hooks: Types.TrapHooks)
			TrapKit.blink({ floor }, info.color, config.Telegraph)
			local color, material = floor.Color, floor.Material
			floor.Color = info.color
			floor.Material = Enum.Material.Neon
			TrapKit.lethal(hooks, burn, config.ActiveSeconds)
			floor.Color = color
			floor.Material = material
		end,
	}
end
