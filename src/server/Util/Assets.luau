--!strict
-- Optional hand-made models. Anything placed in ReplicatedStorage.Assets with the right
-- name replaces the generated placeholder; when it is missing we build from primitives.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "Assets"

local Assets = {}

-- Returns a fresh clone of ReplicatedStorage.Assets[name], or nil when there is no such Model.
function Assets.cloneModel(name: string): Model?
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		return nil
	end
	local template = folder:FindFirstChild(name)
	if template and template:IsA("Model") then
		return template:Clone()
	end
	return nil
end

-- Finds a BasePart named `name` anywhere inside `model`.
function Assets.findPart(model: Instance, name: string): BasePart?
	local found = model:FindFirstChild(name, true)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

return Assets
