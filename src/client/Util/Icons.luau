--!strict
-- Icons for abilities and shop items: an emoji glyph on a coloured tile.

export type Icon = { glyph: string, color: Color3 }

local Icons = {}

Icons.Abilities = {
	FeatherFall = { glyph = "☂", color = Color3.fromRGB(255, 130, 190) },
	SpeedBurst = { glyph = "⚡", color = Color3.fromRGB(70, 170, 255) },
	DoubleJump = { glyph = "⏫", color = Color3.fromRGB(110, 220, 140) },
	Dash = { glyph = "💨", color = Color3.fromRGB(150, 160, 255) },
	Shield = { glyph = "🛡", color = Color3.fromRGB(255, 200, 70) },
	Sprint = { glyph = "🏃", color = Color3.fromRGB(255, 110, 90) },
	BlindFlash = { glyph = "✨", color = Color3.fromRGB(240, 230, 130) },
	RemoteTrigger = { glyph = "📡", color = Color3.fromRGB(200, 120, 255) },
	TrapRecharge = { glyph = "🔄", color = Color3.fromRGB(255, 160, 60) },
	SlowCannon = { glyph = "❄", color = Color3.fromRGB(80, 200, 255) },
} :: { [string]: Icon }

Icons.Passes = {
	DoublePoints = { glyph = "⭐", color = Color3.fromRGB(255, 190, 60) },
	ExtraSlot = { glyph = "➕", color = Color3.fromRGB(90, 200, 120) },
	VIP = { glyph = "👑", color = Color3.fromRGB(255, 200, 40) },
} :: { [string]: Icon }

Icons.Points = { glyph = "💰", color = Color3.fromRGB(240, 180, 50) } :: Icon
Icons.SecondChance = { glyph = "❤", color = Color3.fromRGB(255, 80, 110) } :: Icon
Icons.Unknown = { glyph = "?", color = Color3.fromRGB(120, 125, 140) } :: Icon

function Icons.ability(id: string): Icon
	return Icons.Abilities[id] or Icons.Unknown
end

return Icons
