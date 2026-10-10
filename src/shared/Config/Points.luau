--!strict
-- Points awarded at the end of a round. Whole numbers; multipliers (x2 pass) apply to the round total.

return {
	RunnerPlaces = { 10, 5, 3 }, -- 1st, 2nd and 3rd to cross the finish
	RunnerFinish = 1, -- everyone else who finishes
	TrapperPerKill = 1, -- every runner killed by a trap
	TrapperWin = 5, -- all runners died
}
