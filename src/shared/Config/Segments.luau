--!strict
-- Segment library: what the generator may place. Geometry lives in server/Track/Segments/<builder>.
-- Each builder family comes in several difficulty variants tuned through `params`.
-- Every gap is a share of the safe jump (JumpMath), so all variants stay passable without abilities.

local Types = require(script.Parent.Parent.Types)

-- Link segment: parkour only, no trap and no trapper button.
local function link(
	id: string,
	builder: string,
	length: number,
	rise: number,
	difficulty: number,
	weight: number,
	minDifficultyTier: number,
	params: { [string]: number }
): Types.SegmentDef
	return {
		id = id,
		builder = builder,
		length = length,
		rise = rise,
		difficulty = difficulty,
		trapType = nil,
		weight = weight,
		minDifficultyTier = minDifficultyTier,
		params = params,
	}
end

-- Trap segment: the builder module has the trap's name, and the trapper gets a button for it.
local function trap(
	id: string,
	trapType: Types.TrapType,
	length: number,
	difficulty: number,
	weight: number,
	minDifficultyTier: number,
	params: { [string]: number }
): Types.SegmentDef
	return {
		id = id,
		builder = trapType,
		length = length,
		rise = 0,
		difficulty = difficulty,
		trapType = trapType,
		weight = weight,
		minDifficultyTier = minDifficultyTier,
		params = params,
	}
end

local list: { Types.SegmentDef } = {
	-- Traps (Phase 3: the first five).
	trap("LavaFloor1", "LavaFloor", 40, 1, 3, 1, { safeBlocks = 3 }),
	trap("LavaFloor3", "LavaFloor", 44, 3, 2, 2, { safeBlocks = 2 }),
	trap("VanishingBlocks2", "VanishingBlocks", 40, 2, 3, 1, { tileLength = 4 }),
	trap("VanishingBlocks4", "VanishingBlocks", 48, 4, 2, 2, { tileLength = 3 }),
	trap("ClosingZone2", "ClosingZone", 32, 2, 3, 1, {}),
	trap("ClosingZone4", "ClosingZone", 40, 4, 2, 2, {}),
	trap("CrushingWalls1", "CrushingWalls", 32, 1, 3, 1, {}),
	trap("CrushingWalls3", "CrushingWalls", 40, 3, 2, 2, {}),
	trap("Pistons2", "Pistons", 40, 2, 3, 1, { pistons = 3 }),
	trap("Pistons5", "Pistons", 48, 5, 2, 3, { pistons = 5 }),

	-- Square platforms drifting left and right.
	link("JumpPlatforms1", "JumpPlatforms", 48, 0, 1, 3, 1, { size = 7, gapShare = 0.45 }),
	link("JumpPlatforms2", "JumpPlatforms", 48, 0, 2, 2, 1, { size = 6, gapShare = 0.65 }),
	link("JumpPlatforms3", "JumpPlatforms", 52, 0, 3, 2, 2, { size = 4.5, gapShare = 0.8 }),

	-- Narrow beams on alternating sides; the hardest variant has breaks in the beams.
	link("NarrowBeam1", "NarrowBeam", 40, 0, 1, 3, 1, { beamWidth = 3 }),
	link("NarrowBeam2", "NarrowBeam", 40, 0, 2, 2, 1, { beamWidth = 2 }),
	link("NarrowBeam3", "NarrowBeam", 44, 0, 3, 2, 2, { beamWidth = 1.4 }),
	link("NarrowBeam4", "NarrowBeam", 48, 0, 4, 1, 2, { beamWidth = 1.4, breaks = 2, gapShare = 0.6 }),

	-- Floating steps up (positive rise) or down (negative rise).
	link("StepStairs1", "StepStairs", 44, 6, 1, 3, 1, { stepShare = 0.4, stepLength = 5 }),
	link("StepStairs2", "StepStairs", 48, 8, 2, 2, 1, { stepShare = 0.6, stepLength = 4 }),
	link("StepDown2", "StepStairs", 44, -8, 2, 2, 1, { stepShare = 0.5, stepLength = 4 }),
	link("StepStairs3", "StepStairs", 48, 10, 3, 2, 2, { stepShare = 0.75, stepLength = 4 }),

	-- Narrow platforms alternating left and right: every jump is diagonal.
	link("ZigZag2", "ZigZag", 44, 0, 2, 2, 1, { width = 5, gapShare = 0.6 }),
	link("ZigZag3", "ZigZag", 44, 0, 3, 2, 2, { width = 4, gapShare = 0.72 }),
	link("ZigZag4", "ZigZag", 48, 0, 4, 1, 2, { width = 3, gapShare = 0.82 }),

	-- Round pillars over the void.
	link("Pillars2", "Pillars", 40, 0, 2, 2, 1, { diameter = 5, gapShare = 0.55 }),
	link("Pillars3", "Pillars", 40, 0, 3, 2, 2, { diameter = 4, gapShare = 0.65 }),
	link("Pillars4", "Pillars", 44, 0, 4, 1, 2, { diameter = 3, gapShare = 0.75 }),
	link("Pillars5", "Pillars", 44, 0, 5, 1, 3, { diameter = 2.5, gapShare = 0.85 }),

	-- Platforms that alternate up and down.
	link("UpDownHops1", "UpDownHops", 44, 0, 1, 3, 1, { size = 6, hopShare = 0.3, gapShare = 0.45 }),
	link("UpDownHops2", "UpDownHops", 48, 0, 2, 2, 1, { size = 5, hopShare = 0.5, gapShare = 0.6 }),
	link("UpDownHops4", "UpDownHops", 48, 0, 4, 1, 2, { size = 3.5, hopShare = 0.75, gapShare = 0.75 }),

	-- Small stepping stones scattered across the width.
	link("SteppingStones3", "SteppingStones", 48, 0, 3, 2, 2, { size = 3.5, gapShare = 0.65 }),
	link("SteppingStones4", "SteppingStones", 52, 0, 4, 1, 2, { size = 3, gapShare = 0.78 }),
	link("SteppingStones5", "SteppingStones", 52, 0, 5, 1, 3, { size = 2.5, gapShare = 0.88 }),
}

local byId: { [string]: Types.SegmentDef } = {}
for _, def in list do
	assert(byId[def.id] == nil, `Duplicate segment id {def.id}`)
	byId[def.id] = def
end

-- A numeric builder parameter with a default.
local function param(def: Types.SegmentDef, name: string, default: number): number
	local params = def.params
	if params and params[name] ~= nil then
		return params[name]
	end
	return default
end

return {
	list = list,
	byId = byId,
	param = param,
}
