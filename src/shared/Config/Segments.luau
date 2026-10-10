--!strict
-- Segment library: what the generator may place. Geometry lives in server/Track/Segments.

local Types = require(script.Parent.Parent.Types)

local list: { Types.SegmentDef } = {
	-- Link segments: parkour only, no trap and no trapper button.
	{
		id = "JumpPlatforms",
		length = 48,
		rise = 0,
		difficulty = 1,
		trapType = nil,
		weight = 3,
		minDifficultyTier = 1,
	},
	{
		id = "NarrowBeam",
		length = 40,
		rise = 0,
		difficulty = 2,
		trapType = nil,
		weight = 2,
		minDifficultyTier = 1,
	},
	{
		id = "StepStairs",
		length = 44,
		rise = 6,
		difficulty = 1,
		trapType = nil,
		weight = 2,
		minDifficultyTier = 1,
	},
	{
		id = "ZigZag",
		length = 44,
		rise = 0,
		difficulty = 2,
		trapType = nil,
		weight = 2,
		minDifficultyTier = 1,
	},
	{
		id = "Pillars",
		length = 40,
		rise = 0,
		difficulty = 3,
		trapType = nil,
		weight = 1,
		minDifficultyTier = 2,
	},
}

local byId: { [string]: Types.SegmentDef } = {}
for _, def in list do
	assert(byId[def.id] == nil, `Duplicate segment id {def.id}`)
	byId[def.id] = def
end

return {
	list = list,
	byId = byId,
}
