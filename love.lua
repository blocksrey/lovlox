local setfallback = setmetatable

--[[
setfallback(love, {
	__newindex = function(...)
		print('asdasd')
	end
})
]]




function scheduler_function()
	print('nigga')
end

print('asd')

local love = {}

love.graphics = {}
love.graphics.newShader = function() end
love.graphics.setDefaultFilter = function() end
love.graphics.getDimensions = function() end
love.graphics.newCanvas = function() end
love.graphics.newImage = function() end
love.update = function() end

love.keyboard = {}

love.timer = {}

love.filesystem = {}
love.filesystem.setIdentity = function() end

love.window = {}
love.window.setTitle = function() end

return love