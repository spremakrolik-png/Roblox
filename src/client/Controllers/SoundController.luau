--!strict
-- Plays the sound effects from Config/Sounds: flat (UI) sounds or 3D sounds at a point in the world.
-- Other controllers call SoundController.play; it also reacts to a few round events on its own.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Types = require(ReplicatedStorage.Shared.Types)

local MAX_3D_DISTANCE = 150

local player = Players.LocalPlayer

local SoundController = {}

local templates: { [string]: Sound } = {}

local function template(name: Sounds.SoundName): Sound?
	local existing = templates[name]
	if existing then
		return existing
	end
	local def = Sounds[name]
	if not def then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.id
	sound.Volume = def.volume
	sound.PlaybackSpeed = def.pitch
	sound.Parent = SoundService
	templates[name] = sound
	return sound
end

-- Plays a sound; with `position` it is heard from that point in the world.
function SoundController.play(name: Sounds.SoundName, position: Vector3?)
	local source = template(name)
	if not source then
		return
	end
	if position == nil then
		SoundService:PlayLocalSound(source)
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = `Sound_{name}`
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position
	local sound = source:Clone()
	sound.RollOffMaxDistance = MAX_3D_DISTANCE
	sound.Parent = anchor
	anchor.Parent = workspace
	sound:Play()
	Debris:AddItem(anchor, 4)
end

function SoundController.start()
	-- Start gate: a tick each second of the countdown, then "go".
	task.spawn(function()
		local lastTick = -1
		while true do
			local startsAt = GameState.read(GameState.Keys.RoundStartedAt) :: number
			if GameState.phase() == "Round" and startsAt > 0 and GameState.getRole(player) ~= "None" then
				local remaining = math.ceil(startsAt - workspace:GetServerTimeNow())
				if remaining ~= lastTick and remaining >= 0 and remaining <= 3 then
					lastTick = remaining
					SoundController.play(if remaining == 0 then "Go" else "CountdownTick")
				end
			else
				lastTick = -1
			end
			task.wait(0.05)
		end
	end)

	Remotes.DeathEffect.OnClientEvent:Connect(function(position: Vector3, _color: Color3, kind: string?)
		SoundController.play(if kind == "Hit" then "TrapFired" elseif kind == "Revive" then "Go" else "Death", position)
	end)
	Remotes.FinishEffect.OnClientEvent:Connect(function(position: Vector3, vip: boolean)
		SoundController.play(if vip then "VipFinish" else "Finish", position)
	end)
	Remotes.ShopResult.OnClientEvent:Connect(function(ok: boolean)
		if ok then
			SoundController.play("Purchase")
		end
	end)
	Remotes.RoundResults.OnClientEvent:Connect(function(results: Types.RoundResults)
		local role = GameState.getRole(player)
		if role == "None" then
			return
		end
		local won = (results.winner == "Runners" and role == "Runner")
			or (results.winner == "Trapper" and role == "Trapper")
		SoundController.play(if won then "Win" else "Lose")
	end)
end

return SoundController
