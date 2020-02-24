Instance = {}

function Instance.new(type, parent)
	local self = require("roblox/objects/"..type).new()
	
	if parent then
		self.Parent = parent
		parent[self] = self
	end

	function self:Clone()
	end

	function self:Destroy()
	end
	
	return self
end