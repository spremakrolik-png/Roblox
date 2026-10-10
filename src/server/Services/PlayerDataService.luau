--!strict
-- Saved player data through ProfileStore (session-locked): Points, owned abilities, loadouts for both
-- roles, processed receipts and stats. Also the shop: buying abilities for Points and equipping them,
-- and the safe granting of Robux purchases (receipts are saved before they are confirmed).
-- In Studio without API access ProfileStore falls back to a temporary in-memory store by itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore)

local STORE_NAME = "TrapRunnerPlayers_v1"
local SHOP_RATE_LIMIT = 0.2
local LOAD_WAIT_SECONDS = 30 -- how long a receipt waits for the buyer's data to load
local ROLES = { "Runner", "Trapper" }

local TEMPLATE: Types.ProfileData = {
	Points = 0,
	Owned = {},
	Loadouts = { Runner = {}, Trapper = {} },
	Receipts = {},
	SecondChances = 0,
	Stats = {
		Rounds = 0,
		Finishes = 0,
		Wins = 0,
		TrapperWins = 0,
		Kills = 0,
		BestDistance = 0,
	},
}

local store = ProfileStore.New(STORE_NAME, TEMPLATE :: any)
local profiles: { [Player]: any } = {}
local lastShopRequest: { [Player]: number } = {}
local changeListeners: { (player: Player) -> () } = {}

-- Extra loadout slots (the Extra Ability Slot game pass in Phase 5). Plugged in by MonetizationService.
local extraSlotsFor: (player: Player) -> number = function(_player: Player)
	return 0
end

local PlayerDataService = {}

function PlayerDataService.getData(player: Player): Types.ProfileData?
	local profile = profiles[player]
	if profile and profile:IsActive() then
		return profile.Data :: Types.ProfileData
	end
	return nil
end

function PlayerDataService.isLoaded(player: Player): boolean
	return PlayerDataService.getData(player) ~= nil
end

function PlayerDataService.slotCount(player: Player): number
	return Abilities.BaseSlots + math.clamp(extraSlotsFor(player), 0, Abilities.ExtraSlots)
end

function PlayerDataService.setExtraSlotsProvider(provider: (player: Player) -> number)
	extraSlotsFor = provider
end

-- Equipped, owned abilities of a role, one entry per slot ("" = empty), trimmed to the slot count.
function PlayerDataService.getLoadout(player: Player, role: "Runner" | "Trapper"): { string }
	local data = PlayerDataService.getData(player)
	local result: { string } = {}
	local slots = PlayerDataService.slotCount(player)
	for slot = 1, slots do
		local id = if data then Abilities.loadoutOf(data.Loadouts, role)[slot] else nil
		local def = if id then Abilities.byId[id] else nil
		if data and def and def.role == role and data.Owned[def.id] then
			result[slot] = def.id
		else
			result[slot] = ""
		end
	end
	return result
end

local function updateLeaderstats(player: Player, points: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		local value = Instance.new("IntValue")
		value.Name = "Очки"
		value.Parent = folder
		folder.Parent = player
		leaderstats = folder
	end
	local value = (leaderstats :: Instance):FindFirstChild("Очки")
	if value and value:IsA("IntValue") then
		value.Value = points
	end
end

-- Sends the player's own data to their client and refreshes the leaderboard.
function PlayerDataService.push(player: Player)
	local data = PlayerDataService.getData(player)
	if not data then
		return
	end
	local owned: { string } = {}
	for id, isOwned in data.Owned do
		if isOwned then
			table.insert(owned, id)
		end
	end
	local snapshot: Types.DataSnapshot = {
		points = data.Points,
		owned = owned,
		loadouts = {
			Runner = PlayerDataService.getLoadout(player, "Runner"),
			Trapper = PlayerDataService.getLoadout(player, "Trapper"),
		},
		slots = PlayerDataService.slotCount(player),
		secondChances = data.SecondChances,
	}
	updateLeaderstats(player, data.Points)
	Remotes.PlayerData:FireClient(player, snapshot)
	for _, listener in changeListeners do
		task.spawn(listener, player)
	end
end

-- Called after every change of a player's data (load, purchase, loadout, Points, slots).
function PlayerDataService.onChanged(listener: (player: Player) -> ())
	table.insert(changeListeners, listener)
end

function PlayerDataService.addPoints(player: Player, amount: number)
	local data = PlayerDataService.getData(player)
	if data and amount ~= 0 then
		data.Points = math.max(0, data.Points + math.floor(amount))
		PlayerDataService.push(player)
	end
end

function PlayerDataService.updateStats(player: Player, change: (stats: Types.PlayerStats) -> ())
	local data = PlayerDataService.getData(player)
	if data then
		change(data.Stats)
	end
end

-- Shop ------------------------------------------------------------------------------

local function reply(player: Player, ok: boolean, message: string)
	Remotes.ShopResult:FireClient(player, ok, message)
end

-- Marks an ability owned and puts it straight into the first empty slot of its role.
local function giveAbility(player: Player, data: Types.ProfileData, def: Types.AbilityDef)
	data.Owned[def.id] = true
	local loadout = PlayerDataService.getLoadout(player, def.role)
	for slot, id in loadout do
		if id == "" then
			loadout[slot] = def.id
			Abilities.setLoadout(data.Loadouts, def.role, loadout)
			break
		end
	end
end

local function buy(player: Player, data: Types.ProfileData, abilityId: unknown)
	if typeof(abilityId) ~= "string" then
		return
	end
	local def = Abilities.byId[abilityId]
	if not def then
		return
	end
	if data.Owned[def.id] then
		reply(player, false, "Уже куплено")
		return
	end
	if data.Points < def.price then
		reply(player, false, `Не хватает очков: нужно {def.price}`)
		return
	end
	data.Points -= def.price
	giveAbility(player, data, def)
	PlayerDataService.push(player)
	reply(player, true, `Куплено: {def.name}`)
end

local function equip(player: Player, data: Types.ProfileData, role: unknown, slot: unknown, abilityId: unknown)
	if role ~= "Runner" and role ~= "Trapper" then
		return
	end
	if
		typeof(slot) ~= "number"
		or slot ~= math.floor(slot)
		or slot < 1
		or slot > PlayerDataService.slotCount(player)
	then
		return
	end
	if typeof(abilityId) ~= "string" then
		return
	end
	local roleName: "Runner" | "Trapper" = if role == "Runner" then "Runner" else "Trapper"
	local loadout = PlayerDataService.getLoadout(player, roleName)
	if abilityId ~= "" then
		local def = Abilities.byId[abilityId]
		if not def or def.role ~= roleName or not data.Owned[def.id] then
			return
		end
		-- One ability sits in one slot at a time.
		for index, id in loadout do
			if id == abilityId then
				loadout[index] = ""
			end
		end
	end
	loadout[slot] = abilityId
	Abilities.setLoadout(data.Loadouts, roleName, loadout)
	PlayerDataService.push(player)
end

local function onShopRequest(player: Player, action: unknown, a: unknown, b: unknown, c: unknown)
	local now = os.clock()
	if now - (lastShopRequest[player] or 0) < SHOP_RATE_LIMIT then
		return
	end
	lastShopRequest[player] = now
	local data = PlayerDataService.getData(player)
	if not data then
		return
	end
	if action == "Buy" then
		buy(player, data, a)
	elseif action == "Equip" then
		equip(player, data, a, b, c)
	end
end

-- Robux purchases ---------------------------------------------------------------------

-- Gives an ability bought for Robux. Returns false if it was already owned (the caller compensates).
function PlayerDataService.grantAbility(player: Player, data: Types.ProfileData, def: Types.AbilityDef): boolean
	if data.Owned[def.id] then
		return false
	end
	giveAbility(player, data, def)
	return true
end

-- Grants a developer product exactly once. The receipt id goes into the save together with the
-- reward, and the purchase is confirmed only after a save that contains it, so neither a crash nor a
-- second server can grant it twice or lose it.
function PlayerDataService.processPurchase(
	player: Player,
	purchaseId: string,
	grant: (data: Types.ProfileData) -> ()
): Enum.ProductPurchaseDecision
	local waitedUntil = os.clock() + LOAD_WAIT_SECONDS
	while profiles[player] == nil and player.Parent == Players and os.clock() < waitedUntil do
		task.wait(0.5)
	end
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = profile.Data :: Types.ProfileData
	if not table.find(data.Receipts, purchaseId) then
		local ok, err = pcall(grant, data)
		if not ok then
			warn(`[Data] purchase {purchaseId} for {player.Name} failed: {err}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		while #data.Receipts >= Monetization.ReceiptLogSize do
			table.remove(data.Receipts, 1)
		end
		table.insert(data.Receipts, purchaseId)
		PlayerDataService.push(player)
	end

	local function saved(lastSaved: any): boolean
		local receipts = if type(lastSaved) == "table" then lastSaved.Receipts else nil
		return type(receipts) == "table" and table.find(receipts, purchaseId) ~= nil
	end
	if saved(profile.LastSavedData) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	profile:Save()
	while profile:IsActive() do
		local lastSaved = profile.OnAfterSave:Wait()
		if saved(lastSaved) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Sessions ----------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Не удалось загрузить данные. Попробуй зайти ещё раз.")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Данные открыты на другом сервере. Перезайди в игру.")
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profiles[player] = profile

	-- Older saves may lack a role table.
	local data = profile.Data :: Types.ProfileData
	if RunService:IsStudio() then
		data.Points = math.max(data.Points, GameConfig.Debug.StudioStartPoints)
	end
	for _, role in ROLES do
		if type((data.Loadouts :: any)[role]) ~= "table" then
			(data.Loadouts :: any)[role] = {}
		end
	end
	if type(data.Receipts) ~= "table" then
		data.Receipts = {}
	end
	PlayerDataService.push(player)
end

function PlayerDataService.init()
	Remotes.ShopRequest.OnServerEvent:Connect(onShopRequest)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastShopRequest[player] = nil
		local profile = profiles[player]
		if profile then
			profile:EndSession()
		end
		profiles[player] = nil
	end)
end

return PlayerDataService
