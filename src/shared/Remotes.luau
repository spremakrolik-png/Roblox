--!strict
-- Every RemoteEvent in the game. The server creates them, clients wait for them.
-- Phase 1 has no client -> server remotes: the only player input is where they stand.

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
}

local NAMES = { "RoleBanner", "KillFeed", "RoundResults" }

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
