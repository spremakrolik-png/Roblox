--!strict
-- Ability buttons (keys 1-6 or big on-screen buttons) in a round and in the lobby, Double Jump,
-- the Slow Cannon aim and the Blind Flash overlay. The server decides everything; this only sends requests.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local Icons = require(script.Parent.Parent.Util.Icons)
local UI = require(script.Parent.Parent.Util.UI)
local SoundController = require(script.Parent.SoundController)

local BUTTON_SIZE = 84
local COMPACT_SIZE = 56 -- lobby slots can hold up to six abilities
local MAX_SLOTS = 6
local AIM_DISTANCE = 200
local DOUBLE_JUMP_DELAY = 0.2 -- seconds in the air before a jump press counts as the second jump
local LASER_COLOR = Color3.fromRGB(80, 220, 255)
local LASER_IDLE = Color3.fromRGB(140, 145, 160)

local player = Players.LocalPlayer

local AbilityController = {}

type SlotButton = {
	state: Types.AbilitySlotState,
	button: TextButton,
	cooldown: TextLabel,
	shade: Frame,
}

local column: Frame
local slotButtons: { SlotButton } = {}
local flash: Frame

local KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
}

-- Slow Cannon aim -------------------------------------------------------------------------
-- On a PC with a mouse the cannon aims at the cursor, on a phone at the centre of the screen.
-- A laser from the muzzle shows where the shot will go.

local laser: Part
local laserDot: Part

local function muzzlePosition(character: Model, root: BasePart): Vector3
	local cannon = character:FindFirstChild("SlowCannonFx")
	local barrel = cannon and cannon:FindFirstChild("Barrel")
	local muzzle = barrel and barrel:FindFirstChild("Muzzle")
	if muzzle and muzzle:IsA("Attachment") then
		return muzzle.WorldPosition
	end
	return root.Position + Vector3.new(0, 1.5, 0)
end

-- Muzzle and target point, or nil without a character.
local function aimPoints(): (Vector3?, Vector3?)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not character or not root or not root:IsA("BasePart") then
		return nil, nil
	end
	local screen: Vector2
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		screen = UserInputService:GetMouseLocation()
	else
		screen = camera.ViewportSize / 2
	end
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, laser, laserDot }
	params.CollisionGroup = GameConfig.CollisionGroups.Projectile
	local hit = workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
	local target = if hit then hit.Position else ray.Origin + ray.Direction * AIM_DISTANCE
	return muzzlePosition(character, root), target
end

local function aimDirection(): Vector3?
	local muzzle, target = aimPoints()
	if not muzzle or not target then
		return nil
	end
	local direction = target - muzzle
	return if direction.Magnitude > 0.1 then direction.Unit else nil
end

local function laserPart(name: string, shape: Enum.PartType): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = LASER_COLOR
	return part
end

local function updateLaser()
	local cannon: Types.AbilitySlotState? = nil
	for _, entry in slotButtons do
		if entry.state.id == "SlowCannon" then
			cannon = entry.state
		end
	end
	if not cannon then
		laser.Parent = nil
		laserDot.Parent = nil
		return
	end
	local muzzle, target = aimPoints()
	if not muzzle or not target then
		laser.Parent = nil
		laserDot.Parent = nil
		return
	end
	local ready = not cannon.used and workspace:GetServerTimeNow() >= cannon.readyAt
	local length = (target - muzzle).Magnitude
	laser.Size = Vector3.new(length, 0.12, 0.12)
	laser.CFrame = CFrame.lookAt((muzzle + target) / 2, target) * CFrame.Angles(0, math.pi / 2, 0)
	laser.Color = if ready then LASER_COLOR else LASER_IDLE
	laser.Transparency = if ready then 0.35 else 0.75
	laserDot.Position = target
	laserDot.Color = laser.Color
	laserDot.Transparency = if ready then 0.1 else 0.6
	laser.Parent = workspace.CurrentCamera
	laserDot.Parent = workspace.CurrentCamera
end

local function use(slot: number)
	for _, entry in slotButtons do
		local state = entry.state
		if state.slot == slot then
			if state.kind ~= "Active" and state.kind ~= "OncePerRound" then
				return
			end
			if state.used or workspace:GetServerTimeNow() < state.readyAt then
				return
			end
			local aim = if state.id == "SlowCannon" then aimDirection() else nil
			Remotes.UseAbility:FireServer(slot, aim)
			SoundController.play("Ability")
			return
		end
	end
end

local function rebuild(states: { Types.AbilitySlotState })
	for _, entry in slotButtons do
		entry.button:Destroy()
	end
	table.clear(slotButtons)
	local height = if #states > 3 then COMPACT_SIZE else BUTTON_SIZE
	for index, state in states do
		local icon = Icons.ability(state.id)
		local button = Instance.new("TextButton")
		button.Name = `Slot{state.slot}`
		button.Size = UDim2.fromOffset(BUTTON_SIZE * 1.9, height)
		button.LayoutOrder = index
		button.BackgroundColor3 = UI.Colors.Panel
		button.BackgroundTransparency = 0.1
		button.AutoButtonColor = false
		button.Text = ""
		button.ClipsDescendants = true
		UI.corner(button, 14)
		UI.gradient(button, Color3.fromRGB(44, 48, 66), Color3.fromRGB(18, 20, 30))
		UI.stroke(button, icon.color, 2, 0.2)
		UI.iconTile(button, icon.glyph, icon.color, UDim2.fromOffset(height - 14, height - 14), UDim2.fromOffset(7, 7))
		UI.label({
			name = "Key",
			parent = button,
			text = tostring(state.slot),
			size = UDim2.fromOffset(20, 20),
			position = UDim2.fromOffset(3, 1),
			color = UI.Colors.Gold,
			alignX = Enum.TextXAlignment.Left,
		}).ZIndex =
			3
		UI.label({
			name = "Name",
			parent = button,
			text = state.name,
			size = UDim2.new(1, -(height + 4), 0.5, 0),
			position = UDim2.new(0, height, 0.1, 0),
			alignX = Enum.TextXAlignment.Left,
			maxTextSize = 20,
		})
		local cooldown = UI.label({
			name = "Cooldown",
			parent = button,
			size = UDim2.new(1, -(height + 4), 0.32, 0),
			position = UDim2.new(0, height, 0.6, 0),
			color = UI.Colors.Muted,
			font = Enum.Font.SourceSansSemibold,
			alignX = Enum.TextXAlignment.Left,
			maxTextSize = 18,
		})
		-- Darkness that drains downwards while the ability recharges.
		local shade = Instance.new("Frame")
		shade.Name = "Shade"
		shade.AnchorPoint = Vector2.new(0, 1)
		shade.Position = UDim2.fromScale(0, 1)
		shade.Size = UDim2.fromScale(1, 0)
		shade.BackgroundColor3 = Color3.new(0, 0, 0)
		shade.BackgroundTransparency = 0.45
		shade.BorderSizePixel = 0
		shade.ZIndex = 2
		shade.Parent = button
		UI.pressable(button)
		button.Activated:Connect(function()
			use(state.slot)
		end)
		button.Parent = column
		UI.popIn(button)
		table.insert(slotButtons, { state = state, button = button, cooldown = cooldown, shade = shade })
	end
	column.Visible = #slotButtons > 0
end

local function refresh()
	local now = workspace:GetServerTimeNow()
	for _, entry in slotButtons do
		local state = entry.state
		local text: string
		local ready = false
		local shade = 0
		if state.kind == "Passive" then
			text = "всегда активно"
		elseif state.kind == "OncePassive" then
			text = if state.used then "использовано" else "готово"
			shade = if state.used then 1 else 0
		elseif state.used then
			text = "использовано"
			shade = 1
		elseif now < state.readyAt then
			local remaining = state.readyAt - now
			text = string.format("%d с", math.ceil(remaining))
			local def = Abilities.byId[state.id]
			local total = if def and def.cooldown > 0 then def.cooldown else remaining
			shade = math.clamp(remaining / total, 0, 1)
		else
			text = "готово"
			ready = true
		end
		if entry.cooldown.Text ~= text then
			entry.cooldown.Text = text
		end
		entry.cooldown.TextColor3 = if ready then Color3.fromRGB(110, 230, 140) else UI.Colors.Muted
		entry.shade.Size = UDim2.fromScale(1, shade)
	end
end

-- Double Jump ---------------------------------------------------------------------------

local airborneSince = 0
local usedSecondJump = false

-- A ring of air under the feet on the second jump.
local function jumpRing(position: Vector3)
	local ring = Instance.new("Part")
	ring.Name = "DoubleJumpRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(150, 240, 190)
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace.CurrentCamera
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, 7, 7),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.4)
end

local function setupDoubleJump()
	local function watch(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then
			return
		end
		humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Freefall or new == Enum.HumanoidStateType.Jumping then
				if airborneSince == 0 then
					airborneSince = os.clock()
				end
			elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
				airborneSince = 0
				usedSecondJump = false
			end
		end)
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end

	UserInputService.JumpRequest:Connect(function()
		if player:GetAttribute("DoubleJump") ~= true or usedSecondJump or airborneSince == 0 then
			return
		end
		if os.clock() - airborneSince < DOUBLE_JUMP_DELAY then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			usedSecondJump = true
			local velocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, GameConfig.JumpPower, velocity.Z)
			jumpRing(root.Position - Vector3.new(0, 2.8, 0))
			SoundController.play("Ability")
		end
	end)
end

-- Feather Fall: cap the downward speed of our own character for a while.
local function featherFall(seconds: number, maxFallSpeed: number)
	local stop = os.clock() + seconds
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if os.clock() >= stop or not root or not root:IsA("BasePart") then
			if connection then
				connection:Disconnect()
			end
			return
		end
		local velocity = root.AssemblyLinearVelocity
		if velocity.Y < -maxFallSpeed then
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, -maxFallSpeed, velocity.Z)
		end
	end)
end

-- Blind Flash -------------------------------------------------------------------------------

local function onBlindFlash(seconds: number)
	flash.BackgroundTransparency = 0.02
	flash.Visible = true
	local fade = TweenService:Create(
		flash,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }
	)
	fade:Play()
	fade.Completed:Connect(function()
		flash.Visible = false
	end)
end

function AbilityController.start()
	local gui = UI.screen("Abilities", 7)
	column = Instance.new("Frame")
	column.Name = "Slots"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(1, 0.5)
	column.Position = UDim2.new(1, -12, 0.35, 0)
	column.Size = UDim2.fromOffset(BUTTON_SIZE * 1.9, (COMPACT_SIZE + 8) * MAX_SLOTS)
	column.Visible = false
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = column
	column.Parent = gui

	local flashGui = UI.screen("BlindFlash", 20)
	flashGui.IgnoreGuiInset = true
	flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BorderSizePixel = 0
	flash.Visible = false
	flash.Parent = flashGui

	gui.Parent = player:WaitForChild("PlayerGui")
	flashGui.Parent = player:WaitForChild("PlayerGui")

	Remotes.AbilityState.OnClientEvent:Connect(function(states: { Types.AbilitySlotState })
		rebuild(states)
	end)
	Remotes.BlindFlash.OnClientEvent:Connect(function(seconds: number)
		onBlindFlash(seconds)
	end)
	Remotes.AbilityEffect.OnClientEvent:Connect(function(effect: string, seconds: number, value: number)
		if effect == "FeatherFall" then
			featherFall(seconds, value)
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local slot = KEYS[input.KeyCode]
		if slot then
			use(slot)
		end
	end)
	setupDoubleJump()
	laser = laserPart("CannonLaser", Enum.PartType.Block)
	laserDot = laserPart("CannonTarget", Enum.PartType.Ball)
	laserDot.Size = Vector3.one * 0.8
	RunService.Heartbeat:Connect(refresh)
	RunService.RenderStepped:Connect(updateLaser)
end

return AbilityController
