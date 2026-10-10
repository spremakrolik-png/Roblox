--!strict
-- Wardrobe items: trails, hats and auras bought forever for Points and equipped one per kind.
-- Purely cosmetic: they never change how a character moves.

export type CosmeticKind = "Trail" | "Hat" | "Aura"

export type CosmeticDef = {
	id: string,
	kind: CosmeticKind,
	name: string,
	price: number,
	colors: { Color3 }, -- trail gradient / hat colours / aura colours
	glyph: string, -- icon in the wardrobe
}

local Cosmetics = {}

Cosmetics.Kinds = { "Trail", "Hat", "Aura" } :: { CosmeticKind }
Cosmetics.KindNames = { Trail = "Шлейфы", Hat = "Шапки", Aura = "Ауры" } :: { [CosmeticKind]: string }

Cosmetics.list = {
	-- Trails
	{
		id = "TrailRainbow",
		kind = "Trail",
		name = "Радуга",
		price = 300,
		glyph = "🌈",
		colors = {
			Color3.fromRGB(255, 120, 120),
			Color3.fromRGB(255, 220, 120),
			Color3.fromRGB(140, 230, 150),
			Color3.fromRGB(130, 190, 255),
			Color3.fromRGB(200, 150, 255),
		},
	},
	{
		id = "TrailFire",
		kind = "Trail",
		name = "Огонь",
		price = 200,
		glyph = "🔥",
		colors = { Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 110, 60) },
	},
	{
		id = "TrailIce",
		kind = "Trail",
		name = "Лёд",
		price = 200,
		glyph = "🧊",
		colors = { Color3.fromRGB(240, 250, 255), Color3.fromRGB(120, 200, 255) },
	},
	{
		id = "TrailCandy",
		kind = "Trail",
		name = "Конфета",
		price = 150,
		glyph = "🍬",
		colors = { Color3.fromRGB(255, 170, 200), Color3.fromRGB(255, 255, 255) },
	},
	{
		id = "TrailShadow",
		kind = "Trail",
		name = "Тень",
		price = 250,
		glyph = "🌑",
		colors = { Color3.fromRGB(90, 70, 130), Color3.fromRGB(20, 20, 30) },
	},
	-- Hats
	{
		id = "HatCrown",
		kind = "Hat",
		name = "Корона",
		price = 500,
		glyph = "👑",
		colors = { Color3.fromRGB(250, 200, 70), Color3.fromRGB(230, 70, 90) },
	},
	{
		id = "HatTopHat",
		kind = "Hat",
		name = "Цилиндр",
		price = 300,
		glyph = "🎩",
		colors = { Color3.fromRGB(35, 35, 45), Color3.fromRGB(200, 60, 70) },
	},
	{
		id = "HatParty",
		kind = "Hat",
		name = "Колпак",
		price = 150,
		glyph = "🎉",
		colors = { Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 220, 120) },
	},
	{
		id = "HatHalo",
		kind = "Hat",
		name = "Нимб",
		price = 400,
		glyph = "😇",
		colors = { Color3.fromRGB(255, 235, 150) },
	},
	{
		id = "HatHorns",
		kind = "Hat",
		name = "Рожки",
		price = 250,
		glyph = "😈",
		colors = { Color3.fromRGB(200, 50, 60) },
	},
	{
		id = "HatCatEars",
		kind = "Hat",
		name = "Ушки",
		price = 200,
		glyph = "🐱",
		colors = { Color3.fromRGB(255, 190, 210), Color3.fromRGB(250, 250, 250) },
	},
	-- Auras
	{
		id = "AuraGold",
		kind = "Aura",
		name = "Золотые искры",
		price = 350,
		glyph = "✨",
		colors = { Color3.fromRGB(255, 215, 110) },
	},
	{
		id = "AuraPink",
		kind = "Aura",
		name = "Розовое сияние",
		price = 300,
		glyph = "💗",
		colors = { Color3.fromRGB(255, 160, 200) },
	},
	{
		id = "AuraFrost",
		kind = "Aura",
		name = "Снежинки",
		price = 300,
		glyph = "❄",
		colors = { Color3.fromRGB(200, 235, 255) },
	},
	{
		id = "AuraLeaves",
		kind = "Aura",
		name = "Листопад",
		price = 250,
		glyph = "🍃",
		colors = { Color3.fromRGB(150, 220, 120), Color3.fromRGB(240, 200, 90) },
	},
} :: { CosmeticDef }

Cosmetics.byId = {} :: { [string]: CosmeticDef }
for _, def in Cosmetics.list do
	Cosmetics.byId[def.id] = def
end

return Cosmetics
