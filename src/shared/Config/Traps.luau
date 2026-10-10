--!strict
-- Trap balance: timings, speeds and kill-feed wording. Geometry lives in server/Track/Segments/<Trap>.

local Types = require(script.Parent.Parent.Types)

export type TrapInfo = {
	name: string, -- shown on the trapper's button and in the kill feed
	killVerb: string, -- "<runner> <killVerb> <name>"
	fallVerb: string, -- used when the runner fell after the trap hit them
	color: Color3, -- telegraph flash and death burst
}

local Traps = {
	-- Shared rules
	ButtonActivationDistance = 8, -- ProximityPrompt radius (no hold)
	ButtonDistanceSlack = 4, -- extra distance the server accepts (lag)
	ButtonRateLimit = 0.3, -- seconds between two button presses by the same player
	FallCreditSeconds = 5, -- a fall this soon after a trap hit counts as a trap kill

	LavaFloor = {
		Telegraph = 0.8, -- floor blinks red before it turns to lava
		ActiveSeconds = 3,
		LethalHeight = 4.8, -- root part height above the floor that still burns (safe blocks are higher)
		SafeBlockHeight = 3,
	},
	VanishingBlocks = {
		Telegraph = 0.6,
		WaveSpeed = 20, -- studs per second, a bit faster than a runner
		GoneSeconds = 3, -- how long each row stays gone
	},
	ClosingZone = {
		Telegraph = 0.7, -- then the gates close
		FillSeconds = 2, -- poison rises, then everyone inside dies
		LethalSeconds = 1,
	},
	CrushingWalls = {
		Telegraph = 0.6,
		CloseSeconds = 1.1,
		HoldSeconds = 0.4,
		OpenSeconds = 1.2,
		WallHeight = 9,
	},
	Pistons = {
		Telegraph = 0.7,
		ExtendSeconds = 0.15,
		HoldSeconds = 1,
		RetractSeconds = 0.6,
		PushSpeed = 70, -- sideways knock-back towards the void
		PushUp = 30,
		CrushCheckDelay = 0.35, -- anyone still inside an extended piston after this is crushed
	},

	Info = {
		LavaFloor = {
			name = "Lava Floor",
			killVerb = "was burned by",
			fallVerb = "fell off because of",
			color = Color3.fromRGB(255, 90, 20),
		},
		VanishingBlocks = {
			name = "Vanishing Blocks",
			killVerb = "was dropped by",
			fallVerb = "fell through",
			color = Color3.fromRGB(150, 120, 255),
		},
		ClosingZone = {
			name = "Closing Zone",
			killVerb = "was poisoned in",
			fallVerb = "fell out of",
			color = Color3.fromRGB(90, 255, 90),
		},
		CrushingWalls = {
			name = "Crushing Walls",
			killVerb = "was crushed by",
			fallVerb = "fell off because of",
			color = Color3.fromRGB(255, 60, 60),
		},
		Pistons = {
			name = "Pistons",
			killVerb = "was crushed by",
			fallVerb = "was pushed into the void by",
			color = Color3.fromRGB(255, 200, 40),
		},
	} :: { [Types.TrapType]: TrapInfo },
}

-- Telegraph (warning) duration of a trap type.
function Traps.telegraph(trapType: Types.TrapType): number
	local section = (Traps :: any)[trapType]
	if type(section) == "table" and type(section.Telegraph) == "number" then
		return section.Telegraph
	end
	return 0.7
end

-- Name, verbs and colour of a trap type (falls back to the type name for traps not added yet).
function Traps.info(trapType: Types.TrapType): TrapInfo
	return Traps.Info[trapType]
		or {
			name = trapType,
			killVerb = "was killed by",
			fallVerb = "fell because of",
			color = Color3.fromRGB(255, 255, 255),
		}
end

return Traps
