local game = require("lovlox/game")

local meta = {}
meta.__index = meta

function meta.GetService(self, name)
	local serv = self[name]
	if serv then
		print("obtain service: "..name)
		return serv
	else
		print("no service: "..name)
		return nil
	end
end

setmetatable(game, meta)