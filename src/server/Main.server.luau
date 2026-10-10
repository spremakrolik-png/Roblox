--!strict
-- Server entry point: starts every service in dependency order.

local Services = script.Parent.Services

local CharacterService = require(Services.CharacterService)
local LobbyService = require(Services.LobbyService)
local RoundService = require(Services.RoundService)

local ok, streaming = pcall(function()
	return workspace.StreamingEnabled
end)
if ok and not streaming then
	warn("[Main] Workspace.StreamingEnabled is off. Turn it on in the Workspace properties.")
end

CharacterService.init()
LobbyService.init()
RoundService.start()

print("[Main] Trap Runner server started")
