--!strict
-- Trap segment: a ceiling of panels. After a blink most panels drop to the floor and crush anyone under
-- them; the panels over the green niches stay up, so standing in a niche is safe.
-- params: safeShare (share of panels that stay up).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local TrapsConfig = require(ReplicatedStorage.Shared.Config.Traps)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)
local TrapKit = require(script.Parent.Parent.TrapKit)

local PANEL_LENGTH = 4
local PANEL_THICKNESS = 1

return function(ctx: Types.SegmentContext): Types.TrapHandle
	local config = TrapsConfig.FallingCeiling
	local info = TrapsConfig.info("FallingCeiling")
	local half = ctx.width / 2
	local height = config.CeilingHeight
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	SegmentKit.slab(ctx, { z0 = z0, z1 = z1, name = "Floor" })
	-- Posts along the open edge make the ceiling read as a structure.
	for _, z in { z0, (z0 + z1) / 2, z1 } do
		SegmentKit.slab(ctx, {
			z0 = z - 0.5,
			z1 = z + 0.5,
			x = -half - 0.5,
			width = 1,
			top = height + PANEL_THICKNESS,
			thickness = height + PANEL_THICKNESS,
			name = "Post",
			color = ctx.theme.wallColor,
		})
	end

	local count, length = SegmentKit.layout(z1 - z0, PANEL_LENGTH, 0.05)
	local safeEvery = math.max(2, math.floor(1 / SegmentDefs.param(ctx.def, "safeShare", 0.3) + 0.5))
	local offset = ctx.rng:NextInteger(1, safeEvery)
	local falling: { BasePart } = {}
	local up: { CFrame } = {}
	local down: { CFrame } = {}
	local crushes: { Types.Box } = {}
	for i = 1, count do
		local start = z0 + 0.05 * i + length * (i - 1)
		local panel = SegmentKit.slab(ctx, {
			z0 = start,
			z1 = start + length,
			top = height + PANEL_THICKNESS,
			thickness = PANEL_THICKNESS,
			name = "CeilingPanel",
			color = ctx.theme.wallColor,
		})
		if (i + offset) % safeEvery == 0 then
			-- A niche: this panel never falls; the floor under it is marked.
			SegmentKit.slab(ctx, {
				z0 = start,
				z1 = start + length,
				top = 0.06,
				thickness = 0.05,
				name = "NicheMark",
				color = Color3.fromRGB(70, 220, 110),
				material = Enum.Material.Neon,
				collide = false,
			})
		else
			table.insert(falling, panel)
			table.insert(up, panel.CFrame)
			table.insert(down, panel.CFrame * CFrame.new(0, -height, 0))
			table.insert(crushes, TrapKit.box(ctx, -half - 1, half + 1, -3, height, start, start + length))
		end
	end

	return {
		zone = TrapKit.segmentZone(ctx),
		activate = function(hooks: Types.TrapHooks)
			TrapKit.blink(falling, info.color, config.Telegraph)
			for i, panel in falling do
				TrapKit.move(panel, down[i], config.DropSeconds, Enum.EasingStyle.Quad)
			end
			task.wait(config.DropSeconds)
			for _, box in crushes do
				for _, player in hooks.runnersIn(box) do
					hooks.kill(player)
				end
			end
			task.wait(config.HoldSeconds)
			for i, panel in falling do
				TrapKit.move(panel, up[i], config.RiseSeconds)
			end
			task.wait(config.RiseSeconds)
		end,
	}
end
