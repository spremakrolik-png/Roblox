--!strict
-- Decides which segments make up a track, from the seed alone (no Instances, so it is easy to test).
--
-- Rules (GameConfig.Track):
--   * 24-32 segments; difficulty follows DifficultyBands for each third of the track;
--   * a link segment after every 2-3 trap segments (with no trap segments yet, every slot is a link);
--   * the same trap type never twice in a row; one segment id at most MaxSameSegment times;
--   * a segment never appears before its minDifficultyTier;
--   * a checkpoint gate after every CheckpointEvery segments.
-- When the hard rules leave no candidate, the band is widened step by step; the soft "different
-- builder than the previous segment" preference is dropped first. A trap slot only widens the band
-- by one; if no trap fits even then, the slot becomes a link instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)

local TrackConfig = GameConfig.Track

local TrackPlanner = {}

type PickState = {
	uses: { [string]: number },
	lastTrapType: Types.TrapType?,
	lastBuilder: string?,
}

-- Relaxation steps, tried in order until one yields a candidate. Trap slots stop after the third.
local TRAP_RELAXATIONS = 3
type Relaxation = { bandSlack: number, ignoreTier: boolean, allowSameBuilder: boolean }
local RELAXATIONS: { Relaxation } = {
	{ bandSlack = 0, ignoreTier = false, allowSameBuilder = false },
	{ bandSlack = 0, ignoreTier = false, allowSameBuilder = true },
	{ bandSlack = 1, ignoreTier = false, allowSameBuilder = true },
	{ bandSlack = 2, ignoreTier = false, allowSameBuilder = true },
	{ bandSlack = 4, ignoreTier = true, allowSameBuilder = true },
}

local function tierFor(index: number, count: number): number
	return math.clamp(math.ceil(index * 3 / count), 1, 3)
end

local function candidates(
	defs: { Types.SegmentDef },
	wantTrap: boolean,
	tier: number,
	state: PickState,
	relax: Relaxation
): { Types.SegmentDef }
	local band = TrackConfig.DifficultyBands[tier]
	local result: { Types.SegmentDef } = {}
	for _, def in defs do
		local isTrap = def.trapType ~= nil
		if isTrap ~= wantTrap then
			continue
		end
		if (state.uses[def.id] or 0) >= TrackConfig.MaxSameSegment then
			continue
		end
		if isTrap and def.trapType == state.lastTrapType then
			continue
		end
		if not relax.ignoreTier and def.minDifficultyTier > tier then
			continue
		end
		if def.difficulty < band.min - relax.bandSlack or def.difficulty > band.max + relax.bandSlack then
			continue
		end
		if not relax.allowSameBuilder and def.builder == state.lastBuilder then
			continue
		end
		table.insert(result, def)
	end
	return result
end

local function weightedPick(list: { Types.SegmentDef }, rng: Random): Types.SegmentDef
	local total = 0
	for _, def in list do
		total += def.weight
	end
	local roll = rng:NextNumber(0, total)
	for _, def in list do
		roll -= def.weight
		if roll <= 0 then
			return def
		end
	end
	return list[#list]
end

local function pick(
	defs: { Types.SegmentDef },
	wantTrap: boolean,
	tier: number,
	state: PickState,
	rng: Random,
	steps: number
): Types.SegmentDef?
	for step = 1, math.min(steps, #RELAXATIONS) do
		local list = candidates(defs, wantTrap, tier, state, RELAXATIONS[step])
		if #list > 0 then
			return weightedPick(list, rng)
		end
	end
	return nil
end

local function checkpointsFor(count: number): { number }
	local checkpointsAfter: { number } = {}
	for after = TrackConfig.CheckpointEvery, count - 1, TrackConfig.CheckpointEvery do
		table.insert(checkpointsAfter, after)
	end
	return checkpointsAfter
end

-- GameConfig.Track.DebugSegments: a fixed list of segment ids instead of a random plan.
local function debugPlan(seed: number, defs: { Types.SegmentDef }): Types.TrackPlan
	local segments: { Types.SegmentDef } = {}
	for _, id in TrackConfig.DebugSegments do
		local found: Types.SegmentDef? = nil
		for _, def in defs do
			if def.id == id then
				found = def
				break
			end
		end
		assert(found, `GameConfig.Track.DebugSegments: unknown segment id {id}`)
		table.insert(segments, found)
	end
	return { seed = seed, segments = segments, checkpointsAfter = checkpointsFor(#segments) }
end

function TrackPlanner.plan(seed: number, defs: { Types.SegmentDef }): Types.TrackPlan
	if #TrackConfig.DebugSegments > 0 then
		return debugPlan(seed, defs)
	end
	local rng = Random.new(seed)
	local count = rng:NextInteger(TrackConfig.MinSegments, TrackConfig.MaxSegments)
	local state: PickState = { uses = {}, lastTrapType = nil, lastBuilder = nil }
	local segments: { Types.SegmentDef } = {}

	local trapsSinceLink = 0
	local trapsBeforeLink = rng:NextInteger(TrackConfig.MinTrapsBeforeLink, TrackConfig.MaxTrapsBeforeLink)

	for index = 1, count do
		local tier = tierFor(index, count)
		local wantTrap = trapsSinceLink < trapsBeforeLink
		local def = if wantTrap then pick(defs, true, tier, state, rng, TRAP_RELAXATIONS) else nil
		if not def then
			def = pick(defs, false, tier, state, rng, #RELAXATIONS)
		end
		if not def then
			-- Only reachable if the library is far too small for the track length.
			error(`TrackPlanner: no segment fits slot {index}/{count} (seed {seed})`)
		end

		table.insert(segments, def)
		state.uses[def.id] = (state.uses[def.id] or 0) + 1
		state.lastBuilder = def.builder
		if def.trapType then
			trapsSinceLink += 1
			state.lastTrapType = def.trapType
		else
			trapsSinceLink = 0
			trapsBeforeLink = rng:NextInteger(TrackConfig.MinTrapsBeforeLink, TrackConfig.MaxTrapsBeforeLink)
		end
	end

	return {
		seed = seed,
		segments = segments,
		checkpointsAfter = checkpointsFor(count),
	}
end

TrackPlanner.tierFor = tierFor

return TrackPlanner
