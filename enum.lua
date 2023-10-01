local Enum = {}

local function register_enum(name, values)
	Enum[name] = {}
	for i = 1, #values do
		local v = values[i]
		Enum[name][v] = i - 1
	end
end

register_enum('PartType', {'Ball', 'Block', 'Cylinder', 'Tetahedron'})
register_enum('CameraType', {'Scriptable'})
register_enum('MeshType', {'Wedge'})
register_enum('KeyCode', {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'Space', 'F8'})
register_enum('MouseBehavior', {'LockCenter', 'Default', 'LockCurrentPosition'})

return Enum