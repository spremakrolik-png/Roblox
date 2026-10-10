--!strict
-- Replicated round state. The server writes attributes on ReplicatedStorage.GameState,
-- clients only read them. Per-player state lives in attributes on the Player object.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Types)

local FOLDER_NAME = "GameState"

local GameState = {}

-- Attributes on the GameState folder.
GameState.Keys = table.freeze({
	Phase = "Phase",
	PhaseEndsAt = "PhaseEndsAt", -- server time (workspace:GetServerTimeNow()), 0 = no timer
	RunnerCircle = "RunnerCircle", -- players standing in the RUNNER circle
	TrapperCircle = "TrapperCircle",
	AliveRunners = "AliveRunners",
	TotalRunners = "TotalRunners",
	LeaderProgress = "LeaderProgress", -- 0..1
	RoundStartedAt = "RoundStartedAt", -- server time the start gates open
	TrapperName = "TrapperName",
	ThemeName = "ThemeName",
	CheckpointCount = "CheckpointCount",
	CheckpointMarks = "CheckpointMarks", -- checkpoint positions as track fractions, "0.25,0.5"
})

-- Attributes on each Player.
GameState.PlayerKeys = table.freeze({
	Role = "Role", -- Types.Role
	Circle = "Circle", -- Types.Circle
	Status = "RunnerStatus", -- Types.RunnerStatus
	Progress = "Progress", -- 0..1, best distance along the track
	Place = "Place", -- finish place, 0 = not finished
	Checkpoint = "Checkpoint", -- checkpoints passed this round
})

export type Snapshot = {
	phase: Types.Phase,
	phaseEndsAt: number,
	runnerCircle: number,
	trapperCircle: number,
	aliveRunners: number,
	totalRunners: number,
	leaderProgress: number,
	roundStartedAt: number,
	trapperName: string,
	themeName: string,
	checkpointCount: number,
}

local DEFAULTS: { [string]: any } = {
	Phase = "Waiting",
	PhaseEndsAt = 0,
	RunnerCircle = 0,
	TrapperCircle = 0,
	AliveRunners = 0,
	TotalRunners = 0,
	LeaderProgress = 0,
	RoundStartedAt = 0,
	TrapperName = "",
	ThemeName = "",
	CheckpointCount = 0,
	CheckpointMarks = "",
}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		for key, value in DEFAULTS do
			folder:SetAttribute(key, value)
		end
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function GameState.folder(): Folder
	return folder
end

function GameState.read(key: string): any
	local value = folder:GetAttribute(key)
	if value == nil then
		return DEFAULTS[key]
	end
	return value
end

function GameState.write(key: string, value: any)
	assert(RunService:IsServer(), "GameState is written by the server only")
	if folder:GetAttribute(key) ~= value then
		folder:SetAttribute(key, value)
	end
end

-- Server: switches the phase; `duration` (seconds) drives the countdown clients display.
function GameState.setPhase(phase: Types.Phase, duration: number?)
	GameState.write(GameState.Keys.PhaseEndsAt, if duration then workspace:GetServerTimeNow() + duration else 0)
	GameState.write(GameState.Keys.Phase, phase)
end

function GameState.changed(key: string): RBXScriptSignal
	return folder:GetAttributeChangedSignal(key)
end

function GameState.phase(): Types.Phase
	return GameState.read(GameState.Keys.Phase) :: Types.Phase
end

function GameState.snapshot(): Snapshot
	local keys = GameState.Keys
	return {
		phase = GameState.phase(),
		phaseEndsAt = GameState.read(keys.PhaseEndsAt) :: number,
		runnerCircle = GameState.read(keys.RunnerCircle) :: number,
		trapperCircle = GameState.read(keys.TrapperCircle) :: number,
		aliveRunners = GameState.read(keys.AliveRunners) :: number,
		totalRunners = GameState.read(keys.TotalRunners) :: number,
		leaderProgress = GameState.read(keys.LeaderProgress) :: number,
		roundStartedAt = GameState.read(keys.RoundStartedAt) :: number,
		trapperName = GameState.read(keys.TrapperName) :: string,
		themeName = GameState.read(keys.ThemeName) :: string,
		checkpointCount = GameState.read(keys.CheckpointCount) :: number,
	}
end

-- Player attribute helpers ------------------------------------------------

function GameState.getRole(player: Player): Types.Role
	return (player:GetAttribute(GameState.PlayerKeys.Role) or "None") :: Types.Role
end

function GameState.getCircle(player: Player): Types.Circle
	return (player:GetAttribute(GameState.PlayerKeys.Circle) or "None") :: Types.Circle
end

function GameState.getStatus(player: Player): Types.RunnerStatus
	return (player:GetAttribute(GameState.PlayerKeys.Status) or "None") :: Types.RunnerStatus
end

return GameState
