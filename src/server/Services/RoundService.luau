--!strict
-- The game loop: Waiting/Intermission (LobbyService) -> Countdown -> Round -> Results -> back.
-- The server is the only source of truth for roles, progress, finishes and deaths.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StatusText = require(ReplicatedStorage.Shared.StatusText)
local Types = require(ReplicatedStorage.Shared.Types)
local TrapsConfig = require(ReplicatedStorage.Shared.Config.Traps)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local TrackGenerator = require(script.Parent.Parent.Track.TrackGenerator)
local CharacterService = require(script.Parent.CharacterService)
local LobbyService = require(script.Parent.LobbyService)
local AbilityService = require(script.Parent.AbilityService)
local PointsService = require(script.Parent.PointsService)
local SpectateService = require(script.Parent.SpectateService)
local TrapService = require(script.Parent.TrapService)

local Keys = GameState.Keys
local PlayerKeys = GameState.PlayerKeys

type Roster = {
	trapper: Player,
	runners: { Player },
	-- Circle membership when the countdown started; used to re-pick a trapper who leaves.
	runnerCircle: { Player },
	trapperCircle: { Player },
}

type RunnerState = {
	player: Player,
	userId: number,
	name: string,
	status: Types.RunnerStatus,
	reason: Types.EliminationReason?,
	furthest: number, -- highest segment index reached in order (0 = start area)
	lastAdvanceAt: number, -- os.clock() of the last new segment
	bestDistance: number,
	place: number?,
	finishTime: number?,
	checkpoint: number, -- checkpoints passed in order
	checkpointAt: number, -- os.clock() at the last checkpoint (or when the gates opened)
	checkpointDistance: number, -- track distance of the last checkpoint (0 = start line)
	tooFast: string?, -- set when a stretch was covered faster than physically possible
	cause: string?, -- trap kills: "was crushed by Crushing Walls"
	lastTrap: Types.TrapType?, -- the last trap that hit this runner (for fall credit)
	lastTrapAt: number,
}

type Round = {
	track: Types.Track,
	trapper: Player,
	trapperName: string,
	runners: { RunnerState },
	byPlayer: { [Player]: RunnerState },
	finishers: { RunnerState },
	trapperKills: number,
	startedAt: number, -- os.clock() when the gates opened
	trapperLeft: boolean,
	closed: boolean, -- set when the round has a winner; round handlers ignore events after that
	connections: { RBXScriptConnection },
}

local RoundService = {}

local lastTrapperUserId: number? = nil
local lastTrapperHud = "" -- what the trapper's HUD shows, to send only changes
local TRAPPER_HUD_TRAPS = 5

-- What is currently running, so an unexpected error can still clean up.
local active: { round: Round?, track: Types.Track?, participants: { Player } } = {
	round = nil,
	track = nil,
	participants = {},
}

local ELIMINATION_TEXT: { [Types.EliminationReason]: string } = {
	Died = "%s выбывает",
	Fell = "%s падает в пропасть",
	Trap = "%s попадает в ловушку",
	AFK = "%s выбывает (AFK)",
	Left = "%s выходит из игры",
	Disqualified = "%s: дисквалификация",
}

-- The fastest a runner could legitimately cover `distance` studs: every ability that adds speed
-- (Speed Burst all the way, one Dash), with extra tolerance for lag and the 10 Hz sampling.
local function minStretchTime(distance: number): number
	local rules = GameConfig.AntiCheat
	local topSpeed = GameConfig.RunnerWalkSpeed * rules.SpeedMultiplierAllowance
	return math.max(0, distance - rules.DashAllowance) / topSpeed * rules.TimeTolerance
end

-- Records a checkpoint (or the finish line, when `checkpoint` is nil) and checks the time since the
-- previous one against the physical minimum.
local function passCheckpoint(runner: RunnerState, distance: number, now: number, checkpoint: Types.Checkpoint?)
	local stretch = distance - runner.checkpointDistance
	local elapsed = now - runner.checkpointAt
	local minimum = minStretchTime(stretch)
	if elapsed < minimum and not runner.tooFast then
		runner.tooFast = string.format("%.0f studs in %.2fs (minimum %.2fs)", stretch, elapsed, minimum)
		warn(`[AntiCheat] {runner.name} ({runner.userId}) too fast: {runner.tooFast}`)
	end
	runner.checkpointAt = now
	runner.checkpointDistance = distance
	if checkpoint then
		runner.checkpoint = checkpoint.index
		runner.player:SetAttribute(PlayerKeys.Checkpoint, checkpoint.index)
	end
end

local function feed(text: string, kind: Types.FeedKind)
	local entry: Types.FeedEntry = { text = text, kind = kind }
	Remotes.KillFeed:FireAllClients(entry)
end

local function inGame(player: Player): boolean
	return player.Parent == Players
end

local function setRole(player: Player, role: Types.Role)
	if inGame(player) then
		player:SetAttribute(PlayerKeys.Role, role)
	end
end

local function resetPlayerState(player: Player)
	if not inGame(player) then
		return
	end
	player:SetAttribute(PlayerKeys.Role, "None")
	player:SetAttribute(PlayerKeys.Status, "None")
	player:SetAttribute(PlayerKeys.Progress, 0)
	player:SetAttribute(PlayerKeys.Place, 0)
	player:SetAttribute(PlayerKeys.Checkpoint, 0)
end

local function connect(round: Round, signal: RBXScriptSignal, handler: (...any) -> ())
	table.insert(round.connections, signal:Connect(handler))
end

-- Countdown -------------------------------------------------------------------

local function buildRoster(): Roster?
	local snapshot = LobbyService.snapshotCircles()
	local count = #snapshot.runnerCircle + #snapshot.trapperCircle
	if count < GameConfig.MinPlayers then
		return nil
	end
	local trapper = LobbyService.pickTrapper(snapshot.runnerCircle, snapshot.trapperCircle, lastTrapperUserId)
	if not trapper then
		return nil
	end

	local runners: { Player } = {}
	for _, list in { snapshot.runnerCircle, snapshot.trapperCircle } do
		for _, player in list do
			if player ~= trapper then
				table.insert(runners, player)
			end
		end
	end
	return {
		trapper = trapper,
		runners = runners,
		runnerCircle = snapshot.runnerCircle,
		trapperCircle = snapshot.trapperCircle,
	}
end

local function applyRoles(roster: Roster)
	setRole(roster.trapper, "Trapper")
	for _, runner in roster.runners do
		setRole(runner, "Runner")
	end
	GameState.write(Keys.TrapperName, roster.trapper.DisplayName)
end

local function stillPresent(list: { Player }): { Player }
	local present: { Player } = {}
	for _, player in list do
		if inGame(player) then
			table.insert(present, player)
		end
	end
	return present
end

-- Drops players who left during the countdown and replaces a trapper who left.
-- Returns false when the round can no longer start.
local function pruneRoster(roster: Roster): boolean
	roster.runners = stillPresent(roster.runners)
	if not inGame(roster.trapper) then
		local replacement = LobbyService.pickTrapper(
			stillPresent(roster.runnerCircle),
			stillPresent(roster.trapperCircle),
			lastTrapperUserId
		)
		if not replacement then
			return false
		end
		roster.trapper = replacement
		local index = table.find(roster.runners, replacement)
		if index then
			table.remove(roster.runners, index)
		end
		applyRoles(roster)
		feed(`Трапер вышел. Новый трапер: {replacement.DisplayName}`, "Info")
	end
	return #roster.runners + 1 >= GameConfig.MinPlayers
end

-- Countdown phase: roles are locked and the track is built. Returns nil if it was cancelled.
local function runCountdown(roster: Roster): Types.Track?
	GameState.setPhase("Countdown", GameConfig.CountdownSeconds)
	applyRoles(roster)
	local deadline = os.clock() + GameConfig.CountdownSeconds

	local ok, result = pcall(function()
		return TrackGenerator.generate()
	end)
	if not ok then
		warn(`[Round] Track generation failed: {result}`)
		return nil
	end
	local track = result :: Types.Track
	active.track = track
	GameState.write(Keys.ThemeName, track.theme.name)
	GameState.write(Keys.CheckpointCount, #track.checkpoints)
	local marks: { string } = {}
	for _, checkpoint in track.checkpoints do
		table.insert(marks, string.format("%.4f", checkpoint.distance / track.totalLength))
	end
	GameState.write(Keys.CheckpointMarks, table.concat(marks, ","))
	TrapService.prepare(track)

	while os.clock() < deadline do
		task.wait(0.25)
		if not pruneRoster(roster) then
			feed("Не хватает игроков — раунд отменён", "Info")
			active.track = nil
			TrackGenerator.destroy(track)
			return nil
		end
	end
	return track
end

-- Round -----------------------------------------------------------------------

-- Trap kills pass their own kill-feed line and a short cause for the results screen.
local function eliminate(runner: RunnerState, reason: Types.EliminationReason, feedText: string?, cause: string?)
	if runner.status ~= "Alive" then
		return
	end
	runner.status = "Eliminated"
	runner.reason = reason
	runner.cause = cause
	if inGame(runner.player) then
		runner.player:SetAttribute(PlayerKeys.Status, "Eliminated")
		AbilityService.refresh(runner.player)
	end
	if feedText then
		feed(feedText, "Death")
	else
		feed(string.format(ELIMINATION_TEXT[reason], runner.name), "Death")
	end
end

-- A trap kill: eliminated with the trap as the cause and credited to the trapper.
local function trapKill(round: Round, runner: RunnerState, trapType: Types.TrapType, byFall: boolean)
	if runner.status ~= "Alive" or round.closed then
		return
	end
	local info = TrapsConfig.info(trapType)
	local phrase = if byFall then info.fallPhrase else info.killPhrase
	eliminate(runner, "Trap", `{info.name} {phrase} {runner.name}`, `ловушка «{info.name}»`)
	round.trapperKills += 1
end

local function finish(round: Round, runner: RunnerState)
	runner.status = "Finished"
	table.insert(round.finishers, runner)
	runner.place = #round.finishers
	runner.finishTime = os.clock() - round.startedAt
	runner.bestDistance = round.track.totalLength
	runner.player:SetAttribute(PlayerKeys.Status, "Finished")
	runner.player:SetAttribute(PlayerKeys.Place, runner.place)
	runner.player:SetAttribute(PlayerKeys.Progress, 1)
	AbilityService.refresh(runner.player)
	local root = CharacterService.getRoot(runner.player)
	if root then
		local vip = runner.player:GetAttribute(Monetization.attribute("VIP")) == true
		Remotes.FinishEffect:FireAllClients(root.Position, vip)
	end
	feed(
		string.format(
			"%s финиширует: %d место (%s)",
			runner.name,
			#round.finishers,
			StatusText.formatTime(runner.finishTime or 0)
		),
		"Finish"
	)
end

-- Advances `furthest` only through consecutive segments; a jump further ahead looks like a teleport.
local function updateProgress(round: Round, runner: RunnerState, position: Vector3, now: number)
	local segments = round.track.segments
	local highest = math.min(#segments, runner.furthest + 1 + GameConfig.MaxSegmentSkip)
	local lowest = math.max(1, runner.furthest - 1)
	for index = highest, lowest, -1 do
		local segment = segments[index]
		if TrackGenerator.pointInBox(segment.volume, position) then
			if index > runner.furthest then
				-- Entering segment k+1 passes the checkpoint standing after segment k.
				for _, checkpoint in round.track.checkpoints do
					if checkpoint.afterSegment >= runner.furthest and checkpoint.afterSegment < index then
						passCheckpoint(runner, checkpoint.distance, now, checkpoint)
					end
				end
				runner.furthest = index
				runner.lastAdvanceAt = now
			end
			local distance = segment.startDistance + TrackGenerator.distanceInSegment(segment, position)
			runner.bestDistance = math.max(runner.bestDistance, distance)
			return
		end
	end
end

local function trackRunner(round: Round, runner: RunnerState, now: number)
	local root = CharacterService.getRoot(runner.player)
	if not root then
		return
	end
	local position = root.Position

	if position.Y < TrackGenerator.killYFor(round.track, runner.furthest) then
		if runner.lastTrap and now - runner.lastTrapAt <= TrapsConfig.FallCreditSeconds then
			trapKill(round, runner, runner.lastTrap, true)
		else
			eliminate(runner, "Fell")
		end
		CharacterService.kill(runner.player)
		return
	end

	updateProgress(round, runner, position, now)

	if runner.furthest == #round.track.segments and TrackGenerator.pointInBox(round.track.finishZone, position) then
		-- The finish counts only after every checkpoint, in order, at a humanly possible pace.
		passCheckpoint(runner, round.track.totalLength, now, nil)
		if runner.tooFast or runner.checkpoint < #round.track.checkpoints then
			warn(`[AntiCheat] {runner.name} disqualified at the finish: {runner.tooFast or "missed a checkpoint"}`)
			eliminate(runner, "Disqualified")
			task.spawn(CharacterService.teleport, runner.player, LobbyService.returnCFrame())
		else
			finish(round, runner)
		end
		return
	end

	if now - runner.lastAdvanceAt >= GameConfig.AfkTimeoutSeconds then
		eliminate(runner, "AFK")
		task.spawn(CharacterService.teleport, runner.player, LobbyService.returnCFrame())
	end
end

local function publishProgress(round: Round)
	local alive = 0
	local leader = 0
	for _, runner in round.runners do
		if runner.status == "Alive" then
			alive += 1
		end
		local progress = math.clamp(runner.bestDistance / round.track.totalLength, 0, 1)
		if runner.status ~= "Eliminated" then
			leader = math.max(leader, progress)
		end
		if inGame(runner.player) and runner.player:GetAttribute(PlayerKeys.Progress) ~= progress then
			runner.player:SetAttribute(PlayerKeys.Progress, progress)
		end
	end
	GameState.write(Keys.AliveRunners, alive)
	GameState.write(Keys.LeaderProgress, leader)

	-- The trapper gets a dot on the progress bar and their own HUD: traps ahead and the leader gap.
	local trapper = round.trapper
	local root = if inGame(trapper) and not round.trapperLeft then CharacterService.getRoot(trapper) else nil
	if not root then
		return
	end
	local distance, trapperSegment = TrackGenerator.distanceAlong(round.track, root.Position)
	local trapperProgress = math.clamp(distance / round.track.totalLength, 0, 1)
	if math.abs(((trapper:GetAttribute(PlayerKeys.Progress) or 0) :: number) - trapperProgress) > 0.002 then
		trapper:SetAttribute(PlayerKeys.Progress, trapperProgress)
	end
	local leaderSegment = 0
	for _, runner in round.runners do
		if runner.status == "Alive" then
			leaderSegment = math.max(leaderSegment, runner.furthest)
		end
	end
	local traps: { Types.TrapperHudTrap } = {}
	for _, entry in TrapService.states() do
		local away = entry.trap.segmentIndex - trapperSegment
		if away >= 0 and #traps < TRAPPER_HUD_TRAPS then
			table.insert(traps, {
				name = TrapsConfig.info(entry.trap.trapType).name,
				segmentsAway = away,
				state = entry.state,
			})
		end
	end
	local hud: Types.TrapperHud = {
		trapperSegment = trapperSegment,
		leaderSegment = leaderSegment,
		totalSegments = #round.track.segments,
		traps = traps,
	}
	local key = `{trapperSegment}|{leaderSegment}`
	for _, trap in traps do
		key ..= `|{trap.name}{trap.segmentsAway}{trap.state}`
	end
	if key ~= lastTrapperHud then
		lastTrapperHud = key
		Remotes.TrapperHud:FireClient(trapper, hud)
	end
end

-- Returns the winner once the round is over, nil while it continues.
local function checkOutcome(round: Round): Types.Winner?
	if round.trapperLeft then
		return "Runners"
	end
	local anyStayed = false
	for _, runner in round.runners do
		if runner.status == "Alive" then
			return nil
		end
		if runner.reason ~= "Left" then
			anyStayed = true
		end
	end
	if #round.finishers > 0 then
		return "Runners"
	end
	return if anyStayed then "Trapper" else "NoContest"
end

local function newRunnerState(player: Player): RunnerState
	return {
		player = player,
		userId = player.UserId,
		name = player.DisplayName,
		status = "Alive",
		reason = nil,
		furthest = 0,
		lastAdvanceAt = os.clock(),
		bestDistance = 0,
		checkpoint = 0,
		checkpointAt = os.clock(),
		checkpointDistance = 0,
		tooFast = nil,
		cause = nil,
		lastTrap = nil,
		lastTrapAt = 0,
		place = nil,
		finishTime = nil,
	}
end

local function watchRunner(round: Round, runner: RunnerState)
	local player = runner.player
	local humanoid = CharacterService.getHumanoid(player)
	if humanoid then
		connect(round, humanoid.Died, function()
			if not round.closed then
				eliminate(runner, "Died")
			end
		end)
	end
	-- Covers characters removed without a Died event. When the player is leaving the server this
	-- can fire before PlayerRemoving, so wait a moment and let "Left" win in that case.
	connect(round, player.CharacterRemoving, function()
		task.delay(0.5, function()
			if not round.closed then
				eliminate(runner, if inGame(player) then "Died" else "Left")
			end
		end)
	end)
end

local function watchTrapper(round: Round)
	-- The corridor is safe, but a trapper who resets is put back at the corridor start.
	connect(round, round.trapper.CharacterAdded, function(character: Model)
		task.defer(function()
			character:WaitForChild("HumanoidRootPart", 10)
			if round.closed or round.trapperLeft or not character.Parent then
				return
			end
			CharacterService.setWalkSpeed(round.trapper, GameConfig.TrapperWalkSpeed)
			CharacterService.teleport(round.trapper, round.track.trapperSpawn)
		end)
	end)
end

local function startRound(track: Types.Track, roster: Roster): Round
	local round: Round = {
		track = track,
		trapper = roster.trapper,
		trapperName = roster.trapper.DisplayName,
		runners = {},
		byPlayer = {},
		finishers = {},
		trapperKills = 0,
		startedAt = os.clock(),
		trapperLeft = false,
		closed = false,
		connections = {},
	}
	active.round = round

	-- RoundStartedAt = 0 means "players are being moved"; the HUD shows "Get ready".
	GameState.write(Keys.RoundStartedAt, 0)
	GameState.setPhase("Round")

	for _, player in roster.runners do
		local runner = newRunnerState(player)
		table.insert(round.runners, runner)
		round.byPlayer[player] = runner
		player:SetAttribute(PlayerKeys.Status, "Alive")
		player:SetAttribute(PlayerKeys.Progress, 0)
	end
	GameState.write(Keys.TotalRunners, #round.runners)

	-- Connected before anything yields, so nobody can leave unnoticed.
	connect(round, Players.PlayerRemoving, function(player: Player)
		if round.closed then
			return
		end
		local runner = round.byPlayer[player]
		if runner then
			eliminate(runner, "Left")
		elseif player == round.trapper and not round.trapperLeft then
			round.trapperLeft = true
			feed(`Трапер {round.trapperName} вышел из игры`, "Info")
		end
	end)

	local targets: { CharacterService.TeleportTarget } = {}
	local spawns = track.runnerSpawns
	for index, runner in round.runners do
		if CharacterService.ensureCharacter(runner.player) then
			table.insert(targets, { player = runner.player, cframe = spawns[(index - 1) % #spawns + 1] })
		end
	end
	if CharacterService.ensureCharacter(roster.trapper) then
		table.insert(targets, { player = roster.trapper, cframe = track.trapperSpawn })
	end
	CharacterService.teleportAll(targets)

	-- Frozen at the start until the gates open; this also gives streaming time to load the track.
	for _, target in targets do
		CharacterService.setAnchored(target.player, true)
	end
	for _, runner in round.runners do
		CharacterService.setWalkSpeed(runner.player, GameConfig.RunnerWalkSpeed)
		if CharacterService.isAlive(runner.player) then
			watchRunner(round, runner)
		elseif inGame(runner.player) then
			eliminate(runner, "Died")
		end
	end
	if not inGame(round.trapper) then
		round.trapperLeft = true
	end
	CharacterService.setWalkSpeed(round.trapper, GameConfig.TrapperWalkSpeed)
	watchTrapper(round)
	publishProgress(round)

	GameState.write(Keys.RoundStartedAt, workspace:GetServerTimeNow() + GameConfig.StartGateSeconds)
	task.wait(GameConfig.StartGateSeconds)
	TrackGenerator.openGates(track)
	for _, target in targets do
		CharacterService.setAnchored(target.player, false)
	end

	round.startedAt = os.clock()
	for _, runner in round.runners do
		runner.lastAdvanceAt = round.startedAt
		runner.checkpointAt = round.startedAt
		if runner.status == "Alive" and inGame(runner.player) then
			Remotes.RoleBanner:FireClient(runner.player, "Runner")
		end
	end
	if inGame(round.trapper) then
		Remotes.RoleBanner:FireClient(round.trapper, "Trapper")
	end

	TrapService.start({
		trapper = round.trapper,
		aliveRunners = function(): { Player }
			local alive: { Player } = {}
			for _, runner in round.runners do
				if runner.status == "Alive" and inGame(runner.player) then
					table.insert(alive, runner.player)
				end
			end
			return alive
		end,
		onTrapKill = function(player: Player, trapType: Types.TrapType)
			local runner = round.byPlayer[player]
			if runner and runner.status == "Alive" and not round.closed then
				if AbilityService.absorbTrapHit(player) then
					return -- Shield
				end
				trapKill(round, runner, trapType, false)
				CharacterService.kill(player)
			end
		end,
		onTrapHit = function(player: Player, trapType: Types.TrapType)
			local runner = round.byPlayer[player]
			if runner then
				runner.lastTrap = trapType
				runner.lastTrapAt = os.clock()
			end
		end,
	})

	local runnerPlayers: { Player } = {}
	for _, runner in round.runners do
		table.insert(runnerPlayers, runner.player)
	end
	AbilityService.startRound({
		track = track,
		trapper = round.trapper,
		runners = runnerPlayers,
		aliveRunners = function(): { Player }
			local alive: { Player } = {}
			for _, runner in round.runners do
				if runner.status == "Alive" and inGame(runner.player) then
					table.insert(alive, runner.player)
				end
			end
			return alive
		end,
	})
	return round
end

-- Runs the round until it has a winner. Yields.
local function runRound(round: Round): Types.Winner
	local interval = 1 / GameConfig.TrackingRate
	while true do
		local winner = checkOutcome(round)
		if winner then
			return winner
		end

		local now = os.clock()
		if now - round.startedAt >= GameConfig.RoundHardLimitSeconds then
			warn(
				`[Round] Technical limit of {GameConfig.RoundHardLimitSeconds}s reached (seed {round.track.seed}); closing the round without rewards`
			)
			return "Aborted"
		end

		for _, runner in round.runners do
			if runner.status == "Alive" and inGame(runner.player) then
				trackRunner(round, runner, now)
			end
		end
		publishProgress(round)
		task.wait(interval)
	end
end

-- Stops every round handler, so nothing changes once the results are built.
local function closeRound(round: Round)
	round.closed = true
	TrapService.stop()
	AbilityService.stopRound()
	for _, connection in round.connections do
		connection:Disconnect()
	end
	table.clear(round.connections)
end

-- Results -----------------------------------------------------------------------

local function payOut(round: Round, winner: Types.Winner): { Types.PointsAward }
	local finishers: { Player } = {}
	for _, runner in round.finishers do
		table.insert(finishers, runner.player)
	end
	local runners: { PointsService.RunnerOutcome } = {}
	for _, runner in round.runners do
		table.insert(runners, {
			player = runner.player,
			finished = runner.status == "Finished",
			progress = math.clamp(runner.bestDistance / round.track.totalLength, 0, 1),
		})
	end
	return PointsService.awardRound({
		winner = winner,
		trapper = round.trapper,
		trapperKills = round.trapperKills,
		finishers = finishers,
		runners = runners,
	})
end

local function buildResults(round: Round, winner: Types.Winner): Types.RoundResults
	local results: Types.RoundResults = {
		winner = winner,
		trapperName = round.trapperName,
		trapperKills = round.trapperKills,
		finishers = {},
		eliminated = {},
		survivors = {},
		duration = os.clock() - round.startedAt,
		awards = {},
	}
	for _, runner in round.finishers do
		table.insert(results.finishers, {
			userId = runner.userId,
			name = runner.name,
			place = runner.place or 0,
			time = runner.finishTime or 0,
		})
	end
	for _, runner in round.runners do
		if runner.status == "Eliminated" then
			local reason: Types.EliminationReason = runner.reason or "Died"
			table.insert(results.eliminated, {
				userId = runner.userId,
				name = runner.name,
				reason = reason,
				cause = runner.cause,
			})
		elseif runner.status == "Alive" then
			table.insert(results.survivors, runner.name)
		end
	end
	return results
end

local function announce(results: Types.RoundResults)
	local winner = results.winner
	if winner == "Runners" then
		feed("Победа раннеров!", "Info")
	elseif winner == "Trapper" then
		feed(`Победа трапера {results.trapperName}!`, "Info")
	elseif winner == "NoContest" then
		feed("Ничья: все раннеры вышли", "Info")
	else
		feed("Раунд прерван", "Info")
	end
	print(
		`[Round] Over: winner={winner} finishers={#results.finishers} eliminated={#results.eliminated} duration={math.floor(
			results.duration
		)}s`
	)
end

-- Sends everyone who is still on the track back to the lobby and clears round state.
local function cleanup(round: Round?, track: Types.Track?, participants: { Player })
	if round then
		for _, connection in round.connections do
			connection:Disconnect()
		end
		table.clear(round.connections)
	end

	local targets: { CharacterService.TeleportTarget } = {}
	for _, player in participants do
		if inGame(player) then
			CharacterService.setAnchored(player, false)
			CharacterService.setWalkSpeed(player, nil)
			local root = CharacterService.getRoot(player)
			if root and not LobbyService.isInLobby(root.Position) then
				table.insert(targets, { player = player, cframe = LobbyService.returnCFrame() })
			end
		end
		resetPlayerState(player)
	end
	CharacterService.teleportAll(targets)

	TrapService.clear()
	AbilityService.reset()
	lastTrapperHud = ""
	SpectateService.reset()
	if track then
		TrackGenerator.destroy(track)
	end
	GameState.write(Keys.TrapperName, "")
	GameState.write(Keys.ThemeName, "")
	GameState.write(Keys.CheckpointCount, 0)
	GameState.write(Keys.CheckpointMarks, "")
	GameState.write(Keys.AliveRunners, 0)
	GameState.write(Keys.TotalRunners, 0)
	GameState.write(Keys.LeaderProgress, 0)
	GameState.write(Keys.RoundStartedAt, 0)
end

-- Main loop -----------------------------------------------------------------------

local function playOnce()
	LobbyService.waitForPlayers()

	local roster = buildRoster()
	if not roster then
		return
	end
	-- Everyone who may get a role this round; cleanup resets all of them.
	active.participants = table.clone(roster.runners)
	table.insert(active.participants, roster.trapper)

	local track = runCountdown(roster)
	if not track then
		return
	end
	lastTrapperUserId = roster.trapper.UserId

	local round = startRound(track, roster)
	local winner = runRound(round)
	closeRound(round)

	local results = buildResults(round, winner)
	results.awards = payOut(round, winner)
	announce(results)
	GameState.setPhase("Results", GameConfig.ResultsSeconds)
	Remotes.RoundResults:FireAllClients(results)
	task.wait(GameConfig.ResultsSeconds)
end

local function cleanupActive()
	cleanup(active.round, active.track, active.participants)
	active.round = nil
	active.track = nil
	active.participants = {}
end

function RoundService.start()
	task.spawn(function()
		while true do
			local ok, err = pcall(playOnce)
			if not ok then
				warn(`[Round] Game loop error: {err}`)
			end
			local cleaned, cleanupErr = pcall(cleanupActive)
			if not cleaned then
				warn(`[Round] Cleanup error: {cleanupErr}`)
			end
			if not ok or not cleaned then
				task.wait(1)
			end
		end
	end)
end

return RoundService
