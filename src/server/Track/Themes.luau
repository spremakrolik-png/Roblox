--!strict
-- Visual themes for the track. One is picked from the seed each round; they only change looks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local list: { Types.Theme } = {
	{
		name = "Лавовый храм",
		floorColor = Color3.fromRGB(120, 96, 82),
		floorMaterial = Enum.Material.Slate,
		floorPhysics = nil,
		accentColor = Color3.fromRGB(255, 140, 30),
		wallColor = Color3.fromRGB(70, 52, 44),
		glassColor = Color3.fromRGB(255, 190, 140),
		corridorColor = Color3.fromRGB(92, 40, 30),
		abyssColor = Color3.fromRGB(255, 90, 20),
		abyssMaterial = Enum.Material.Neon,
		decorColor = Color3.fromRGB(96, 78, 66),
		decorMaterial = Enum.Material.Cobblestone,
		decorTopColor = Color3.fromRGB(255, 120, 20),
	},
	{
		name = "Неоновый город",
		floorColor = Color3.fromRGB(34, 36, 52),
		floorMaterial = Enum.Material.SmoothPlastic,
		floorPhysics = nil,
		accentColor = Color3.fromRGB(0, 230, 255),
		wallColor = Color3.fromRGB(24, 24, 38),
		glassColor = Color3.fromRGB(150, 110, 255),
		corridorColor = Color3.fromRGB(60, 20, 80),
		abyssColor = Color3.fromRGB(255, 40, 200),
		abyssMaterial = Enum.Material.ForceField,
		decorColor = Color3.fromRGB(30, 30, 46),
		decorMaterial = Enum.Material.Metal,
		decorTopColor = Color3.fromRGB(0, 230, 255),
	},
	{
		name = "Ледяная пещера",
		floorColor = Color3.fromRGB(190, 225, 245),
		floorMaterial = Enum.Material.Ice,
		-- Looks like ice but grips like plastic: slippery floors are a trap (Ice Floor), not a theme.
		floorPhysics = PhysicalProperties.new(Enum.Material.Plastic),
		accentColor = Color3.fromRGB(120, 210, 255),
		wallColor = Color3.fromRGB(120, 150, 175),
		glassColor = Color3.fromRGB(200, 240, 255),
		corridorColor = Color3.fromRGB(70, 110, 150),
		abyssColor = Color3.fromRGB(30, 90, 150),
		abyssMaterial = Enum.Material.Glass,
		decorColor = Color3.fromRGB(170, 215, 240),
		decorMaterial = Enum.Material.Glacier,
		decorTopColor = Color3.fromRGB(230, 250, 255),
	},
	{
		name = "Конфетная фабрика",
		floorColor = Color3.fromRGB(255, 190, 220),
		floorMaterial = Enum.Material.SmoothPlastic,
		floorPhysics = nil,
		accentColor = Color3.fromRGB(120, 230, 190),
		wallColor = Color3.fromRGB(240, 120, 170),
		glassColor = Color3.fromRGB(255, 230, 160),
		corridorColor = Color3.fromRGB(150, 90, 200),
		abyssColor = Color3.fromRGB(110, 60, 40),
		abyssMaterial = Enum.Material.SmoothPlastic,
		decorColor = Color3.fromRGB(255, 255, 255),
		decorMaterial = Enum.Material.SmoothPlastic,
		decorTopColor = Color3.fromRGB(255, 60, 110),
	},
}

local Themes = {}

Themes.list = list

-- The theme for a seed: same seed, same theme.
function Themes.forSeed(seed: number): Types.Theme
	return list[Random.new(seed + 7919):NextInteger(1, #list)]
end

return Themes
