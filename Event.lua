local meta = {}
meta.__index = meta

function meta.Disconnect(self)
	self.func = nil
end

local Event = {}

function Event.new(func)
	local self = {}
	self.func = func
	return setmetatable(self, meta)
end

return Event