--!strict
-- Trap segment: a walled room. After a blink both gates close, poison rises for a few seconds and
-- everyone still inside dies; then the gates open again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local TrapsConfig = require(ReplicatedStorage.Shared.Config.Traps)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)
local TrapKit = require(script.Parent.Parent.TrapKit)

local GATE_THICKNESS = 0.6
local POISON_START = 0.2

return function(ctx: Types.SegmentContext): Types.TrapHandle
	local config = TrapsConfig.ClosingZone
	local info = TrapsConfig.info("ClosingZone")
	local height = GameConfig.Track.GateHeight
	local half = ctx.width / 2
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	SegmentKit.slab(ctx, { z0 = z0, z1 = z1, name = "RoomFloor" })
	SegmentKit.slab(ctx, {
		z0 = z0,
		z1 = z1,
		x = -half - 0.5,
		width = 1,
		top = height,
		thickness = height,
		name = "RoomWall",
		color = ctx.theme.wallColor,
	})

	local gates: { BasePart } = {}
	local frames: { BasePart } = {}
	for _, z in { z0, z1 } do
		local gate = SegmentKit.slab(ctx, {
			z0 = z - GATE_THICKNESS / 2,
			z1 = z + GATE_THICKNESS / 2,
			top = height,
			thickness = height,
			name = "Gate",
			color = info.color,
			material = Enum.Material.ForceField,
		})
		TrapKit.setSolid(gate, false)
		table.insert(gates, gate)
		-- Always-visible lintel so runners can see where the gates are.
		table.insert(
			frames,
			SegmentKit.slab(ctx, {
				z0 = z - 0.5,
				z1 = z + 0.5,
				top = height + 1,
				thickness = 1,
				name = "GateFrame",
				color = ctx.theme.accentColor,
				collide = false,
			})
		)
	end

	local poison = SegmentKit.slab(ctx, {
		z0 = z0 + GATE_THICKNESS,
		z1 = z1 - GATE_THICKNESS,
		top = POISON_START,
		thickness = POISON_START,
		name = "Poison",
		color = info.color,
		material = Enum.Material.Neon,
		collide = false,
	})
	TrapKit.setSolid(poison, false)
	local poisonLow = poison.CFrame
	local poisonSize = poison.Size
	local poisonHigh = poisonLow * CFrame.new(0, (height - POISON_START) / 2, 0)

	local room = TrapKit.box(ctx, -half, half, -3, height, z0 + GATE_THICKNESS / 2, z1 - GATE_THICKNESS / 2)

	return {
		zone = TrapKit.segmentZone(ctx),
		activate = function(hooks: Types.TrapHooks)
			TrapKit.blink(frames, info.color, config.Telegraph)
			for _, gate in gates do
				TrapKit.setSolid(gate, true, 0.3)
			end
			poison.Transparency = 0.55
			TrapKit.tween(poison, config.FillSeconds, {
				Size = Vector3.new(poisonSize.X, height, poisonSize.Z),
				CFrame = poisonHigh,
			})
			task.wait(config.FillSeconds)
			TrapKit.lethal(hooks, room, config.LethalSeconds)
			for _, gate in gates do
				TrapKit.setSolid(gate, false)
			end
			TrapKit.setSolid(poison, false)
			poison.Size = poisonSize
			poison.CFrame = poisonLow
		end,
	}
end
