--!strict
-- Points and stats at the end of a round (Config/Points). Aborted rounds pay nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PointsConfig = require(ReplicatedStorage.Shared.Config.Points)
local Types = require(ReplicatedStorage.Shared.Types)
local PlayerDataService = require(script.Parent.PlayerDataService)

export type RunnerOutcome = {
	player: Player,
	finished: boolean,
	progress: number, -- 0..1
}

export type RoundOutcome = {
	winner: Types.Winner,
	trapper: Player,
	trapperKills: number,
	finishers: { Player }, -- in finish order
	runners: { RunnerOutcome },
}

local PointsService = {}

-- Points multiplier (the x2 Points game pass in Phase 5). Plugged in by MonetizationService.
local multiplierFor: (player: Player) -> number = function(_player: Player)
	return 1
end

function PointsService.setMultiplierProvider(provider: (player: Player) -> number)
	multiplierFor = provider
end

-- Pays out the round and returns what everyone earned (for the results screen).
function PointsService.awardRound(outcome: RoundOutcome): { Types.PointsAward }
	local awards: { Types.PointsAward } = {}
	if outcome.winner == "Aborted" then
		return awards
	end

	local earned: { [Player]: number } = {}
	for place, player in outcome.finishers do
		earned[player] = PointsConfig.RunnerPlaces[place] or PointsConfig.RunnerFinish
	end
	local trapperPoints = outcome.trapperKills * PointsConfig.TrapperPerKill
	if outcome.winner == "Trapper" then
		trapperPoints += PointsConfig.TrapperWin
	end
	earned[outcome.trapper] = trapperPoints

	local function pay(player: Player, base: number)
		if player.Parent ~= Players then
			return
		end
		local total = math.floor(base * multiplierFor(player))
		PlayerDataService.addPoints(player, total)
		if total > 0 then
			table.insert(awards, { userId = player.UserId, name = player.DisplayName, points = total })
		end
	end

	for _, runner in outcome.runners do
		pay(runner.player, earned[runner.player] or 0)
		PlayerDataService.updateStats(runner.player, function(stats)
			stats.Rounds += 1
			stats.BestDistance = math.max(stats.BestDistance, runner.progress)
			if runner.finished then
				stats.Finishes += 1
				if outcome.winner == "Runners" then
					stats.Wins += 1
				end
			end
		end)
	end
	pay(outcome.trapper, trapperPoints)
	PlayerDataService.updateStats(outcome.trapper, function(stats)
		stats.Rounds += 1
		stats.Kills += outcome.trapperKills
		if outcome.winner == "Trapper" then
			stats.TrapperWins += 1
		end
	end)

	table.sort(awards, function(a: Types.PointsAward, b: Types.PointsAward)
		return a.points > b.points
	end)
	return awards
end

return PointsService
