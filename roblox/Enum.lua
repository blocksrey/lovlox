local enum = {}
local meta = {}

local function new(name, ...)

end

setmetatable(enum, meta)

meta.__index = function(index)

end

new("SmoothPlastic", "Material", "SmoothPlastic")
new("Smooth", "Material", "Smooth")

Enum = {
	Material = {};
	SurfaceType = {};
	PartType = {};
}