--!strict
-- Client entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Shared modules and the server-created state must exist before controllers require them.
ReplicatedStorage:WaitForChild("Shared")
ReplicatedStorage:WaitForChild("GameState")
ReplicatedStorage:WaitForChild("Remotes")

local Controllers = script.Parent:WaitForChild("Controllers")

require(Controllers:WaitForChild("SoundController")).start()
require(Controllers:WaitForChild("HUDController")).start()
require(Controllers:WaitForChild("ProgressController")).start()
require(Controllers:WaitForChild("LobbyController")).start()
require(Controllers:WaitForChild("EffectsController")).start()
require(Controllers:WaitForChild("SpectateController")).start()
require(Controllers:WaitForChild("AbilityController")).start()
require(Controllers:WaitForChild("ShopController")).start()
require(Controllers:WaitForChild("AbilityCardController")).start()
require(Controllers:WaitForChild("WardrobeController")).start()
require(Controllers:WaitForChild("BoardsController")).start()
require(Controllers:WaitForChild("VipController")).start()
require(Controllers:WaitForChild("ScreenFxController")).start()
require(Controllers:WaitForChild("SecondChanceController")).start()
require(Controllers:WaitForChild("MusicController")).start()
