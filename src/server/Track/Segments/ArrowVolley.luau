--!strict
-- Trap segment: a wall on the open side shoots volleys of arrows across the track along lanes that
-- glow red first. Lanes alternate between volleys; the gaps between lanes are safe.
-- params: laneWidth, gapWidth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local TrapsConfig = require(ReplicatedStorage.Shared.Config.Traps)
local Types = require(ReplicatedStorage.Shared.Types)
local Build = require(script.Parent.Parent.Parent.Util.Build)
local SegmentKit = require(script.Parent.Parent.SegmentKit)
local TrapKit = require(script.Parent.Parent.TrapKit)

local ARROW_HEIGHTS = { 1.5, 3.5 }

type Lane = { marker: BasePart, box: Types.Box, z: number }

return function(ctx: Types.SegmentContext): Types.TrapHandle
	local config = TrapsConfig.ArrowVolley
	local info = TrapsConfig.info("ArrowVolley")
	local half = ctx.width / 2
	local wallHeight = GameConfig.Track.GateHeight
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	SegmentKit.slab(ctx, { z0 = z0, z1 = z1, name = "Floor" })
	SegmentKit.slab(ctx, {
		z0 = z0,
		z1 = z1,
		x = -half - 0.5,
		width = 1,
		top = wallHeight,
		thickness = wallHeight,
		name = "ArrowWall",
		color = ctx.theme.wallColor,
	})

	local laneWidth = SegmentDefs.param(ctx.def, "laneWidth", 2)
	local gapWidth = SegmentDefs.param(ctx.def, "gapWidth", 3)
	local lanes: { Lane } = {}
	local z = z0 + gapWidth / 2
	while z + laneWidth <= z1 - gapWidth / 2 do
		local marker = SegmentKit.slab(ctx, {
			z0 = z,
			z1 = z + laneWidth,
			top = 0.06,
			thickness = 0.05,
			name = "LaneMark",
			color = Color3.fromRGB(110, 30, 30),
			material = Enum.Material.SmoothPlastic,
			collide = false,
		})
		table.insert(lanes, {
			marker = marker,
			box = TrapKit.box(ctx, -half - 1, half + 1, -3, 8, z, z + laneWidth),
			z = z + laneWidth / 2,
		})
		z += laneWidth + gapWidth
	end

	local function shoot(lane: Lane)
		for _, height in ARROW_HEIGHTS do
			local arrow = Build.part({
				name = "Arrow",
				size = Vector3.new(3, 0.3, 0.3),
				cframe = SegmentKit.at(ctx, -half, height, lane.z),
				color = info.color,
				material = Enum.Material.Neon,
				canCollide = false,
				canTouch = false,
				canQuery = false,
				castShadow = false,
				parent = ctx.parent,
			})
			TrapKit.move(arrow, SegmentKit.at(ctx, half, height, lane.z), config.FlightSeconds)
			task.delay(config.FlightSeconds, function()
				arrow:Destroy()
			end)
		end
	end

	return {
		zone = TrapKit.segmentZone(ctx),
		activate = function(hooks: Types.TrapHooks)
			for volley = 1, config.Volleys do
				if not hooks.isLive() then
					return
				end
				local active: { Lane } = {}
				for index, lane in lanes do
					if index % 2 == volley % 2 then
						table.insert(active, lane)
					end
				end
				local markers: { BasePart } = {}
				for _, lane in active do
					table.insert(markers, lane.marker)
				end
				TrapKit.blink(markers, info.color, config.Telegraph)
				for _, lane in active do
					shoot(lane)
				end
				task.wait(config.FlightSeconds / 2)
				for _, lane in active do
					for _, player in hooks.runnersIn(lane.box) do
						hooks.kill(player)
					end
				end
				task.wait(config.VolleyInterval)
			end
		end,
	}
end
