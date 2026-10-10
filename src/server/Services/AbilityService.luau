--!strict
-- Abilities in a round. A player's equipped loadout for their role is locked when the gates open.
-- Every use is validated on the server: round running, role, slot, ownership (via the loadout),
-- cooldown or once-per-round, and a rate limit. Effects run on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local TrackGenerator = require(script.Parent.Parent.Track.TrackGenerator)
local Build = require(script.Parent.Parent.Util.Build)
local CharacterService = require(script.Parent.CharacterService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TrapService = require(script.Parent.TrapService)

local DOUBLE_JUMP_ATTRIBUTE = "DoubleJump"
local CANNON_COLOR = Color3.fromRGB(80, 200, 255)

export type RoundContext = {
	track: Types.Track,
	trapper: Player,
	runners: { Player },
	aliveRunners: () -> { Player },
}

type SlotState = {
	slot: number,
	def: Types.AbilityDef,
	readyAt: number, -- os.clock()
	used: boolean,
}

local AbilityService = {}

local context: RoundContext? = nil
local equipped: { [Player]: { SlotState } } = {}
local shieldUntil: { [Player]: number } = {}
local lastUse: { [Player]: number } = {}

local function param(def: Types.AbilityDef, name: string): number
	return Abilities.param(def, name)
end

-- Sends the HUD the player's slots with ready times converted to server time.
local function pushState(player: Player)
	local states: { Types.AbilitySlotState } = {}
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for _, state in equipped[player] or {} do
		table.insert(states, {
			slot = state.slot,
			id = state.def.id,
			name = state.def.name,
			kind = state.def.kind,
			readyAt = if state.readyAt > now then serverNow + (state.readyAt - now) else 0,
			used = state.used,
		})
	end
	Remotes.AbilityState:FireClient(player, states)
end

-- Effects ---------------------------------------------------------------------------

local function closestDistance(point: Vector3, from: Vector3, to: Vector3): number
	local segment = to - from
	local length = segment.Magnitude
	if length < 1e-6 then
		return (point - from).Magnitude
	end
	local t = math.clamp((point - from):Dot(segment) / (length * length), 0, 1)
	return (point - (from + segment * t)).Magnitude
end

local function slowRunner(def: Types.AbilityDef, target: Player)
	CharacterService.addSpeedModifier(target, "SlowCannon", param(def, "SlowMultiplier"), param(def, "SlowSeconds"))
	local root = CharacterService.getRoot(target)
	if root then
		Remotes.DeathEffect:FireAllClients(root.Position, CANNON_COLOR)
	end
end

-- One Slow Cannon shot, simulated on the server. It flies through the glass (collision groups) and
-- stops at the first other surface or at the first runner within HitRadius.
local function fireShot(
	current: RoundContext,
	shooter: Player,
	origin: Vector3,
	direction: Vector3,
	def: Types.AbilityDef
)
	local speed = param(def, "ProjectileSpeed")
	local range = param(def, "Range")
	local hitRadius = param(def, "HitRadius")
	local ball = Build.part({
		name = "CannonShot",
		shape = Enum.PartType.Ball,
		size = Vector3.one * 1.2,
		cframe = CFrame.new(origin),
		color = CANNON_COLOR,
		material = Enum.Material.Neon,
		canCollide = false,
		canTouch = false,
		canQuery = false,
		castShadow = false,
		parent = workspace,
	})
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ball, shooter.Character :: Instance }
	params.CollisionGroup = GameConfig.CollisionGroups.Projectile

	local position = origin
	local travelled = 0
	local connection: RBXScriptConnection? = nil
	local function finish()
		if connection then
			connection:Disconnect()
		end
		ball:Destroy()
	end
	connection = RunService.Heartbeat:Connect(function(dt: number)
		if context ~= current then
			finish()
			return
		end
		local step = math.min(speed * dt, range - travelled)
		local nextPosition = position + direction * step
		for _, runner in current.aliveRunners() do
			local root = CharacterService.getRoot(runner)
			if root and closestDistance(root.Position, position, nextPosition) <= hitRadius then
				slowRunner(def, runner)
				finish()
				return
			end
		end
		local hit = workspace:Raycast(position, direction * step, params)
		if hit then
			local model = hit.Instance:FindFirstAncestorOfClass("Model") :: Model?
			local target = if model then Players:GetPlayerFromCharacter(model) else nil
			if target and table.find(current.aliveRunners(), target) then
				slowRunner(def, target)
			end
			finish()
			return
		end
		position = nextPosition
		travelled += step
		ball.Position = position
		if travelled >= range then
			finish()
		end
	end)
end

-- The segment the trapper is standing next to (nil before the first segment or past the last).
local function segmentBeside(track: Types.Track, position: Vector3): Types.TrackSegment?
	for _, segment in track.segments do
		local relative = segment.entry:PointToObjectSpace(position)
		local along = -relative.Z
		if along >= 0 and along <= segment.def.length then
			return segment
		end
	end
	return nil
end

type Effect = (player: Player, def: Types.AbilityDef, current: RoundContext, aim: Vector3?) -> boolean

local EFFECTS: { [string]: Effect } = {
	FeatherFall = function(player, def)
		if not CharacterService.getRoot(player) then
			return false
		end
		-- The client owns its character's physics, so it applies the slow fall itself.
		Remotes.AbilityEffect:FireClient(player, "FeatherFall", param(def, "Duration"), param(def, "MaxFallSpeed"))
		return true
	end,
	SpeedBurst = function(player, def)
		CharacterService.addSpeedModifier(player, def.id, param(def, "Multiplier"), param(def, "Duration"))
		return true
	end,
	Sprint = function(player, def)
		CharacterService.addSpeedModifier(player, def.id, param(def, "Multiplier"), param(def, "Duration"))
		return true
	end,
	Dash = function(player, def)
		local root = CharacterService.getRoot(player)
		if not root then
			return false
		end
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 1e-3 then
			return false
		end
		local seconds = param(def, "Seconds")
		CharacterService.applyVelocity(player, flat.Unit * (param(def, "Distance") / seconds), seconds, "Dash")
		return true
	end,
	BlindFlash = function(player, def, current)
		local root = CharacterService.getRoot(player)
		local segment = if root then segmentBeside(current.track, root.Position) else nil
		if not segment then
			return false
		end
		local duration = param(def, "Duration")
		local length = segment.def.length
		local fog: Types.Box = {
			cframe = segment.entry * CFrame.new(0, 7, -length / 2),
			size = Vector3.new(GameConfig.Track.Width + 4, 18, length),
		}
		local cloud = Build.part({
			name = "BlindFog",
			size = fog.size,
			cframe = fog.cframe,
			color = Color3.fromRGB(235, 235, 245),
			transparency = 0.25,
			canCollide = false,
			canTouch = false,
			canQuery = false,
			castShadow = false,
			parent = current.track.model,
		})
		Debris:AddItem(cloud, duration)
		for _, runner in current.aliveRunners() do
			local runnerRoot = CharacterService.getRoot(runner)
			if runnerRoot and TrackGenerator.pointInBox(fog, runnerRoot.Position) then
				Remotes.BlindFlash:FireClient(runner, duration)
			end
		end
		return true
	end,
	RemoteTrigger = function(player, def)
		return TrapService.activateNearest(player, param(def, "Range"))
	end,
	TrapRecharge = function(player)
		return TrapService.rechargeLast(player)
	end,
	SlowCannon = function(player, def, current, aim)
		if typeof(aim) ~= "Vector3" or aim.Magnitude < 0.5 or aim.Magnitude > 1.5 then
			return false
		end
		local direction = aim.Unit
		task.spawn(function()
			for _ = 1, param(def, "Shots") do
				local root = CharacterService.getRoot(player)
				if context ~= current or not root then
					return
				end
				fireShot(current, player, root.Position + Vector3.new(0, 1.5, 0) + direction * 2, direction, def)
				task.wait(param(def, "ShotInterval"))
			end
		end)
		return true
	end,
}

-- Requests -----------------------------------------------------------------------------

local function canAct(current: RoundContext, player: Player): boolean
	if player == current.trapper then
		return true
	end
	return table.find(current.aliveRunners(), player) ~= nil
end

local function onUse(player: Player, slot: unknown, aim: unknown)
	local current = context
	if not current or typeof(slot) ~= "number" then
		return
	end
	local now = os.clock()
	if now - (lastUse[player] or 0) < Abilities.UseRateLimit then
		return
	end
	lastUse[player] = now

	local state: SlotState? = nil
	for _, candidate in equipped[player] or {} do
		if candidate.slot == slot then
			state = candidate
		end
	end
	if not state or not canAct(current, player) then
		return
	end
	local kind = state.def.kind
	if kind ~= "Active" and kind ~= "OncePerRound" then
		return
	end
	if state.used or now < state.readyAt then
		return
	end

	local effect = EFFECTS[state.def.id]
	local aimVector: Vector3? = if typeof(aim) == "Vector3" then aim else nil
	if effect and effect(player, state.def, current, aimVector) then
		if kind == "Active" then
			state.readyAt = now + state.def.cooldown
		else
			state.used = true
		end
		pushState(player)
	end
end

-- Round lifecycle -----------------------------------------------------------------------

-- Locks loadouts and arms abilities once the gates open.
function AbilityService.startRound(roundContext: RoundContext)
	context = roundContext
	table.clear(equipped)
	table.clear(shieldUntil)
	local function arm(player: Player, role: "Runner" | "Trapper")
		local slots: { SlotState } = {}
		for slot, id in PlayerDataService.getLoadout(player, role) do
			local def = Abilities.byId[id]
			if def then
				table.insert(slots, { slot = slot, def = def, readyAt = 0, used = false })
				if def.id == "DoubleJump" then
					player:SetAttribute(DOUBLE_JUMP_ATTRIBUTE, true)
				end
			end
		end
		equipped[player] = slots
		pushState(player)
	end
	for _, runner in roundContext.runners do
		if runner.Parent == Players then
			arm(runner, "Runner")
		end
	end
	if roundContext.trapper.Parent == Players then
		arm(roundContext.trapper, "Trapper")
	end
end

-- Shield: absorbs one direct trap hit per round, then a short grace period for the same trap.
function AbilityService.absorbTrapHit(player: Player): boolean
	local now = os.clock()
	if (shieldUntil[player] or 0) > now then
		return true
	end
	for _, state in equipped[player] or {} do
		if state.def.id == "Shield" and not state.used then
			state.used = true
			local grace = param(state.def, "GraceSeconds")
			shieldUntil[player] = now + grace
			local character = player.Character
			if character then
				local field = Instance.new("ForceField")
				field.Visible = true
				field.Parent = character
				Debris:AddItem(field, grace)
			end
			pushState(player)
			return true
		end
	end
	return false
end

-- Stops abilities (the round has a winner).
function AbilityService.stopRound()
	context = nil
end

-- Clears everything after the round: equipped slots, effects and the HUD.
function AbilityService.reset()
	context = nil
	for player in equipped do
		if player.Parent == Players then
			player:SetAttribute(DOUBLE_JUMP_ATTRIBUTE, nil)
			CharacterService.clearSpeedModifiers(player)
			Remotes.AbilityState:FireClient(player, {})
		end
	end
	table.clear(equipped)
	table.clear(shieldUntil)
end

function AbilityService.init()
	Remotes.UseAbility.OnServerEvent:Connect(onUse)
	Players.PlayerRemoving:Connect(function(player)
		equipped[player] = nil
		shieldUntil[player] = nil
		lastUse[player] = nil
	end)
end

return AbilityService
