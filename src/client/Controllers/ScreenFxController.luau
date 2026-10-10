--!strict
-- Screen effects for the local player: "dynamic vision" while fast (wider field of view, speed lines,
-- richer colours), a punch for Dash, frosty edges when slowed by the cannon, soft edges in Feather
-- Fall, a red flash and shake on death, confetti at the finish and a floating "+N" reward.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local UI = require(script.Parent.Parent.Util.UI)

local SPEED_FOV = 14
local DASH_FOV = 20
local SLOW_FOV = -6
local FOV_LERP = 10 -- how fast the field of view follows its target (per second)
local LINES_PER_SECOND = 70
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 90, 120),
	Color3.fromRGB(255, 205, 60),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(120, 230, 140),
	Color3.fromRGB(200, 130, 255),
}

local player = Players.LocalPlayer

local ScreenFxController = {}

local gui: ScreenGui
local linesLayer: Frame
local flash: Frame
local edges: { Frame } = {}
local correction: ColorCorrectionEffect

local baseFov = 70
local speedUntil = 0
local dashUntil = 0
local slowUntil = 0
local floatUntil = 0
local shakeUntil = 0
local lineBudget = 0

-- Speed lines -------------------------------------------------------------------------------

local function spawnLine()
	local angle = math.random() * math.pi * 2
	local direction = Vector2.new(math.cos(angle), math.sin(angle))
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BorderSizePixel = 0
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.BackgroundTransparency = 0.45
	line.Rotation = math.deg(angle)
	local length = math.random(80, 180)
	line.Size = UDim2.fromOffset(length, 2)
	local start = 0.32 + math.random() * 0.1
	line.Position = UDim2.fromScale(0.5 + direction.X * start, 0.5 + direction.Y * start)
	line.Parent = linesLayer
	local finish = start + 0.35
	local tween = TweenService:Create(line, TweenInfo.new(0.28, Enum.EasingStyle.Linear), {
		Position = UDim2.fromScale(0.5 + direction.X * finish, 0.5 + direction.Y * finish),
		BackgroundTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		line:Destroy()
	end)
end

-- Edge glow (frost, feather) ----------------------------------------------------------------

local function buildEdges()
	-- Four gradient strips fading towards the centre of the screen.
	local specs = {
		{ size = UDim2.fromScale(1, 0.22), position = UDim2.fromScale(0, 0), rotation = 90 },
		{ size = UDim2.fromScale(1, 0.22), position = UDim2.fromScale(0, 0.78), rotation = -90 },
		{ size = UDim2.fromScale(0.16, 1), position = UDim2.fromScale(0, 0), rotation = 0 },
		{ size = UDim2.fromScale(0.16, 1), position = UDim2.fromScale(0.84, 0), rotation = 180 },
	}
	for _, spec in specs do
		local edge = Instance.new("Frame")
		edge.Size = spec.size
		edge.Position = spec.position
		edge.BorderSizePixel = 0
		edge.BackgroundColor3 = Color3.new(1, 1, 1)
		edge.BackgroundTransparency = 1
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = spec.rotation
		gradient.Transparency = NumberSequence.new(0, 1)
		gradient.Parent = edge
		edge.Parent = gui
		table.insert(edges, edge)
	end
end

local function setEdges(color: Color3, transparency: number)
	for _, edge in edges do
		edge.BackgroundColor3 = color
		TweenService:Create(edge, TweenInfo.new(0.3), { BackgroundTransparency = transparency }):Play()
	end
end

-- Frame update ------------------------------------------------------------------------------

local function update(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	local fast = now < speedUntil
	local dashing = now < dashUntil
	local slowed = now < slowUntil

	local target = baseFov
	if fast then
		target += SPEED_FOV
	end
	if dashing then
		target += DASH_FOV
	end
	if slowed then
		target += SLOW_FOV
	end
	camera.FieldOfView += (target - camera.FieldOfView) * math.min(1, dt * FOV_LERP)

	if fast or dashing then
		lineBudget += dt * LINES_PER_SECOND * (if dashing then 2 else 1)
		while lineBudget >= 1 do
			lineBudget -= 1
			spawnLine()
		end
	else
		lineBudget = 0
	end

	-- Colour grading: vivid when fast, cold when slowed.
	local saturation = if fast or dashing then 0.3 elseif slowed then -0.35 else 0
	local tint = if slowed then Color3.fromRGB(205, 232, 255) else Color3.new(1, 1, 1)
	correction.Saturation += (saturation - correction.Saturation) * math.min(1, dt * 6)
	correction.TintColor = correction.TintColor:Lerp(tint, math.min(1, dt * 6))
	correction.Contrast += ((if fast then 0.08 else 0) - correction.Contrast) * math.min(1, dt * 6)

	if now < shakeUntil then
		local strength = (shakeUntil - now) * 0.6
		camera.CFrame *= CFrame.Angles(
			(math.random() - 0.5) * strength * 0.05,
			(math.random() - 0.5) * strength * 0.05,
			0
		)
	end
end

local function refreshEdges()
	local now = os.clock()
	if now < slowUntil then
		setEdges(Color3.fromRGB(150, 220, 255), 0.35)
	elseif now < floatUntil then
		setEdges(Color3.fromRGB(255, 220, 240), 0.6)
	else
		setEdges(Color3.new(1, 1, 1), 1)
	end
end

local function after(seconds: number)
	task.delay(seconds + 0.05, refreshEdges)
end

-- Events ---------------------------------------------------------------------------------------

local function onAbilityEffect(effect: string, seconds: number)
	local now = os.clock()
	if effect == "Speed" then
		speedUntil = math.max(speedUntil, now + seconds)
	elseif effect == "Dash" then
		dashUntil = now + math.max(seconds, 0.25)
	elseif effect == "Slowed" then
		slowUntil = math.max(slowUntil, now + seconds)
		refreshEdges()
		after(seconds)
	elseif effect == "FeatherFall" then
		floatUntil = math.max(floatUntil, now + seconds)
		refreshEdges()
		after(seconds)
	end
end

local function redFlash()
	flash.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
	flash.BackgroundTransparency = 0.35
	TweenService:Create(flash, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
	shakeUntil = os.clock() + 0.45
end

local function confetti()
	for _ = 1, 70 do
		local piece = Instance.new("Frame")
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)]
		piece.Size = UDim2.fromOffset(math.random(6, 12), math.random(10, 18))
		piece.Position = UDim2.new(math.random(), 0, 0, -20)
		piece.Rotation = math.random(0, 360)
		piece.Parent = gui
		local seconds = 1.6 + math.random() * 1.4
		local tween =
			TweenService:Create(piece, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromScale(piece.Position.X.Scale + (math.random() - 0.5) * 0.2, 1.05),
				Rotation = piece.Rotation + math.random(-540, 540),
			})
		tween:Play()
		tween.Completed:Connect(function()
			piece:Destroy()
		end)
	end
end

local function rewardPopup(points: number)
	local label = UI.label({
		name = "Reward",
		parent = gui,
		text = `+{points} очков`,
		size = UDim2.fromScale(0.5, 0.1),
		position = UDim2.fromScale(0.5, 0.2),
		anchor = Vector2.new(0.5, 0.5),
		color = UI.Colors.Gold,
		maxTextSize = 64,
	})
	label.TextStrokeTransparency = 0
	UI.popIn(label)
	local rise = TweenService:Create(label, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.12),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	task.delay(0.8, function()
		rise:Play()
	end)
	rise.Completed:Connect(function()
		label:Destroy()
	end)
end

function ScreenFxController.start()
	gui = UI.screen("ScreenFx", 5)
	gui.IgnoreGuiInset = true
	linesLayer = Instance.new("Frame")
	linesLayer.Name = "SpeedLines"
	linesLayer.BackgroundTransparency = 1
	linesLayer.Size = UDim2.fromScale(1, 1)
	linesLayer.Parent = gui
	buildEdges()
	flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BorderSizePixel = 0
	flash.BackgroundTransparency = 1
	flash.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")

	correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "AbilityGrading"
	local function attach()
		local camera = workspace.CurrentCamera
		if camera then
			correction.Parent = camera
			baseFov = 70
		end
	end
	attach()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attach)

	Remotes.AbilityEffect.OnClientEvent:Connect(function(effect: string, seconds: number)
		onAbilityEffect(effect, seconds)
	end)
	player:GetAttributeChangedSignal(GameState.PlayerKeys.Status):Connect(function()
		local status = GameState.getStatus(player)
		if status == "Eliminated" then
			redFlash()
		elseif status == "Finished" then
			confetti()
		end
	end)
	Remotes.RoundResults.OnClientEvent:Connect(function(results: Types.RoundResults)
		for _, award in results.awards do
			if award.userId == player.UserId and award.points > 0 then
				task.delay(1, rewardPopup, award.points)
			end
		end
	end)
	-- Right after the camera scripts, so the shake is not overwritten.
	RunService:BindToRenderStep("ScreenFx", Enum.RenderPriority.Camera.Value + 1, update)
end

return ScreenFxController
