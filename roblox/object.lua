require("roblox/game")

local object = {}
local meta   = {}

local function object.new()
	return setmetatable(object, meta)
end

function meta:GetChildren()
	local final = {}
	for index, value in next, game do
		
	end
	return final
end