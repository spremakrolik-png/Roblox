--!strict
-- The track progress bar (a dot for every runner and the trapper, checkpoint ticks, the finish) and
-- the trapper's panel: the next traps with their state and a warning when the leading runner is
-- 2+ segments ahead. Reads replicated state and the TrapperHud remote; decides nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local UI = require(script.Parent.Parent.Util.UI)

local REFRESH_INTERVAL = 0.1
local DOT_SIZE = 14
local OWN_DOT_SIZE = 20
local LEADER_WARNING_GAP = 2 -- segments
local ELIMINATED_COLOR = Color3.fromRGB(110, 115, 128)
local STATE_TEXT = { Ready = "готова", Running = "работает", Used = "использована" }
local STATE_COLOR = {
	Ready = Color3.fromRGB(90, 220, 120),
	Running = UI.Colors.Gold,
	Used = Color3.fromRGB(130, 135, 150),
}

local player = Players.LocalPlayer

local ProgressController = {}

local bar: Frame
local fill: Frame
local marks: Frame
local dots: { [Player]: Frame } = {}
local lastMarks = ""

local trapperPanel: Frame
local leaderWarning: TextLabel
local trapList: Frame
local hud: Types.TrapperHud? = nil

-- Progress bar ----------------------------------------------------------------------

local function circle(parent: Instance, size: number, color: Color3): Frame
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(size, size)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	dot.Parent = parent
	return dot
end

local function buildBar(gui: ScreenGui)
	bar = Instance.new("Frame")
	bar.Name = "TrackProgress"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 124)
	bar.Size = UDim2.new(0.5, 0, 0, 10)
	bar.BackgroundColor3 = UI.Colors.Panel
	bar.BackgroundTransparency = 0.2
	bar.BorderSizePixel = 0
	bar.Visible = false
	UI.sizeLimit(bar, Vector2.new(220, 10), Vector2.new(560, 10))
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = bar

	fill = Instance.new("Frame")
	fill.Name = "Leader"
	fill.BackgroundColor3 = UI.Colors.Runner
	fill.BackgroundTransparency = 0.6
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	UI.gradient(fill, Color3.fromRGB(120, 220, 255), Color3.fromRGB(150, 110, 255), 0)
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	fill.Parent = bar

	marks = Instance.new("Frame")
	marks.Name = "Checkpoints"
	marks.BackgroundTransparency = 1
	marks.Size = UDim2.fromScale(1, 1)
	marks.Parent = bar

	local finish = UI.label({
		name = "Finish",
		parent = bar,
		text = "ФИНИШ",
		size = UDim2.fromOffset(60, 18),
		position = UDim2.new(1, 6, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
		color = UI.Colors.Gold,
		alignX = Enum.TextXAlignment.Left,
		maxTextSize = 16,
	})
	finish.ZIndex = 2
	bar.Parent = gui
end

local function refreshMarks()
	local text = GameState.read(GameState.Keys.CheckpointMarks) :: string
	if text == lastMarks then
		return
	end
	lastMarks = text
	for _, child in marks:GetChildren() do
		child:Destroy()
	end
	for value in string.gmatch(text, "[^,]+") do
		local fraction = tonumber(value)
		if fraction then
			local tick = Instance.new("Frame")
			tick.Name = "Checkpoint"
			tick.AnchorPoint = Vector2.new(0.5, 0.5)
			tick.Position = UDim2.fromScale(fraction, 0.5)
			tick.Size = UDim2.new(0, 3, 1, 8)
			tick.BackgroundColor3 = Color3.new(1, 1, 1)
			tick.BackgroundTransparency = 0.3
			tick.BorderSizePixel = 0
			tick.Parent = marks
		end
	end
end

local function dotFor(other: Player): Frame
	local existing = dots[other]
	if existing then
		return existing
	end
	local own = other == player
	local dot = circle(bar, if own then OWN_DOT_SIZE else DOT_SIZE, UI.Colors.Runner)
	dot.Name = other.Name
	dot.ZIndex = if own then 4 else 3
	if own then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 2
		stroke.Parent = dot
	end
	dots[other] = dot
	return dot
end

local function refreshBar()
	local phase = GameState.phase()
	local started = (GameState.read(GameState.Keys.RoundStartedAt) :: number) > 0
	bar.Visible = phase == "Round" and started
	if not bar.Visible then
		for other, dot in dots do
			dot:Destroy()
			dots[other] = nil
		end
		return
	end
	refreshMarks()
	fill.Size = UDim2.fromScale(math.clamp(GameState.read(GameState.Keys.LeaderProgress) :: number, 0, 1), 1)

	local seen: { [Player]: boolean } = {}
	for _, other in Players:GetPlayers() do
		local role = GameState.getRole(other)
		if role == "Runner" or role == "Trapper" then
			seen[other] = true
			local dot = dotFor(other)
			local progress = other:GetAttribute(GameState.PlayerKeys.Progress)
			local value = if typeof(progress) == "number" then math.clamp(progress, 0, 1) else 0
			-- The trapper rides just under the line so runner dots stay readable.
			dot.Position = UDim2.new(value, 0, if role == "Trapper" then 1 else 0.5, if role == "Trapper" then 6 else 0)
			local color: Color3
			if role == "Trapper" then
				color = UI.Colors.Trapper
			else
				local status = GameState.getStatus(other)
				color = if status == "Finished"
					then UI.Colors.Gold
					elseif status == "Eliminated" then ELIMINATED_COLOR
					else UI.Colors.Runner
			end
			dot.BackgroundColor3 = color
		end
	end
	for other, dot in dots do
		if not seen[other] then
			dot:Destroy()
			dots[other] = nil
		end
	end
end

-- Trapper panel -----------------------------------------------------------------------

local function buildTrapperPanel(gui: ScreenGui)
	trapperPanel = UI.panel("TrapperPanel", gui, UDim2.fromOffset(230, 210), UDim2.fromOffset(10, 150), Vector2.zero)
	UI.padding(trapperPanel, 8)
	UI.gradient(trapperPanel, Color3.fromRGB(70, 30, 40), Color3.fromRGB(20, 16, 24))
	UI.stroke(trapperPanel, UI.Colors.Trapper, 2, 0.35)
	trapperPanel.Visible = false
	UI.label({
		name = "Title",
		parent = trapperPanel,
		text = "Ловушки впереди",
		size = UDim2.new(1, 0, 0, 24),
		color = UI.Colors.Trapper,
		maxTextSize = 22,
	})
	trapList = Instance.new("Frame")
	trapList.Name = "Traps"
	trapList.BackgroundTransparency = 1
	trapList.Position = UDim2.fromOffset(0, 28)
	trapList.Size = UDim2.new(1, 0, 1, -28)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = trapList
	trapList.Parent = trapperPanel

	leaderWarning = UI.label({
		name = "LeaderWarning",
		parent = gui,
		size = UDim2.new(0.7, 0, 0, 34),
		position = UDim2.new(0.5, 0, 0, 150),
		anchor = Vector2.new(0.5, 0),
		color = UI.Colors.Trapper,
		maxTextSize = 30,
	})
	leaderWarning.Visible = false
end

local function renderTraps()
	for _, child in trapList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local data = hud
	if not data then
		return
	end
	if #data.traps == 0 then
		UI.label({
			name = "None",
			parent = trapList,
			text = "Впереди ловушек нет",
			size = UDim2.new(1, 0, 0, 24),
			color = UI.Colors.Muted,
			maxTextSize = 18,
		})
		return
	end
	for index, trap in data.traps do
		local where = if trap.segmentsAway == 0 then "рядом" else `через {trap.segmentsAway}`
		local label = UI.label({
			name = `Trap{index}`,
			parent = trapList,
			text = `{trap.name} · {where} · {STATE_TEXT[trap.state]}`,
			size = UDim2.new(1, 0, 0, 30),
			color = STATE_COLOR[trap.state],
			font = Enum.Font.SourceSansSemibold,
			alignX = Enum.TextXAlignment.Left,
			maxTextSize = 18,
		})
		label.LayoutOrder = index
	end
end

local function refreshTrapper()
	local isTrapper = GameState.getRole(player) == "Trapper" and GameState.phase() == "Round"
	local data = hud
	trapperPanel.Visible = isTrapper and data ~= nil
	local gap = if data then data.leaderSegment - data.trapperSegment else 0
	if isTrapper and data and gap >= LEADER_WARNING_GAP then
		leaderWarning.Text = `Лидер раннеров впереди на {gap} сегм. — догоняй!`
		-- Blink twice a second.
		leaderWarning.Visible = os.clock() % 1 < 0.6
	else
		leaderWarning.Visible = false
	end
	if not isTrapper and data then
		hud = nil
	end
end

function ProgressController.start()
	local gui = UI.screen("Progress", 11)
	buildBar(gui)
	buildTrapperPanel(gui)
	gui.Parent = player:WaitForChild("PlayerGui")

	Remotes.TrapperHud.OnClientEvent:Connect(function(data: Types.TrapperHud)
		hud = data
		renderTraps()
	end)
	Players.PlayerRemoving:Connect(function(other)
		local dot = dots[other]
		if dot then
			dot:Destroy()
			dots[other] = nil
		end
	end)

	task.spawn(function()
		while true do
			refreshBar()
			refreshTrapper()
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

return ProgressController
