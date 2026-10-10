--!strict
-- Shared type definitions used by both the server and the client.

-- Game loop ---------------------------------------------------------------

export type Phase = "Waiting" | "Intermission" | "Countdown" | "Round" | "Results"

export type Role = "None" | "Runner" | "Trapper"

-- Which lobby circle a player is standing in.
export type Circle = "None" | "Runner" | "Trapper"

export type RunnerStatus = "None" | "Alive" | "Finished" | "Eliminated"

-- "Trap": killed by a trap, or fell shortly after a trap hit them (credited to the trapper).
-- "Disqualified": reached the finish faster than physically possible between checkpoints.
export type EliminationReason = "Died" | "Fell" | "Trap" | "AFK" | "Left" | "Disqualified"

-- "NoContest": every runner left the server. "Aborted": the technical round limit fired.
export type Winner = "Runners" | "Trapper" | "NoContest" | "Aborted"

-- Track -------------------------------------------------------------------

export type TrapType =
	"LavaFloor"
	| "VanishingBlocks"
	| "ClosingZone"
	| "CrushingWalls"
	| "FallingCeiling"
	| "Pistons"
	| "SpinningBlade"
	| "ArrowVolley"
	| "IceFloor"
	| "FakeFloor"
	| "RisingFlood"

export type SegmentDef = {
	id: string, -- unique; also the name of an optional hand-made model "Segment_<id>"
	builder: string, -- module in server/Track/Segments that builds it
	length: number, -- studs along the track, entry to exit
	rise: number, -- net height change, entry to exit
	difficulty: number, -- 1..5
	trapType: TrapType?, -- nil for link (parkour-only) segments
	weight: number, -- relative pick weight for the generator
	minDifficultyTier: number, -- earliest third of the track (1..3) the segment may appear in
	params: { [string]: number }?, -- builder-specific tuning (gap share, platform size, ...)
}

-- Output of the track planner: what goes where, decided from the seed alone.
export type TrackPlan = {
	seed: number,
	segments: { SegmentDef },
	checkpointsAfter: { number }, -- a checkpoint gate stands after these segment indices
}

export type Theme = {
	name: string,
	floorColor: Color3,
	floorMaterial: Enum.Material,
	floorPhysics: PhysicalProperties?, -- overrides the material's physics (e.g. ice that is not slippery)
	accentColor: Color3,
	wallColor: Color3,
	glassColor: Color3,
	corridorColor: Color3,
	abyssColor: Color3, -- decorative surface far below the track (lava, neon grid, water, chocolate)
	abyssMaterial: Enum.Material,
	decorColor: Color3, -- columns rising from the abyss on the open side
	decorMaterial: Enum.Material,
	decorTopColor: Color3,
}

-- An oriented box in world space.
export type Box = {
	cframe: CFrame,
	size: Vector3,
}

-- Everything a segment builder needs. Local frame: entry.LookVector is "forward",
-- the floor top at the entry is y = 0, and the builder must leave walkable floor at
-- the exit, which is `entry * CFrame.new(0, def.rise, -def.length)`.
export type SegmentContext = {
	entry: CFrame,
	def: SegmentDef,
	width: number,
	padLength: number,
	theme: Theme,
	parent: Model,
	rng: Random,
}

-- Link builders return nothing; trap builders return a TrapHandle.
export type SegmentBuilder = (ctx: SegmentContext) -> ...any

-- What a trap gets from TrapService while it runs. Every call is a no-op once the round is over.
export type TrapHooks = {
	runnersIn: (box: Box) -> { Player }, -- alive runners whose root part is inside the box
	kill: (player: Player) -> (), -- kill a runner with this trap (credited to the trapper)
	markHit: (player: Player) -> (), -- a fall soon after this counts as a kill by this trap
	push: (player: Player, velocity: Vector3) -> (), -- knock a runner away (server-side)
	isLive: () -> boolean,
}

-- Returned by a trap segment's builder.
export type TrapHandle = {
	zone: Box, -- where runners get the on-screen warning
	activate: (hooks: TrapHooks) -> (), -- yields: telegraph, effect, reset
}

export type TrackTrap = {
	segmentIndex: number,
	trapType: TrapType,
	handle: TrapHandle,
	buttonCFrame: CFrame, -- floor point in the trapper corridor at the start of the segment
}

-- Sent to every client when a trap fires.
export type TrapAlert = {
	trapType: TrapType,
	name: string,
	zoneCFrame: CFrame,
	zoneSize: Vector3,
	telegraph: number,
}

export type TrackSegment = {
	index: number,
	def: SegmentDef,
	entry: CFrame,
	exit: CFrame,
	volume: Box, -- used for progress tracking
	startDistance: number, -- distance from the start line to this segment's entry
	killY: number, -- runners below this height while on this segment are dead
	model: Model,
}

export type Checkpoint = {
	index: number, -- 1..N in track order
	afterSegment: number, -- passed when a runner enters segment afterSegment + 1
	distance: number, -- from the start line
}

export type Track = {
	model: Model,
	seed: number,
	theme: Theme,
	segments: { TrackSegment },
	totalLength: number,
	runnerSpawns: { CFrame },
	trapperSpawn: CFrame,
	finishZone: Box,
	startKillY: number, -- kill height on the start pad
	checkpoints: { Checkpoint },
	traps: { TrackTrap },
	gates: { BasePart },
}

-- Abilities and player data ------------------------------------------------

export type AbilityId =
	"FeatherFall"
	| "SpeedBurst"
	| "DoubleJump"
	| "Dash"
	| "Shield"
	| "Sprint"
	| "BlindFlash"
	| "RemoteTrigger"
	| "TrapRecharge"
	| "SlowCannon"

-- "Active": pressed, has a cooldown. "Passive": always on while equipped. "OncePassive": triggers
-- by itself once per round (Shield). "OncePerRound": pressed, usable once per round.
export type AbilityKind = "Active" | "Passive" | "OncePassive" | "OncePerRound"

export type AbilityDef = {
	id: AbilityId,
	role: "Runner" | "Trapper",
	name: string,
	description: string,
	price: number, -- Points
	cooldown: number, -- seconds, Active only
	kind: AbilityKind,
	params: { [string]: number },
}

export type Loadouts = {
	Runner: { string }, -- ability ids per slot, "" = empty
	Trapper: { string },
}

export type PlayerStats = {
	Rounds: number,
	Finishes: number,
	Wins: number, -- rounds won as a runner (finished and runners won)
	TrapperWins: number,
	Kills: number,
	BestDistance: number, -- best progress share, 0..1
}

-- Saved per player (ProfileStore). Only plain data: no Instances or userdata.
export type ProfileData = {
	Points: number,
	Owned: { [string]: boolean },
	Loadouts: Loadouts,
	Receipts: { [string]: boolean }, -- processed purchase receipt ids (Phase 5)
	Stats: PlayerStats,
}

-- What the client sees of its own data.
export type DataSnapshot = {
	points: number,
	owned: { string },
	loadouts: Loadouts,
	slots: number,
}

-- One equipped ability as the HUD shows it during a round.
export type AbilitySlotState = {
	slot: number, -- loadout slot (keys 1/2/3)
	id: string,
	name: string,
	kind: AbilityKind,
	readyAt: number, -- server time when it can be used again (0 = ready)
	used: boolean, -- once-per-round abilities that are spent
}

-- Network payloads --------------------------------------------------------

export type FeedKind = "Death" | "Finish" | "Info"

export type FeedEntry = {
	text: string,
	kind: FeedKind,
}

export type FinisherEntry = {
	userId: number,
	name: string,
	place: number,
	time: number, -- seconds since the start gate opened
}

export type EliminatedEntry = {
	userId: number,
	name: string,
	reason: EliminationReason,
	cause: string?, -- for traps: the full phrase, e.g. "was crushed by Crushing Walls"
}

export type RoundResults = {
	winner: Winner,
	trapperName: string,
	trapperKills: number,
	finishers: { FinisherEntry },
	eliminated: { EliminatedEntry },
	survivors: { string }, -- runners still alive when the round ended early (trapper left)
	duration: number,
	awards: { PointsAward }, -- empty when the round was aborted
}

export type PointsAward = {
	userId: number,
	name: string,
	points: number,
}

return {}
