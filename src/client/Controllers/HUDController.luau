--!strict
-- In-game HUD: phase status, personal line, start-gate countdown, role banner, kill feed and
-- the results screen. Reads replicated state only; it never decides anything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StatusText = require(ReplicatedStorage.Shared.StatusText)
local Types = require(ReplicatedStorage.Shared.Types)
local UI = require(script.Parent.Parent.Util.UI)

local REFRESH_INTERVAL = 0.1
local FEED_LIFETIME = 6
local FEED_MAX_ENTRIES = 6
local BANNER_SECONDS = 2.5

local player = Players.LocalPlayer

local HUDController = {}

type Elements = {
	gui: ScreenGui,
	statusTitle: TextLabel,
	statusDetail: TextLabel,
	personal: TextLabel,
	gateCountdown: TextLabel,
	banner: TextLabel,
	feed: Frame,
	results: Frame,
	resultsTitle: TextLabel,
	resultsSummary: TextLabel,
	resultsList: ScrollingFrame,
}

local elements: Elements
local feedOrder = 0
local bannerToken = 0
local lastPhase: Types.Phase? = nil

local ELIMINATION_LABEL: { [Types.EliminationReason]: string } = {
	Died = "died",
	Fell = "fell into the void",
	AFK = "eliminated (AFK)",
	Left = "left the game",
}

local FEED_COLORS: { [Types.FeedKind]: Color3 } = {
	Death = UI.Colors.Death,
	Finish = UI.Colors.Gold,
	Info = UI.Colors.Text,
}

-- Building --------------------------------------------------------------------

local function build(): Elements
	local gui = UI.screen("HUD", 10)

	local status = UI.panel("Status", gui, UDim2.new(0.5, 0, 0, 72), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0))
	UI.sizeLimit(status, Vector2.new(280, 56), Vector2.new(560, 90))
	UI.padding(status, 6)
	local statusTitle = UI.label({
		name = "Title",
		parent = status,
		size = UDim2.fromScale(1, 0.58),
		maxTextSize = 34,
	})
	local statusDetail = UI.label({
		name = "Detail",
		parent = status,
		size = UDim2.fromScale(1, 0.42),
		position = UDim2.fromScale(0, 0.58),
		color = UI.Colors.Muted,
		font = Enum.Font.GothamMedium,
		maxTextSize = 22,
	})

	local personal = UI.label({
		name = "Personal",
		parent = gui,
		size = UDim2.new(0.5, 0, 0, 30),
		position = UDim2.new(0.5, 0, 0, 86),
		anchor = Vector2.new(0.5, 0),
		maxTextSize = 26,
	})

	local gateCountdown = UI.label({
		name = "GateCountdown",
		parent = gui,
		size = UDim2.fromScale(0.3, 0.2),
		position = UDim2.fromScale(0.5, 0.38),
		anchor = Vector2.new(0.5, 0.5),
		color = UI.Colors.Gold,
	})

	local banner = UI.label({
		name = "Banner",
		parent = gui,
		size = UDim2.fromScale(0.9, 0.12),
		position = UDim2.fromScale(0.5, 0.3),
		anchor = Vector2.new(0.5, 0.5),
		maxTextSize = 72,
	})
	banner.Visible = false

	local feed = Instance.new("Frame")
	feed.Name = "KillFeed"
	feed.BackgroundTransparency = 1
	-- Bottom right: the top right corner belongs to Roblox's player list on PC, and on phones this
	-- offset keeps the feed above the jump button.
	feed.AnchorPoint = Vector2.new(1, 1)
	feed.Position = UDim2.new(1, -10, 1, -150)
	feed.Size = UDim2.fromScale(0.32, 0.4)
	UI.sizeLimit(feed, Vector2.new(200, 100), Vector2.new(380, 320))
	local feedLayout = Instance.new("UIListLayout")
	feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
	feedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	feedLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	feedLayout.Padding = UDim.new(0, 4)
	feedLayout.Parent = feed
	feed.Parent = gui

	local results =
		UI.panel("Results", gui, UDim2.fromScale(0.6, 0.62), UDim2.fromScale(0.5, 0.55), Vector2.new(0.5, 0.5))
	UI.sizeLimit(results, Vector2.new(280, 240), Vector2.new(520, 460))
	UI.padding(results, 12)
	results.Visible = false
	local resultsTitle = UI.label({
		name = "Title",
		parent = results,
		size = UDim2.fromScale(1, 0.16),
		maxTextSize = 44,
	})
	local resultsSummary = UI.label({
		name = "Summary",
		parent = results,
		size = UDim2.fromScale(1, 0.1),
		position = UDim2.fromScale(0, 0.17),
		color = UI.Colors.Muted,
		font = Enum.Font.GothamMedium,
		maxTextSize = 20,
	})
	local resultsList = Instance.new("ScrollingFrame")
	resultsList.Name = "List"
	resultsList.BackgroundTransparency = 1
	resultsList.BorderSizePixel = 0
	resultsList.Position = UDim2.fromScale(0, 0.3)
	resultsList.Size = UDim2.fromScale(1, 0.7)
	resultsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	resultsList.CanvasSize = UDim2.new()
	resultsList.ScrollBarThickness = 6
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = resultsList
	resultsList.Parent = results

	gui.Parent = player:WaitForChild("PlayerGui")

	return {
		gui = gui,
		statusTitle = statusTitle,
		statusDetail = statusDetail,
		personal = personal,
		gateCountdown = gateCountdown,
		banner = banner,
		feed = feed,
		results = results,
		resultsTitle = resultsTitle,
		resultsSummary = resultsSummary,
		resultsList = resultsList,
	}
end

-- Status ----------------------------------------------------------------------

local function setText(label: TextLabel, text: string, color: Color3?)
	if label.Text ~= text then
		label.Text = text
	end
	if color and label.TextColor3 ~= color then
		label.TextColor3 = color
	end
	label.Visible = text ~= ""
end

-- One line about the local player; only for round participants.
local function personalLine(state: GameState.Snapshot): (string, Color3)
	local role = GameState.getRole(player)
	local phase = state.phase
	if role == "None" or (phase ~= "Countdown" and phase ~= "Round") then
		return "", UI.Colors.Text
	end

	if phase == "Countdown" then
		if role == "Trapper" then
			return "You will be the TRAPPER", UI.Colors.Trapper
		end
		return "You will be a RUNNER", UI.Colors.Runner
	end

	if role == "Trapper" then
		return "TRAPPER - keep up with the runners!", UI.Colors.Trapper
	end
	local status = GameState.getStatus(player)
	if status == "Finished" then
		local place = player:GetAttribute(GameState.PlayerKeys.Place)
		return string.format("Finished #%d! Watch the others", if typeof(place) == "number" then place else 0),
			UI.Colors.Gold
	elseif status == "Eliminated" then
		return "Eliminated - you are spectating", UI.Colors.Death
	end
	local progress = player:GetAttribute(GameState.PlayerKeys.Progress)
	local percent = if typeof(progress) == "number" then math.floor(progress * 100 + 0.5) else 0
	return string.format("Your progress: %d%%", percent), UI.Colors.Runner
end

local function gateLine(state: GameState.Snapshot, now: number): string
	if state.phase ~= "Round" or GameState.getRole(player) == "None" then
		return ""
	end
	if state.roundStartedAt <= 0 then
		return ""
	end
	local remaining = state.roundStartedAt - now
	if remaining <= 0 then
		return ""
	end
	return tostring(math.ceil(remaining))
end

local function refresh()
	local state = GameState.snapshot()
	local now = workspace:GetServerTimeNow()

	local title, detail = StatusText.describe(state, now)
	setText(elements.statusTitle, title)
	setText(elements.statusDetail, detail)

	local line, color = personalLine(state)
	setText(elements.personal, line, color)
	setText(elements.gateCountdown, gateLine(state, now))

	-- The results screen closes when the Results phase ends.
	if lastPhase == "Results" and state.phase ~= "Results" then
		elements.results.Visible = false
	end
	lastPhase = state.phase
end

-- Banner ----------------------------------------------------------------------

local function showBanner(text: string, color: Color3)
	bannerToken += 1
	local token = bannerToken
	local banner = elements.banner
	banner.Text = text
	banner.TextColor3 = color
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.3
	banner.Visible = true
	banner.Size = UDim2.fromScale(0.6, 0.08)
	TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.9, 0.12) })
		:Play()

	task.delay(BANNER_SECONDS, function()
		if token ~= bannerToken then
			return
		end
		local fade =
			TweenService:Create(banner, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		if token == bannerToken then
			banner.Visible = false
		end
	end)
end

local function onRoleBanner(role: Types.Role)
	if role == "Trapper" then
		showBanner("YOU ARE THE TRAPPER - stop them all!", UI.Colors.Trapper)
	elseif role == "Runner" then
		showBanner("RUN!", UI.Colors.Runner)
	end
end

-- Kill feed ---------------------------------------------------------------------

local function onFeed(entry: Types.FeedEntry)
	feedOrder += 1
	local label = UI.label({
		name = "Entry",
		parent = elements.feed,
		text = entry.text,
		size = UDim2.new(1, 0, 0, 24),
		color = FEED_COLORS[entry.kind] or UI.Colors.Text,
		font = Enum.Font.GothamBold,
		alignX = Enum.TextXAlignment.Right,
		maxTextSize = 20,
	})
	label.LayoutOrder = feedOrder -- newest at the bottom

	local entries: { TextLabel } = {}
	for _, child in elements.feed:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(entries, child)
		end
	end
	if #entries > FEED_MAX_ENTRIES then
		table.sort(entries, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		entries[1]:Destroy() -- the oldest has the lowest LayoutOrder
	end

	task.delay(FEED_LIFETIME, function()
		if label.Parent then
			local fade =
				TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			label:Destroy()
		end
	end)
end

-- Results -----------------------------------------------------------------------

local function addResultLine(order: number, text: string, color: Color3)
	local label = UI.label({
		name = "Line",
		parent = elements.resultsList,
		text = text,
		size = UDim2.new(1, -8, 0, 28),
		color = color,
		font = Enum.Font.GothamBold,
		alignX = Enum.TextXAlignment.Left,
		maxTextSize = 22,
	})
	label.LayoutOrder = order
end

local function onResults(results: Types.RoundResults)
	for _, child in elements.resultsList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local winner = results.winner
	if winner == "Runners" then
		setText(elements.resultsTitle, "RUNNERS WIN!", UI.Colors.Runner)
	elseif winner == "Trapper" then
		setText(elements.resultsTitle, "TRAPPER WINS!", UI.Colors.Trapper)
	elseif winner == "NoContest" then
		setText(elements.resultsTitle, "NO CONTEST", UI.Colors.Muted)
	else
		setText(elements.resultsTitle, "ROUND ABORTED", UI.Colors.Muted)
	end
	setText(
		elements.resultsSummary,
		string.format(
			"Trapper: %s  |  Kills: %d  |  Time: %s",
			results.trapperName,
			results.trapperKills,
			StatusText.formatClock(results.duration)
		)
	)

	local order = 0
	for _, finisher in results.finishers do
		order += 1
		local color = if finisher.place <= 3 then UI.Colors.Gold else UI.Colors.Text
		addResultLine(
			order,
			string.format("#%d  %s  %s", finisher.place, finisher.name, StatusText.formatTime(finisher.time)),
			color
		)
	end
	for _, name in results.survivors do
		order += 1
		addResultLine(order, string.format("%s - survived", name), UI.Colors.Runner)
	end
	for _, entry in results.eliminated do
		order += 1
		addResultLine(
			order,
			string.format("%s - %s", entry.name, ELIMINATION_LABEL[entry.reason] or "eliminated"),
			UI.Colors.Death
		)
	end
	if order == 0 then
		addResultLine(1, "No runners this round", UI.Colors.Muted)
	end

	elements.results.Visible = true
end

-- Start -------------------------------------------------------------------------

function HUDController.start()
	elements = build()

	Remotes.RoleBanner.OnClientEvent:Connect(function(role: Types.Role)
		onRoleBanner(role)
	end)
	Remotes.KillFeed.OnClientEvent:Connect(function(entry: Types.FeedEntry)
		onFeed(entry)
	end)
	Remotes.RoundResults.OnClientEvent:Connect(function(results: Types.RoundResults)
		onResults(results)
	end)

	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

return HUDController
