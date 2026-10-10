--!strict
-- Builds the round's track: start area, segments, finish platform and the trapper corridor
-- behind a glass wall. Phase 1 uses the fixed segment list from GameConfig.Track.FixedSegments;
-- Phase 2 replaces the selection with a seeded generator.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local Types = require(ReplicatedStorage.Shared.Types)
local Assets = require(script.Parent.Parent.Util.Assets)
local Build = require(script.Parent.Parent.Util.Build)
local Segments = require(script.Parent.Segments)
local Themes = require(script.Parent.Themes)

local TrackConfig = GameConfig.Track

local TrackGenerator = {}

-- Lateral layout (local x, right of the track centre): track | glass | corridor | outer wall.
local HALF_WIDTH = TrackConfig.Width / 2
local WALL = TrackConfig.WallThickness
local CORRIDOR_X = HALF_WIDTH + WALL + TrackConfig.CorridorWidth / 2
local OUTER_WALL_X = HALF_WIDTH + WALL + TrackConfig.CorridorWidth + WALL / 2
local LEFT_EDGE = -HALF_WIDTH - WALL -- outer face of the left side walls
local RIGHT_EDGE = OUTER_WALL_X + WALL / 2 -- outer face of the corridor wall

local function pointInBox(box: Types.Box, position: Vector3): boolean
	local relative = box.cframe:PointToObjectSpace(position)
	local half = box.size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

-- Glass wall, trapper corridor floor and the outer corridor wall alongside one stretch of track
-- that starts at `from` (floor height 0) and ends `length` studs ahead at floor height `rise`.
local function buildSides(parent: Instance, theme: Types.Theme, from: CFrame, length: number, rise: number)
	local low = math.min(0, rise) - TrackConfig.FallKillDepth
	local high = math.max(0, rise) + TrackConfig.GlassHeight
	local wallHeight = high - low
	local wallY = (low + high) / 2

	Build.part({
		name = "Glass",
		size = Vector3.new(WALL, wallHeight, length),
		cframe = from * CFrame.new(HALF_WIDTH + WALL / 2, wallY, -length / 2),
		color = theme.glassColor,
		material = Enum.Material.Glass,
		transparency = 0.65,
		castShadow = false,
		parent = parent,
	})
	Build.part({
		name = "CorridorWall",
		size = Vector3.new(WALL, wallHeight, length),
		cframe = from * CFrame.new(OUTER_WALL_X, wallY, -length / 2),
		color = theme.wallColor,
		parent = parent,
	})

	-- The corridor is one straight (possibly sloped) floor, so the trapper never has to jump.
	local overlap = 0.1
	local startPoint = (from * CFrame.new(CORRIDOR_X, -0.5, overlap)).Position
	local endPoint = (from * CFrame.new(CORRIDOR_X, rise - 0.5, -length - overlap)).Position
	Build.span(
		"CorridorFloor",
		startPoint,
		endPoint,
		TrackConfig.CorridorWidth,
		1,
		theme.corridorColor,
		Enum.Material.SmoothPlastic,
		parent
	)

	-- Accent strip along the foot of the glass on the corridor side.
	local stripStart = (from * CFrame.new(HALF_WIDTH + WALL + 0.5, 0.05, 0)).Position
	local stripEnd = (from * CFrame.new(HALF_WIDTH + WALL + 0.5, rise + 0.05, -length)).Position
	local strip = Build.span("Accent", stripStart, stripEnd, 1, 0.2, theme.accentColor, Enum.Material.Neon, parent)
	strip.CanCollide = false
	strip.CanQuery = false
end

-- Wall across the full width (track + corridor) at `at`, used to close both ends.
local function buildCap(parent: Instance, theme: Types.Theme, at: CFrame, floorY: number)
	local height = TrackConfig.GlassHeight + TrackConfig.FallKillDepth
	Build.part({
		name = "Cap",
		size = Vector3.new(RIGHT_EDGE - LEFT_EDGE, height, WALL),
		cframe = at * CFrame.new((LEFT_EDGE + RIGHT_EDGE) / 2, floorY + TrackConfig.GlassHeight - height / 2, 0),
		color = theme.wallColor,
		parent = parent,
	})
end

-- Wall along the open (left) edge of a stretch, so runners cannot fall off the start or finish.
local function buildLeftWall(parent: Instance, theme: Types.Theme, from: CFrame, length: number)
	Build.part({
		name = "SideWall",
		size = Vector3.new(WALL, TrackConfig.GateHeight, length),
		cframe = from * CFrame.new(-HALF_WIDTH - WALL / 2, TrackConfig.GateHeight / 2, -length / 2),
		color = theme.wallColor,
		parent = parent,
	})
end

local function buildGate(parent: Instance, theme: Types.Theme, at: CFrame, x: number, width: number): Part
	return Build.part({
		name = "Gate",
		size = Vector3.new(width, TrackConfig.GateHeight, 0.6),
		cframe = at * CFrame.new(x, TrackConfig.GateHeight / 2, 0),
		color = theme.accentColor,
		material = Enum.Material.ForceField,
		transparency = 0.2,
		parent = parent,
	})
end

local function buildStart(model: Model, theme: Types.Theme, origin: CFrame): ({ CFrame }, CFrame, { BasePart })
	local area = Build.model("Start", model)
	local length = TrackConfig.StartPadLength
	-- The start area lies behind the start line (local +Z is backwards).
	local from = origin * CFrame.new(0, 0, length)

	Build.part({
		name = "StartPad",
		size = Vector3.new(TrackConfig.Width, 1, length),
		cframe = from * CFrame.new(0, -0.5, -length / 2),
		color = theme.floorColor,
		material = theme.floorMaterial,
		parent = area,
	})
	buildSides(area, theme, from, length, 0)
	buildLeftWall(area, theme, from, length)
	buildCap(area, theme, from, 0)

	local gates: { BasePart } = {
		buildGate(area, theme, origin, 0, TrackConfig.Width),
		buildGate(area, theme, origin, CORRIDOR_X, TrackConfig.CorridorWidth),
	}

	-- 3 columns x 4 rows of runner spawns, facing forward, standing on the pad.
	local spawns: { CFrame } = {}
	for row = 0, 3 do
		for column = -1, 1 do
			table.insert(spawns, origin * CFrame.new(column * 4, 3.5, 5 + row * 4))
		end
	end
	local trapperSpawn = origin * CFrame.new(CORRIDOR_X, 3.5, length / 2)
	return spawns, trapperSpawn, gates
end

local function buildFinish(model: Model, theme: Types.Theme, from: CFrame): Types.Box
	local area = Build.model("Finish", model)
	local length = TrackConfig.FinishPadLength

	Build.part({
		name = "FinishPad",
		size = Vector3.new(TrackConfig.Width, 1, length),
		cframe = from * CFrame.new(0, -0.5, -length / 2),
		color = theme.floorColor,
		material = theme.floorMaterial,
		parent = area,
	})
	buildSides(area, theme, from, length, 0)
	buildLeftWall(area, theme, from, length)
	buildCap(area, theme, from * CFrame.new(0, 0, -length), 0)

	Build.part({
		name = "FinishLine",
		size = Vector3.new(TrackConfig.Width, 0.2, 1.5),
		cframe = from * CFrame.new(0, 0.1, -1.5),
		color = theme.accentColor,
		material = Enum.Material.Neon,
		canCollide = false,
		canQuery = false,
		parent = area,
	})
	local banner = Build.part({
		name = "FinishBanner",
		size = Vector3.new(TrackConfig.Width, 3, 0.6),
		cframe = from * CFrame.new(0, TrackConfig.GateHeight - 1.5, -1.5),
		color = theme.wallColor,
		canCollide = false,
		parent = area,
	})
	-- The runners approach from behind the banner's back face (+Z), so label both faces.
	Build.sign(banner, Enum.NormalId.Back, "FINISH", theme.accentColor)
	Build.sign(banner, Enum.NormalId.Front, "FINISH", theme.accentColor)

	-- Everything past the finish line counts as finished.
	local zoneStart = 2.5
	return {
		cframe = from * CFrame.new(0, TrackConfig.ProgressVolumeHeight / 2, -(zoneStart + length) / 2),
		size = Vector3.new(TrackConfig.Width, TrackConfig.ProgressVolumeHeight, length - zoneStart),
	}
end

local function buildSegment(index: number, ctx: Types.SegmentContext): Model
	local def = ctx.def
	local entry = ctx.entry
	local segmentModel = ctx.parent
	local asset = Assets.cloneModel("Segment_" .. def.id)
	if asset then
		-- Contract: the asset's pivot is the entry floor centre, facing forward.
		asset:PivotTo(entry)
		asset.Parent = segmentModel
	else
		local builder = Segments[def.id]
		assert(builder, `No builder for segment {def.id}`)
		builder(ctx)
	end
	buildSides(segmentModel, ctx.theme, entry, def.length, def.rise)
	segmentModel:SetAttribute("Index", index)
	return segmentModel
end

-- Builds a new track in Workspace. Pass a seed to rebuild a specific track for debugging.
function TrackGenerator.generate(seed: number?): Types.Track
	local trackSeed = seed or Random.new():NextInteger(1, 2 ^ 30)
	print(`[Track] seed = {trackSeed}`)
	local rng = Random.new(trackSeed)
	local theme = Themes.default

	local model = Instance.new("Model")
	model.Name = "Track"
	model:SetAttribute("Seed", trackSeed)

	local origin = CFrame.lookAt(TrackConfig.Origin, TrackConfig.Origin + Vector3.xAxis)
	local runnerSpawns, trapperSpawn, gates = buildStart(model, theme, origin)

	local segments: { Types.TrackSegment } = {}
	local entry = origin
	local distance = 0
	local lowestFloor = origin.Y
	for index, id in TrackConfig.FixedSegments do
		local def = SegmentDefs.byId[id]
		assert(def, `Unknown segment id {id}`)

		local ctx: Types.SegmentContext = {
			entry = entry,
			def = def,
			width = TrackConfig.Width,
			padLength = TrackConfig.PadLength,
			theme = theme,
			parent = Build.model(string.format("%02d_%s", index, def.id), model),
			rng = rng,
		}
		local segmentModel = buildSegment(index, ctx)

		local exit = entry * CFrame.new(0, def.rise, -def.length)
		local low = math.min(0, def.rise) - TrackConfig.ProgressVolumeDepth
		local high = math.max(0, def.rise) + TrackConfig.ProgressVolumeHeight
		table.insert(segments, {
			index = index,
			def = def,
			entry = entry,
			exit = exit,
			volume = {
				cframe = entry * CFrame.new(0, (low + high) / 2, -def.length / 2),
				size = Vector3.new(TrackConfig.Width + TrackConfig.ProgressVolumeSlack * 2, high - low, def.length),
			},
			startDistance = distance,
			model = segmentModel,
		})

		distance += def.length
		lowestFloor = math.min(lowestFloor, exit.Y)
		entry = exit
	end

	local finishZone = buildFinish(model, theme, entry)
	model.Parent = workspace

	return {
		model = model,
		seed = trackSeed,
		theme = theme,
		segments = segments,
		totalLength = distance,
		runnerSpawns = runnerSpawns,
		trapperSpawn = trapperSpawn,
		finishZone = finishZone,
		killY = lowestFloor - TrackConfig.FallKillDepth,
		gates = gates,
	}
end

function TrackGenerator.openGates(track: Types.Track)
	for _, gate in track.gates do
		gate:Destroy()
	end
	table.clear(track.gates)
end

function TrackGenerator.destroy(track: Types.Track)
	track.model:Destroy()
end

TrackGenerator.pointInBox = pointInBox

-- Distance (studs) a point has covered inside a segment, measured along the segment's forward axis.
function TrackGenerator.distanceInSegment(segment: Types.TrackSegment, position: Vector3): number
	local relative = segment.entry:PointToObjectSpace(position)
	return math.clamp(-relative.Z, 0, segment.def.length)
end

return TrackGenerator
