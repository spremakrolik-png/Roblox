--!strict
-- Spectator camera. Eliminated runners start spectating automatically; finished runners and lobby
-- players can press СМОТРЕТЬ (spectate). The camera follows living runners or the trapper; switch with the big
-- arrow buttons or Q / E. The server moves streaming to the watched player (SpectateService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.Util.UI)

local BUTTON_SIZE = 56

local player = Players.LocalPlayer

local SpectateController = {}

local spectating = false
local optedOut = false -- the player left spectating; do not restart it automatically this round
local target: Player? = nil
local requestedFor: Model? = nil -- the target character the server was last asked to stream

local panel: Frame
local nameLabel: TextLabel
local startButton: TextButton

local function isActive(other: Player): boolean
	local role = GameState.getRole(other)
	return role == "Trapper" or (role == "Runner" and GameState.getStatus(other) == "Alive")
end

-- Living runners, best progress first, then the trapper.
local function watchable(): { Player }
	local list: { Player } = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and isActive(other) then
			table.insert(list, other)
		end
	end
	table.sort(list, function(a: Player, b: Player)
		local aTrapper = GameState.getRole(a) == "Trapper"
		local bTrapper = GameState.getRole(b) == "Trapper"
		if aTrapper ~= bTrapper then
			return bTrapper
		end
		local aProgress = a:GetAttribute(GameState.PlayerKeys.Progress)
		local bProgress = b:GetAttribute(GameState.PlayerKeys.Progress)
		return (if typeof(aProgress) == "number" then aProgress else 0)
			> (if typeof(bProgress) == "number" then bProgress else 0)
	end)
	return list
end

local function canSpectate(): boolean
	return GameState.phase() == "Round" and not isActive(player)
end

local function ownHumanoid(): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function setTarget(newTarget: Player?)
	target = newTarget
	requestedFor = nil
end

local function stop()
	spectating = false
	setTarget(nil)
	Remotes.SpectateRequest:FireServer(0)
	local camera = workspace.CurrentCamera
	local humanoid = ownHumanoid()
	if camera and humanoid then
		camera.CameraSubject = humanoid
	end
end

local function cycle(direction: number)
	if not spectating then
		return
	end
	local list = watchable()
	if #list == 0 then
		setTarget(nil)
		return
	end
	local index = (target and table.find(list, target)) or 0
	setTarget(list[(index - 1 + direction) % #list + 1])
end

local function update()
	if not canSpectate() then
		if spectating then
			stop()
		end
		if GameState.phase() ~= "Round" then
			optedOut = false
		end
		panel.Visible = false
		startButton.Visible = false
		return
	end

	if not spectating then
		local eliminated = GameState.getRole(player) == "Runner" and GameState.getStatus(player) == "Eliminated"
		if eliminated and not optedOut then
			spectating = true
		else
			panel.Visible = false
			startButton.Visible = true
			return
		end
	end

	startButton.Visible = false
	panel.Visible = true
	local list = watchable()
	if not target or not table.find(list, target) then
		setTarget(list[1])
	end

	local current = target
	if not current then
		nameLabel.Text = "Смотреть не на кого"
		return
	end
	local role = if GameState.getRole(current) == "Trapper" then "трапер" else "раннер"
	nameLabel.Text = `{current.DisplayName} ({role})`

	local character = current.Character
	if character ~= requestedFor then
		requestedFor = character
		Remotes.SpectateRequest:FireServer(current.UserId)
	end
	-- The character appears once it has streamed in.
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if humanoid and camera and camera.CameraSubject ~= humanoid then
		camera.CameraSubject = humanoid
	end
end

local function makeButton(name: string, text: string, parent: Instance, position: UDim2, anchor: Vector2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Font = Enum.Font.SourceSansBold
	button.TextScaled = true
	button.TextColor3 = UI.Colors.Text
	button.BackgroundColor3 = UI.Colors.Panel
	button.BackgroundTransparency = 0.2
	button.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	button.Position = position
	button.AnchorPoint = anchor
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	button.Parent = parent
	return button
end

function SpectateController.start()
	local gui = UI.screen("Spectate", 6)

	panel =
		UI.panel("Panel", gui, UDim2.new(0.6, 0, 0, BUTTON_SIZE + 12), UDim2.new(0.5, 0, 1, -72), Vector2.new(0.5, 1))
	UI.sizeLimit(panel, Vector2.new(300, BUTTON_SIZE + 12), Vector2.new(560, BUTTON_SIZE + 12))
	UI.padding(panel, 6)
	panel.Visible = false
	local previous = makeButton("Previous", "<", panel, UDim2.fromScale(0, 0.5), Vector2.new(0, 0.5))
	local nextButton = makeButton("Next", ">", panel, UDim2.new(1, -BUTTON_SIZE - 6, 0.5, 0), Vector2.new(1, 0.5))
	local exit = makeButton("Exit", "X", panel, UDim2.fromScale(1, 0.5), Vector2.new(1, 0.5))
	exit.Size = UDim2.fromOffset(BUTTON_SIZE * 0.8, BUTTON_SIZE * 0.8)
	nameLabel = UI.label({
		name = "Target",
		parent = panel,
		size = UDim2.new(1, -(BUTTON_SIZE * 3 + 24), 1, 0),
		position = UDim2.fromOffset(BUTTON_SIZE + 6, 0),
		maxTextSize = 26,
	})

	startButton = makeButton("Spectate", "СМОТРЕТЬ", gui, UDim2.new(0.5, 0, 1, -72), Vector2.new(0.5, 1))
	startButton.Size = UDim2.fromOffset(BUTTON_SIZE * 3, BUTTON_SIZE)
	startButton.Visible = false
	gui.Parent = player:WaitForChild("PlayerGui")

	previous.Activated:Connect(function()
		cycle(-1)
	end)
	nextButton.Activated:Connect(function()
		cycle(1)
	end)
	exit.Activated:Connect(function()
		optedOut = true
		stop()
	end)
	startButton.Activated:Connect(function()
		optedOut = false
		spectating = true
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Left then
			cycle(-1)
		elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Right then
			cycle(1)
		end
	end)

	RunService.Heartbeat:Connect(update)
end

return SpectateController
