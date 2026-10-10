--!strict
-- The lobby: the two role circles, who stands in them, trapper selection, the waiting/intermission
-- phases and the big status board on the wall.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GameState = require(ReplicatedStorage.Shared.GameState)
local StatusText = require(ReplicatedStorage.Shared.StatusText)
local Types = require(ReplicatedStorage.Shared.Types)
local Assets = require(script.Parent.Parent.Util.Assets)
local Build = require(script.Parent.Parent.Util.Build)
local CharacterService = require(script.Parent.CharacterService)

local LobbyConfig = GameConfig.Lobby
local REFRESH_INTERVAL = 0.2

type CircleKind = "Runner" | "Trapper"

type CircleInfo = {
	kind: CircleKind,
	center: Vector3,
	radius: number,
	countLabel: TextLabel,
}

export type CircleSnapshot = {
	runnerCircle: { Player },
	trapperCircle: { Player },
}

local LobbyService = {}

local circles: { CircleInfo } = {}
local boardTitle: TextLabel? = nil
local boardDetail: TextLabel? = nil
local spawnCFrame = CFrame.new(LobbyConfig.Origin)
local lobbyBox: Types.Box = { cframe = CFrame.new(LobbyConfig.Origin), size = Vector3.one }
local rng = Random.new()

-- Building ------------------------------------------------------------------

local function addCircleLabel(part: BasePart, kind: CircleKind, color: Color3): TextLabel
	local billboard = Build.billboard(part, 7, Vector2.new(16, 7))
	Build.textLabel(
		"Title",
		billboard,
		if kind == "Runner" then "РАННЕР" else "ТРАПЕР",
		color,
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 0.6)
	)
	return Build.textLabel(
		"Count",
		billboard,
		"Игроков: 0",
		Color3.new(1, 1, 1),
		UDim2.fromScale(0, 0.6),
		UDim2.fromScale(1, 0.4)
	)
end

local function registerCircle(part: BasePart, kind: CircleKind, color: Color3)
	local radius = part:GetAttribute("Radius")
	table.insert(circles, {
		kind = kind,
		center = part.Position,
		radius = if typeof(radius) == "number" then radius else LobbyConfig.CircleRadius,
		countLabel = addCircleLabel(part, kind, color),
	})
end

local function attachBoard(part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "StatusBoard"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	background.BorderSizePixel = 0
	background.Parent = gui

	Build.textLabel(
		"Logo",
		background,
		"ТРАП РАННЕР",
		Color3.fromRGB(255, 196, 40),
		UDim2.fromScale(0.05, 0.05),
		UDim2.fromScale(0.9, 0.3)
	)
	boardTitle = Build.textLabel(
		"Title",
		background,
		"",
		Color3.new(1, 1, 1),
		UDim2.fromScale(0.05, 0.4),
		UDim2.fromScale(0.9, 0.3)
	)
	boardDetail = Build.textLabel(
		"Detail",
		background,
		"",
		Color3.fromRGB(190, 200, 220),
		UDim2.fromScale(0.05, 0.72),
		UDim2.fromScale(0.9, 0.2)
	)
	gui.Parent = part
end

local function buildPlaceholderLobby(): Model
	local origin = LobbyConfig.Origin
	local size = LobbyConfig.FloorSize
	local height = LobbyConfig.WallHeight
	local model = Build.model("Lobby")

	Build.part({
		name = "Floor",
		size = Vector3.new(size, 2, size),
		cframe = CFrame.new(origin + Vector3.new(0, -1, 0)),
		color = LobbyConfig.FloorColor,
		material = Enum.Material.Slate,
		parent = model,
	})
	for _, side in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local alongX = side.Z ~= 0
		Build.part({
			name = "Wall",
			size = if alongX then Vector3.new(size + 4, height, 2) else Vector3.new(2, height, size + 4),
			cframe = CFrame.new(origin + side * (size / 2 + 1) + Vector3.new(0, height / 2, 0)),
			color = LobbyConfig.WallColor,
			parent = model,
		})
	end

	local spawnPosition = origin + LobbyConfig.SpawnOffset + Vector3.new(0, 0.5, 0)
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "SpawnLocation"
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.CFrame = CFrame.lookAt(spawnPosition, spawnPosition + Vector3.zAxis)
	spawnLocation.Color = Color3.fromRGB(80, 86, 104)
	spawnLocation.Material = Enum.Material.SmoothPlastic
	spawnLocation.Parent = model

	Build.disc(
		"RunnerCircle",
		origin + LobbyConfig.RunnerCircleOffset,
		LobbyConfig.CircleRadius,
		LobbyConfig.RunnerColor,
		model
	)
	Build.disc(
		"TrapperCircle",
		origin + LobbyConfig.TrapperCircleOffset,
		LobbyConfig.CircleRadius,
		LobbyConfig.TrapperColor,
		model
	)

	Build.part({
		name = "Board",
		size = Vector3.new(44, 22, 1),
		cframe = CFrame.new(origin + LobbyConfig.BoardOffset),
		color = Color3.fromRGB(18, 20, 28),
		parent = model,
	})
	return model
end

-- Uses ReplicatedStorage.Assets.Lobby when it has the required parts, otherwise builds a placeholder.
local function createLobby(): Model
	local asset = Assets.cloneModel("Lobby")
	if asset then
		if Assets.findPart(asset, "RunnerCircle") and Assets.findPart(asset, "TrapperCircle") then
			return asset
		end
		warn("[Lobby] Assets.Lobby needs parts named RunnerCircle and TrapperCircle; using the placeholder")
		asset:Destroy()
	end
	return buildPlaceholderLobby()
end

-- Spawn points outside the lobby would put respawning runners in the wrong place (e.g. the
-- default Baseplate template's SpawnLocation), so they are switched off for this session.
local function disableForeignSpawns(lobby: Model)
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") and not descendant:IsDescendantOf(lobby) and descendant.Enabled then
			descendant.Enabled = false
			warn(`[Lobby] Disabled SpawnLocation {descendant:GetFullName()}; players spawn in the lobby`)
		end
	end
end

local function setupLobby()
	local lobby = createLobby()
	lobby.Parent = workspace
	disableForeignSpawns(lobby)

	local runnerPart = Assets.findPart(lobby, "RunnerCircle") :: BasePart
	local trapperPart = Assets.findPart(lobby, "TrapperCircle") :: BasePart
	registerCircle(runnerPart, "Runner", LobbyConfig.RunnerColor)
	registerCircle(trapperPart, "Trapper", LobbyConfig.TrapperColor)

	local board = Assets.findPart(lobby, "Board")
	if board then
		attachBoard(board)
	end

	local spawnLocation = lobby:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation then
		spawnCFrame = spawnLocation.CFrame
	end

	local boxCFrame, boxSize = lobby:GetBoundingBox()
	lobbyBox = { cframe = boxCFrame, size = boxSize + Vector3.new(4, 20, 4) }
end

-- Circles -------------------------------------------------------------------

local function circleAt(position: Vector3): Types.Circle
	for _, circle in circles do
		local offset = position - circle.center
		-- Measured up from the circle, so jumping inside a circle keeps you in it.
		if
			offset.Y >= -2
			and offset.Y <= LobbyConfig.CircleMaxHeight
			and Vector2.new(offset.X, offset.Z).Magnitude <= circle.radius
		then
			return circle.kind
		end
	end
	return "None"
end

local function setText(label: TextLabel?, text: string)
	if label and label.Text ~= text then
		label.Text = text
	end
end

-- Recomputes who stands where and refreshes every lobby display.
local function refresh()
	local counts: { [Types.Circle]: number } = { None = 0, Runner = 0, Trapper = 0 }
	for _, player in Players:GetPlayers() do
		local circle: Types.Circle = "None"
		local root = CharacterService.getRoot(player)
		if root and CharacterService.isAlive(player) then
			circle = circleAt(root.Position)
		end
		if GameState.getCircle(player) ~= circle then
			player:SetAttribute(GameState.PlayerKeys.Circle, circle)
		end
		counts[circle] += 1
	end

	GameState.write(GameState.Keys.RunnerCircle, counts.Runner)
	GameState.write(GameState.Keys.TrapperCircle, counts.Trapper)

	for _, circle in circles do
		local count = counts[circle.kind]
		setText(circle.countLabel, `Игроков: {count}`)
	end

	local title, detail = StatusText.describe(GameState.snapshot(), workspace:GetServerTimeNow())
	setText(boardTitle, title)
	setText(boardDetail, detail)
end

function LobbyService.countInCircles(): number
	return (GameState.read(GameState.Keys.RunnerCircle) :: number)
		+ GameState.read(GameState.Keys.TrapperCircle) :: number
end

-- Fresh list of the players standing in each circle right now.
function LobbyService.snapshotCircles(): CircleSnapshot
	refresh()
	local snapshot: CircleSnapshot = { runnerCircle = {}, trapperCircle = {} }
	for _, player in Players:GetPlayers() do
		local circle = GameState.getCircle(player)
		if circle == "Runner" then
			table.insert(snapshot.runnerCircle, player)
		elseif circle == "Trapper" then
			table.insert(snapshot.trapperCircle, player)
		end
	end
	return snapshot
end

-- Picks the trapper: random among the TRAPPER circle, or among everyone when that circle is
-- empty. Last round's trapper is skipped when someone else is eligible.
function LobbyService.pickTrapper(
	runnerCircle: { Player },
	trapperCircle: { Player },
	lastTrapperUserId: number?
): Player?
	local pool: { Player } = {}
	if #trapperCircle > 0 then
		pool = table.clone(trapperCircle)
	else
		table.move(runnerCircle, 1, #runnerCircle, 1, pool)
	end

	if lastTrapperUserId and #pool > 1 then
		local others: { Player } = {}
		for _, player in pool do
			if player.UserId ~= lastTrapperUserId then
				table.insert(others, player)
			end
		end
		if #others > 0 then
			pool = others
		end
	end

	if #pool == 0 then
		return nil
	end
	return pool[rng:NextInteger(1, #pool)]
end

-- Phases: Waiting (not enough players in circles) and Intermission (grace timer). Returns
-- once the intermission ends with enough players still standing in circles. Yields.
function LobbyService.waitForPlayers()
	while true do
		GameState.setPhase("Waiting")
		while LobbyService.countInCircles() < GameConfig.MinPlayers do
			task.wait(REFRESH_INTERVAL)
		end

		local duration = GameConfig.IntermissionSeconds
		if duration <= 0 then
			return
		end
		GameState.setPhase("Intermission", duration)
		local deadline = os.clock() + duration
		local enough = true
		while os.clock() < deadline do
			task.wait(REFRESH_INTERVAL)
			if LobbyService.countInCircles() < GameConfig.MinPlayers then
				enough = false
				break
			end
		end
		if enough then
			return
		end
	end
end

-- A spot near the lobby spawn for players coming back from the track.
function LobbyService.returnCFrame(): CFrame
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(0, LobbyConfig.ReturnSpread)
	local offset = Vector3.new(math.cos(angle) * distance, 4, math.sin(angle) * distance)
	return CFrame.new(spawnCFrame.Position + offset) * spawnCFrame.Rotation
end

function LobbyService.isInLobby(position: Vector3): boolean
	local relative = lobbyBox.cframe:PointToObjectSpace(position)
	local half = lobbyBox.size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

function LobbyService.init()
	setupLobby()
	-- Characters that spawned before the lobby existed (e.g. solo Play in an empty place) start in the void.
	for _, player in Players:GetPlayers() do
		local root = CharacterService.getRoot(player)
		if root and not LobbyService.isInLobby(root.Position) then
			task.spawn(CharacterService.teleport, player, LobbyService.returnCFrame())
		end
	end
	task.spawn(function()
		while true do
			local ok, err = pcall(refresh)
			if not ok then
				warn(`[Lobby] refresh failed: {err}`)
			end
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

return LobbyService
