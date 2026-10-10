--!strict
-- Global tuning: timings, speeds and sizes. Gameplay code must not hard-code these numbers.

local GameConfig = {
	-- Players ------------------------------------------------------------
	MinPlayers = 2, -- players standing in circles needed to start a round
	MaxPlayers = 12, -- informational: set the same value in Game Settings > Places

	-- Game loop (seconds) ------------------------------------------------
	IntermissionSeconds = 10, -- lobby grace period once enough players stand in circles (0 = start at once)
	CountdownSeconds = 15, -- roles are locked and the track is built during this time
	StartGateSeconds = 3, -- players stand frozen at the start before the gates open
	ResultsSeconds = 8,

	-- Round safety (players never see these) ----------------------------
	AfkTimeoutSeconds = 25, -- a runner who does not reach a new segment in this time is eliminated
	RoundHardLimitSeconds = 12 * 60, -- technical limit; the round is closed with no rewards
	TrackingRate = 10, -- server progress checks per second
	MaxSegmentSkip = 1, -- how many segments a runner may skip between two checks before it looks like a teleport

	-- Characters ----------------------------------------------------------
	LobbyWalkSpeed = 16,
	RunnerWalkSpeed = 16,
	TrapperWalkSpeed = 16 * 3, -- three times a runner: the trapper has to keep up with the leader
	JumpPower = 50,
	Gravity = 196.2,
	JumpSafetyMargin = 0.15, -- every generated jump stays at least 15% below the physical limit
	PlayerCollisions = false, -- players walk through each other (no pushing rivals off beams)

	-- Lobby ---------------------------------------------------------------
	Lobby = {
		Origin = Vector3.new(0, 50, 0), -- centre of the lobby floor surface
		FloorSize = 140,
		WallHeight = 30,
		SpawnOffset = Vector3.new(0, 0, -40),
		ReturnSpread = 14, -- players sent back to the lobby land within this radius of the spawn
		CircleRadius = 11,
		CircleMaxHeight = 14, -- root part height above the circle that still counts (standing ~3 + a full jump ~6.4)
		RunnerCircleOffset = Vector3.new(-28, 0, 18),
		TrapperCircleOffset = Vector3.new(28, 0, 18),
		BoardOffset = Vector3.new(0, 16, 69),
		RunnerColor = Color3.fromRGB(40, 150, 255),
		TrapperColor = Color3.fromRGB(255, 60, 60),
		FloorColor = Color3.fromRGB(46, 49, 60),
		WallColor = Color3.fromRGB(32, 34, 44),
	},

	-- Track ---------------------------------------------------------------
	Track = {
		Origin = Vector3.new(1500, 200, 0), -- start line; the track runs along +X, far from the lobby
		Width = 16,
		PadLength = 4, -- flat floor at the entry and exit of every segment
		StartPadLength = 24,
		FinishPadLength = 32,
		GateHeight = 14,
		GlassHeight = 40, -- above the highest floor of a span
		WallThickness = 1,
		CorridorWidth = 20, -- the trapper's corridor is wider than the 16-stud track
		FallKillDepth = 40, -- below the lowest floor of the track
		ProgressVolumeHeight = 40,
		ProgressVolumeDepth = 12,
		ProgressVolumeSlack = 4, -- extra width on each side, so a runner mid-jump still counts
		DecorSpacing = 28, -- themed columns along the open side
		DecorOffset = 20, -- their distance from the track centre (out of jumping reach)

		-- Generator
		DebugSeed = 0, -- non-zero: every round uses this seed (to replay a track from the logs)
		-- Non-empty: every track is exactly these segment ids, in order (to test specific traps), e.g.
		-- { "LavaFloor1", "VanishingBlocks2", "ClosingZone2", "CrushingWalls1", "Pistons2" }
		DebugSegments = {} :: { string },
		MinSegments = 24,
		MaxSegments = 32,
		-- Allowed segment difficulty in each third of the track.
		DifficultyBands = {
			{ min = 1, max = 2 },
			{ min = 2, max = 4 },
			{ min = 3, max = 5 },
		},
		MinTrapsBeforeLink = 2, -- a link segment follows every 2-3 trap segments
		MaxTrapsBeforeLink = 3,
		MaxSameSegment = 2, -- one segment id at most this many times per track
		CheckpointEvery = 6, -- segments between checkpoint gates
	},

	-- Anti-cheat: the fastest a runner could legitimately cover the stretch between checkpoints.
	AntiCheat = {
		SpeedMultiplierAllowance = 1.6, -- Speed Burst (+60%) running the whole stretch
		DashAllowance = 18, -- one Dash per stretch
		TimeTolerance = 0.8, -- extra slack for lag and measurement at 10 Hz
	},
}

return GameConfig
