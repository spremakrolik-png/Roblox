--!strict
-- Registry of segment builders, keyed by SegmentDef.builder (see shared/Config/Segments).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local builders: { [string]: Types.SegmentBuilder } = {
	JumpPlatforms = require(script.JumpPlatforms),
	NarrowBeam = require(script.NarrowBeam),
	StepStairs = require(script.StepStairs),
	ZigZag = require(script.ZigZag),
	Pillars = require(script.Pillars),
	UpDownHops = require(script.UpDownHops),
	SteppingStones = require(script.SteppingStones),
}

return builders
