--!strict
-- Sound effects. The defaults are sounds that ship with every Roblox client (rbxasset://sounds/...),
-- so the game makes noise with no uploads. Swap any id for "rbxassetid://<number>" to use your own.

export type SoundDef = {
	id: string,
	volume: number,
	pitch: number,
}

export type SoundName =
	"CountdownTick"
	| "Go"
	| "TrapWarning"
	| "TrapFired"
	| "Death"
	| "Finish"
	| "VipFinish"
	| "Ability"
	| "Click"
	| "Purchase"
	| "Win"
	| "Lose"

local Sounds: { [SoundName]: SoundDef } = {
	CountdownTick = { id = "rbxasset://sounds/clickfast.wav", volume = 0.6, pitch = 1 },
	Go = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = 1.2 },
	TrapWarning = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = 0.6 },
	TrapFired = { id = "rbxasset://sounds/snap.wav", volume = 0.6, pitch = 0.8 },
	Death = { id = "rbxasset://sounds/splat.wav", volume = 0.8, pitch = 1 },
	Finish = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = 1.5 },
	VipFinish = { id = "rbxasset://sounds/flashbulb.wav", volume = 0.8, pitch = 1 },
	Ability = { id = "rbxasset://sounds/swoosh.wav", volume = 0.6, pitch = 1.1 },
	Click = { id = "rbxasset://sounds/button.wav", volume = 0.5, pitch = 1 },
	Purchase = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = 1.8 },
	Win = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8, pitch = 1.3 },
	Lose = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = 0.5 },
}

return Sounds
