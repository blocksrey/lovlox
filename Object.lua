local Signal = require("lovlox/Signal")

local meta = {}
meta.__index = meta

function meta.Destroy(self)

end

function meta.Clone(self)

end

local object = {}

function object.new(Parent)
	local self = {}

	self.ClassName = nil
	self.Parent  = Parent
	self.Changed = Signal.new()

	return setmetatable(self, meta)
end

return object