--!strict
-- Trap buttons in the trapper corridor and trap activation. Every press is validated on the server:
-- the presser must be this round's trapper, near the button, the button unused, and not spamming.
-- RoundService owns the runners; it plugs in through TrapService.start(context).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrapsConfig = require(ReplicatedStorage.Shared.Config.Traps)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local TrackGenerator = require(script.Parent.Parent.Track.TrackGenerator)
local Build = require(script.Parent.Parent.Util.Build)
local CharacterService = require(script.Parent.CharacterService)

local READY_COLOR = Color3.fromRGB(60, 230, 90)
local USED_COLOR = Color3.fromRGB(110, 110, 120)
local PUSH_SECONDS = 0.25

export type RoundContext = {
	trapper: Player,
	aliveRunners: () -> { Player },
	onTrapKill: (player: Player, trapType: Types.TrapType) -> (),
	onTrapHit: (player: Player, trapType: Types.TrapType) -> (),
}

type ButtonState = {
	trap: Types.TrackTrap,
	used: boolean,
	prompt: ProximityPrompt,
	top: BasePart,
	status: TextLabel,
}

local TrapService = {}

local buttons: { ButtonState } = {}
local context: RoundContext? = nil
local lastPress: { [Player]: number } = {}

local function setUsed(button: ButtonState)
	button.used = true
	button.prompt.Enabled = false
	button.top.Color = USED_COLOR
	button.top.Material = Enum.Material.SmoothPlastic
	button.status.Text = "USED"
	button.status.TextColor3 = USED_COLOR
end

-- Pushes a runner with a short-lived LinearVelocity. The character's owner simulates the
-- constraint, so this works from the server without trusting the client.
local function push(player: Player, velocity: Vector3)
	local root = CharacterService.getRoot(player)
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "TrapPush"
	attachment.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Name = "TrapPush"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	mover.VectorVelocity = velocity
	mover.MaxForce = math.huge
	mover.Parent = root
	Debris:AddItem(mover, PUSH_SECONDS)
	Debris:AddItem(attachment, PUSH_SECONDS)
end

local function hooksFor(trapType: Types.TrapType): Types.TrapHooks
	local info = TrapsConfig.info(trapType)
	return {
		runnersIn = function(box: Types.Box): { Player }
			local inside: { Player } = {}
			local current = context
			if not current then
				return inside
			end
			for _, player in current.aliveRunners() do
				local root = CharacterService.getRoot(player)
				if root and TrackGenerator.pointInBox(box, root.Position) then
					table.insert(inside, player)
				end
			end
			return inside
		end,
		kill = function(player: Player)
			local current = context
			if not current then
				return
			end
			local root = CharacterService.getRoot(player)
			if root then
				Remotes.DeathEffect:FireAllClients(root.Position, info.color)
			end
			current.onTrapKill(player, trapType)
		end,
		markHit = function(player: Player)
			local current = context
			if current then
				current.onTrapHit(player, trapType)
			end
		end,
		push = function(player: Player, velocity: Vector3)
			if context then
				push(player, velocity)
			end
		end,
		isLive = function(): boolean
			return context ~= nil
		end,
	}
end

local function activate(button: ButtonState)
	local trap = button.trap
	local info = TrapsConfig.info(trap.trapType)
	setUsed(button)
	local telegraph = TrapsConfig.telegraph(trap.trapType)
	local alert: Types.TrapAlert = {
		trapType = trap.trapType,
		name = info.name,
		zoneCFrame = trap.handle.zone.cframe,
		zoneSize = trap.handle.zone.size,
		telegraph = telegraph,
	}
	Remotes.TrapActivated:FireAllClients(alert)
	task.spawn(function()
		local ok, err = pcall(trap.handle.activate, hooksFor(trap.trapType))
		if not ok then
			warn(`[Trap] {trap.trapType} on segment {trap.segmentIndex} failed: {err}`)
		end
	end)
end

local function onTriggered(button: ButtonState, player: Player)
	local current = context
	if not current or player ~= current.trapper or button.used then
		return
	end
	local now = os.clock()
	if now - (lastPress[player] or 0) < TrapsConfig.ButtonRateLimit then
		return
	end
	lastPress[player] = now
	local root = CharacterService.getRoot(player)
	local reach = TrapsConfig.ButtonActivationDistance + TrapsConfig.ButtonDistanceSlack
	if not root or (root.Position - button.top.Position).Magnitude > reach then
		return
	end
	activate(button)
end

local function buildButton(trap: Types.TrackTrap, parent: Instance): ButtonState
	local info = TrapsConfig.info(trap.trapType)
	Build.part({
		name = "ButtonBase",
		size = Vector3.new(2.4, 3, 2.4),
		cframe = trap.buttonCFrame * CFrame.new(0, 1.5, 0),
		color = Color3.fromRGB(40, 40, 48),
		material = Enum.Material.Metal,
		parent = parent,
	})
	local top = Build.part({
		name = "ButtonTop",
		size = Vector3.new(1.8, 0.5, 1.8),
		cframe = trap.buttonCFrame * CFrame.new(0, 3.25, 0),
		color = READY_COLOR,
		material = Enum.Material.Neon,
		parent = parent,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Activate"
	prompt.ObjectText = info.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = TrapsConfig.ButtonActivationDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Enabled = false
	prompt.Parent = top

	local billboard = Build.billboard(top, 3.5, Vector2.new(8, 3))
	Build.textLabel(
		"Name",
		billboard,
		string.upper(info.name),
		info.color,
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 0.6)
	)
	local status =
		Build.textLabel("Status", billboard, "READY", READY_COLOR, UDim2.fromScale(0, 0.6), UDim2.fromScale(1, 0.4))

	local button: ButtonState = { trap = trap, used = false, prompt = prompt, top = top, status = status }
	prompt.Triggered:Connect(function(player: Player)
		onTriggered(button, player)
	end)
	return button
end

-- Builds the buttons for a freshly generated track (disabled until the round starts).
function TrapService.prepare(track: Types.Track)
	table.clear(buttons)
	for _, trap in track.traps do
		local segment = track.segments[trap.segmentIndex]
		table.insert(buttons, buildButton(trap, segment.model))
	end
end

-- Arms every unused button for this round.
function TrapService.start(roundContext: RoundContext)
	context = roundContext
	table.clear(lastPress)
	for _, button in buttons do
		button.prompt.Enabled = not button.used
	end
end

-- Disarms the buttons; traps already running stop hurting anyone.
function TrapService.stop()
	context = nil
	for _, button in buttons do
		button.prompt.Enabled = false
	end
end

-- Forgets the buttons (their parts are destroyed with the track).
function TrapService.clear()
	TrapService.stop()
	table.clear(buttons)
end

return TrapService
