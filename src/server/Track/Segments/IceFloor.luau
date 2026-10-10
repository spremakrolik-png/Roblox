--!strict
-- Trap segment: the floor turns to ice for a few seconds and drifts towards the open edge, so runners
-- slide off unless they push against it. Falling is what kills.
-- params: drift (studs per second towards the edge).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local TrapsConfig = require(ReplicatedStorage.Shared.Config.Traps)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)
local TrapKit = require(script.Parent.Parent.TrapKit)

return function(ctx: Types.SegmentContext): Types.TrapHandle
	local config = TrapsConfig.IceFloor
	local info = TrapsConfig.info("IceFloor")
	local half = ctx.width / 2
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	local floor = SegmentKit.slab(ctx, { z0 = z0, z1 = z1, name = "IceFloor" })
	local drift = -ctx.entry.RightVector * SegmentDefs.param(ctx.def, "drift", 9)
	local over = TrapKit.box(ctx, -half - 2, half + 2, -GameConfig.Track.FallKillDepth, 16, z0, z1)

	return {
		zone = TrapKit.segmentZone(ctx),
		activate = function(hooks: Types.TrapHooks)
			TrapKit.blink({ floor }, info.color, config.Telegraph)
			local color, material, physics = floor.Color, floor.Material, floor.CustomPhysicalProperties
			floor.Color = info.color
			floor.Material = Enum.Material.Ice
			floor.CustomPhysicalProperties = PhysicalProperties.new(0.9, 0, 0, 100, 1)
			-- An anchored part's velocity moves whoever stands on it, like a conveyor.
			floor.AssemblyLinearVelocity = drift
			TrapKit.markWhile(hooks, over, config.ActiveSeconds)
			floor.AssemblyLinearVelocity = Vector3.zero
			floor.Color = color
			floor.Material = material
			floor.CustomPhysicalProperties = physics
		end,
	}
end
