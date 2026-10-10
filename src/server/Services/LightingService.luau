--!strict
-- The look of the world: soft sky haze, bloom on neon, gentle sun rays and colour grading. During a
-- round the haze and grading lean slightly towards the track theme's accent colour.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Types = require(ReplicatedStorage.Shared.Types)

local LightingService = {}

local BASE_ATMOSPHERE = Color3.fromRGB(205, 215, 235)
local BASE_DECAY = Color3.fromRGB(120, 110, 170)

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
	Lighting.Brightness = 2.2
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 30
	Lighting.Ambient = Color3.fromRGB(90, 85, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 135, 165)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.ExposureCompensation = 0.1

	atmosphere = ensure("Atmosphere", "TrapRunnerAtmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.2
	atmosphere.Color = BASE_ATMOSPHERE
	atmosphere.Decay = BASE_DECAY
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.4

	local bloom = ensure("BloomEffect", "TrapRunnerBloom") :: BloomEffect
	bloom.Intensity = 0.8
	bloom.Size = 28
	bloom.Threshold = 1.6

	local rays = ensure("SunRaysEffect", "TrapRunnerSunRays") :: SunRaysEffect
	rays.Intensity = 0.06
	rays.Spread = 0.6

	grading = ensure("ColorCorrectionEffect", "TrapRunnerGrading") :: ColorCorrectionEffect
	grading.Saturation = 0.18
	grading.Contrast = 0.08
	grading.Brightness = 0.02
	grading.TintColor = Color3.new(1, 1, 1)
end

-- Leans the sky and colours towards the theme of the track being played (nil = back to neutral).
function LightingService.setTheme(theme: Types.Theme?)
	local accent = if theme then theme.accentColor else nil
	local info = TweenInfo.new(2)
	TweenService:Create(atmosphere, info, {
		Color = if accent then BASE_ATMOSPHERE:Lerp(accent, 0.25) else BASE_ATMOSPHERE,
		Decay = if accent then BASE_DECAY:Lerp(accent, 0.35) else BASE_DECAY,
	}):Play()
	TweenService:Create(grading, info, {
		TintColor = if accent then Color3.new(1, 1, 1):Lerp(accent, 0.06) else Color3.new(1, 1, 1),
	}):Play()
end

return LightingService
