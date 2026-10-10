--!strict
-- Ability buttons during a round (keys 1/2/3 or big on-screen buttons), Double Jump, the Slow Cannon
-- aim and the Blind Flash overlay. The server decides everything; this only sends requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local UI = require(script.Parent.Parent.Util.UI)

local BUTTON_SIZE = 84
local AIM_DISTANCE = 200
local DOUBLE_JUMP_DELAY = 0.2 -- seconds in the air before a jump press counts as the second jump

local player = Players.LocalPlayer

local AbilityController = {}

type SlotButton = {
	state: Types.AbilitySlotState,
	button: TextButton,
	cooldown: TextLabel,
}

local column: Frame
local slotButtons: { SlotButton } = {}
local flash: Frame

local KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
}

-- Where the trapper aims: from the character towards the centre of the screen.
local function aimDirection(): Vector3?
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not root or not root:IsA("BasePart") then
		return nil
	end
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local target = ray.Origin + ray.Direction * AIM_DISTANCE
	local direction = target - root.Position
	return if direction.Magnitude > 0 then direction.Unit else nil
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
			return
		end
	end
end

local function rebuild(states: { Types.AbilitySlotState })
	for _, entry in slotButtons do
		entry.button:Destroy()
	end
	table.clear(slotButtons)
	for index, state in states do
		local button = Instance.new("TextButton")
		button.Name = `Slot{state.slot}`
		button.Size = UDim2.fromOffset(BUTTON_SIZE * 1.6, BUTTON_SIZE)
		button.LayoutOrder = index
		button.BackgroundColor3 = UI.Colors.Panel
		button.BackgroundTransparency = 0.15
		button.AutoButtonColor = true
		button.Text = ""
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = button
		UI.label({
			name = "Key",
			parent = button,
			text = tostring(state.slot),
			size = UDim2.fromOffset(22, 22),
			position = UDim2.fromOffset(6, 4),
			color = UI.Colors.Gold,
			alignX = Enum.TextXAlignment.Left,
		})
		UI.label({
			name = "Name",
			parent = button,
			text = state.name,
			size = UDim2.new(1, -12, 0.5, 0),
			position = UDim2.new(0, 6, 0.2, 0),
			maxTextSize = 20,
		})
		local cooldown = UI.label({
			name = "Cooldown",
			parent = button,
			size = UDim2.new(1, -12, 0.3, 0),
			position = UDim2.new(0, 6, 0.68, 0),
			color = UI.Colors.Muted,
			font = Enum.Font.SourceSansSemibold,
			maxTextSize = 18,
		})
		button.Activated:Connect(function()
			use(state.slot)
		end)
		button.Parent = column
		table.insert(slotButtons, { state = state, button = button, cooldown = cooldown })
	end
	column.Visible = #slotButtons > 0
end

local function refresh()
	local now = workspace:GetServerTimeNow()
	for _, entry in slotButtons do
		local state = entry.state
		local text: string
		local ready = false
		if state.kind == "Passive" then
			text = "всегда активно"
		elseif state.kind == "OncePassive" then
			text = if state.used then "использовано" else "готово"
		elseif state.used then
			text = "использовано"
		elseif now < state.readyAt then
			text = string.format("%d с", math.ceil(state.readyAt - now))
		else
			text = "готово"
			ready = true
		end
		if entry.cooldown.Text ~= text then
			entry.cooldown.Text = text
		end
		entry.cooldown.TextColor3 = if ready then UI.Colors.Runner else UI.Colors.Muted
		entry.button.BackgroundTransparency = if ready or state.kind == "Passive" then 0.15 else 0.45
	end
end

-- Double Jump ---------------------------------------------------------------------------

local airborneSince = 0
local usedSecondJump = false

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
	column.Size = UDim2.fromOffset(BUTTON_SIZE * 1.6, (BUTTON_SIZE + 8) * 3)
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
	RunService.Heartbeat:Connect(refresh)
end

return AbilityController
