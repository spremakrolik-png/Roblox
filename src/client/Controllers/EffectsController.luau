--!strict
-- Visual feedback that is purely cosmetic: the on-screen trap warning (the telegraph) for runners
-- inside a trap's zone, a confirmation for the trapper, the cartoon burst where a runner died and
-- the finish bursts (gold fireworks for VIP).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local UI = require(script.Parent.Parent.Util.UI)
local SoundController = require(script.Parent.SoundController)

local WARNING_EXTRA = 0.6 -- the warning stays a bit after the telegraph
local BLINK_INTERVAL = 0.15
local BURST_SECONDS = 0.45
local VIP_VOLLEYS = 5

local player = Players.LocalPlayer

local EffectsController = {}

local warning: TextLabel
local warningToken = 0

local function inBox(cframe: CFrame, size: Vector3, position: Vector3): boolean
	local relative = cframe:PointToObjectSpace(position)
	local half = size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

local function showWarning(text: string, color: Color3, seconds: number, blink: boolean)
	warningToken += 1
	local token = warningToken
	warning.Text = text
	warning.TextColor3 = color
	warning.Visible = true
	task.spawn(function()
		local deadline = os.clock() + seconds
		while os.clock() < deadline and token == warningToken do
			task.wait(BLINK_INTERVAL)
			if blink and token == warningToken then
				warning.Visible = not warning.Visible
			end
		end
		if token == warningToken then
			warning.Visible = false
		end
	end)
end

local function onTrapActivated(alert: Types.TrapAlert)
	local seconds = alert.telegraph + WARNING_EXTRA
	if GameState.getRole(player) == "Trapper" then
		showWarning(`Ловушка «{alert.name}» сработала!`, UI.Colors.Gold, seconds, false)
		SoundController.play("TrapFired")
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and inBox(alert.zoneCFrame, alert.zoneSize, root.Position) then
		showWarning(`!! {alert.name} !!`, UI.Colors.Trapper, seconds, true)
		SoundController.play("TrapWarning")
	end
end

local function burst(position: Vector3, color: Color3, scale: number?)
	local size = scale or 1
	local ball = Instance.new("Part")
	ball.Name = "DeathBurst"
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Size = Vector3.one
	ball.Position = position

	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(12 * size, 24 * size)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.8, 0)
	emitter.Parent = ball
	ball.Parent = workspace

	emitter:Emit(math.floor(30 * size))
	TweenService:Create(ball, TweenInfo.new(BURST_SECONDS * size), { Size = Vector3.one * 9 * size, Transparency = 1 })
		:Play()
	Debris:AddItem(ball, 1.5)
end

function EffectsController.start()
	local gui = UI.screen("Effects", 8)
	warning = UI.label({
		name = "TrapWarning",
		parent = gui,
		size = UDim2.fromScale(0.8, 0.1),
		position = UDim2.fromScale(0.5, 0.22),
		anchor = Vector2.new(0.5, 0.5),
		color = UI.Colors.Trapper,
		maxTextSize = 64,
	})
	warning.Visible = false
	gui.Parent = player:WaitForChild("PlayerGui")

	Remotes.TrapActivated.OnClientEvent:Connect(function(alert: Types.TrapAlert)
		onTrapActivated(alert)
	end)
	Remotes.DeathEffect.OnClientEvent:Connect(function(position: Vector3, color: Color3)
		burst(position, color)
	end)
	Remotes.FinishEffect.OnClientEvent:Connect(function(position: Vector3, vip: boolean)
		if not vip then
			burst(position, UI.Colors.Gold)
			return
		end
		-- VIP: a volley of gold fireworks above the finisher.
		for index = 0, VIP_VOLLEYS - 1 do
			task.delay(index * 0.25, function()
				local offset = Vector3.new(math.random(-8, 8), 8 + math.random(0, 8), math.random(-8, 8))
				burst(position + offset, if index % 2 == 0 then UI.Colors.Gold else Color3.new(1, 1, 1), 1.6)
			end)
		end
	end)
end

return EffectsController
