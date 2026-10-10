--!strict
-- Jump limits of a default runner (no abilities), derived from GameConfig.
-- Every value already includes GameConfig.JumpSafetyMargin.

local GameConfig = require(script.Parent.Config.GameConfig)

local JumpMath = {}

local function factor(): number
	return 1 - GameConfig.JumpSafetyMargin
end

-- Highest ledge (studs above the take-off floor) a runner can safely jump onto.
function JumpMath.maxRise(): number
	local v = GameConfig.JumpPower
	return (v * v) / (2 * GameConfig.Gravity) * factor()
end

-- Widest edge-to-edge gap a runner can safely clear when landing `rise` studs higher
-- (negative = landing lower). Returns 0 when the ledge is out of reach.
function JumpMath.maxGap(rise: number?): number
	local h = rise or 0
	local v = GameConfig.JumpPower
	local g = GameConfig.Gravity
	local discriminant = v * v - 2 * g * h
	if discriminant < 0 then
		return 0
	end
	local airTime = (v + math.sqrt(discriminant)) / g
	return GameConfig.RunnerWalkSpeed * airTime * factor()
end

return JumpMath
