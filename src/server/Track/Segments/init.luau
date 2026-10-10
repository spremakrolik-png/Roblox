--!strict
-- Registry of segment builders, keyed by SegmentDef.builder (see shared/Config/Segments).
-- Link builders return nothing; trap builders return a Types.TrapHandle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local builders: { [string]: Types.SegmentBuilder } = {
	-- Links
	JumpPlatforms = require(script.JumpPlatforms),
	NarrowBeam = require(script.NarrowBeam),
	StepStairs = require(script.StepStairs),
	ZigZag = require(script.ZigZag),
	Pillars = require(script.Pillars),
	UpDownHops = require(script.UpDownHops),
	SteppingStones = require(script.SteppingStones),
	-- Traps
	LavaFloor = require(script.LavaFloor),
	VanishingBlocks = require(script.VanishingBlocks),
	ClosingZone = require(script.ClosingZone),
	CrushingWalls = require(script.CrushingWalls),
	Pistons = require(script.Pistons),
	FallingCeiling = require(script.FallingCeiling),
	SpinningBlade = require(script.SpinningBlade),
	ArrowVolley = require(script.ArrowVolley),
	IceFloor = require(script.IceFloor),
	FakeFloor = require(script.FakeFloor),
	RisingFlood = require(script.RisingFlood),
}

return builders
