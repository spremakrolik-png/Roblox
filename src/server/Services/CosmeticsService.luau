--!strict
-- Puts each player's equipped wardrobe items on their character: on every spawn and whenever the
-- wardrobe changes. Buying and equipping go through PlayerDataService (shop requests).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Config.Cosmetics)
local CosmeticFx = require(script.Parent.Parent.Util.CosmeticFx)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CosmeticsService = {}

-- What is on the current character, to rebuild only what changed.
type Applied = { character: Model, items: { [string]: string } }
local applied: { [Player]: Applied } = {}

local function refresh(player: Player)
	local data = PlayerDataService.getData(player)
	local character = player.Character
	if not data or not character or not character.Parent then
		return
	end
	local state = applied[player]
	if not state or state.character ~= character then
		local fresh: Applied = { character = character, items = {} }
		state = fresh
		applied[player] = state
	end
	local equipped = data.Cosmetics.Equipped :: any
	for _, kind in Cosmetics.Kinds do
		local id = equipped[kind] or ""
		if state.items[kind] ~= id then
			state.items[kind] = id
			CosmeticFx.apply(character, kind, id)
		end
	end
end

function CosmeticsService.init()
	PlayerDataService.onChanged(refresh)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			character:WaitForChild("HumanoidRootPart", 10)
			refresh(player)
		end)
		if player.Character then
			task.spawn(refresh, player)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		applied[player] = nil
	end)
end

return CosmeticsService
