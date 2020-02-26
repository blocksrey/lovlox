local meta = {}
meta.__index = meta

local Instance = {}

function Instance.new(type, parent)
	local self = require("lovlox/Objects/"..type).new()
	return setmetatable(self, meta)
end

return Instance