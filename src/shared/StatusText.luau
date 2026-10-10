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
		return "Встань в круг, чтобы играть",
			string.format("Игроков в кругах: %d / %d", inCircles, GameConfig.MinPlayers)
	elseif phase == "Intermission" then
		return string.format("Следующий раунд через %d", StatusText.secondsLeft(state, now)),
			"Встань в круг РАННЕР или ТРАПЕР"
	elseif phase == "Countdown" then
		local detail = string.format("Трапер: %s", state.trapperName)
		if state.themeName ~= "" then
			detail ..= "  |  " .. state.themeName
		end
		return string.format("Раунд начнётся через %d", StatusText.secondsLeft(state, now)), detail
	elseif phase == "Round" then
		local detail = string.format(
			"Живых раннеров: %d / %d   Лидер: %d%%",
			state.aliveRunners,
			state.totalRunners,
			math.floor(state.leaderProgress * 100 + 0.5)
		)
		if state.roundStartedAt <= 0 or now < state.roundStartedAt then
			return "Приготовься...", detail
		end
		return string.format("Идёт раунд  %s", StatusText.formatClock(now - state.roundStartedAt)), detail
	else
		return "Раунд окончен", "Скоро следующий раунд"
	end
end

return StatusText
