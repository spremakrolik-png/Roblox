--!strict
-- Background music with a mute button. Calm in the lobby, faster during a round. Plays the tracks
-- from Config/Music, or the built-in music box when there are none (or they fail to load).

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GameState = require(ReplicatedStorage.Shared.GameState)
local Music = require(ReplicatedStorage.Shared.Config.Music)
local UI = require(script.Parent.Parent.Util.UI)

type Mood = "Lobby" | "Round"

local player = Players.LocalPlayer

local MusicController = {}

local muted = false
local group: SoundGroup

local function mood(): Mood
	local phase = GameState.phase()
	if (phase == "Round" or phase == "Countdown") and GameState.getRole(player) ~= "None" then
		return "Round"
	end
	return "Lobby"
end

local function setMuted(value: boolean)
	muted = value
	TweenService:Create(group, TweenInfo.new(0.4), { Volume = if muted then 0 else Music.Volume }):Play()
end

-- Tracks -----------------------------------------------------------------------------------------

local function loadTrack(id: string): Sound?
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = group
	sound.Parent = SoundService
	local ok = false
	pcall(function()
		ContentProvider:PreloadAsync({ sound }, function(_, status)
			ok = status == Enum.AssetFetchStatus.Success
		end)
	end)
	if not ok then
		warn(`[Music] could not load {id}; using the music box`)
		sound:Destroy()
		return nil
	end
	return sound
end

local function loadList(ids: { string }): { Sound }
	local list: { Sound } = {}
	for _, id in ids do
		local sound = loadTrack(id)
		if sound then
			table.insert(list, sound)
		end
	end
	return list
end

-- Plays real tracks; returns false when there are none for either mood.
local function runTracks(): boolean
	local tracks: { [Mood]: { Sound } } = {
		Lobby = loadList(Music.LobbyTracks),
		Round = loadList(Music.RoundTracks),
	}
	if #tracks.Lobby == 0 and #tracks.Round == 0 then
		return false
	end
	if #tracks.Round == 0 then
		tracks.Round = tracks.Lobby
	elseif #tracks.Lobby == 0 then
		tracks.Lobby = tracks.Round
	end
	task.spawn(function()
		local playing: Sound? = nil
		local playingMood: Mood? = nil
		while true do
			local current = mood()
			if current ~= playingMood then
				playingMood = current
				local list = tracks[current]
				local nextSound = list[math.random(1, #list)]
				if playing and playing ~= nextSound then
					local old = playing
					TweenService:Create(old, TweenInfo.new(Music.FadeSeconds), { Volume = 0 }):Play()
					task.delay(Music.FadeSeconds, function()
						if old ~= playing then
							old:Stop()
						end
					end)
				end
				playing = nextSound
				if not nextSound.IsPlaying then
					nextSound:Play()
				end
				TweenService:Create(nextSound, TweenInfo.new(Music.FadeSeconds), { Volume = 1 }):Play()
			end
			task.wait(0.5)
		end
	end)
	return true
end

-- Music box ------------------------------------------------------------------------------------

local template: Sound

local function note(semitones: number, volume: number)
	local sound = template:Clone()
	sound.PlaybackSpeed = 2 ^ ((semitones + Music.MusicBox.Transpose) / 12)
	sound.Volume = volume
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 3)
end

local MELODY = { 0, 2, 4, 7, 9, 12 } -- C major pentatonic

local function runMusicBox()
	template = Instance.new("Sound")
	template.Name = "MusicBoxNote"
	template.SoundId = Music.MusicBox.Sample
	template.SoundGroup = group
	template.Parent = SoundService
	task.spawn(function()
		local bar = 0
		local nextTime = os.clock()
		while true do
			local song = if mood() == "Round" then Music.MusicBox.Round else Music.MusicBox.Lobby
			local step = 60 / song.Tempo / 2 -- eighth notes
			local root = song.Chords[bar % #song.Chords + 1]
			local chord = { root, root + 4, root + 7, root + 12 }
			if root == 9 or root == 2 or root == 4 then
				chord[2] = root + 3 -- minor chords on ii, iii and vi
			end
			for index, which in song.Pattern do
				if index == 1 or index == 5 then
					note(root - 12, 0.5) -- bass
				end
				note(chord[which], if index % 2 == 1 then 0.45 else 0.32)
				if index % 2 == 1 and math.random() < song.MelodyChance then
					note(MELODY[math.random(1, #MELODY)] + 12, 0.28)
				end
				nextTime += step
				task.wait(math.max(0, nextTime - os.clock()))
			end
			bar += 1
		end
	end)
end

-- Mute button -------------------------------------------------------------------------------------

local function buildButton()
	local gui = UI.screen("Music", 6)
	local button = Instance.new("TextButton")
	button.Name = "MusicToggle"
	button.AnchorPoint = Vector2.new(0, 0.5)
	button.Position = UDim2.new(0, 12, 0.55, -110)
	button.Size = UDim2.fromOffset(48, 48)
	button.BackgroundColor3 = Color3.fromRGB(150, 90, 220)
	button.AutoButtonColor = false
	button.Text = "♪"
	button.TextScaled = true
	button.Font = Enum.Font.SourceSansBold
	button.TextColor3 = Color3.new(1, 1, 1)
	UI.corner(button, 24)
	UI.gradient(button, Color3.fromRGB(190, 120, 255), Color3.fromRGB(110, 60, 190))
	UI.stroke(button, Color3.new(1, 1, 1), 2, 0.5)
	UI.pressable(button)
	button.Activated:Connect(function()
		setMuted(not muted)
		button.Text = if muted then "✕" else "♪"
	end)
	button.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

function MusicController.start()
	group = Instance.new("SoundGroup")
	group.Name = "Music"
	group.Volume = Music.Volume
	group.Parent = SoundService
	buildButton()
	task.spawn(function()
		if not runTracks() then
			runMusicBox()
		end
	end)
end

return MusicController
