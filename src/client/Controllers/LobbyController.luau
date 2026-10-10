--!strict
-- Lobby hint for players without a role: which circle they stand in, or how to join.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage.Shared.GameState)
local UI = require(script.Parent.Parent.Util.UI)

local REFRESH_INTERVAL = 0.2

local player = Players.LocalPlayer

local LobbyController = {}

local function hint(): (string, Color3)
	if GameState.getRole(player) ~= "None" then
		return "", UI.Colors.Text
	end
	local phase = GameState.phase()
	local circle = GameState.getCircle(player)
	local roundRunning = phase == "Countdown" or phase == "Round" or phase == "Results"

	if circle == "Runner" then
		return if roundRunning then "RUNNER circle - you'll run next round" else "You're in the RUNNER circle",
			UI.Colors.Runner
	elseif circle == "Trapper" then
		return if roundRunning then "TRAPPER circle - you may trap next round" else "You're in the TRAPPER circle",
			UI.Colors.Trapper
	end
	if roundRunning then
		return "Round in progress - stand in a circle to join the next one", UI.Colors.Muted
	end
	return "Stand in a circle to play", UI.Colors.Muted
end

function LobbyController.start()
	local gui = UI.screen("Lobby", 5)
	local pill = UI.panel("Hint", gui, UDim2.new(0.6, 0, 0, 44), UDim2.new(0.5, 0, 1, -16), Vector2.new(0.5, 1))
	UI.sizeLimit(pill, Vector2.new(260, 36), Vector2.new(560, 56))
	UI.padding(pill, 6)
	local label = UI.label({
		name = "Text",
		parent = pill,
		size = UDim2.fromScale(1, 1),
		maxTextSize = 26,
	})
	gui.Parent = player:WaitForChild("PlayerGui")

	task.spawn(function()
		while true do
			local text, color = hint()
			pill.Visible = text ~= ""
			if label.Text ~= text then
				label.Text = text
			end
			label.TextColor3 = color
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

return LobbyController
