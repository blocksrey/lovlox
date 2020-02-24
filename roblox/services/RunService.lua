require("roblox/game")
local event = require("roblox/Event")

local steppers = {}

local RunService = {}

RunService.RenderStepped = {}
function RunService.RenderStepped:Connect()
end

game.RunService = RunService
