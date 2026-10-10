--!strict
-- Draws the lobby boards on this client: the top-100 lists (Points, wins) with avatar pictures and
-- the player's own stats. The server puts the lists on the board parts as a JSON attribute; drawing
-- them here (in PlayerGui) lets players scroll the lists.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local UI = require(script.Parent.Parent.Util.UI)

type Entry = { userId: number, name: string, value: number }

local PIXELS_PER_STUD = 25
local ROW_HEIGHT = 46
local MEDALS = { "🥇", "🥈", "🥉" }
local TITLES = { Points = "ТОП-100 · ОЧКИ", Wins = "ТОП-100 · ПОБЕДЫ" }
local ACCENTS = { Points = Color3.fromRGB(255, 205, 90), Wins = Color3.fromRGB(130, 200, 255) }

local player = Players.LocalPlayer

local BoardsController = {}

local guis: { [Instance]: SurfaceGui } = {}
local playerGui: PlayerGui
local snapshot: Types.DataSnapshot? = nil
local statsLabels: { TextLabel } = {}

local function surface(part: BasePart): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = `Board_{part:GetAttribute("Kind")}`
	gui.Adornee = part
	gui.Face = if part:GetAttribute("Face") == "Front" then Enum.NormalId.Front else Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.ResetOnSpawn = false
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BorderSizePixel = 0
	background.BackgroundColor3 = Color3.fromRGB(40, 38, 58)
	UI.gradient(background, Color3.fromRGB(52, 48, 78), Color3.fromRGB(26, 26, 40))
	background.Parent = gui
	gui.Parent = playerGui
	return gui
end

local function title(parent: Instance, text: string, color: Color3)
	UI.label({
		name = "Title",
		parent = parent,
		text = text,
		size = UDim2.new(1, -20, 0, 60),
		position = UDim2.fromOffset(10, 8),
		color = color,
		maxTextSize = 44,
	})
end

-- Top-100 --------------------------------------------------------------------------------------

local function buildLeaderboard(part: BasePart)
	local kind = part:GetAttribute("Kind") :: string
	local gui = surface(part)
	local background = gui:FindFirstChild("Background") :: Frame
	title(background, TITLES[kind] or kind, ACCENTS[kind] or UI.Colors.Gold)
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(10, 76)
	list.Size = UDim2.new(1, -20, 1, -130)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 10
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list
	list.Parent = background
	local footer = UI.label({
		name = "Footer",
		parent = background,
		size = UDim2.new(1, -20, 0, 40),
		position = UDim2.new(0, 10, 1, -48),
		color = UI.Colors.Muted,
		maxTextSize = 28,
	})

	local function render()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local json = part:GetAttribute("Entries")
		local ok, entries = pcall(function()
			return HttpService:JSONDecode(if typeof(json) == "string" then json else "[]")
		end)
		local rows: { Entry } = if ok and type(entries) == "table" then entries else {}
		local myRank: number? = nil
		for rank, entry in rows do
			local mine = entry.userId == player.UserId
			if mine then
				myRank = rank
			end
			local row = Instance.new("Frame")
			row.Name = `Row{rank}`
			row.LayoutOrder = rank
			row.Size = UDim2.new(1, -14, 0, ROW_HEIGHT)
			row.BorderSizePixel = 0
			row.BackgroundColor3 = if mine then Color3.fromRGB(90, 80, 140) else Color3.fromRGB(58, 56, 82)
			row.BackgroundTransparency = if mine then 0 else 0.3
			UI.corner(row, 8)
			UI.label({
				name = "Rank",
				parent = row,
				text = MEDALS[rank] or `#{rank}`,
				size = UDim2.new(0, 60, 1, -8),
				position = UDim2.fromOffset(4, 4),
				color = if rank <= 3 then UI.Colors.Gold else UI.Colors.Muted,
				maxTextSize = 30,
			})
			local avatar = Instance.new("ImageLabel")
			avatar.Name = "Avatar"
			avatar.BackgroundColor3 = Color3.fromRGB(30, 30, 44)
			avatar.Size = UDim2.fromOffset(ROW_HEIGHT - 8, ROW_HEIGHT - 8)
			avatar.Position = UDim2.fromOffset(66, 4)
			avatar.Image = `rbxthumb://type=AvatarHeadShot&id={entry.userId}&w=48&h=48`
			UI.corner(avatar, 18)
			avatar.Parent = row
			UI.label({
				name = "Name",
				parent = row,
				text = entry.name,
				size = UDim2.new(1, -230, 1, -8),
				position = UDim2.fromOffset(114, 4),
				alignX = Enum.TextXAlignment.Left,
				color = if mine then UI.Colors.Gold else UI.Colors.Text,
				maxTextSize = 28,
			})
			UI.label({
				name = "Value",
				parent = row,
				text = tostring(entry.value),
				size = UDim2.new(0, 110, 1, -8),
				position = UDim2.new(1, -116, 0, 4),
				alignX = Enum.TextXAlignment.Right,
				color = ACCENTS[kind] or UI.Colors.Gold,
				maxTextSize = 28,
			})
			row.Parent = list
		end
		if #rows == 0 then
			footer.Text = "Пока пусто — сыграй раунд!"
		elseif myRank then
			footer.Text = `Ты на {myRank} месте`
		else
			footer.Text = "Тебя пока нет в топе"
		end
	end
	render()
	part:GetAttributeChangedSignal("Entries"):Connect(render)
	guis[part] = gui
end

-- Stats ------------------------------------------------------------------------------------------

local STAT_ROWS: { { label: string, read: (Types.DataSnapshot) -> string } } = {
	{
		label = "Очки",
		read = function(data)
			return tostring(data.points)
		end,
	},
	{
		label = "Раундов сыграно",
		read = function(data)
			return tostring(data.stats.Rounds)
		end,
	},
	{
		label = "Финишей",
		read = function(data)
			return tostring(data.stats.Finishes)
		end,
	},
	{
		label = "Побед раннером",
		read = function(data)
			return tostring(data.stats.Wins)
		end,
	},
	{
		label = "Побед трапером",
		read = function(data)
			return tostring(data.stats.TrapperWins)
		end,
	},
	{
		label = "Убийств ловушками",
		read = function(data)
			return tostring(data.stats.Kills)
		end,
	},
	{
		label = "Лучший забег",
		read = function(data)
			return `{math.floor(data.stats.BestDistance * 100 + 0.5)}%`
		end,
	},
}

local function renderStats()
	local data = snapshot
	for index, row in STAT_ROWS do
		local label = statsLabels[index]
		if label then
			label.Text = if data then row.read(data) else "…"
		end
	end
end

local function buildStats(part: BasePart)
	local gui = surface(part)
	local background = gui:FindFirstChild("Background") :: Frame
	title(background, "МОЯ СТАТИСТИКА", Color3.fromRGB(150, 230, 170))
	local avatar = Instance.new("ImageLabel")
	avatar.BackgroundColor3 = Color3.fromRGB(30, 30, 44)
	avatar.Size = UDim2.fromOffset(96, 96)
	avatar.Position = UDim2.new(0.5, -48, 0, 74)
	avatar.Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=150&h=150`
	UI.corner(avatar, 48)
	avatar.Parent = background
	UI.label({
		name = "Name",
		parent = background,
		text = player.DisplayName,
		size = UDim2.new(1, -20, 0, 36),
		position = UDim2.fromOffset(10, 176),
		maxTextSize = 32,
	})
	table.clear(statsLabels)
	for index, row in STAT_ROWS do
		local y = 224 + (index - 1) * 46
		UI.label({
			name = `Label{index}`,
			parent = background,
			text = row.label,
			size = UDim2.new(0.62, -20, 0, 40),
			position = UDim2.fromOffset(24, y),
			alignX = Enum.TextXAlignment.Left,
			color = UI.Colors.Muted,
			maxTextSize = 28,
		})
		table.insert(
			statsLabels,
			UI.label({
				name = `Value{index}`,
				parent = background,
				size = UDim2.new(0.38, -24, 0, 40),
				position = UDim2.new(0.62, 0, 0, y),
				alignX = Enum.TextXAlignment.Right,
				color = UI.Colors.Gold,
				maxTextSize = 30,
			})
		)
	end
	renderStats()
	guis[part] = gui
end

local function watchTag(tag: string, build: (BasePart) -> ())
	local function added(instance: Instance)
		if instance:IsA("BasePart") and not guis[instance] then
			build(instance)
		end
	end
	for _, instance in CollectionService:GetTagged(tag) do
		added(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(added)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		local gui = guis[instance]
		if gui then
			gui:Destroy()
			guis[instance] = nil
		end
	end)
end

function BoardsController.start()
	playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	Remotes.PlayerData.OnClientEvent:Connect(function(data: Types.DataSnapshot)
		snapshot = data
		renderStats()
	end)
	watchTag("Leaderboard", buildLeaderboard)
	watchTag("StatsBoard", buildStats)
end

return BoardsController
