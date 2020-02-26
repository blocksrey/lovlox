local meta = {}
meta.__index = meta

local function new(x, y, z)
	local self = {}

	self.x = x
	self.y = y
	self.z = z

	return setmetatable(self, meta)
end

function meta.Dot(a, b)
	return a.x*b.x + a.y*b.y + a.z*b.z
end

function meta.Cross(a, b)
	return new(
		a.y*b.z - a.z*b.y,
		a.z*b.x - a.x*b.z,
		a.x*b.y - a.y*b.x
	)
end

local Vector3 = {}

Vector3.new = new

return Vector3
