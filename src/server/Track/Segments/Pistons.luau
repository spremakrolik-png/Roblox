--!strict
-- Trap segment: a walkway along the open edge with pistons on the glass side. After a blink the
-- pistons punch across the walkway and knock runners into the void; anyone left inside an extended
-- piston is crushed. Runners in the gaps between pistons are safe.
-- params: pistons (how many).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local TrapsConfig = require(ReplicatedStorage.Shared.Config.Traps)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)
local TrapKit = require(script.Parent.Parent.TrapKit)

local PISTON_LENGTH = 5
local PISTON_GAP = 3
local PISTON_HEIGHT = 7 -- taller than a jump, so runners cannot stand on them
local WALKWAY_EDGE = 1 -- walkway spans from the open edge to x = 1; pistons rest at x = 1..half

return function(ctx: Types.SegmentContext): Types.TrapHandle
	local config = TrapsConfig.Pistons
	local info = TrapsConfig.info("Pistons")
	local half = ctx.width / 2
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	SegmentKit.slab(ctx, {
		z0 = z0,
		z1 = z1,
		x = (-half + WALKWAY_EDGE) / 2,
		width = half + WALKWAY_EDGE,
		name = "Walkway",
	})

	local wanted = SegmentDefs.param(ctx.def, "pistons", 3)
	local count, length = SegmentKit.layout(z1 - z0, PISTON_LENGTH, PISTON_GAP)
	count = math.min(count, wanted)
	local spacing = (z1 - z0 - count * length) / (count + 1)

	local pistons: { BasePart } = {}
	local rest: { CFrame } = {}
	local out: { CFrame } = {}
	local sweeps: { Types.Box } = {}
	local crushes: { Types.Box } = {}
	local travel = half + WALKWAY_EDGE
	for i = 1, count do
		local start = z0 + spacing * i + length * (i - 1)
		local piston = SegmentKit.slab(ctx, {
			z0 = start,
			z1 = start + length,
			x = (half + WALKWAY_EDGE) / 2,
			width = half - WALKWAY_EDGE,
			top = PISTON_HEIGHT,
			thickness = PISTON_HEIGHT + 4,
			name = "Piston",
			color = ctx.theme.wallColor,
		})
		table.insert(pistons, piston)
		table.insert(rest, piston.CFrame)
		table.insert(out, piston.CFrame * CFrame.new(-travel, 0, 0))
		table.insert(
			sweeps,
			TrapKit.box(ctx, -half - 1, half, -3, PISTON_HEIGHT + 2, start - 0.5, start + length + 0.5)
		)
		table.insert(crushes, TrapKit.box(ctx, -half, -WALKWAY_EDGE, -3, PISTON_HEIGHT, start, start + length))
	end

	local push = -ctx.entry.RightVector * config.PushSpeed + Vector3.yAxis * config.PushUp

	return {
		zone = TrapKit.segmentZone(ctx),
		activate = function(hooks: Types.TrapHooks)
			TrapKit.blink(pistons, info.color, config.Telegraph)
			for i, piston in pistons do
				for _, player in hooks.runnersIn(sweeps[i]) do
					hooks.markHit(player)
					hooks.push(player, push)
				end
				TrapKit.move(piston, out[i], config.ExtendSeconds)
			end
			task.wait(config.CrushCheckDelay)
			for _, box in crushes do
				for _, player in hooks.runnersIn(box) do
					hooks.kill(player)
				end
			end
			task.wait(math.max(0, config.HoldSeconds - config.CrushCheckDelay))
			for i, piston in pistons do
				TrapKit.move(piston, rest[i], config.RetractSeconds)
			end
			task.wait(config.RetractSeconds)
		end,
	}
end
