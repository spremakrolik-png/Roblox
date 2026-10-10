--!strict
-- Helpers shared by trap segments: zones in segment-local coordinates, telegraph blinking,
-- lethal zone loops and tweens. Coordinates match SegmentKit (z forward, x right, y up).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.SegmentKit)

local BLINK_INTERVAL = 0.12
local LETHAL_TICK = 0.1

local TrapKit = {}

-- An oriented box in the segment's frame: x in [x0, x1], y in [y0, y1], forward z in [z0, z1].
function TrapKit.box(
	ctx: Types.SegmentContext,
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	z0: number,
	z1: number
): Types.Box
	return {
		cframe = SegmentKit.at(ctx, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		size = Vector3.new(x1 - x0, y1 - y0, z1 - z0),
	}
end

-- The whole segment, tall enough to include jumping runners (used for on-screen warnings).
function TrapKit.segmentZone(ctx: Types.SegmentContext): Types.Box
	local half = ctx.width / 2
	return TrapKit.box(ctx, -half - 2, half, -6, 16, 0, ctx.def.length)
end

-- Flashes parts between their own look and the warning colour for `duration` seconds. Yields.
function TrapKit.blink(parts: { BasePart }, color: Color3, duration: number)
	local originals: { { color: Color3, material: Enum.Material } } = {}
	for i, part in parts do
		originals[i] = { color = part.Color, material = part.Material }
	end
	local lit = false
	local deadline = os.clock() + duration
	while os.clock() < deadline do
		lit = not lit
		for i, part in parts do
			part.Color = if lit then color else originals[i].color
			part.Material = if lit then Enum.Material.Neon else originals[i].material
		end
		task.wait(BLINK_INTERVAL)
	end
	for i, part in parts do
		part.Color = originals[i].color
		part.Material = originals[i].material
	end
end

-- Kills every runner inside `box` for `duration` seconds. Yields.
function TrapKit.lethal(hooks: Types.TrapHooks, box: Types.Box, duration: number)
	local deadline = os.clock() + duration
	repeat
		if not hooks.isLive() then
			return
		end
		for _, player in hooks.runnersIn(box) do
			hooks.kill(player)
		end
		task.wait(LETHAL_TICK)
	until os.clock() >= deadline
end

-- Marks every runner inside `box` as hit (so a fall soon after is credited) for `duration` seconds. Yields.
function TrapKit.markWhile(hooks: Types.TrapHooks, box: Types.Box, duration: number)
	local deadline = os.clock() + duration
	repeat
		if not hooks.isLive() then
			return
		end
		for _, player in hooks.runnersIn(box) do
			hooks.markHit(player)
		end
		task.wait(LETHAL_TICK)
	until os.clock() >= deadline
end

-- Tweens properties of a part. Returns the tween (already playing).
function TrapKit.tween(part: BasePart, seconds: number, goals: { [string]: any }, style: Enum.EasingStyle?): Tween
	local tween = TweenService:Create(
		part,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Linear, Enum.EasingDirection.In),
		goals
	)
	tween:Play()
	return tween
end

-- Tweens an anchored part's CFrame. Returns the tween (already playing).
function TrapKit.move(part: BasePart, target: CFrame, seconds: number, style: Enum.EasingStyle?): Tween
	return TrapKit.tween(part, seconds, { CFrame = target }, style)
end

-- Hides a part completely (no collision, no queries) or brings it back.
function TrapKit.setSolid(part: BasePart, solid: boolean, transparency: number?)
	part.CanCollide = solid
	part.CanQuery = solid
	part.CanTouch = solid
	part.Transparency = if solid then (transparency or 0) else 1
end

return TrapKit
