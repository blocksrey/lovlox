local v3   = Vector3.new
local c3   = Color3.new

local bow          = _G.load("bow")
local input        = _G.load("input")

local bowmodeldefaults = {
	framesize   = v3(1/5, 1, 1/10);
	stringsize  = v3(1/20, 7/5, 1/20);
	framecolor  = c3(1, 1, 1);
	stringcolor = c3(1, 1, 1);
}

local bow0    = bow.new({})
local bowmod0 = bow.newmodel(bowmodeldefaults, workspace)

local function onrest()
	
end

local function ondraw()
	
end

local function onrelease()
	--arrowhandler.newarrow(bowmod0.framemiddle.CFrame.p + bowmod0.framemiddle.CFrame.lookVector, bow0.s.p*256*bowmod0.framemiddle.CFrame.lookVector, Color3.new(math.random(), math.random(), math.random()))
end

input.began(function(io)
	if io.UserInputType == Enum.UserInputType.MouseButton1 then
		if bow.draw(bow0) then
			ondraw()
		end
	elseif io.UserInputType == Enum.UserInputType.MouseButton2 then
		if bow.rest(bow0) then
			onrest()
		end
	end
end)

input.ended(function(io)
	if io.UserInputType == Enum.UserInputType.MouseButton1 then
		if bow.release(bow0) then
			onrelease()
		end
	end
end)

game:GetService("RunService").RenderStepped:Connect(function()
	bow.update(bow0, tick())
	bow0.cf = workspace.CurrentCamera.CFrame*CFrame.new(3/4, -1/2, -2)
	bow.match(bowmod0, bow0)
end)

return nil
