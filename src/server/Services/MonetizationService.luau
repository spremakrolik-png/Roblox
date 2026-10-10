--!strict
-- Game passes (x2 Points, Extra Ability Slot, VIP) and developer products (Points packs, abilities
-- for Robux). Pass ownership is cached per player and mirrored to "Pass_<id>" player attributes for
-- the client. Products go through ProcessReceipt, granted exactly once via PlayerDataService.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PointsService = require(script.Parent.PointsService)

type Grant = (player: Player, data: Types.ProfileData) -> ()

local MonetizationService = {}

local passes: { [Player]: { [Monetization.PassId]: boolean } } = {}
local secondChanceHandler: (player: Player) -> () = function(_player: Player) end
local productGrants: { [number]: Grant } = {}

function MonetizationService.owns(player: Player, id: Monetization.PassId): boolean
	local owned = passes[player]
	return owned ~= nil and owned[id] == true
end

-- VIP: a gold "[VIP] Name" tag above the head instead of the default name.
local function decorateVip(player: Player, character: Model)
	if not MonetizationService.owns(player, "VIP") then
		return
	end
	local head = character:WaitForChild("Head", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not head or not head:IsA("BasePart") or head:FindFirstChild("VipName") then
		return
	end
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "VipName"
	billboard.Size = UDim2.fromOffset(220, 36)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.MaxDistance = 120
	billboard.Adornee = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.SourceSansBold
	label.TextScaled = true
	label.Text = `{Monetization.VipTag} {player.DisplayName}`
	label.TextColor3 = Monetization.VipColor
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	billboard.Parent = head
end

local function setOwned(player: Player, id: Monetization.PassId, owned: boolean)
	local cache = passes[player]
	if not cache or player.Parent ~= Players then
		return
	end
	cache[id] = owned
	player:SetAttribute(Monetization.attribute(id), if owned then true else nil)
	if id == "ExtraSlot" then
		-- The slot count changed: resend data (this also refreshes the lobby ability slots).
		PlayerDataService.push(player)
	elseif id == "VIP" and owned and player.Character then
		task.spawn(decorateVip, player, player.Character)
	end
end

local function loadPasses(player: Player)
	passes[player] = {}
	player.CharacterAdded:Connect(function(character)
		decorateVip(player, character)
	end)
	for _, def in Monetization.Passes do
		if def.assetId ~= 0 then
			local ok, owned = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.assetId)
			end)
			if ok and owned then
				setOwned(player, def.id, true)
			elseif not ok then
				warn(`[Monetization] could not check pass {def.id} for {player.Name}: {owned}`)
			end
		end
	end
end

local function passByAsset(assetId: number): Monetization.PassDef?
	if assetId == 0 then
		return nil
	end
	for _, def in Monetization.Passes do
		if def.assetId == assetId then
			return def
		end
	end
	return nil
end

-- Products -------------------------------------------------------------------------------

local function buildProducts()
	for _, pack in Monetization.PointsPacks do
		if pack.productId ~= 0 then
			local points = pack.points
			productGrants[pack.productId] = function(_player: Player, data: Types.ProfileData)
				data.Points += points
			end
		end
	end
	if Monetization.SecondChance.productId ~= 0 then
		productGrants[Monetization.SecondChance.productId] = function(_player: Player, data: Types.ProfileData)
			data.SecondChances += 1
		end
	end
	for abilityId, product in Monetization.AbilityProducts do
		local def = Abilities.byId[abilityId]
		if product.productId ~= 0 and def then
			productGrants[product.productId] = function(player: Player, data: Types.ProfileData)
				if not PlayerDataService.grantAbility(player, data, def) then
					-- Already owned (bought for Points while the prompt was open): refund in Points.
					data.Points += def.price
				end
			end
		end
	end
end

-- Called after a second chance purchase is saved (RoundService revives the runner if it can).
function MonetizationService.setSecondChanceHandler(handler: (player: Player) -> ())
	secondChanceHandler = handler
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local grant = productGrants[receipt.ProductId]
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not grant then
		warn(`[Monetization] unknown product {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	local decision = PlayerDataService.processPurchase(player, purchaseId, function(data)
		grant(player, data)
	end)
	if decision == Enum.ProductPurchaseDecision.PurchaseGranted and player.Parent == Players then
		if receipt.ProductId == Monetization.SecondChance.productId then
			task.spawn(secondChanceHandler, player)
		else
			Remotes.ShopResult:FireClient(player, true, "Покупка получена!")
		end
	end
	return decision
end

function MonetizationService.init()
	buildProducts()
	MarketplaceService.ProcessReceipt = processReceipt

	PointsService.setMultiplierProvider(function(player: Player)
		return if MonetizationService.owns(player, "DoublePoints") then 2 else 1
	end)
	PlayerDataService.setExtraSlotsProvider(function(player: Player)
		return if MonetizationService.owns(player, "ExtraSlot") then Abilities.ExtraSlots else 0
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, assetId: number, purchased: boolean)
			local def = passByAsset(assetId)
			if purchased and def then
				setOwned(player, def.id, true)
				Remotes.ShopResult:FireClient(player, true, `Пропуск получен: {def.name}`)
			end
		end
	)

	Players.PlayerAdded:Connect(loadPasses)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPasses, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		passes[player] = nil
	end)
end

return MonetizationService
