--!strict
-- Character plumbing: collision groups, jump/walk settings, teleports and helpers
-- for finding a player's humanoid and root part.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local PLAYER_GROUP = GameConfig.CollisionGroups.Players
local TELEPORT_STREAM_TIMEOUT = 4
local TELEPORT_BATCH_TIMEOUT = 6

local CharacterService = {}

-- Base walk speed each player should have; re-applied whenever their character respawns.
local walkSpeeds: { [Player]: number } = {}

-- Temporary speed multipliers (Speed Burst, Sprint, Slow Cannon). They stack by multiplying.
type SpeedModifier = { multiplier: number, token: number }
local modifiers: { [Player]: { [string]: SpeedModifier } } = {}
local modifierToken = 0

local function currentSpeed(player: Player): number
	local speed = walkSpeeds[player] or GameConfig.LobbyWalkSpeed
	for _, modifier in modifiers[player] or {} do
		speed *= modifier.multiplier
	end
	return speed
end

local function applySpeed(player: Player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.WalkSpeed = currentSpeed(player)
	end
end

function CharacterService.getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

function CharacterService.getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function CharacterService.isAlive(player: Player): boolean
	local humanoid = CharacterService.getHumanoid(player)
	return humanoid ~= nil and humanoid.Health > 0 and CharacterService.getRoot(player) ~= nil
end

-- Makes sure the player has a living character, respawning them if needed. Yields.
function CharacterService.ensureCharacter(player: Player): boolean
	if CharacterService.isAlive(player) then
		return true
	end
	if player.Parent ~= Players then
		return false
	end
	local ok, err = pcall(function()
		player:LoadCharacterAsync()
	end)
	if not ok then
		warn(`[Character] LoadCharacterAsync failed for {player.Name}: {err}`)
	end
	return CharacterService.isAlive(player)
end

function CharacterService.setWalkSpeed(player: Player, speed: number?)
	walkSpeeds[player] = speed
	applySpeed(player)
end

-- Multiplies the player's walk speed for `seconds`. Re-applying the same key restarts it.
function CharacterService.addSpeedModifier(player: Player, key: string, multiplier: number, seconds: number)
	modifierToken += 1
	local token = modifierToken
	local list = modifiers[player] or {}
	modifiers[player] = list
	list[key] = { multiplier = multiplier, token = token }
	applySpeed(player)
	task.delay(seconds, function()
		local current = modifiers[player]
		if current and current[key] and current[key].token == token then
			current[key] = nil
			applySpeed(player)
		end
	end)
end

function CharacterService.clearSpeedModifiers(player: Player)
	modifiers[player] = nil
	applySpeed(player)
end

function CharacterService.setAnchored(player: Player, anchored: boolean)
	local root = CharacterService.getRoot(player)
	if root then
		root.Anchored = anchored
	end
end

function CharacterService.kill(player: Player)
	local humanoid = CharacterService.getHumanoid(player)
	if humanoid then
		humanoid.Health = 0
	end
end

-- Drives the character at `velocity` for `seconds` with a short-lived LinearVelocity. The character's
-- owner simulates the constraint, so this works from the server without trusting the client.
function CharacterService.applyVelocity(player: Player, velocity: Vector3, seconds: number, name: string)
	local root = CharacterService.getRoot(player)
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Name = name
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	mover.VectorVelocity = velocity
	mover.MaxForce = math.huge
	mover.Parent = root
	Debris:AddItem(mover, seconds)
	Debris:AddItem(attachment, seconds)
end

-- Moves a character, asking the client to stream the destination in first. Yields.
function CharacterService.teleport(player: Player, cframe: CFrame)
	pcall(function()
		player:RequestStreamAroundAsync(cframe.Position, TELEPORT_STREAM_TIMEOUT)
	end)
	local character = player.Character
	local root = CharacterService.getRoot(player)
	if not character or not root then
		return
	end
	character:PivotTo(cframe)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

export type TeleportTarget = {
	player: Player,
	cframe: CFrame,
}

-- Teleports several players in parallel and waits until all of them have moved (or a timeout).
function CharacterService.teleportAll(targets: { TeleportTarget })
	local pending = #targets
	for _, target in targets do
		task.spawn(function()
			CharacterService.teleport(target.player, target.cframe)
			pending -= 1
		end)
	end
	local deadline = os.clock() + TELEPORT_BATCH_TIMEOUT
	while pending > 0 and os.clock() < deadline do
		task.wait()
	end
end

local function setupCharacter(player: Player, character: Model)
	local function assignGroup(descendant: Instance)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = PLAYER_GROUP
		end
	end
	for _, descendant in character:GetDescendants() do
		assignGroup(descendant)
	end
	character.DescendantAdded:Connect(assignGroup)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = GameConfig.JumpPower
		humanoid.WalkSpeed = currentSpeed(player)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)
	if player.Character then
		task.spawn(setupCharacter, player, player.Character)
	end
end

function CharacterService.init()
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, PLAYER_GROUP, GameConfig.PlayerCollisions)
	local groups = GameConfig.CollisionGroups
	PhysicsService:RegisterCollisionGroup(groups.Glass)
	PhysicsService:RegisterCollisionGroup(groups.Projectile)
	PhysicsService:CollisionGroupSetCollidable(groups.Projectile, groups.Glass, false)

	workspace.Gravity = GameConfig.Gravity
	StarterPlayer.CharacterUseJumpPower = true
	StarterPlayer.CharacterJumpPower = GameConfig.JumpPower
	StarterPlayer.CharacterWalkSpeed = GameConfig.LobbyWalkSpeed

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		walkSpeeds[player] = nil
		modifiers[player] = nil
	end)
end

return CharacterService
