--!strict
-- Visual themes for the track. Phase 1 ships one; Phase 2 adds Lava Temple, Neon City,
-- Ice Cave and Candy Factory and picks one at random each round.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local list: { Types.Theme } = {
	{
		name = "Training Grounds",
		floorColor = Color3.fromRGB(96, 102, 118),
		floorMaterial = Enum.Material.SmoothPlastic,
		accentColor = Color3.fromRGB(255, 196, 40),
		wallColor = Color3.fromRGB(58, 62, 74),
		glassColor = Color3.fromRGB(170, 220, 255),
		corridorColor = Color3.fromRGB(110, 44, 48),
	},
}

return {
	list = list,
	default = list[1],
}
