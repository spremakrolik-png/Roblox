--!strict
-- Top-100 boards: Points and wins (as runner or trapper). Scores are written to OrderedDataStores
-- every few minutes and when a player leaves; the boards are re-read every minute. Players on this
-- server always show their live value, so the boards also work in Studio without API access.
-- The list goes to clients as a JSON attribute on each board's screen; clients draw it.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local PlayerDataService = require(script.Parent.PlayerDataService)

type Kind = "Points" | "Wins"
type Entry = { userId: number, name: string, value: number }

local SIZE = 100
local READ_INTERVAL = 60
local WRITE_INTERVAL = 180
local STORE_NAMES: { [Kind]: string } = { Points = "TopPoints_v1", Wins = "TopWins_v1" }
local KINDS: { Kind } = { "Points", "Wins" }

local LeaderboardService = {}

local stores: { [Kind]: OrderedDataStore? } = {}
local stored: { [Kind]: { Entry } } = { Points = {}, Wins = {} }
local lastScore: { [Player]: { [Kind]: number } } = {} -- known scores, also used after the profile is gone
local written: { [Player]: { [Kind]: number } } = {}
local names: { [number]: string } = {}

local function scoreOf(data: Types.ProfileData, kind: Kind): number
	if kind == "Points" then
		return data.Points
	end
	return data.Stats.Wins + data.Stats.TrapperWins
end

local function nameFor(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and typeof(name) == "string" then name else `Игрок {userId}`
	names[userId] = result
	return result
end

local function remember(player: Player)
	local data = PlayerDataService.getData(player)
	if data then
		lastScore[player] = { Points = scoreOf(data, "Points"), Wins = scoreOf(data, "Wins") }
	end
end

local function write(player: Player)
	local scores = lastScore[player]
	if not scores then
		return
	end
	local done = written[player] or {}
	written[player] = done
	for _, kind in KINDS do
		local store = stores[kind]
		local value = scores[kind]
		if store and done[kind] ~= value then
			local ok, err = pcall(function()
				store:SetAsync(tostring(player.UserId), value)
			end)
			if ok then
				done[kind] = value
			else
				warn(`[Leaderboard] write {kind} for {player.Name} failed: {err}`)
			end
		end
	end
end

local function read(kind: Kind)
	local store = stores[kind]
	if not store then
		return
	end
	local ok, result = pcall(function()
		return store:GetSortedAsync(false, SIZE):GetCurrentPage()
	end)
	if not ok then
		warn(`[Leaderboard] read {kind} failed: {result}`)
		return
	end
	local entries: { Entry } = {}
	for _, item in result :: { any } do
		local userId = tonumber(item.key)
		if userId and typeof(item.value) == "number" then
			table.insert(entries, { userId = userId, name = nameFor(userId), value = item.value })
		end
	end
	stored[kind] = entries
end

-- Stored entries with the live scores of everyone on this server mixed in.
local function merged(kind: Kind): { Entry }
	local byUser: { [number]: Entry } = {}
	for _, entry in stored[kind] do
		byUser[entry.userId] = entry
	end
	for player, scores in lastScore do
		if player.Parent == Players then
			byUser[player.UserId] = { userId = player.UserId, name = player.DisplayName, value = scores[kind] }
		end
	end
	local list: { Entry } = {}
	for _, entry in byUser do
		if entry.value > 0 then
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a: Entry, b: Entry)
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.userId < b.userId
	end)
	while #list > SIZE do
		table.remove(list)
	end
	return list
end

local function publish()
	for _, screen in CollectionService:GetTagged("Leaderboard") do
		local kind = screen:GetAttribute("Kind")
		if kind == "Points" or kind == "Wins" then
			local json = HttpService:JSONEncode(merged(kind))
			if screen:GetAttribute("Entries") ~= json then
				screen:SetAttribute("Entries", json)
			end
		end
	end
end

function LeaderboardService.init()
	for _, kind in KINDS do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(STORE_NAMES[kind])
		end)
		stores[kind] = if ok then store else nil
	end

	PlayerDataService.onChanged(function(player: Player)
		remember(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.spawn(function()
			write(player)
			lastScore[player] = nil
			written[player] = nil
			publish()
		end)
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			write(player)
		end
	end)

	-- Reading and publishing.
	task.spawn(function()
		while true do
			for _, kind in KINDS do
				read(kind)
			end
			publish()
			task.wait(READ_INTERVAL)
		end
	end)
	-- Live values for this server, without waiting for the next read.
	task.spawn(function()
		while true do
			task.wait(5)
			publish()
		end
	end)
	-- Writing.
	task.spawn(function()
		while true do
			task.wait(WRITE_INTERVAL)
			for _, player in Players:GetPlayers() do
				write(player)
			end
		end
	end)
end

return LeaderboardService
