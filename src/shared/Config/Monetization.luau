--!strict
-- Game passes and developer products. The ids are placeholders: create the passes and products on
-- the Roblox Creator Dashboard and paste their ids here. Anything left at 0 is hidden in the shop
-- and never prompted.

export type PassId = "DoublePoints" | "ExtraSlot" | "VIP"

export type PassDef = {
	id: PassId,
	assetId: number, -- game pass id
	name: string,
	description: string,
	robux: number, -- shown on the button only; the real price is set on the dashboard
}

export type PointsPack = {
	productId: number,
	points: number,
	robux: number,
}

local Monetization = {
	Passes = {
		{
			id = "DoublePoints",
			assetId = 0,
			name = "x2 Очки",
			description = "Все очки за раунды удваиваются",
			robux = 199,
		},
		{
			id = "ExtraSlot",
			assetId = 0,
			name = "Доп. слот",
			description = "Третий слот способности для обеих ролей",
			robux = 149,
		},
		{
			id = "VIP",
			assetId = 0,
			name = "VIP",
			description = "Золотой ник и тег в чате, салют на финише",
			robux = 99,
		},
	} :: { PassDef },

	-- Points packs (developer products). Not affected by x2 Points.
	PointsPacks = {
		{ productId = 0, points = 500, robux = 49 },
		{ productId = 0, points = 1500, robux = 129 },
		{ productId = 0, points = 5000, robux = 349 },
	} :: { PointsPack },

	-- One developer product per ability: ability id -> { productId, robux shown on the button }.
	AbilityProducts = {
		FeatherFall = { productId = 0, robux = 25 },
		SpeedBurst = { productId = 0, robux = 35 },
		DoubleJump = { productId = 0, robux = 55 },
		Dash = { productId = 0, robux = 65 },
		Shield = { productId = 0, robux = 99 },
		Sprint = { productId = 0, robux = 25 },
		BlindFlash = { productId = 0, robux = 55 },
		RemoteTrigger = { productId = 0, robux = 85 },
		TrapRecharge = { productId = 0, robux = 95 },
		SlowCannon = { productId = 0, robux = 99 },
	} :: { [string]: { productId: number, robux: number } },

	ReceiptLogSize = 100, -- processed receipt ids kept in a player's save (newest last)

	-- VIP look
	VipColor = Color3.fromRGB(255, 200, 40),
	VipTag = "[VIP]",
}

function Monetization.pass(id: PassId): PassDef?
	for _, def in Monetization.Passes do
		if def.id == id then
			return def
		end
	end
	return nil
end

-- The player attribute that tells clients a pass is owned (e.g. "Pass_VIP").
function Monetization.attribute(id: PassId): string
	return `Pass_{id}`
end

return Monetization
