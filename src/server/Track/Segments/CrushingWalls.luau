--!strict
-- Trap segment: walls on both sides. After a blink they slide together and crush anyone between
-- them, then slide back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrapsConfig = require(ReplicatedStorage.Shared.Config.Traps)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)
local TrapKit = require(script.Parent.Parent.TrapKit)

local WALL_THICKNESS = 2

return function(ctx: Types.SegmentContext): Types.TrapHandle
	local config = TrapsConfig.CrushingWalls
	local info = TrapsConfig.info("CrushingWalls")
	local half = ctx.width / 2
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	SegmentKit.slab(ctx, { z0 = z0, z1 = z1, name = "Floor" })

	local walls: { BasePart } = {}
	local open: { CFrame } = {}
	local closed: { CFrame } = {}
	local travel = half - WALL_THICKNESS -- the inner faces meet on the centre line
	for _, side in { -1, 1 } do
		local wall = SegmentKit.slab(ctx, {
			z0 = z0,
			z1 = z1,
			x = side * (half - WALL_THICKNESS / 2),
			width = WALL_THICKNESS,
			top = config.WallHeight,
			thickness = config.WallHeight,
			name = "CrushWall",
			color = ctx.theme.wallColor,
		})
		table.insert(walls, wall)
		table.insert(open, wall.CFrame)
		table.insert(closed, wall.CFrame * CFrame.new(-side * travel, 0, 0))
	end

	local crush = TrapKit.box(ctx, -half, half, -3, config.WallHeight, z0, z1)

	return {
		zone = TrapKit.segmentZone(ctx),
		activate = function(hooks: Types.TrapHooks)
			TrapKit.blink(walls, info.color, config.Telegraph)
			for i, wall in walls do
				TrapKit.move(wall, closed[i], config.CloseSeconds, Enum.EasingStyle.Quad)
			end
			task.wait(config.CloseSeconds)
			TrapKit.lethal(hooks, crush, config.HoldSeconds)
			for i, wall in walls do
				TrapKit.move(wall, open[i], config.OpenSeconds)
			end
			task.wait(config.OpenSeconds)
		end,
	}
end
