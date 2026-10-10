--!strict
-- Character plumbing: collision groups, jump/walk settings, teleports and helpers
-- for finding a player's humanoid and root part.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local PLAYER_GROUP = "Players"
local TELEPORT_STREAM_TIMEOUT = 4
local TELEPORT_BATCH_TIMEOUT = 6

local CharacterService = {}

-- Walk speed each player should have; re-applied whenever their character respawns.
local walkSpeeds: { [Player]: number } = {}

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
		player:LoadCharacter()
	end)
	if not ok then
		warn(`[Character] LoadCharacter failed for {player.Name}: {err}`)
	end
	return CharacterService.isAlive(player)
end

function CharacterService.setWalkSpeed(player: Player, speed: number?)
	walkSpeeds[player] = speed
	local humanoid = CharacterService.getHumanoid(player)
	if humanoid then
		humanoid.WalkSpeed = speed or GameConfig.LobbyWalkSpeed
	end
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
		humanoid.WalkSpeed = walkSpeeds[player] or GameConfig.LobbyWalkSpeed
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
	end)
end

return CharacterService
