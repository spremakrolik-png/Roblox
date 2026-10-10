--!strict
-- Trap segment: a basin with raised refuges. Acid rises from below; anyone not up on a refuge
-- dissolves. Each refuge has a step, so it is two easy jumps up.
-- params: refuges (how many refuges).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local TrapsConfig = require(ReplicatedStorage.Shared.Config.Traps)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)
local TrapKit = require(script.Parent.Parent.TrapKit)

local STEP_TOP = 3.5
local REFUGE_TOP = 7
local REFUGE_LENGTH = 6
local ACID_BOTTOM = -3

return function(ctx: Types.SegmentContext): Types.TrapHandle
	local config = TrapsConfig.RisingFlood
	local info = TrapsConfig.info("RisingFlood")
	local half = ctx.width / 2
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	SegmentKit.slab(ctx, { z0 = z0, z1 = z1, name = "Basin" })

	local count = SegmentDefs.param(ctx.def, "refuges", 3)
	local side = if ctx.rng:NextNumber() < 0.5 then -1 else 1
	for i = 1, count do
		local z = z0 + (z1 - z0) * i / (count + 1)
		local x = side * (half - 3)
		SegmentKit.slab(ctx, {
			z0 = z - REFUGE_LENGTH / 2,
			z1 = z + REFUGE_LENGTH / 2,
			x = x,
			width = 6,
			top = REFUGE_TOP,
			thickness = REFUGE_TOP,
			name = "Refuge",
			color = ctx.theme.accentColor,
		})
		SegmentKit.slab(ctx, {
			z0 = z - REFUGE_LENGTH / 2,
			z1 = z + REFUGE_LENGTH / 2,
			x = x - side * 4.5,
			width = 3,
			top = STEP_TOP,
			thickness = STEP_TOP,
			name = "RefugeStep",
		})
		side = -side
	end

	local acid = SegmentKit.slab(ctx, {
		z0 = z0,
		z1 = z1,
		width = ctx.width,
		top = ACID_BOTTOM + 0.2,
		thickness = 0.2,
		name = "Acid",
		color = info.color,
		material = Enum.Material.Neon,
		collide = false,
	})
	TrapKit.setSolid(acid, false)
	local base = SegmentKit.at(ctx, 0, 0, (z0 + z1) / 2)
	local width, length = acid.Size.X, acid.Size.Z

	local function setLevel(level: number)
		local height = level - ACID_BOTTOM
		acid.Size = Vector3.new(width, height, length)
		acid.CFrame = base * CFrame.new(0, ACID_BOTTOM + height / 2, 0)
	end

	-- Raises (or lowers) the acid over `seconds`; while `lethal`, dissolves runners near its surface.
	local function animate(hooks: Types.TrapHooks, from: number, to: number, seconds: number, lethal: boolean)
		local started = os.clock()
		repeat
			RunService.Heartbeat:Wait()
			local alpha = math.clamp((os.clock() - started) / seconds, 0, 1)
			local level = from + (to - from) * alpha
			setLevel(level)
			if lethal and hooks.isLive() then
				local box = TrapKit.box(ctx, -half - 1, half + 1, -3, level + config.LethalMargin, z0, z1)
				for _, player in hooks.runnersIn(box) do
					hooks.kill(player)
				end
			end
		until alpha >= 1
	end

	return {
		zone = TrapKit.segmentZone(ctx),
		activate = function(hooks: Types.TrapHooks)
			acid.Transparency = 0.35
			setLevel(ACID_BOTTOM + 0.2)
			TrapKit.blink({ acid }, info.color, config.Telegraph)
			acid.Transparency = 0.35
			animate(hooks, ACID_BOTTOM + 0.2, config.FloodHeight, config.RiseSeconds, true)
			animate(hooks, config.FloodHeight, config.FloodHeight, config.HoldSeconds, true)
			animate(hooks, config.FloodHeight, ACID_BOTTOM + 0.2, config.DrainSeconds, false)
			TrapKit.setSolid(acid, false)
		end,
	}
end
