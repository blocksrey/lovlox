--global scope stuff
game     = require("lovlox/game")
Vector3  = require("lovlox/Vector3")
Color3   = require("lovlox/Color3")
CFrame   = require("lovlox/CFrame")
Instance = require("lovlox/Instance")
Enum     = require("lovlox/Enum")

--service instances
require("lovlox/Services/ReplicatedFirst")
require("lovlox/Services/RunService")
require("lovlox/Services/UserInputService")

require("lovlox/Service")

--enumerators
require("lovlox/Enums/KeyCode")
require("lovlox/Enums/Material")
require("lovlox/Enums/PartType")
require("lovlox/Enums/SurfaceType")



function _G.load(name)
	local find = require("lovlox/test/"..name)
	if find then
		print("load: "..name)
		return find
	else
		print("no find: "..name)
		return nil
	end
end

require("lovlox/test/main")



local lovlox = {}

function lovlox.update(t1)
end

function lovlox.render(meshes)
end

return lovlox