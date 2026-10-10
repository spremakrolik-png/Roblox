--!strict
-- Trap balance: timings, speeds and kill-feed wording. Geometry lives in server/Track/Segments/<Trap>.

local Types = require(script.Parent.Parent.Types)

-- Player-facing text is Russian. The trap is the subject of the kill-feed line, so the phrase
-- agrees with the trap's name and never has to guess the player's gender:
-- "<name> <killPhrase> <runner>", e.g. "Давящие стены раздавили Player123".
export type TrapInfo = {
	name: string, -- shown on the trapper's button, in warnings and in the kill feed
	killPhrase: string, -- the trap killed the runner directly
	fallPhrase: string, -- the runner fell soon after the trap hit them
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
	FallingCeiling = {
		Telegraph = 0.8, -- falling panels blink; the panels over the green niches stay up
		CeilingHeight = 12,
		DropSeconds = 0.35,
		HoldSeconds = 1,
		RiseSeconds = 1.5,
	},
	SpinningBlade = {
		Telegraph = 0.8, -- the blade appears and blinks before it starts to spin
		SpinSeconds = 6,
		BladeHeight = 1.2, -- blade centre above the floor: jump over it
		LethalHeight = 4.4, -- root part height above the floor the blade still hits
		HitWidth = 1.6, -- distance from the blade line that counts as a hit
	},
	ArrowVolley = {
		Telegraph = 0.8, -- the lanes about to be shot glow red on the floor
		Volleys = 3,
		VolleyInterval = 1.3,
		FlightSeconds = 0.25,
	},
	IceFloor = {
		Telegraph = 0.6,
		ActiveSeconds = 6, -- the floor turns to ice and drifts towards the open edge
	},
	FakeFloor = {
		Telegraph = 0.9, -- the tiles that will drop blink red
		GoneSeconds = 4,
	},
	RisingFlood = {
		Telegraph = 0.8,
		FloodHeight = 5, -- acid level above the floor at its highest
		LethalMargin = 1.5, -- root parts this close above the acid still dissolve
		RiseSeconds = 2.5,
		HoldSeconds = 2,
		DrainSeconds = 1.5,
	},

	Info = {
		LavaFloor = {
			name = "Лавовый пол",
			killPhrase = "сжёг",
			fallPhrase = "сбросил в пропасть",
			color = Color3.fromRGB(255, 90, 20),
		},
		VanishingBlocks = {
			name = "Исчезающие блоки",
			killPhrase = "уронили",
			fallPhrase = "уронили в пропасть",
			color = Color3.fromRGB(150, 120, 255),
		},
		ClosingZone = {
			name = "Закрывающаяся зона",
			killPhrase = "отравила",
			fallPhrase = "сбросила в пропасть",
			color = Color3.fromRGB(90, 255, 90),
		},
		CrushingWalls = {
			name = "Давящие стены",
			killPhrase = "раздавили",
			fallPhrase = "сбросили в пропасть",
			color = Color3.fromRGB(255, 60, 60),
		},
		Pistons = {
			name = "Поршни",
			killPhrase = "раздавили",
			fallPhrase = "столкнули в пропасть",
			color = Color3.fromRGB(255, 200, 40),
		},
		FallingCeiling = {
			name = "Падающий потолок",
			killPhrase = "придавил",
			fallPhrase = "сбросил в пропасть",
			color = Color3.fromRGB(200, 130, 60),
		},
		SpinningBlade = {
			name = "Вращающееся лезвие",
			killPhrase = "срезало",
			fallPhrase = "сбросило в пропасть",
			color = Color3.fromRGB(230, 230, 240),
		},
		ArrowVolley = {
			name = "Залп стрел",
			killPhrase = "сразил",
			fallPhrase = "сбросил в пропасть",
			color = Color3.fromRGB(255, 70, 70),
		},
		IceFloor = {
			name = "Ледяной пол",
			killPhrase = "заморозил",
			fallPhrase = "скинул в пропасть",
			color = Color3.fromRGB(140, 220, 255),
		},
		FakeFloor = {
			name = "Ложный пол",
			killPhrase = "обманул",
			fallPhrase = "уронил в пропасть",
			color = Color3.fromRGB(255, 120, 200),
		},
		RisingFlood = {
			name = "Кислотный потоп",
			killPhrase = "растворил",
			fallPhrase = "смыл в пропасть",
			color = Color3.fromRGB(150, 255, 60),
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
			killPhrase = "поймала",
			fallPhrase = "сбросила в пропасть",
			color = Color3.fromRGB(255, 255, 255),
		}
end

return Traps
