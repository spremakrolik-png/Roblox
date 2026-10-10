--!strict
-- Trap segment: the floor is a grid of tiles. On activation a random part of them blinks red and
-- drops away for a few seconds; every row keeps at least one solid tile.
-- params: fallShare (share of tiles that drop).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local TrapsConfig = require(ReplicatedStorage.Shared.Config.Traps)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)
local TrapKit = require(script.Parent.Parent.TrapKit)

local COLUMNS = 3
local ROW_LENGTH = 4
local GAP = 0.15

return function(ctx: Types.SegmentContext): Types.TrapHandle
	local config = TrapsConfig.FakeFloor
	local info = TrapsConfig.info("FakeFloor")
	local half = ctx.width / 2
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	local count, length = SegmentKit.layout(z1 - z0, ROW_LENGTH, GAP)
	local tileWidth = (ctx.width - GAP * (COLUMNS - 1)) / COLUMNS
	local rows: { { BasePart } } = {}
	for row = 1, count do
		local start = z0 + GAP * row + length * (row - 1)
		local tiles: { BasePart } = {}
		for column = 1, COLUMNS do
			local x = -half + tileWidth / 2 + (column - 1) * (tileWidth + GAP)
			tiles[column] = SegmentKit.slab(ctx, {
				z0 = start,
				z1 = start + length,
				x = x,
				width = tileWidth,
				name = "Tile",
				color = if (row + column) % 2 == 0
					then ctx.theme.floorColor
					else ctx.theme.floorColor:Lerp(Color3.new(1, 1, 1), 0.2),
			})
		end
		rows[row] = tiles
	end

	local fallShare = SegmentDefs.param(ctx.def, "fallShare", 0.4)
	local over = TrapKit.box(ctx, -half - 2, half + 2, -GameConfig.Track.FallKillDepth, 16, z0, z1)
	local picker = Random.new()

	return {
		zone = TrapKit.segmentZone(ctx),
		activate = function(hooks: Types.TrapHooks)
			local dropping: { BasePart } = {}
			for _, tiles in rows do
				local keep = picker:NextInteger(1, #tiles)
				for column, tile in tiles do
					if column ~= keep and picker:NextNumber() < fallShare then
						table.insert(dropping, tile)
					end
				end
			end
			TrapKit.blink(dropping, info.color, config.Telegraph)
			for _, tile in dropping do
				TrapKit.setSolid(tile, false)
			end
			TrapKit.markWhile(hooks, over, config.GoneSeconds)
			for _, tile in dropping do
				TrapKit.setSolid(tile, true)
			end
		end,
	}
end
