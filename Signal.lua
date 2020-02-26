local Event = require("lovlox/Event")

local meta = {}
meta.__index = meta
local Signal = {}

function Signal.new()
	local self = {}
	self.events = {}
	return setmetatable(self, meta)
end

function Signal.update(self, ...)
	for index, event in next, self.events do
		event.func(...)
	end
end

--meta funcs
function meta.Connect(self, func)
	local event = Event.new(func)
	table.insert(self.events, event)
	return event
end

meta.__call = Signal.update

return Signal