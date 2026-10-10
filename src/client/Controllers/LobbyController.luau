--!strict
-- Lobby hint for players without a role: which circle they stand in, or how to join. Also spins
-- and bobs the floating lobby decorations (tag "LobbySpin") on this client only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
		return if roundRunning
			then "Круг РАННЕР — побежишь в следующем раунде"
			else "Ты в круге РАННЕР",
			UI.Colors.Runner
	elseif circle == "Trapper" then
		return if roundRunning
			then "Круг ТРАПЕР — можешь стать трапером в следующем раунде"
			else "Ты в круге ТРАПЕР",
			UI.Colors.Trapper
	end
	if roundRunning then
		return "Идёт раунд — встань в круг, чтобы сыграть в следующем",
			UI.Colors.Muted
	end
	return "Встань в круг, чтобы играть", UI.Colors.Muted
end

local spinning: { [BasePart]: CFrame } = {}

local function addSpinner(instance: Instance)
	if instance:IsA("BasePart") then
		spinning[instance] = instance.CFrame
	end
end

local function spin()
	local t = os.clock()
	for part, home in spinning do
		if not part.Parent then
			spinning[part] = nil
			continue
		end
		local speed = (part:GetAttribute("Spin") or 1) :: number
		part.CFrame = home
			* CFrame.new(0, math.sin(t * speed * 1.5) * 1.2, 0)
			* CFrame.Angles(0, t * speed, t * speed * 0.5)
	end
end

function LobbyController.start()
	for _, instance in CollectionService:GetTagged("LobbySpin") do
		addSpinner(instance)
	end
	CollectionService:GetInstanceAddedSignal("LobbySpin"):Connect(addSpinner)
	RunService.RenderStepped:Connect(spin)

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
