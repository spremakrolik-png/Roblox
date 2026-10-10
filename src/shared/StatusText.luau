--!strict
-- Human-readable status lines built from the replicated game state.
-- Used by the lobby board (server) and the HUD (client) so both always say the same thing.

local GameConfig = require(script.Parent.Config.GameConfig)
local GameState = require(script.Parent.GameState)

local StatusText = {}

function StatusText.formatClock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

function StatusText.formatTime(seconds: number): string
	-- Round to tenths first, so 59.96 s prints as 1:00.0 and not 0:60.0.
	local tenths = math.floor(math.max(0, seconds) * 10 + 0.5)
	local minutes = tenths // 600
	return string.format("%d:%04.1f", minutes, (tenths - minutes * 600) / 10)
end

function StatusText.secondsLeft(state: GameState.Snapshot, now: number): number
	if state.phaseEndsAt <= 0 then
		return 0
	end
	return math.max(0, math.ceil(state.phaseEndsAt - now))
end

-- Returns a headline and a detail line.
function StatusText.describe(state: GameState.Snapshot, now: number): (string, string)
	local phase = state.phase
	local inCircles = state.runnerCircle + state.trapperCircle
	if phase == "Waiting" then
		return "Stand in a circle to play",
			string.format("Players in circles: %d / %d", inCircles, GameConfig.MinPlayers)
	elseif phase == "Intermission" then
		return string.format("Next round in %d", StatusText.secondsLeft(state, now)),
			"Step into RUNNER or TRAPPER to join"
	elseif phase == "Countdown" then
		local detail = string.format("Trapper: %s", state.trapperName)
		if state.themeName ~= "" then
			detail ..= "  |  " .. state.themeName
		end
		return string.format("Round starts in %d", StatusText.secondsLeft(state, now)), detail
	elseif phase == "Round" then
		local detail = string.format(
			"Runners alive: %d / %d   Leader: %d%%",
			state.aliveRunners,
			state.totalRunners,
			math.floor(state.leaderProgress * 100 + 0.5)
		)
		if state.roundStartedAt <= 0 or now < state.roundStartedAt then
			return "Get ready...", detail
		end
		return string.format("Round in progress  %s", StatusText.formatClock(now - state.roundStartedAt)), detail
	else
		return "Round over", "Next round soon"
	end
end

return StatusText
