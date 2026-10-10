--!strict
-- Trap segment: the floor is a row of blocks; after a blink they vanish in a wave from the start of
-- the segment to the end, then come back. Falling is what kills.
-- params: tileLength (length of one row of blocks).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local TrapsConfig = require(ReplicatedStorage.Shared.Config.Traps)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)
local TrapKit = require(script.Parent.Parent.TrapKit)

local ROW_GAP = 0.25

return function(ctx: Types.SegmentContext): Types.TrapHandle
	local config = TrapsConfig.VanishingBlocks
	local info = TrapsConfig.info("VanishingBlocks")
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	local count, length = SegmentKit.layout(z1 - z0, SegmentDefs.param(ctx.def, "tileLength", 4), ROW_GAP)
	local rows: { BasePart } = {}
	local delays: { number } = {}
	for i = 1, count do
		local start = z0 + ROW_GAP * i + length * (i - 1)
		rows[i] = SegmentKit.slab(ctx, {
			z0 = start,
			z1 = start + length,
			name = "Block",
			color = if i % 2 == 0 then ctx.theme.floorColor else ctx.theme.floorColor:Lerp(Color3.new(1, 1, 1), 0.2),
		})
		delays[i] = (start - z0) / config.WaveSpeed
	end

	local half = ctx.width / 2
	-- Everyone over the blocks while they drop is credited to the trap if they fall.
	local over = TrapKit.box(ctx, -half - 2, half + 2, -GameConfig.Track.FallKillDepth, 16, z0, z1)
	local wave = (z1 - z0) / config.WaveSpeed

	return {
		zone = TrapKit.segmentZone(ctx),
		activate = function(hooks: Types.TrapHooks)
			TrapKit.blink(rows, info.color, config.Telegraph)
			task.spawn(TrapKit.markWhile, hooks, over, wave + 1.5)
			for i, row in rows do
				task.delay(delays[i], function()
					TrapKit.setSolid(row, false)
					task.delay(config.GoneSeconds, function()
						TrapKit.setSolid(row, true)
					end)
				end)
			end
			task.wait(wave + config.GoneSeconds)
		end,
	}
end
