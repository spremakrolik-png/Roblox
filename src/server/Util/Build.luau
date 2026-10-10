--!strict
-- Small helpers for building geometry out of primitives.

local Build = {}

export type PartProps = {
	name: string?,
	size: Vector3,
	cframe: CFrame,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	shape: Enum.PartType?,
	canCollide: boolean?,
	canTouch: boolean?,
	canQuery: boolean?,
	castShadow: boolean?,
	physics: PhysicalProperties?,
	parent: Instance?,
}

function Build.part(props: PartProps): Part
	local part = Instance.new("Part")
	part.Name = props.name or "Part"
	part.Anchored = true
	if props.shape then
		part.Shape = props.shape
	end
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(200, 200, 200)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.canCollide ~= nil then
		part.CanCollide = props.canCollide
	end
	if props.canTouch ~= nil then
		part.CanTouch = props.canTouch
	end
	if props.canQuery ~= nil then
		part.CanQuery = props.canQuery
	end
	if props.physics then
		part.CustomPhysicalProperties = props.physics
	end
	if props.castShadow ~= nil then
		part.CastShadow = props.castShadow
	end
	part.Parent = props.parent
	return part
end

-- A vertical cylinder whose top surface is at `top` (world Y of `base` plus `top`).
function Build.pillar(
	name: string,
	base: CFrame,
	top: number,
	diameter: number,
	height: number,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	physics: PhysicalProperties?
): Part
	return Build.part({
		name = name,
		shape = Enum.PartType.Cylinder,
		physics = physics,
		size = Vector3.new(height, diameter, diameter),
		-- A cylinder's axis is its local X; roll it upright.
		cframe = base * CFrame.new(0, top - height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		color = color,
		material = material,
		parent = parent,
	})
end

-- A flat disc lying on the floor (used for the lobby circles).
function Build.disc(name: string, center: Vector3, radius: number, color: Color3, parent: Instance): Part
	return Build.part({
		name = name,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.4, radius * 2, radius * 2),
		cframe = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color = color,
		material = Enum.Material.Neon,
		transparency = 0.25,
		canCollide = false,
		canTouch = false,
		canQuery = false,
		castShadow = false,
		parent = parent,
	})
end

-- A part stretched between two points (ramps, beams, corridor floors).
function Build.span(
	name: string,
	from: Vector3,
	to: Vector3,
	width: number,
	thickness: number,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local length = (to - from).Magnitude
	return Build.part({
		name = name,
		size = Vector3.new(width, thickness, length),
		cframe = CFrame.lookAt((from + to) / 2, to),
		color = color,
		material = material,
		parent = parent,
	})
end

function Build.model(name: string, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- Big text on one face of a part.
function Build.sign(part: BasePart, face: Enum.NormalId, text: string, textColor: Color3): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = textColor
	label.TextScaled = true
	label.Parent = gui

	gui.Parent = part
	return label
end

-- Floating text above a part. Returns the frame so callers can add more labels.
function Build.billboard(adornee: BasePart, heightOffset: number, sizeStuds: Vector2): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Billboard"
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(sizeStuds.X, sizeStuds.Y)
	gui.StudsOffsetWorldSpace = Vector3.new(0, heightOffset, 0)
	gui.MaxDistance = 250
	gui.LightInfluence = 0
	gui.Parent = adornee
	return gui
end

function Build.textLabel(
	name: string,
	parent: Instance,
	text: string,
	color: Color3,
	position: UDim2,
	size: UDim2
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.4
	label.Parent = parent
	return label
end

return Build
