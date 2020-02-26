local game   = require("lovlox/game")
local signal = require("lovlox/Signal")

local RunService = {}

RunService.RenderStepped = signal.new()

game.RunService = RunService

--[[
RunService.RenderStepped:Connect(function(...)
	print("RENDERSTEPPEDLOL:", ...)
end)

signal.update(RunService.RenderStepped, 1, "woah", 2, "this is cool")
]]