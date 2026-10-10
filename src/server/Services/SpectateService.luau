--!strict
-- Spectating. The camera itself is client-side; the server's job is streaming: with
-- StreamingEnabled a spectator in the lobby would not receive the far-away track, so the server
-- moves the spectator's ReplicationFocus to the watched player. Requests are validated.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CharacterService = require(script.Parent.CharacterService)

local RATE_LIMIT = 0.15

local SpectateService = {}

local lastRequest: { [Player]: number } = {}

-- Runners still running and the trapper can be watched; everyone else may watch.
local function isActivePlayer(player: Player): boolean
	local role = GameState.getRole(player)
	return role == "Trapper" or (role == "Runner" and GameState.getStatus(player) == "Alive")
end

local function onRequest(player: Player, targetUserId: unknown)
	if typeof(targetUserId) ~= "number" then
		return
	end
	local now = os.clock()
	if now - (lastRequest[player] or 0) < RATE_LIMIT then
		return
	end
	lastRequest[player] = now

	if targetUserId == 0 then
		player.ReplicationFocus = nil
		return
	end
	if GameState.phase() ~= "Round" or isActivePlayer(player) then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player or not isActivePlayer(target) then
		return
	end
	local root = CharacterService.getRoot(target)
	if root then
		player.ReplicationFocus = root
	end
end

-- Everyone back to streaming around their own character (end of round).
function SpectateService.reset()
	for _, player in Players:GetPlayers() do
		player.ReplicationFocus = nil
	end
end

function SpectateService.init()
	Remotes.SpectateRequest.OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return SpectateService
