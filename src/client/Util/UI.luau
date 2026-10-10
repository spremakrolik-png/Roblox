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

return UI
