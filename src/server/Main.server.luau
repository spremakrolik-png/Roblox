--!strict
-- Server entry point: starts every service in dependency order.

local Services = script.Parent.Services

local AbilityService = require(Services.AbilityService)
local CharacterService = require(Services.CharacterService)
local CosmeticsService = require(Services.CosmeticsService)
local LeaderboardService = require(Services.LeaderboardService)
local LightingService = require(Services.LightingService)
local LobbyService = require(Services.LobbyService)
local MonetizationService = require(Services.MonetizationService)
local PlayerDataService = require(Services.PlayerDataService)
local RoundService = require(Services.RoundService)
local SpectateService = require(Services.SpectateService)

local ok, streaming = pcall(function()
	return workspace.StreamingEnabled
end)
if ok and not streaming then
	warn("[Main] Workspace.StreamingEnabled is off. Turn it on in the Workspace properties.")
end

LightingService.init()
CharacterService.init()
PlayerDataService.init()
MonetizationService.init()
CosmeticsService.init()
LobbyService.init()
AbilityService.init()
SpectateService.init()
LeaderboardService.init()
RoundService.start()

print("[Main] Trap Runner server started")
