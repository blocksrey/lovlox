local game = require("lovlox/game")

game.ReplicatedFirst = {}

local meta = {}
meta.__index = meta

function meta.RemoveDefaultLoadingScreen(serv)
	print("remove default loading screen")
end

local service = {}

setmetatable(service, meta)

game.ReplicatedFirst = service
