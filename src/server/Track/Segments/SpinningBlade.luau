--!strict
-- Trap segment: a blade appears at foot height around a post in the middle of the segment and spins
-- for a few seconds. Jump over it as it passes.
-- params: revolution (seconds per full turn).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local TrapsConfig = require(ReplicatedStorage.Shared.Config.Traps)
local Types = require(ReplicatedStorage.Shared.Types)
local SegmentKit = require(script.Parent.Parent.SegmentKit)
local TrapKit = require(script.Parent.Parent.TrapKit)

return function(ctx: Types.SegmentContext): Types.TrapHandle
	local config = TrapsConfig.SpinningBlade
	local info = TrapsConfig.info("SpinningBlade")
	local half = ctx.width / 2
	SegmentKit.entryPad(ctx)
	SegmentKit.exitPad(ctx)

	local z0, z1 = SegmentKit.innerSpan(ctx)
	SegmentKit.slab(ctx, { z0 = z0, z1 = z1, name = "Floor" })
	local middle = (z0 + z1) / 2
	local center = SegmentKit.at(ctx, 0, config.BladeHeight, middle)
	SegmentKit.pillar(ctx, 0, middle, config.BladeHeight + 0.6, 1.2)

	local radius = half
	local blade = SegmentKit.slab(ctx, {
		z0 = middle - 0.4,
		z1 = middle + 0.4,
		width = radius * 2,
		top = config.BladeHeight + 0.4,
		thickness = 0.8,
		name = "Blade",
		color = info.color,
		material = Enum.Material.Metal,
		collide = false,
	})
	TrapKit.setSolid(blade, false)
	blade.CanCollide = false

	local revolution = SegmentDefs.param(ctx.def, "revolution", 1.6)
	local reach =
		TrapKit.box(ctx, -radius - 1, radius + 1, -3, config.LethalHeight, middle - radius - 1, middle + radius + 1)

	return {
		zone = TrapKit.segmentZone(ctx),
		activate = function(hooks: Types.TrapHooks)
			blade.Transparency = 0
			TrapKit.blink({ blade }, info.color, config.Telegraph)
			local started = os.clock()
			local finished = false
			local connection = RunService.Heartbeat:Connect(function()
				local elapsed = os.clock() - started
				if elapsed >= config.SpinSeconds or not hooks.isLive() then
					finished = true
					return
				end
				local angle = elapsed / revolution * math.pi * 2
				local frame = center * CFrame.Angles(0, angle, 0)
				blade.CFrame = frame
				local along = frame.RightVector
				for _, player in hooks.runnersIn(reach) do
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						local offset = root.Position - frame.Position
						local flat = Vector3.new(offset.X, 0, offset.Z)
						local onBlade = flat:Dot(along)
						local fromLine = (flat - along * onBlade).Magnitude
						if math.abs(onBlade) <= radius and fromLine <= config.HitWidth then
							hooks.kill(player)
						end
					end
				end
			end)
			repeat
				task.wait()
			until finished
			connection:Disconnect()
			blade.Transparency = 1
		end,
	}
end
