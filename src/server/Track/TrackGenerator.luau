--!strict
-- Builds the round's track from a seed: start area, the segments chosen by TrackPlanner, checkpoint
-- gates, the finish platform, the trapper corridor behind a glass wall and the theme's decor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local SegmentDefs = require(ReplicatedStorage.Shared.Config.Segments)
local Types = require(ReplicatedStorage.Shared.Types)
local Assets = require(script.Parent.Parent.Util.Assets)
local Build = require(script.Parent.Parent.Util.Build)
local Segments = require(script.Parent.Segments)
local Themes = require(script.Parent.Themes)
local TrackPlanner = require(script.Parent.TrackPlanner)

local TrackConfig = GameConfig.Track

local TrackGenerator = {}

-- Lateral layout (local x, right of the track centre): track | glass | corridor | outer wall.
local HALF_WIDTH = TrackConfig.Width / 2
local WALL = TrackConfig.WallThickness
local CORRIDOR_X = HALF_WIDTH + WALL + TrackConfig.CorridorWidth / 2
local OUTER_WALL_X = HALF_WIDTH + WALL + TrackConfig.CorridorWidth + WALL / 2
local LEFT_EDGE = -HALF_WIDTH - WALL -- outer face of the left side walls
local RIGHT_EDGE = OUTER_WALL_X + WALL / 2 -- outer face of the corridor wall
-- Trap buttons stand by the outer corridor wall: more than 8 studs (the prompt radius) from any runner.
local BUTTON_X = OUTER_WALL_X - WALL / 2 - 2

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
		physics = theme.floorPhysics,
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
		physics = theme.floorPhysics,
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

-- Theme decor under and beside one stretch of track: a surface far below (lava, neon, water...)
-- and columns rising from it on the open side, out of jumping reach and without collision.
local function buildDecor(parent: Instance, theme: Types.Theme, from: CFrame, length: number, rise: number)
	local killDepth = TrackConfig.FallKillDepth
	local abyssTop = math.min(0, rise) - killDepth + 8
	local abyss = Build.part({
		name = "Abyss",
		size = Vector3.new(TrackConfig.DecorOffset * 2 + TrackConfig.Width * 2, 1, length + 0.2),
		cframe = from * CFrame.new(0, abyssTop - 0.5, -length / 2),
		color = theme.abyssColor,
		material = theme.abyssMaterial,
		canCollide = false,
		canTouch = false,
		canQuery = false,
		castShadow = false,
		parent = parent,
	})
	abyss.Transparency = if theme.abyssMaterial == Enum.Material.Glass then 0.3 else 0

	local spacing = TrackConfig.DecorSpacing
	local z = spacing / 2
	while z < length do
		local floorY = rise * z / length
		local base = from * CFrame.new(-TrackConfig.DecorOffset, 0, -z)
		local column = Build.pillar(
			"Column",
			base,
			floorY + 10,
			3,
			floorY + 10 - abyssTop,
			theme.decorColor,
			theme.decorMaterial,
			parent
		)
		column.CanCollide = false
		column.CanQuery = false
		local top = Build.part({
			name = "ColumnTop",
			size = Vector3.new(3.6, 1.2, 3.6),
			cframe = base * CFrame.new(0, floorY + 10.6, 0),
			color = theme.decorTopColor,
			material = Enum.Material.Neon,
			canCollide = false,
			canQuery = false,
			castShadow = false,
			parent = parent,
		})
		top.CanTouch = false
		z += spacing
	end
end

-- A non-solid arch across the track (and a marker in the corridor) where a checkpoint is counted.
local function buildCheckpointGate(parent: Instance, theme: Types.Theme, at: CFrame, number: number, total: number)
	local gate = Build.model(`Checkpoint{number}`, parent)
	local height = TrackConfig.GateHeight
	local function piece(name: string, size: Vector3, offset: CFrame)
		Build.part({
			name = name,
			size = size,
			cframe = at * offset,
			color = theme.accentColor,
			material = Enum.Material.Neon,
			canCollide = false,
			canTouch = false,
			canQuery = false,
			castShadow = false,
			parent = gate,
		})
	end
	piece("PostLeft", Vector3.new(0.8, height, 0.8), CFrame.new(-HALF_WIDTH + 0.4, height / 2, 0))
	piece("PostRight", Vector3.new(0.8, height, 0.8), CFrame.new(HALF_WIDTH - 0.4, height / 2, 0))
	piece("CorridorMark", Vector3.new(TrackConfig.CorridorWidth, 0.2, 1.5), CFrame.new(CORRIDOR_X, 0.1, 0))
	local beam = Build.part({
		name = "Sign",
		size = Vector3.new(TrackConfig.Width, 2.5, 0.6),
		cframe = at * CFrame.new(0, height - 1.25, 0),
		color = theme.wallColor,
		canCollide = false,
		canTouch = false,
		canQuery = false,
		parent = gate,
	})
	local text = `CHECKPOINT {number}/{total}`
	Build.sign(beam, Enum.NormalId.Back, text, theme.accentColor)
	Build.sign(beam, Enum.NormalId.Front, text, theme.accentColor)
end

-- Builds one segment. Trap segments also return their TrapHandle.
local function buildSegment(index: number, ctx: Types.SegmentContext): (Model, Types.TrapHandle?)
	local def = ctx.def
	local entry = ctx.entry
	local segmentModel = ctx.parent
	local handle: Types.TrapHandle? = nil
	-- Hand-made models replace link segments only: a trap needs its moving parts from the builder.
	local asset = if def.trapType then nil else Assets.cloneModel("Segment_" .. def.id)
	if asset then
		-- Contract: the asset's pivot is the entry floor centre, facing forward.
		asset:PivotTo(entry)
		asset.Parent = segmentModel
	else
		local builder = Segments[def.builder]
		assert(builder, `No builder {def.builder} for segment {def.id}`)
		local result = builder(ctx)
		if def.trapType then
			assert(type(result) == "table", `Trap segment {def.id} did not return a TrapHandle`)
			handle = result :: Types.TrapHandle
		end
	end
	buildSides(segmentModel, ctx.theme, entry, def.length, def.rise)
	segmentModel:SetAttribute("Index", index)
	return segmentModel, handle
end

-- A fresh random seed, or GameConfig.Track.DebugSeed when it is set (to replay a track from the logs).
function TrackGenerator.newSeed(): number
	if TrackConfig.DebugSeed ~= 0 then
		return TrackConfig.DebugSeed
	end
	return Random.new():NextInteger(1, 2 ^ 30)
end

-- Builds a new track in Workspace. The same seed always gives the same track.
function TrackGenerator.generate(seed: number?): Types.Track
	local trackSeed = seed or TrackGenerator.newSeed()
	local plan = TrackPlanner.plan(trackSeed, SegmentDefs.list)
	local theme = Themes.forSeed(trackSeed)
	-- Geometry gets its own stream, so tweaking a builder never changes which segments are picked.
	local rng = Random.new(trackSeed + 104729)

	local ids: { string } = {}
	for _, def in plan.segments do
		table.insert(ids, def.id)
	end
	print(`[Track] seed = {trackSeed}, theme = {theme.name}, {#plan.segments} segments: {table.concat(ids, ", ")}`)

	local model = Instance.new("Model")
	model.Name = "Track"
	model:SetAttribute("Seed", trackSeed)

	local origin = CFrame.lookAt(TrackConfig.Origin, TrackConfig.Origin + Vector3.xAxis)
	local runnerSpawns, trapperSpawn, gates = buildStart(model, theme, origin)
	buildDecor(model, theme, origin * CFrame.new(0, 0, TrackConfig.StartPadLength), TrackConfig.StartPadLength, 0)

	local segments: { Types.TrackSegment } = {}
	local traps: { Types.TrackTrap } = {}
	local entry = origin
	local distance = 0
	for index, def in plan.segments do
		local ctx: Types.SegmentContext = {
			entry = entry,
			def = def,
			width = TrackConfig.Width,
			padLength = TrackConfig.PadLength,
			theme = theme,
			parent = Build.model(string.format("%02d_%s", index, def.id), model),
			rng = rng,
		}
		local segmentModel, handle = buildSegment(index, ctx)
		if handle and def.trapType then
			table.insert(traps, {
				segmentIndex = index,
				trapType = def.trapType,
				handle = handle,
				-- Near the outer corridor wall, at the start of the segment: the trapper has to keep up.
				buttonCFrame = entry * CFrame.new(BUTTON_X, 0, -TrackConfig.PadLength / 2),
			})
		end
		buildDecor(segmentModel, theme, entry, def.length, def.rise)

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
			killY = math.min(entry.Y, exit.Y) - TrackConfig.FallKillDepth,
			model = segmentModel,
		})

		distance += def.length
		entry = exit
	end

	local checkpoints: { Types.Checkpoint } = {}
	for number, after in plan.checkpointsAfter do
		local segment = segments[after]
		buildCheckpointGate(segment.model, theme, segment.exit, number, #plan.checkpointsAfter)
		table.insert(checkpoints, {
			index = number,
			afterSegment = after,
			distance = segment.startDistance + segment.def.length,
		})
	end

	local finishZone = buildFinish(model, theme, entry)
	buildDecor(model, theme, entry, TrackConfig.FinishPadLength, 0)
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
		startKillY = origin.Y - TrackConfig.FallKillDepth,
		checkpoints = checkpoints,
		traps = traps,
		gates = gates,
	}
end

-- Height below which a runner who has reached segment `furthest` (0 = start pad) is dead. Uses the
-- lowest floor among the neighbouring segments, since a runner may step back onto the previous one.
function TrackGenerator.killYFor(track: Types.Track, furthest: number): number
	local killY = if furthest <= 1 then track.startKillY else math.huge
	for index = math.max(1, furthest - 1), math.min(#track.segments, furthest + 1) do
		killY = math.min(killY, track.segments[index].killY)
	end
	if killY == math.huge then
		killY = track.startKillY
	end
	return killY
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
