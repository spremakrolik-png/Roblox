--!strict
-- Every RemoteEvent in the game. The server creates them, clients wait for them.
-- Client -> server remotes are validated on the server (SpectateService, PlayerDataService, AbilityService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

export type Remotes = {
	-- server -> one client: (role: Types.Role) when the start gates open
	RoleBanner: RemoteEvent,
	-- server -> all clients: (entry: Types.FeedEntry)
	KillFeed: RemoteEvent,
	-- server -> all clients: (results: Types.RoundResults)
	RoundResults: RemoteEvent,
	-- server -> all clients: (alert: Types.TrapAlert) when a trap starts its telegraph
	TrapActivated: RemoteEvent,
	-- server -> all clients: (position: Vector3, color: Color3) cartoon burst where a runner died
	DeathEffect: RemoteEvent,
	-- client -> server: (targetUserId: number) whom to spectate, 0 = stop
	SpectateRequest: RemoteEvent,
	-- server -> one client: (snapshot: Types.DataSnapshot) points, owned abilities, loadouts
	PlayerData: RemoteEvent,
	-- client -> server: ("Buy", abilityId) or ("Equip", role, slot, abilityId or "")
	ShopRequest: RemoteEvent,
	-- server -> one client: (ok: boolean, message: string) answer to a shop request
	ShopResult: RemoteEvent,
	-- client -> server: (slot: number, aim: Vector3?) use an equipped ability
	UseAbility: RemoteEvent,
	-- server -> one client: (slots: { Types.AbilitySlotState }) equipped abilities this round
	AbilityState: RemoteEvent,
	-- server -> one client: (seconds: number) Blind Flash fog on the screen
	BlindFlash: RemoteEvent,
	-- server -> one client: ("FeatherFall", seconds, maxFallSpeed) effects the character's owner
	-- must simulate (the client owns its character's physics)
	AbilityEffect: RemoteEvent,
}

local NAMES = {
	"RoleBanner",
	"KillFeed",
	"RoundResults",
	"TrapActivated",
	"DeathEffect",
	"SpectateRequest",
	"PlayerData",
	"ShopRequest",
	"ShopResult",
	"UseAbility",
	"AbilityState",
	"BlindFlash",
	"AbilityEffect",
}

local folder: Instance
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		folder = created
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local remotes: { [string]: RemoteEvent } = {}
for _, name in NAMES do
	remotes[name] = folder:WaitForChild(name) :: RemoteEvent
end

return (remotes :: any) :: Remotes
