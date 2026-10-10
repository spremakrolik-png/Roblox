--!strict
-- Background music. Put music asset ids ("rbxassetid://<number>") into the lists to use real tracks:
-- the Creator Store (Audio -> Music) has free tracks you can add to your game. With empty lists, or if
-- a track fails to load, the game plays its own calm "music box" tune made from a built-in sound.

local Music = {
	Volume = 0.3,
	LobbyTracks = {} :: { string },
	RoundTracks = {} :: { string },
	FadeSeconds = 1.5,

	-- Music box (used without tracks)
	MusicBox = {
		Sample = "rbxasset://sounds/electronicpingshort.wav",
		Transpose = -7, -- semitones; the sample is bright, so everything is played a bit lower
		Lobby = {
			Tempo = 84, -- beats per minute; notes are eighths
			Chords = { 0, 7, 9, 5 }, -- I V vi IV in C major (semitones of each chord root)
			Pattern = { 1, 2, 3, 4, 3, 2, 3, 2 }, -- indices into root, third, fifth, octave
			MelodyChance = 0.35,
		},
		Round = {
			Tempo = 124,
			Chords = { 9, 5, 0, 7 }, -- vi IV I V: more drive
			Pattern = { 1, 3, 2, 3, 4, 3, 2, 3 },
			MelodyChance = 0.5,
		},
	},
}

return Music
