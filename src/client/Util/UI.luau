--!strict
-- Tiny helpers for building UI in code. Sizes use Scale + constraints so they work on phones.

local UI = {}

UI.Colors = table.freeze({
	Panel = Color3.fromRGB(16, 18, 26),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(180, 188, 205),
	Runner = Color3.fromRGB(70, 170, 255),
	Trapper = Color3.fromRGB(255, 80, 80),
	Gold = Color3.fromRGB(255, 205, 60),
	Death = Color3.fromRGB(255, 120, 110),
})

export type LabelProps = {
	name: string,
	parent: Instance,
	text: string?,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	font: Enum.Font?,
	alignX: Enum.TextXAlignment?,
	maxTextSize: number?,
}

function UI.label(props: LabelProps): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = props.name
	label.BackgroundTransparency = 1
	label.Size = props.size
	label.Position = props.position or UDim2.new()
	label.AnchorPoint = props.anchor or Vector2.zero
	label.Text = props.text or ""
	label.TextColor3 = props.color or UI.Colors.Text
	label.Font = props.font or Enum.Font.SourceSansBold
	label.TextScaled = true
	label.TextXAlignment = props.alignX or Enum.TextXAlignment.Center
	label.TextStrokeTransparency = 0.5
	if props.maxTextSize then
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = props.maxTextSize
		constraint.Parent = label
	end
	label.Parent = props.parent
	return label
end

function UI.panel(name: string, parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor
	frame.BackgroundColor3 = UI.Colors.Panel
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

function UI.sizeLimit(parent: Instance, minSize: Vector2, maxSize: Vector2)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = minSize
	constraint.MaxSize = maxSize
	constraint.Parent = parent
end

function UI.padding(parent: Instance, pixels: number)
	local padding = Instance.new("UIPadding")
	local inset = UDim.new(0, pixels)
	padding.PaddingTop = inset
	padding.PaddingBottom = inset
	padding.PaddingLeft = inset
	padding.PaddingRight = inset
	padding.Parent = parent
end

function UI.screen(name: string, displayOrder: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder
	return gui
end

-- Polish ------------------------------------------------------------------------------

local TweenService = game:GetService("TweenService")

function UI.corner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

-- A vertical (rotation 90) or horizontal colour gradient over the object's background.
function UI.gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
end

function UI.stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

local function scaleOf(object: GuiObject): UIScale
	local existing = object:FindFirstChildOfClass("UIScale")
	if existing then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Parent = object
	return scale
end

-- Buttons squash when pressed and grow a little under the mouse.
function UI.pressable(button: GuiButton)
	local scale = scaleOf(button)
	local function to(value: number, seconds: number)
		TweenService:Create(scale, TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = value,
		}):Play()
	end
	button.MouseEnter:Connect(function()
		to(1.05, 0.15)
	end)
	button.MouseLeave:Connect(function()
		to(1, 0.15)
	end)
	button.MouseButton1Down:Connect(function()
		to(0.92, 0.08)
	end)
	button.MouseButton1Up:Connect(function()
		to(1.05, 0.2)
	end)
	button.Activated:Connect(function()
		scale.Scale = 0.9
		to(1, 0.3)
	end)
end

-- Panels and cards pop in with a little overshoot.
function UI.popIn(object: GuiObject)
	local scale = scaleOf(object)
	scale.Scale = 0.85
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

-- A rounded colour tile with an emoji icon (shop cards, ability buttons).
function UI.iconTile(parent: Instance, glyph: string, color: Color3, size: UDim2, position: UDim2?): Frame
	local tile = Instance.new("Frame")
	tile.Name = "Icon"
	tile.Size = size
	tile.Position = position or UDim2.new()
	tile.BackgroundColor3 = color
	tile.BorderSizePixel = 0
	UI.corner(tile, 10)
	UI.gradient(tile, color:Lerp(Color3.new(1, 1, 1), 0.35), color:Lerp(Color3.new(0, 0, 0), 0.25))
	UI.stroke(tile, Color3.new(1, 1, 1), 2, 0.55)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = tile
	local label = Instance.new("TextLabel")
	label.Name = "Glyph"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.52)
	label.Size = UDim2.fromScale(0.78, 0.78)
	label.Text = glyph
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = tile
	tile.Parent = parent
	return tile
end

return UI
