--!strict
-- The look of the world: a calm daytime sky with light haze, a little bloom on neon and gentle
-- colour grading. During a round the haze leans slightly towards the track theme's accent colour.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Types = require(ReplicatedStorage.Shared.Types)

local LightingService = {}

local BASE_ATMOSPHERE = Color3.fromRGB(200, 205, 215)
local BASE_DECAY = Color3.fromRGB(110, 120, 140)

local atmosphere: Atmosphere
local grading: ColorCorrectionEffect

-- Reuses an effect left from an earlier run (e.g. edited in Studio) or creates it.
local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local created = Instance.new(className :: any)
	created.Name = name
	created.Parent = Lighting
	return created
end

function LightingService.init()
	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 35
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 138)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.ExposureCompensation = 0

	atmosphere = ensure("Atmosphere", "TrapRunnerAtmosphere") :: Atmosphere
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.1
	atmosphere.Color = BASE_ATMOSPHERE
	atmosphere.Decay = BASE_DECAY
	atmosphere.Glare = 0
	atmosphere.Haze = 0.8

	local bloom = ensure("BloomEffect", "TrapRunnerBloom") :: BloomEffect
	bloom.Intensity = 0.25
	bloom.Size = 20
	bloom.Threshold = 2.4

	local rays = ensure("SunRaysEffect", "TrapRunnerSunRays") :: SunRaysEffect
	rays.Intensity = 0.02
	rays.Spread = 0.4

	grading = ensure("ColorCorrectionEffect", "TrapRunnerGrading") :: ColorCorrectionEffect
	grading.Saturation = 0.05
	grading.Contrast = 0.04
	grading.Brightness = 0
	grading.TintColor = Color3.new(1, 1, 1)
end

-- Leans the sky and colours towards the theme of the track being played (nil = back to neutral).
function LightingService.setTheme(theme: Types.Theme?)
	local accent = if theme then theme.accentColor else nil
	local info = TweenInfo.new(2)
	TweenService:Create(atmosphere, info, {
		Color = if accent then BASE_ATMOSPHERE:Lerp(accent, 0.12) else BASE_ATMOSPHERE,
		Decay = if accent then BASE_DECAY:Lerp(accent, 0.2) else BASE_DECAY,
	}):Play()
	TweenService:Create(grading, info, {
		TintColor = if accent then Color3.new(1, 1, 1):Lerp(accent, 0.03) else Color3.new(1, 1, 1),
	}):Play()
end

return LightingService
