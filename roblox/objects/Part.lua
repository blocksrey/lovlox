local part = {}
local meta = {}

function part.new()
	return setmetatable(part, meta)
end

function meta.__index(index)
	return meta[index]
end

return part