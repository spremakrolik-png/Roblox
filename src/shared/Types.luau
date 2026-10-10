--!strict
-- Shared type definitions used by both the server and the client.

-- Game loop ---------------------------------------------------------------

export type Phase = "Waiting" | "Intermission" | "Countdown" | "Round" | "Results"

export type Role = "None" | "Runner" | "Trapper"

-- Which lobby circle a player is standing in.
export type Circle = "None" | "Runner" | "Trapper"

export type RunnerStatus = "None" | "Alive" | "Finished" | "Eliminated"

export type EliminationReason = "Died" | "Fell" | "AFK" | "Left"

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
	id: string,
	length: number, -- studs along the track, entry to exit
	rise: number, -- net height change, entry to exit
	difficulty: number, -- 1..5
	trapType: TrapType?, -- nil for link (parkour-only) segments
	weight: number, -- relative pick weight for the generator
	minDifficultyTier: number, -- earliest third of the track (1..3) the segment may appear in
}

export type Theme = {
	name: string,
	floorColor: Color3,
	floorMaterial: Enum.Material,
	accentColor: Color3,
	wallColor: Color3,
	glassColor: Color3,
	corridorColor: Color3,
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

export type SegmentBuilder = (ctx: SegmentContext) -> ()

export type TrackSegment = {
	index: number,
	def: SegmentDef,
	entry: CFrame,
	exit: CFrame,
	volume: Box, -- used for progress tracking
	startDistance: number, -- distance from the start line to this segment's entry
	model: Model,
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
	killY: number, -- runners below this height are dead
	gates: { BasePart },
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
}

export type RoundResults = {
	winner: Winner,
	trapperName: string,
	trapperKills: number,
	finishers: { FinisherEntry },
	eliminated: { EliminatedEntry },
	survivors: { string }, -- runners still alive when the round ended early (trapper left)
	duration: number,
}

return {}
