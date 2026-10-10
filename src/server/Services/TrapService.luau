--!strict
-- Trap buttons in the trapper corridor and trap activation. Every press is validated on the server:
-- the presser must be this round's trapper, near the button, the button unused, and not spamming.
-- RoundService owns the runners; it plugs in through TrapService.start(context).

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
	running: boolean, -- the trap is mid-activation (cannot be recharged yet)
	prompt: ProximityPrompt,
	top: BasePart,
	status: TextLabel,
}

local TrapService = {}

local buttons: { ButtonState } = {}
local usedOrder: { ButtonState } = {} -- most recent last, for Trap Recharge
local context: RoundContext? = nil
local lastPress: { [Player]: number } = {}

local function setUsed(button: ButtonState)
	button.used = true
	button.prompt.Enabled = false
	button.top.Color = USED_COLOR
	button.top.Material = Enum.Material.SmoothPlastic
	button.status.Text = "ИСПОЛЬЗОВАНО"
	button.status.TextColor3 = USED_COLOR
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
				CharacterService.applyVelocity(player, velocity, PUSH_SECONDS, "TrapPush")
			end
		end,
		isLive = function(): boolean
			return context ~= nil
		end,
	}
end

local function setReady(button: ButtonState)
	button.used = false
	button.prompt.Enabled = context ~= nil
	button.top.Color = READY_COLOR
	button.top.Material = Enum.Material.Neon
	button.status.Text = "ГОТОВО"
	button.status.TextColor3 = READY_COLOR
end

local function activate(button: ButtonState)
	local trap = button.trap
	local info = TrapsConfig.info(trap.trapType)
	setUsed(button)
	button.running = true
	table.insert(usedOrder, button)
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
		button.running = false
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
	prompt.ActionText = "Активировать"
	prompt.ObjectText = info.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = TrapsConfig.ButtonActivationDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Enabled = false
	prompt.Parent = top

	local billboard = Build.billboard(top, 3.5, Vector2.new(8, 3))
	Build.textLabel("Name", billboard, info.name, info.color, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.6))
	local status = Build.textLabel(
		"Status",
		billboard,
		"ГОТОВО",
		READY_COLOR,
		UDim2.fromScale(0, 0.6),
		UDim2.fromScale(1, 0.4)
	)

	local button: ButtonState = {
		trap = trap,
		used = false,
		running = false,
		prompt = prompt,
		top = top,
		status = status,
	}
	prompt.Triggered:Connect(function(player: Player)
		onTriggered(button, player)
	end)
	return button
end

-- Builds the buttons for a freshly generated track (disabled until the round starts).
function TrapService.prepare(track: Types.Track)
	table.clear(buttons)
	table.clear(usedOrder)
	for _, trap in track.traps do
		local segment = track.segments[trap.segmentIndex]
		table.insert(buttons, buildButton(trap, segment.model))
	end
end

-- Remote Trigger: activates the closest ready trap within `range` studs of the trapper.
-- Returns false (and changes nothing) when there is none.
function TrapService.activateNearest(player: Player, range: number): boolean
	local current = context
	local root = CharacterService.getRoot(player)
	if not current or player ~= current.trapper or not root then
		return false
	end
	local best: ButtonState? = nil
	local bestDistance = range
	for _, button in buttons do
		if not button.used then
			local distance = (button.top.Position - root.Position).Magnitude
			if distance <= bestDistance then
				best = button
				bestDistance = distance
			end
		end
	end
	if not best then
		return false
	end
	activate(best)
	return true
end

-- Trap Recharge: makes the most recently used trap that has finished resetting ready again.
function TrapService.rechargeLast(player: Player): boolean
	local current = context
	if not current or player ~= current.trapper then
		return false
	end
	for index = #usedOrder, 1, -1 do
		local button = usedOrder[index]
		if button.used and not button.running then
			table.remove(usedOrder, index)
			setReady(button)
			return true
		end
	end
	return false
end

-- Every trap in track order with its button state (for the trapper's HUD).
function TrapService.states(): { { trap: Types.TrackTrap, state: "Ready" | "Running" | "Used" } }
	local list: { { trap: Types.TrackTrap, state: "Ready" | "Running" | "Used" } } = {}
	for _, button in buttons do
		local state: "Ready" | "Running" | "Used" = if button.running
			then "Running"
			elseif button.used then "Used"
			else "Ready"
		table.insert(list, { trap = button.trap, state = state })
	end
	return list
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
	table.clear(usedOrder)
end

return TrapService
