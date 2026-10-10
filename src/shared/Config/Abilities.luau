--!strict
-- Abilities: bought forever for Points (or Robux), equipped in per-role loadouts. Price scale: 100 = weakest,
-- 500 = strongest. Player-facing text is Russian.

local Types = require(script.Parent.Parent.Types)

local Abilities = {}

Abilities.BaseSlots = 2 -- per role; a game pass adds a third (Phase 5)
Abilities.ExtraSlots = 1
Abilities.UseRateLimit = 0.15 -- seconds between two ability requests from one player

local list: { Types.AbilityDef } = {
	-- Runner ------------------------------------------------------------------
	{
		id = "FeatherFall",
		role = "Runner",
		name = "Плавное падение",
		description = "Медленное падение 3 с",
		price = 100,
		cooldown = 20,
		kind = "Active",
		lobbyUse = true,
		params = { Duration = 3, MaxFallSpeed = 8 },
	},
	{
		id = "SpeedBurst",
		role = "Runner",
		name = "Ускорение",
		description = "+60% скорости на 2,5 с",
		price = 150,
		cooldown = 15,
		kind = "Active",
		lobbyUse = true,
		params = { Duration = 2.5, Multiplier = 1.6 },
	},
	{
		id = "DoubleJump",
		role = "Runner",
		name = "Двойной прыжок",
		description = "Второй прыжок в воздухе (работает всегда)",
		price = 250,
		cooldown = 0,
		kind = "Passive",
		lobbyUse = true,
		params = {},
	},
	{
		id = "Dash",
		role = "Runner",
		name = "Рывок",
		description = "Рывок вперёд на 18 studs",
		price = 300,
		cooldown = 12,
		kind = "Active",
		lobbyUse = true,
		params = { Distance = 18, Seconds = 0.2 },
	},
	{
		id = "Shield",
		role = "Runner",
		name = "Щит",
		description = "Спасает от одного удара ловушки за раунд (не от падения)",
		price = 500,
		cooldown = 0,
		kind = "OncePassive",
		lobbyUse = false,
		params = { GraceSeconds = 1.5 },
	},
	-- Trapper -----------------------------------------------------------------
	{
		id = "Sprint",
		role = "Trapper",
		name = "Спринт",
		description = "+40% скорости на 4 с",
		price = 100,
		cooldown = 18,
		kind = "Active",
		lobbyUse = true,
		params = { Duration = 4, Multiplier = 1.4 },
	},
	{
		id = "BlindFlash",
		role = "Trapper",
		name = "Ослепляющая вспышка",
		description = "Туман на сегменте напротив: раннеры плохо видят 3 с",
		price = 250,
		cooldown = 20,
		kind = "Active",
		lobbyUse = false,
		params = { Duration = 3 },
	},
	{
		id = "RemoteTrigger",
		role = "Trapper",
		name = "Дистанционный запуск",
		description = "Раз за раунд: запустить ближайшую ловушку до 60 studs",
		price = 400,
		cooldown = 0,
		kind = "OncePerRound",
		lobbyUse = false,
		params = { Range = 60 },
	},
	{
		id = "TrapRecharge",
		role = "Trapper",
		name = "Перезарядка ловушки",
		description = "Раз за раунд: вернуть последнюю использованную ловушку",
		price = 450,
		cooldown = 0,
		kind = "OncePerRound",
		lobbyUse = false,
		params = {},
	},
	{
		id = "SlowCannon",
		role = "Trapper",
		name = "Замедляющая пушка",
		description = "3 выстрела сквозь стекло: попавший раннер замедлен на 60% на 3 с",
		price = 500,
		cooldown = 8,
		kind = "Active",
		lobbyUse = true,
		params = {
			Shots = 3,
			ShotInterval = 0.15,
			ProjectileSpeed = 150,
			Range = 200,
			HitRadius = 2.5,
			SlowMultiplier = 0.4,
			SlowSeconds = 3,
		},
	},
}

local byId: { [string]: Types.AbilityDef } = {}
for _, def in list do
	assert(byId[def.id] == nil, `Duplicate ability {def.id}`)
	byId[def.id] = def
end

Abilities.list = list
Abilities.byId = byId

-- The slot list of one role in a loadout table (typed accessors: the roles are fixed keys).
function Abilities.loadoutOf(loadouts: Types.Loadouts, role: "Runner" | "Trapper"): { string }
	return if role == "Runner" then loadouts.Runner else loadouts.Trapper
end

function Abilities.setLoadout(loadouts: Types.Loadouts, role: "Runner" | "Trapper", slots: { string })
	if role == "Runner" then
		loadouts.Runner = slots
	else
		loadouts.Trapper = slots
	end
end

-- A numeric tuning value of an ability.
function Abilities.param(def: Types.AbilityDef, name: string): number
	local value = def.params[name]
	assert(value ~= nil, `Ability {def.id} has no param {name}`)
	return value
end

return Abilities
