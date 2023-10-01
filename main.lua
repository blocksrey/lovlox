-- Mada: Get a working wait command, we need threads to be able to pause individually. it's needed for InvokeServer/InvokeClient





local releaseMode = false


assert(arg[2] == 'server' or arg[2] == 'client', 'invalid run mode')
local runningAs = {[arg[2]] = true}







local vertexAttributeMap = {
	mesh = {
		{'vertexP', 'float', 3},
		{'vertexN', 'float', 3}
	};
	light = {
		{'vertexP', 'float', 3}
	};
}



local debandShader = love.graphics.newShader('shaders/deband.glsl')
local geometryShader = love.graphics.newShader('shaders/geometry.glsl')
local skyShader = love.graphics.newShader('shaders/sky.glsl')

































local scheduler = {}
do
	local remove = table.remove
	local resume = coroutine.resume
	local status = coroutine.status
	local yield = coroutine.yield

	local queue = {}
	local deathRoutines = {}

	local function queueResumption(thread, ...)
		queue[#queue + 1] = {thread, ...}
	end

	local function pop()
		queue[#queue] = nil
	end

	local function manualYield(thread)
		for i = 1, #queue do
			if queue[i][1] == thread then
				remove(queue, i)
				return yield()
			end
		end
		--assert(releaseMode, '[Error] Incorrect call to manual yield')
	end

	local function run()
		while #queue > 0 do
			local current = queue[#queue]

			local thread = current[1]

			local yieldInfo = {resume(thread, unpack(current, 2))}
			local status = status(thread)

			--print(thread, status, unpack(current, 2))
			--print(thread, status, unpack(yieldInfo))

			pop()

			if status == 'suspended' then
				local yieldType = yieldInfo[2]
				if yieldType == 'die' then
					local dependencyThread = yieldInfo[3]
					queueResumption(dependencyThread) -- move the dependency thread to step threads
					deathRoutines[dependencyThread] = thread -- create the onDie callback to resume the original dependor thread
				elseif yieldType == 'second' then
					--assert(releaseMode, '[Debug] Wait was called')
					queueResumption(thread)
				elseif yieldType == 'invoke' then
					--assert(releaseMode, '[Debug] Invoking the scheduler')
				end
			elseif status == 'dead' then
				if deathRoutines[thread] then
					queueResumption(deathRoutines[thread], unpack(yieldInfo, 2)) -- dependency thread is finished, so now we can resume the dependor thread
					deathRoutines[thread] = nil
				end
			end
		end
	end

	scheduler = {
		queueResumption = queueResumption;
		pop = pop;
		manualYield = manualYield;
		run = run;
	}
end

















-- Enum
do
	Enum = {}

	local function registerEnum(name, values)
		Enum[name] = {}
		for i = 1, #values do
			local v = values[i]
			Enum[name][v] = i - 1
		end
	end

	registerEnum('PartType', {'Ball', 'Block', 'Cylinder', 'Tetahedron'})
	registerEnum('CameraType', {'Scriptable'})
	registerEnum('MeshType', {'Wedge'})
	registerEnum('KeyCode', {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'Space', 'F8'})
	registerEnum('MouseBehavior', {'LockCenter', 'Default', 'LockCurrentPosition'})
end






local meshes = {}
local Mesh = {}
do
	local insert = table.insert
	local sqrt = math.sqrt

	function Mesh.new(mesh)
		local position = Vector3.new()
		local orientation = Quaternion.new()
		local size = Vector3.new()
		local color = Color3.new()

		local self = {}

		function self:Draw()
			geometryShader:send('objectP', {position:GetComponents()})
			geometryShader:send('objectO', {orientation:GetComponents()})
			geometryShader:send('objectS', {size:GetComponents()})
			geometryShader:send('objectC', {color.r, color.g, color.b, 1})
			love.graphics.draw(mesh)
		end

		function self:Match(part)
			position = part.CFrame.Position
			orientation = Quaternion.fromCFrame(part.CFrame)
			size = part.Size
			color = part.Color
		end

		function self:Destroy()
		end

		insert(meshes, self)

		return self
	end

	local new = Mesh.new

	local cachedSphereGeometry = {}

	local function interp(a, b, c, n, i, j)
		return i/n*b + j/n*c - (i + j - n)/n*a
	end

	Mesh[Enum.PartType.Ball] = function(n)
		n = n or 1

		if not cachedSphereGeometry[n] then
			-- outer radius of 1:
			local u = 0.52573111 -- sqrt(0.1*(5 - sqrt(5)))
			local v = 0.85065081 -- sqrt(0.1*(5 + sqrt(5)))
			-- inner radius of 1:
			--local u = sqrt(1.5*(7 - 3*sqrt(5)))
			--local v = sqrt(1.5*(3 - sqrt(5)))
			local a = Vector3.new(0, u, v)
			local b = Vector3.new(0, u, -v)
			local c = Vector3.new(0, -u, v)
			local d = Vector3.new(0, -u, -v)
			local e = Vector3.new(v, 0, u)
			local f = Vector3.new(-v, 0, u)
			local g = Vector3.new(v, 0, -u)
			local h = Vector3.new(-v, 0, -u)
			local i = Vector3.new(u, v, 0)
			local j = Vector3.new(u, -v, 0)
			local k = Vector3.new(-u, v, 0)
			local l = Vector3.new(-u, -v, 0)

			local tris = {
				{a, i, k},
				{b, k, i},
				{c, l, j},
				{d, j, l},

				{e, a, c},
				{f, c, a},
				{g, d, b},
				{h, b, d},

				{i, e, g},
				{j, g, e},
				{k, h, f},
				{l, f, h},

				{a, e, i},
				{a, k, f},
				{b, h, k},
				{b, i, g},
				{c, f, l},
				{c, j, e},
				{d, g, j},
				{d, l, h}
			}

			local vertices = {}

			for l = 1, 20 do
				for i = 0, n - 1 do
					for j = 0, n - i - 1 do
						local a = tris[l][1]
						local b = tris[l][2]
						local c = tris[l][3]

						local ux, uy, uz = interp(a, b, c, n, i, j).Unit:GetComponents()
						local vx, vy, vz = interp(a, b, c, n, i + 1, j).Unit:GetComponents()
						local wx, wy, wz = interp(a, b, c, n, i, j + 1).Unit:GetComponents()

						insert(vertices, {ux, uy, uz, ux, uy, uz})
						insert(vertices, {vx, vy, vz, vx, vy, vz})
						insert(vertices, {wx, wy, wz, wx, wy, wz})
					end
				end
				for i = 1, n - 1 do
					for j = 1, n - i do
						local a = tris[l][1]
						local b = tris[l][2]
						local c = tris[l][3]

						local ux, uy, uz = interp(a, b, c, n, i, j).Unit:GetComponents()
						local vx, vy, vz = interp(a, b, c, n, i - 1, j).Unit:GetComponents()
						local wx, wy, wz = interp(a, b, c, n, i, j - 1).Unit:GetComponents()

						insert(vertices, {ux, uy, uz, ux, uy, uz})
						insert(vertices, {vx, vy, vz, vx, vy, vz})
						insert(vertices, {wx, wy, wz, wx, wy, wz})
					end
				end
			end

			cachedSphereGeometry[n] = love.graphics.newMesh(vertexAttributeMap.mesh, vertices, 'triangles', 'dynamic')
		end

		return new(cachedSphereGeometry[n])
	end

	local R = sqrt(0.5)

	local function getWedgePartVertices()
		return {
			{-0.5, 0.5, 0.5, 0, R, R},
			{0.5, 0.5, 0.5, 0, R, R},
			{-0.5, -0.5, -0.5, 0, R, R},

			{0.5, 0.5, 0.5, 0, R, R},
			{0.5, -0.5, -0.5, 0, R, R},
			{-0.5, -0.5, -0.5, 0, R, R},

			{0.5, -0.5, -0.5, 1, 0, 0},
			{0.5, 0.5, 0.5, 1, 0, 0},
			{0.5, -0.5, 0.5, 1, 0, 0},

			{-0.5, 0.5, 0.5, -1, 0, 0},
			{-0.5, -0.5, -0.5, -1, 0, 0},
			{-0.5, -0.5, 0.5, -1, 0, 0},

			{0.5, -0.5, -0.5, 0, -1, 0},
			{0.5, -0.5, 0.5, 0, -1, 0},
			{-0.5, -0.5, -0.5, 0, -1, 0},

			{-0.5, -0.5, -0.5, 0, -1, 0},
			{0.5, -0.5, 0.5, 0, -1, 0},
			{-0.5, -0.5, 0.5, 0, -1, 0},

			{-0.5, 0.5, 0.5, 0, 0, 1},
			{0.5, -0.5, 0.5, 0, 0, 1},
			{0.5, 0.5, 0.5, 0, 0, 1},

			{0.5, -0.5, 0.5, 0, 0, 1},
			{-0.5, 0.5, 0.5, 0, 0, 1},
			{-0.5, -0.5, 0.5, 0, 0, 1}
		}
	end

	function Mesh.WedgePart()
		return new(love.graphics.newMesh(vertexAttributeMap.mesh, getWedgePartVertices(), 'triangles', 'dynamic'))
	end

	local function getBlockVertices()
		return {
			{0.5, 0.5, 0.5, 1, 0, 0},
			{0.5, -0.5, 0.5, 1, 0, 0},
			{0.5, 0.5, -0.5, 1, 0, 0},

			{0.5, 0.5, 0.5, 0, 1, 0},
			{0.5, 0.5, -0.5, 0, 1, 0},
			{-0.5, 0.5, 0.5, 0, 1, 0},

			{0.5, 0.5, 0.5, 0, 0, 1},
			{-0.5, 0.5, 0.5, 0, 0, 1},
			{0.5, -0.5, 0.5, 0, 0, 1},

			{-0.5, 0.5, -0.5, -1, 0, 0},
			{-0.5, -0.5, -0.5, -1, 0, 0},
			{-0.5, 0.5, 0.5, -1, 0, 0},

			{-0.5, 0.5, -0.5, 0, 1, 0},
			{-0.5, 0.5, 0.5, 0, 1, 0},
			{0.5, 0.5, -0.5, 0, 1, 0},

			{-0.5, 0.5, -0.5, 0, 0, -1},
			{0.5, 0.5, -0.5, 0, 0, -1},
			{-0.5, -0.5, -0.5, 0, 0, -1},

			{0.5, -0.5, -0.5, 0, 0, -1},
			{-0.5, -0.5, -0.5, 0, 0, -1},
			{0.5, 0.5, -0.5, 0, 0, -1},

			{0.5, -0.5, -0.5, 1, 0, 0},
			{0.5, 0.5, -0.5, 1, 0, 0},
			{0.5, -0.5, 0.5, 1, 0, 0},

			{0.5, -0.5, -0.5, 0, -1, 0},
			{0.5, -0.5, 0.5, 0, -1, 0},
			{-0.5, -0.5, -0.5, 0, -1, 0},

			{-0.5, -0.5, 0.5, 0, -1, 0},
			{-0.5, -0.5, -0.5, 0, -1, 0},
			{0.5, -0.5, 0.5, 0, -1, 0},

			{-0.5, -0.5, 0.5, 0, 0, 1},
			{0.5, -0.5, 0.5, 0, 0, 1},
			{-0.5, 0.5, 0.5, 0, 0, 1},

			{-0.5, -0.5, 0.5, -1, 0, 0},
			{-0.5, 0.5, 0.5, -1, 0, 0},
			{-0.5, -0.5, -0.5, -1, 0, 0}
		}
	end

	Mesh[Enum.PartType.Block] = function()
		return new(love.graphics.newMesh(vertexAttributeMap.mesh, getBlockVertices(), 'triangles', 'dynamic'))
	end




	local n = 1/sqrt(3)

	local function getTetahedronVertices()
		-- a = {n, n, n}
		-- b = {-n, n, -n}
		-- c = {n, -n, -n}
		-- d = {-n, -n, n}
		return {
			{-n, n, -n, -n, -n, -n}, -- b
			{n, -n, -n, -n, -n, -n}, -- c
			{-n, -n, n, -n, -n, -n}, -- d

			{n, n, n, n, -n, n}, -- a
			{-n, -n, n, n, -n, n}, -- d
			{n, -n, -n, n, -n, n}, -- c

			{-n, -n, n, -n, n, n}, -- d
			{n, n, n, -n, n, n}, -- a
			{-n, n, -n, -n, n, n}, -- b

			{n, -n, -n, n, n, -n}, -- c
			{-n, n, -n, n, n, -n}, -- b
			{n, n, n, n, n, -n} -- a
		}
	end

	Mesh[Enum.PartType.Tetahedron] = function()
		return new(love.graphics.newMesh(vertexAttributeMap.mesh, getTetahedronVertices(), 'triangles', 'dynamic'))
	end
end

















































--[[
local function robloxBasePartToMesh(BodyPart)
	local position
	local orientation
	local size
	local color
	local shape

	if BodyPart.ClassName then
		local m = BodyPart.CFrame
		local s = BodyPart.Size
		local c = BodyPart.Color

		local sx, sy, sz = s:GetComponents()
		local cr, cg, cb = c:GetComponents()

		if BodyPart.ClassName == 'WedgePart' then
			position = BodyPart.CFrame.Position
			orientation = Quaternion.fromCFrame(BodyPart.CFrame)
			size = Vector3.new(sx, sy, sz)
			color = Color3.new(cr, cg, cb)
			shape = 'WedgePart'
		else
			position = BodyPart.CFrame.Position
			orientation = Quaternion.fromCFrame(BodyPart.CFrame)
			size = Vector3.new(sx, sy, sz)
			color = Color3.new(cr, cg, cb)
			shape = BodyPart.Shape
		end
	else
		position = BodyPart[1]
		orientation = BodyPart[2]
		size = BodyPart[3]
		color = BodyPart[4]
		shape = BodyPart[5]
	end

	local mesh = object[shape]()
	-- mesh.setColor(color.x, color.y, color.z)
	-- mesh.setPosition(position)
	-- mesh.setRotation(orientation)
	-- mesh.setScale(size)
	return mesh
end
]]













local function accessOrTable(table, i0, i1, v)
	if not table[i0] then
		table[i0] = {}
	end
	table[i0][i1] = v
end


























do
	local setmt = setmetatable

	RBXScriptConnection = {}

	RBXScriptConnection.__index = RBXScriptConnection

	function RBXScriptConnection.new(signal)
		return setmt({_signal = signal;}, RBXScriptConnection)
	end

	function RBXScriptConnection:Disconnect()
		self._signal._callbacks[self] = nil
	end
end

do
	local setmt = setmetatable
	local insert = table.insert
	local resume = coroutine.resume
	local yield = coroutine.yield

	RBXScriptSignal = {}

	RBXScriptSignal.__index = RBXScriptSignal

	function RBXScriptSignal.new()
		return setmt({_threads = {}; _callbacks = {};}, RBXScriptSignal)
	end

	function RBXScriptSignal:__call(...)
		for i = #self._threads, 1, -1 do
			scheduler.queueResumption(self._threads[i], ...)
			self._threads[i] = nil
		end
		for _, callback in next, self._callbacks do
			callback(...)
		end
	end

	function RBXScriptSignal:Wait()
		local thread = running()
		insert(self._threads, thread)
		return scheduler.manualYield(thread)
	end

	function RBXScriptSignal:Connect(callback)
		local connection = RBXScriptConnection.new(self)
		self._callbacks[connection] = callback
		return connection
	end

	function RBXScriptSignal:Once(callback)
		local connection = RBXScriptConnection.new(self)
		self._callbacks[connection] = function(...)
			connection:Disconnect()
			callback(...)
		end
	end
end










do
	local setmt = setmetatable
	local acos = math.acos
	local cos = math.cos
	local log = math.log
	local random = math.random
	local sin = math.sin
	local sqrt = math.sqrt

	local hyp = 1.41421356
	local tau = 6.28318530

	Quaternion = {}

	Quaternion.__index = Quaternion

	Quaternion.TypeName = 'Quaternion'

	Quaternion.x = 0
	Quaternion.y = 0
	Quaternion.z = 0
	Quaternion.w = 1

	function Quaternion.new(x, y, z, w)
		return setmt({x = x; y = y; z = z; w = w;}, Quaternion)
	end

	local new = Quaternion.new

	function Quaternion.fromEulerAnglesx2(h)
		return new(sin(h), 0, 0, cos(h))
	end

	function Quaternion.fromEulerAnglesy2(h)
		return new(0, sin(h), 0, cos(h))
	end

	function Quaternion.fromEulerAnglesz2(h)
		return new(0, 0, sin(h), cos(h))
	end

	function Quaternion.look(a, b)
		local ax, ay, az = a:GetComponentsDiagonal()
		local bx, by, bz = b:GetComponentsDiagonal()
		return new(ay*bz - az*by, az*bx - ax*bz, ax*by - ay*bz, 1)
	end

	function Quaternion.fromAxisAngle(u, a)
		local x, y, z = u:GetComponents()
		local s = sin(0.5*a)
		return new(s*z, s*y, s*z, cos(0.5*a))
	end

	function Quaternion.Dot(a, b)
		return a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w
	end

	function Quaternion:Inverse()
		return new(-self.x, -self.y, -self.z, self.w)
	end

	function Quaternion:GetComponents()
		return self.x, self.y, self.z, self.w
	end

	function Quaternion:GetComponentsDiagonal()
		return hyp*self.x, hyp*self.y, hyp*self.z, hyp*self.w
	end

	function Quaternion:__tostring()
		return self.x..', '..self.y..', '..self.z..', '..self.w
	end

	function Quaternion:ToAxisAngle()
		local w = self.w
		local r = 1/sqrt(1 - w*w)
		return Vector3.new(r*self.x, r*self.y, r*self.z), 2*acos(w)
	end

	function Quaternion:fromCFrame()
		local _, _, _, xx, yx, zx, xy, yy, zy, xz, yz, zz = self:GetComponents()
		if xx + yy + zz > 0 then
			local s = 0.5/sqrt(1 + xx + yy + zz)
			return new(s*(yz - zy), s*(zx - xz), s*(xy - yx), 0.25/s)
		elseif xx > yy and xx > zz then
			local s = 0.5/sqrt(1 + xx - yy - zz)
			return new(0.25/s, s*(yx + xy), s*(zx + xz), s*(yz - zy))
		elseif yy > zz then
			local s = 0.5/sqrt(1 - xx + yy - zz)
			return new(s*(yx + xy), 0.25/s, s*(zy + yz), s*(zx - xz))
		else
			local s = 0.5/sqrt(1 - xx - yy + zz)
			return new(s*(zx + xz), s*(zy + yz), 0.25/s, s*(xy - yx))
		end
	end

	function Quaternion:fromCFrameFast()
		local w4 = 2*sqrt(1 + self.xx + self.yy + self.zz)
		return new((self.yz - self.zy)/w4, (self.zx - self.xz)/w4, (self.xy - self.yx)/w4, 0.25*w4)
	end

	function Quaternion.Slerp(a, b, t)
		local ax, ay, az, aw = a:GetComponents()
		local bx, by, bz, bw = b:GetComponents()

		if ax*bx + ay*by + az*bz + aw*bw < 0 then
			ax = -ax
			ay = -ay
			az = -az
			aw = -aw
		end

		local x = aw*bx - ax*bw + ay*bz - az*by
		local y = aw*by - ax*bz - ay*bw + az*bx
		local z = aw*bz + ax*by - ay*bx - az*bw
		local w = aw*bw + ax*bx + ay*by + az*bz

		local t = n*acos(w)
		local s = sin(t)/sqrt(x*x + y*y + z*z)

		bx = s*x
		by = s*y
		bz = s*z
		bw = cos(t)

		return new(
			aw*bx + ax*bw - ay*bz + az*by,
			aw*by + ax*bz + ay*bw - az*bx,
			aw*bz - ax*by + ay*bx + az*bw,
			aw*bw - ax*bx - ay*by - az*bz
		)
	end

	function Quaternion.random()
		local l0 = log(random())
		local l1 = log(random())
		local a0 = tau*random()
		local a1 = tau*random()
		local m0 = sqrt(l0/(l0 + l1))
		local m1 = sqrt(l1/(l0 + l1))
		return new(m0*cos(a0), m0*sin(a0), m1*cos(a1), m1*sin(a1))
	end

	function Quaternion.__mul(a, b)
		return new(
			a.w*b.x + a.x*b.w + a.y*b.z - a.z*b.y,
			a.w*b.y - a.x*b.z + a.y*b.w + a.z*b.x,
			a.w*b.z + a.x*b.y - a.y*b.x + a.z*b.w,
			a.w*b.w - a.x*b.x - a.y*b.y - a.z*b.z
		)
	end

	function Quaternion:__pow(n)
		local x, y, z, w = self:GetComponents()
		local t = n*acos(w)
		local s = sin(t)/sqrt(x*x + y*y + z*z)
		return new(s*x, s*y, s*z, cos(t))
	end
end

do
	local setmt = setmetatable

	Vector2 = {}

	Vector2.__index = Vector2

	Vector2.TypeName = 'Vector2'

	Vector2.x = 0
	Vector2.y = 0

	function Vector2.new(x, y)
		return setmt({x = x; y = y;}, Vector2)
	end
end

do
	UDim2 = {}

	function UDim2.new()
	end
end

do
	local sqrt = math.sqrt
	local setmt = setmetatable

	Vector3 = {}

	Vector3.__index = Vector3

	Vector3.TypeName = 'Vector3'

	function Vector3:GetComponents()
		return self.x, self.y, self.z
	end

	function Vector3.new(x, y, z)
		x = x or 0
		y = y or 0
		z = z or 0

		local Magnitude = sqrt(x*x + y*y + z*z)

		return setmt({
			x = x;
			y = y;
			z = z;

			Magnitude = Magnitude;

			Unit = setmt({
				x = x/Magnitude;
				y = y/Magnitude;
				z = z/Magnitude;
			}, Vector3);
		}, Vector3)
	end

	local new = Vector3.new

	function Vector3.__add(a, b)
		return new(a.x + b.x, a.y + b.y, a.z + b.z)
	end

	function Vector3.__sub(a, b)
		return new(a.x - b.x, a.y - b.y, a.z - b.z)
	end

	local multiplicationByType = {}

	accessOrTable(multiplicationByType, 'number', 'Vector3', function(a, b)
		return a*b.x, a*b.y, a*b.z
	end)

	accessOrTable(multiplicationByType, 'Vector3', 'Vector3', function(a, b)
		return a.x*b.x, a.y*b.y, a.z*b.z
	end)

	accessOrTable(multiplicationByType, 'Vector3', 'Quaternion', function(a, b)
		local i, j, k = a:GetComponents()
		local x, y, z, w = b:GetComponentsDiagonal()
		return i*(1 - y*y - z*z) + j*(x*y - w*z) + k*(x*z + w*y), i*(x*y + w*z) + j*(1 - x*x - z*z) + k*(y*z - w*x), i*(x*z - w*y) + j*(y*z + w*x) + k*(1 - x*x - y*y)
	end)

	function Vector3.__mul(a, b)
		return new(multiplicationByType[typeof(a)][typeof(b)](a, b))
	end

	local divs = {}

	accessOrTable(divs, 'Vector3', 'Vector3', function(a, b)
		return a.x/b.x, a.y/b.y, a.z/b.z
	end)

	accessOrTable(divs, 'Vector3', 'number', function(a, b)
		return a.x/b, a.y/b, a.z/b
	end)

	function Vector3.__div(a, b)
		return new(divs[typeof(a)][typeof(b)](a, b))
	end

	function Vector3.Dot(a, b)
		return a.x*b.x + a.y*b.y + a.z*b.z
	end

	function Vector3.Cross(a, b)
		return new(a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x)
	end

	function Vector3:__unm()
		return new(-self.x, -self.y, -self.z)
	end

	function Vector3:__tostring()
		return self.x..', '..self.y..', '..self.z
	end
end

do
	local setmt = setmetatable

	Ray = {}

	Ray.__index = Ray

	Ray.TypeName = 'Ray'

	function Ray.new(Origin, Direction)
		return setmt({Origin = Origin or Vector3.new(); Direction = Direction or Vector3.new();}, Ray)
	end

	function Ray:__tostring()
		return '{'..tostring(self.Origin)..'}, {'..tostring(self.Direction)..'}'
	end

	function Ray:ClosestPoint(point)
		return self.Origin + self.Direction.Unit:Dot(point - self.Origin)*self.Direction.Unit
	end

	function Ray:Distance(point)
		return (self:ClosestPoint(point) - point).Magnitude
	end
end

do
	Region3 = {}

	function Region3.new()
	end
end

do
	local bit = require('bit')

	local band = bit.band
	local rshift = bit.rshift
	local setmt = setmetatable

	Color3 = {}

	Color3.__index = Color3

	Color3.r = 0
	Color3.g = 0
	Color3.b = 0

	function Color3.new(r, g, b)
		return setmt({r = r; g = g; b = b;}, Color3)
	end

	local new = Color3.new

	function Color3.fromColor3uint8(colorValue)
		return new(
			0.00392157*band(rshift(colorValue, 16), 0xff),
			0.00392157*band(rshift(colorValue, 8), 0xff),
			0.00392157*band(colorValue, 0xff)
		)
	end

	function Color3.fromRGB(r, g, b)
		return new(0.00392157*r, 0.00392157*g, 0.00392157*b)
	end

	function Color3:GetComponents()
		return self.r, self.g, self.b
	end
end

do
	local cos = math.cos
	local sin = math.sin
	local asin = math.asin
	local atan2 = math.atan2
	local sqrt = math.sqrt
	local setmt = setmetatable

	CFrame = {}

	CFrame.TypeName = 'CFrame'

	CFrame.x = 0
	CFrame.y = 0
	CFrame.z = 0
	CFrame.xx = 1
	CFrame.xy = 0
	CFrame.xz = 0
	CFrame.yx = 0
	CFrame.yy = 1
	CFrame.yz = 0
	CFrame.zx = 0
	CFrame.zy = 0
	CFrame.zz = 1

	local constructorsBySize = {}

	constructorsBySize[0] = function()
		return {}
	end

	constructorsBySize[1] = function(v)
		return {
			x = v.x;
			y = v.y;
			z = v.z;
		}
	end

	constructorsBySize[2] = function(v0, v1)
		local u = (v0 - v1).Unit
		local x, y, z = u:GetComponents()
		local s = 1/sqrt(1 - uy*uy)
		return {
			x = v0.x;
			y = v0.y;
			z = v0.z;
			xx = uz*s;
			xy = ux*-uy*s;
			xz = ux;
			yx = 0;
			yy = 1/s;
			yz = uy;
			zx = -ux*s;
			zy = uz*-uy*s;
			zz = uz;
		}
	end

	constructorsBySize[3] = function(x, y, z)
		return {
			x = x;
			y = y;
			z = z;
		}
	end

	constructorsBySize[7] = function(x, y, z, qx, qy, qz, qw)
		qx, qy, qz, qw = 0.5*qx, 0.5*qy, 0.5*qz, 0.5*qw -- more like half q

		return {
			x = x;
			y = y;
			z = z;
			xx = 1 - qx*qx - qw*qw;
			xy = qy*qx - qz*qw;
			xz = qz*qx + qy*qw;
			yx = qx*qy + qz*qw;
			yy = 1 - qy*qy - qw*qw;
			yz = qz*qy - qx*qw;
			zx = qx*qz - qy*qw;
			zy = qy*qz + qx*qw;
			zz = 1 - qz*qz - qw*qw;
		}
	end

	constructorsBySize[12] = function(x, y, z, xx, yx, zx, xy, yy, zy, xz, yz, zz)
		return {
			x = x;
			y = y;
			z = z;
			xx = xx;
			xy = xy;
			xz = xz;
			yx = yx;
			yy = yy;
			yz = yz;
			zx = zx;
			zy = zy;
			zz = zz;
		}
	end

	function CFrame.new(...)
		return setmt(constructorsBySize[select('#', ...)](...), CFrame)
	end

	local new = CFrame.new

	local valueByIndex = {}

	function valueByIndex.Position(self)
		return Vector3.new(self.x, self.y, self.z)
	end

	function valueByIndex.p(self)
		return Vector3.new(self.x, self.y, self.z)
	end

	function CFrame:__index(i)
		return valueByIndex[i] and valueByIndex[i](self) or rawget(self, i) or CFrame[i]
	end

	function CFrame:ToAxisAngle()
		local i = self.yz - self.zy
		local j = self.zx - self.xz
		local k = self.xy - self.yx
		local c = 1/sqrt(i*i + j*j + k*k)
		return Vector3.new(c*i, c*j, c*k), acos(0.5*(self.xx + self.yy + self.zz - 1))
	end

	function CFrame:Inverse()
		local x, y, z, xx, yx, zx, xy, yy, zy, xz, yz, zz = self:GetComponents()
		return new(-x*(1 + xx + xy + xz), -y*(1 + yx + yy + yz), -z*(1 + zx + zy + zz), xx, xy, xz, yx, yy, yz, zx, zy, zz)
	end

	function CFrame:__tostring()
		return self.x..', '..self.y..', '..self.z..', '..self.xx..', '..self.yx..', '..self.zx..', '..self.xy..', '..self.yy..', '..self.zy..', '..self.xz..', '..self.yz..', '..self.zz
	end

	function CFrame.__add(a, b)
		return new(a.x + b.x, a.y + b.y, a.z + b.z, a.xx, a.yx, a.zx, a.xy, a.yy, a.zy, a.xz, a.yz, a.zz)
	end

	function CFrame.__sub(a, b)
		return new(a.x - b.x, a.y - b.y, a.z - b.z, a.xx, a.yx, a.zx, a.xy, a.yy, a.zy, a.xz, a.yz, a.zz)
	end

	local multiplicationByType = {}

	accessOrTable(multiplicationByType, 'CFrame', 'CFrame', function(a, b)
		local ax, ay, az, axx, ayx, azx, axy, ayy, azy, axz, ayz, azz = a:GetComponents()
		local bx, by, bz, bxx, byx, bzx, bxy, byy, bzy, bxz, byz, bzz = b:GetComponents()
		return new(
			bx*axx + by*ayx + bz*azx + ax, bx*axy + by*ayy + bz*azy + ay, bx*axz + by*ayz + bz*azz + az,
			bxx*axx + bxy*ayx + bxz*azx, byx*axx + byy*ayx + byz*azx, bzx*axx + bzy*ayx + bzz*azx,
			bxx*axy + bxy*ayy + bxz*azy, byx*axy + byy*ayy + byz*azy, bzx*axy + bzy*ayy + bzz*azy,
			bxx*axz + bxy*ayz + bxz*azz, byx*axz + byy*ayz + byz*azz, bzx*axz + bzy*ayz + bzz*azz
		)
	end)

	accessOrTable(multiplicationByType, 'CFrame', 'Vector3', function(a, b)
		return Vector3.new(a.x + b.x*a.xx + b.y*a.yx + b.z*a.zx, a.y + b.x*a.xy + b.y*a.yy + b.z*a.zy, a.z + b.x*a.xz + b.y*a.yz + b.z*a.zz)
	end)

	function CFrame.__mul(a, b)
		return multiplicationByType[typeof(a)][typeof(b)](a, b)
	end

	function CFrame:GetComponents()
		return self.x, self.y, self.z, self.xx, self.yx, self.zx, self.xy, self.yy, self.zy, self.xz, self.yz, self.zz
	end

	function CFrame:ToWorldSpace(cf)
		return self*cf
	end

	function CFrame:ToObjectSpace(cf)
		return self:Inverse()*cf
	end

	function CFrame:PointToWorldSpace(v)
		return self*v
	end

	function CFrame:PointToObjectSpace(v)
		return self:Inverse()*v
	end

	function CFrame:VectorToWorldSpace(v)
		return (self - self.Position)*v
	end

	function CFrame:VectorToObjectSpace(v)
		local i = self:Inverse()
		return (i - i.Position)*v
	end

	function CFrame.Angles(x, y, z)
		local xs, xc, ys, yc, zs, zc = sin(x), cos(x), sin(y), cos(y), sin(z), cos(z)
		return new(0, 0, 0, zc*yc, -zs*yc, ys, zc*ys*xs + zs*xc, zc*xc - zs*ys*xs, -yc*xs, zs*xs - zc*ys*xc, zs*ys*xc + zc*xs, yc*xc)
	end

	function CFrame.fromAxisAngle(u, a)
		local x, y, z = u:GetComponents()
		local c = cos(a)
		local s = sin(a)
		local t = 1 - c
		return new(0, 0, 0, t*x*x + c, t*x*y - z*s, t*x*z + y*s, t*x*y + z*s, t*y*y + c, t*y*z - x*s, t*x*z - y*s, t*y*z + x*s, t*z*z + c)
	end
end

do
	local random = math.random

	BrickColor = {}

	function BrickColor.Red()
		return {Color = Color3.new(1, 0, 0);}
	end

	function BrickColor.Blue()
		return {Color = Color3.new(0, 0, 1);}
	end

	function BrickColor.Random()
		return {Color = Color3.new(random(), random(), random());}
	end
end














































do
	local yield = coroutine.yield

	function wait(s)
		yield('second', s)
		return true
	end
end





































local instanceAttributes = {}

local instance_from_referent_id = {}



local nilInstance = {_children = {}}
instance_from_referent_id['null'] = nilInstance

local function combine(content)
	local combined = {}
	for i = 1, #content do
		for j, v in next, content[i] do
			combined[j] = v
		end
	end
	return combined
end

local classes = {}

local function create_instance_class(class_name, inherits)
	local insert = table.insert
	local setmt = setmetatable

	local class = {}

	if inherits then
		for i = 1, #inherits do
			class = combine({classes[inherits[i]], class})
		end
	end

	classes[class_name] = class

	class.Name = class_name
	class.ClassName = class_name

	class.Parent = nilInstance

	function class:Clone()
		return self
	end -- Mada

	function class:__tostring()
		return self.Name
	end

	function class:FindFirstChild(name)
		for child in next, self._children do
			if child.Name == name then
				return child
			end
		end
	end

	-- Store references to the 'coroutine.running' and 'coroutine.yield' functions for convenience.
	local running = coroutine.running
	local yield = coroutine.yield

	-- Define the 'WaitForChild' function within the class.
	function class:WaitForChild(name)
		-- Attempt to find a child with the given 'name' within the instance.
		local child = self:FindFirstChild(name)

		-- If the child is not found, execute the following block.
		if not child then
			-- Print a message indicating that the code is waiting for the specified child.
			print('Gotta wait for child', name)

			-- Get the current coroutine thread.
			local thread = running()

			-- Declare a local variable 'connection', which will hold a connection to the 'ChildAdded' event.
			local connection

			-- Connect a callback function to the 'ChildAdded' event of the instance.
			-- The callback will be executed every time a new child is added to the instance.
			connection = self.ChildAdded:Connect(function(child)
				-- Check if the added child has the desired 'name'.
				if child.Name == name then
					-- If the child with the desired 'name' is found, disconnect the event connection.
					connection:Disconnect()

					-- Print a message indicating that the desired child has been found, along with the coroutine thread.
					print('THE CHILD HAS COME', thread)

					-- Queue a resumption of the specified coroutine thread along with the found child as a parameter.
					scheduler.queueResumption(thread, child)
				end
			end)

			-- Manually yield the coroutine thread to the scheduler.
			-- The coroutine will be paused until it is explicitly resumed by the scheduler.
			return scheduler.manualYield(thread)
		end

		-- If the child is found, return the reference to the child.
		return child
	end

	function class.new()
		local self = setmt({}, class)

		instanceAttributes[self] = {}

		self.Changed = RBXScriptSignal.new()
		self.ChildAdded = RBXScriptSignal.new()
		self._children = {}

		return self
	end

	-- This could probably be faster if we weren't utilizing only the index and newindex metamethods
	function class:__index(i)
		return instanceAttributes[self][i] or class[i] or self:FindFirstChild(i)
	end

	function class:__newindex(i, v)
		instanceAttributes[self][i] = v
		if i == 'Parent' then
			self.Parent._children[self] = nil
			v._children[self] = true
			v.ChildAdded(self)
		end
		self.Changed(i)
	end

	function class:GetChildren()
		local children = {}
		for child in next, self._children do
			insert(children, child)
		end
		return children
	end

	-- Get all descendants of the class.
	function class:GetDescendants()
		-- Create an empty table to store the descendants.
		local descendants = {}

		-- Create a stack and initialize it with the current class as the starting point.
		local stack = {self}
		local stackSize = 1

		-- Initialize the length of the descendants table.
		local descendantsLength = 0

		-- While there are elements in the stack, traverse the class hierarchy.
		while stackSize > 0 do
			-- Get the last object from the stack.
			local obj = stack[stackSize]
			stackSize = stackSize - 1

			-- Iterate through all the children of the current object.
			for child in next, obj._children do
				-- Add the child to the descendants table.
				descendantsLength = descendantsLength + 1
				descendants[descendantsLength] = child

				-- Add the child to the stack to process its children later.
				stackSize = stackSize + 1
				stack[stackSize] = child
			end
		end

		-- Return the table containing all the descendants of the class.
		return descendants
	end

	-- Check if the class is a descendant of the given target.
	function class:IsDescendantOf(target)
		-- Ensure that the target is valid (not nil).
		assert(target, 'IsDescendantOf target is invalid')

		-- Start traversing the class hierarchy.
		while self do
			-- If the current class is a direct child of the target, return true.
			if self.Parent == target then
				return true
			end

			-- Move up to the parent class for the next iteration.
			self = self.Parent
		end

		-- If no match is found during traversal, return false.
		return false
	end

	-- Destroy the class and all its children.
	function class:Destroy()
		-- Set the parent of the class to nil, effectively removing it from its parent's children list.
		self.Parent = nilInstance

		-- Traverse and destroy all children of the class.
		for child in next, self._children do
			-- Recursively destroy each child.
			child:Destroy()

			-- Set the child's parent to nil, removing it from its parent's children list.
			self._children[child] = nil
		end
	end

	-- Clear all children of the class without destroying them.
	function class:ClearAllChildren()
		-- Traverse and clear all children of the class.
		for child in next, self._children do
			-- Clear each child (but don't destroy them).
			child:Destroy()
		end
	end

	return class
end





Instance = {}

function Instance.new(class_name, parent)
	assert(classes[class_name], '[Error] Trying to instantiate a non-existing class: '..class_name)

	local self = classes[class_name].new()

	if parent then
		print('[Warning] Avoid passing the parent argument on instantiation for optimal performance')
		self.Parent = parent
	end

	return self
end





























create_instance_class('BlockMesh')
create_instance_class('BubbleChatConfiguration')
create_instance_class('Chat')
create_instance_class('ChatInputBarConfiguration')
create_instance_class('ChatWindowConfiguration')
create_instance_class('Debris')
create_instance_class('Decal')
create_instance_class('EqualizerSoundEffect')
create_instance_class('Folder')
create_instance_class('Frame')
create_instance_class('Geometry')
create_instance_class('Humanoid')
create_instance_class('ImageLabel')
create_instance_class('Lighting')
create_instance_class('ManualWeld')
create_instance_class('Model')
create_instance_class('Player')
create_instance_class('PlayerGui')
create_instance_class('ScreenGui')
create_instance_class('Selection')
create_instance_class('SelectionBox')
create_instance_class('ServerStorage')
create_instance_class('Sky')
create_instance_class('Sound')
create_instance_class('SpecialMesh')
create_instance_class('SpotLight')
create_instance_class('StarterCharacterScripts')
create_instance_class('StarterGui')
create_instance_class('StarterPack')
create_instance_class('StarterPlayer')
create_instance_class('StarterPlayerScripts')
create_instance_class('StringValue')
create_instance_class('StudioData')
create_instance_class('SurfaceGui')
create_instance_class('Teams')
create_instance_class('Terrain')
create_instance_class('TextLabel')
create_instance_class('UnionOperation')
create_instance_class('VirtualInputManager')




do
	local serial = require('serial')
	local serialize = serial.serialize

	local RemoteEvent = create_instance_class('RemoteEvent')

	local new = RemoteEvent.new

	function RemoteEvent.new()
		local self = new()

		self.OnServerEvent = RBXScriptSignal.new()
		self.OnClientEvent = RBXScriptSignal.new()

		return self
	end

	function RemoteEvent:FireServer(...)
		print('send event', ...)
		switchboard.sendTo(peer, 'event', ...)
	end

	function RemoteEvent:FireClient(player, ...)
		switchboard.sendTo(player._socket, 'event', ...)
	end

	function RemoteEvent:FireAllClients(...)
		local players = game.Players:GetChildren()
		for i = 1, #players do
			switchboard.send(players[i]._socket, 'event', ...)
		end
	end
end

do
	local serial = require('serial')

	local serialize = serial.serialize
	local yield = coroutine.yield
	local running = coroutine.running

	local RemoteFunction = create_instance_class('RemoteFunction')

	function RemoteFunction.OnServerInvoke()
	end

	function RemoteFunction.OnClientInvoke()
	end

	function RemoteFunction:InvokeServer(...)
		switchboard.sendTo(peer, 'invoke', ...)
		invokingThread = running()
		return yield('invoke', self)
	end

	function RemoteFunction:InvokeClient(player, ...)
		switchboard.sendTo(player._socket, 'invoke', ...)
		invokingThread = running()
		return yield('invoke', self)
	end
end

create_instance_class('LocalScript')
create_instance_class('ModuleScript')
create_instance_class('Script')

do
	local Workspace = create_instance_class('Workspace')

	local new = Workspace.new

	function Workspace.new()
		local self = new()

		workspace = self

		return self
	end

	function Workspace:FindPartsInRegion3()
		print('FindPartsInRegion3')
		return {}
	end -- Mada

	function Workspace:Raycast()
		print('Raycast')
		return {}
	end -- Mada
end

do
	local BasePart = create_instance_class('BasePart')

	BasePart.CFrame = CFrame.new()
	BasePart.Size = Vector3.new(2, 1, 4)
	BasePart.Color = Color3.new(0.75, 0.75, 0.75)
	BasePart.Anchored = false
	BasePart.CanCollide = true
end

do
	local Camera = create_instance_class('Camera')

	Camera.FieldOfView = 70
end

--[[
local function getBasePartShape(basePart)
	return basePart.ClassName == 'Part' and basePart.Shape or basePart.ClassName
end
]]

do
	local Part = create_instance_class('Part', {'BasePart'})

	local newIndex = {}

	function newIndex.CFrame(self)
		if self._mesh then
			self._mesh:Match(self)
		end
	end

	function newIndex.Size(self)
		if self._mesh then
			self._mesh:Match(self)
		end
	end

	function newIndex.Parent(self, parent0, parent)
		parent0 = parent0 or nilInstance

		parent0._children[self] = nil
		parent._children[self] = true
		parent.ChildAdded(self)

		if self:IsDescendantOf(workspace) then
			if not self._mesh then
				self._mesh = Mesh[self.Shape]()
				self._mesh:Match(self)
			end
		elseif self._mesh then
			self._mesh:Destroy()
			self._mesh = nil
		end
	end

	function Part:__newindex(i, v)
		local v0 = instanceAttributes[self][i]
		instanceAttributes[self][i] = v
		if newIndex[i] then
			newIndex[i](self, v0, v)
		end
	end

	Part.Shape = Enum.PartType.Block
end

do
	local WedgePart = create_instance_class('WedgePart', {'BasePart'})

	local newIndex = {}

	function newIndex.CFrame(self)
		if self._mesh then
			self._mesh:Match(self)
		end
	end

	function newIndex.Size(self)
		if self._mesh then
			self._mesh:Match(self)
		end
	end

	function newIndex.Parent(self, parent0, parent)
		parent0 = parent0 or nilInstance

		parent0._children[self] = nil
		parent._children[self] = true
		parent.ChildAdded(self)

		if self:IsDescendantOf(workspace) then
			if not self._mesh then
				self._mesh = Mesh.WedgePart()
				self._mesh:Match(self)
			end
		elseif self._mesh then
			self._mesh:Destroy()
			self._mesh = nil
		end
	end

	function WedgePart:__newindex(i, v)
		local v0 = instanceAttributes[self][i]
		instanceAttributes[self][i] = v
		if newIndex[i] then
			newIndex[i](self, v0, v)
		end
	end
end

local services = {}

-- services
create_instance_class('AnalyticsService')
create_instance_class('AssetService')
create_instance_class('CollectionService')
create_instance_class('ContextActionService')
create_instance_class('CookiesService')
create_instance_class('CSGDictionaryService')
create_instance_class('GamePassService')
create_instance_class('GuidRegistryService')
create_instance_class('HttpService')
create_instance_class('InsertService')
create_instance_class('LanguageService')
create_instance_class('LocalizationService')
create_instance_class('LodDataService')
create_instance_class('LuaWebService')
create_instance_class('MaterialService')
create_instance_class('NonReplicatedCSGDictionaryService')
create_instance_class('PermissionsService')
create_instance_class('PhysicsService')
create_instance_class('PlayerEmulatorService')
create_instance_class('ProcessInstancePhysicsService')
create_instance_class('ProximityPromptService')
create_instance_class('ScriptService')
create_instance_class('ServerScriptService')
create_instance_class('ServiceVisibilityService')
create_instance_class('SoundService')
create_instance_class('TeleportService')
create_instance_class('TestService')
create_instance_class('TextChatService')
create_instance_class('TimerService')
create_instance_class('TouchInputService')
create_instance_class('TweenService')
create_instance_class('VoiceChatService')
create_instance_class('VRService')

do
	local UserInputService = {}

	UserInputService.InputBegan = RBXScriptSignal.new()
	UserInputService.InputChanged = RBXScriptSignal.new()
	UserInputService.InputEnded = RBXScriptSignal.new()
	UserInputService.IsKeyDown = love.keyboard.isDown

	services.UserInputService = UserInputService
end

do
	local ReplicatedFirst = create_instance_class('ReplicatedFirst')

	function ReplicatedFirst:RemoveDefaultLoadingScreen()
	end -- Mada

	services.ReplicatedFirst = ReplicatedFirst
end

do
	local RunService = {}

	RunService.RenderStepped = RBXScriptSignal.new()
	RunService.Heartbeat = RBXScriptSignal.new()

	services.RunService = RunService
end

do
	local Players = create_instance_class('Players')

	local new = Players.new

	function Players.new()
		local self = new()

		self.PlayerRemoving = RBXScriptSignal.new()

		services.Players = self

		return self
	end
end

do
	local ReplicatedStorage = create_instance_class('ReplicatedStorage')

	local new = ReplicatedStorage.new

	function ReplicatedStorage.new()
		local self = new()

		services.ReplicatedStorage = self

		return self
	end
end

do
	local Game = create_instance_class('Game')

	function Game:GetService(serviceName)
		return services[serviceName]
	end
end







































-- time
do
	time = love.timer.getTime
end

-- tick
do
	local time0 = os.time()

	function tick()
		return time0 + time()
	end
end

-- wait
--[[
do
	local ffi = require('ffi')

	if ffi.os == 'windows' then
		ffi.cdef('void Sleep(int);')

		local Sleep = ffi.C.Sleep

		function wait(s)
			Sleep(1000*(s or 0))
			return true
		end
	else
		ffi.cdef('int poll(struct pollfd *, unsigned long, int);')

		local poll = ffi.C.poll

		function wait(s)
			poll(nil, 0, 1000*(s or 0))
			return true
		end
	end
end
]]

-- typeof
do
	function typeof(object)
		local type = type(object)
		return type == 'table' and object.TypeName or type
	end
end

-- debug
do
	function debug.profilebegin()
	end

	function debug.profileend()
	end
end

-- require
do
	local yield = coroutine.yield

	local cachedScripts = {}

	function robloxRequire(script)
		if not script.lostVirginity then
			script.lostVirginity = true
			cachedScripts[script] = yield('die', script._thread)
		end
		return cachedScripts[script]
	end
end




















love.draw = RBXScriptSignal.new()
love.keypressed = RBXScriptSignal.new()
love.load = RBXScriptSignal.new()
love.mousemoved = RBXScriptSignal.new()
love.mousepressed = RBXScriptSignal.new()
love.mousereleased = RBXScriptSignal.new()
love.resize = RBXScriptSignal.new()
love.update = RBXScriptSignal.new()
love.wheelmoved = RBXScriptSignal.new()



love.graphics.setDefaultFilter('nearest', 'nearest', 1)

-- Make buffers and set global canvas size
love.resize:Connect(function(sx, sy)
	csx = sx
	csy = sy

	local depthBuffer = love.graphics.newCanvas(csx, csy, {type = '2d'; format = 'depth24';})

	geometryBuffer = {
		love.graphics.newCanvas(csx, csy, {type = '2d'; format = 'rgba8';}),
		love.graphics.newCanvas(csx, csy, {type = '2d'; format = 'rgba8';}),
		love.graphics.newCanvas(csx, csy, {type = '2d'; format = 'rgba8';}),
		love.graphics.newCanvas(csx, csy, {type = '2d'; format = 'rgba8';}),
		depthstencil = depthBuffer;
	}

	compositeBuffer = {
		love.graphics.newCanvas(csx, csy, {type = '2d'; format = 'rgba8';}),
		depthstencil = depthBuffer;
	}
end)

love.resize(love.graphics.getDimensions())





















local switchboard = {}
do
	local bufferReceiveArgument = '*l'

	local serial = require('serial')
	local socket = require('socket')

	local deserialize = serial.deserialize
	local serialize = serial.serialize
	local insert = table.insert
	local remove = table.remove

	local peers = {}
	local peersInverse = {}

	switchboard.onConnect = RBXScriptSignal.new()
	switchboard.onDisconnect = RBXScriptSignal.new()
	switchboard.onReceive = RBXScriptSignal.new()

	function switchboard.connect(peer)
		peersInverse[peer] = true
		insert(peers, peer)
		switchboard.onConnect(peer)
	end

	function switchboard.run()
		for i = 1, #peers do
			local peer = peers[i]

			while true do
				local bytes, receiveStatus = peer:receive(bufferReceiveArgument)

				if bytes then
					local data = deserialize(bytes)

					switchboard.onReceive(peer, unpack(data)) -- tuple unpacking
				elseif receiveStatus == 'closed' then
					switchboard.onDisconnect(peer)
					peersInverse[peer] = nil
					for i = 1, #peers do
						if peers[i] == peer then
							remove(peers, i)
							break
						end
					end
					peer:close()
					break
				elseif not bytes then
					break
				end
			end
		end

		--[[
			for peer in next, peersInverse do
			local bytes, status = peer:receive(bufferReceiveArgument)

			print(bytes, status)

			if bytes then
				local data = deserialize(bytes)

				switchboard.onReceive(peer, unpack(data)) -- tuple unpacking
			elseif status == 'closed' then
				switchboard.onDisconnect(peer)
				peersInverse[peer] = nil
				peer:close()
			end
		end
		]]
	end

	function switchboard.send(...)
		for i = 1, #peers do
			switchboard.sendTo(peers[i], ...)
		end
	end

	function switchboard.sendBut(ignoredPeer, ...)
		-- Lie for a little bit
		peersInverse[ignoredPeer] = nil

		for peer in next, peersInverse do
			switchboard.sendTo(peer, ...)
		end

		-- And then undo the lie
		peersInverse[ignoredPeer] = true
	end

	function switchboard.sendTo(peer, ...)
		peer:send(serialize(...))
	end
end






















local network = {}
do
	network.onConnect = switchboard.onConnect
	network.onDisconnect = switchboard.onDisconnect

	local socket = require('socket')

	local callers = {}

	function network.onReceive(name)
		if not callers[name] then
			callers[name] = RBXScriptSignal.new()
		end
		return callers[name]
	end

	switchboard.onReceive:Connect(function(socket, name, ...)
		assert(callers[name], 'No caller by name: '..name)
		callers[name](socket, ...)
	end)

	function network.client(address, port)
		local host = socket.tcp()
		host:settimeout(0) -- non-blocking mode

		host:connect(address, port)

		switchboard.connect(host)

		return host
	end

	function network.server(address, port)
		local host = socket.bind(address, port)
		host:settimeout(0) -- non-blocking mode

		function network.pollPeers()
			local peer = host:accept()
			while peer do
				peer:settimeout(0)
				switchboard.connect(peer)
				peer = host:accept()
			end
		end
	end
end


































local game = Instance.new('Game')





local lovlox = {}

do
	local xml2lua = require('xml2lua/xml2lua')
	local tree = require('xml2lua/tree')

	local create = coroutine.create

	local match = {}

	local function recurse_rbxlx_node(dom_node, previous)
		for i, v in next, dom_node do
			if i ~= '_attr' and type(i) == 'string' then
				for _, child_node in next, v do
					if match[i] then
						match[i](child_node, previous)
					else
						-- Branch
					end
				end
			end
		end
	end

	function match.roblox(dom_node)
		recurse_rbxlx_node(dom_node, game)
	end

	local random = math.random

	-- Create a new Instance of the class
	function match.Item(dom_node, parent)
		local class_name = dom_node._attr.class
		local instance = Instance.new(class_name)
		instance.Parent = parent

		local referent_id = dom_node._attr.referent

		-- Set the referent_id to this object
		instance_from_referent_id[referent_id] = self

		recurse_rbxlx_node(dom_node, instance)
	end

	function match.Ref(dom_node, instance)
		local referent_id = dom_node[1]
		local attribute_name = dom_node._attr.name
		instance[attribute_name] = instance_from_referent_id[referent_id]
	end

	match.Properties = recurse_rbxlx_node

	local to_bool = {}
	to_bool['true'] = true
	to_bool['false'] = false

	function match.string(dom_node, previous)
		previous[dom_node._attr.name] = dom_node[1]
	end

	function match.bool(dom_node, previous)
		previous[dom_node._attr.name] = to_bool[dom_node[1]]
	end

	function match.float(dom_node, previous)
		previous[dom_node._attr.name] = tonumber(dom_node[1])
	end

	function match.int(dom_node, previous)
		previous[dom_node._attr.name] = tonumber(dom_node[1])
	end

	function match.token(dom_node, previous)
		previous[dom_node._attr.name] = tonumber(dom_node[1])
	end

	local scriptInitializers = {}

	function scriptInitializers.Script(script, thread)
		scheduler.queueResumption(thread)
	end

	function scriptInitializers.LocalScript(script, thread)
		scheduler.queueResumption(thread)
	end

	function scriptInitializers.ModuleScript(script, thread)
		script._thread = thread
	end

	if runningAs.server then
		function scriptInitializers.LocalScript()
		end
	elseif runningAs.client then
		function scriptInitializers.Script()
		end
	end

	function match.ProtectedString(dom_node, script)
		local entry = load('return function(script, require) return function()'..dom_node[1]..' end end')()(script, robloxRequire)
		local thread = create(entry)
		scriptInitializers[script.ClassName](script, thread)
	end

	function match.Vector3(dom_node, previous)
		if dom_node._attr.name == 'size' then
			dom_node._attr.name = 'Size'
		end
		previous[dom_node._attr.name] = Vector3.new(tonumber(dom_node.X[1][1]), tonumber(dom_node.Y[1][1]), tonumber(dom_node.Z[1][1]))
	end

	function match.Color3uint8(dom_node, previous)
		if dom_node._attr.name == 'Color3uint8' then
			dom_node._attr.name = 'Color'
		end
		previous[dom_node._attr.name] = Color3.fromColor3uint8(dom_node[1])
	end

	function match.Color3(dom_node, previous)
		previous[dom_node._attr.name] = Color3.new(tonumber(dom_node.R[1][1]), tonumber(dom_node.G[1][1]), tonumber(dom_node.B[1][1]))
	end

	function match.CoordinateFrame(dom_node, previous)
		previous[dom_node._attr.name] = CFrame.new(
			tonumber(dom_node.X[1][1]),
			tonumber(dom_node.Y[1][1]),
			tonumber(dom_node.Z[1][1]),
			tonumber(dom_node.R00[1][1]),
			tonumber(dom_node.R01[1][1]),
			tonumber(dom_node.R02[1][1]),
			tonumber(dom_node.R10[1][1]),
			tonumber(dom_node.R11[1][1]),
			tonumber(dom_node.R12[1][1]),
			tonumber(dom_node.R20[1][1]),
			tonumber(dom_node.R21[1][1]),
			tonumber(dom_node.R22[1][1])
		)
	end

	local function load_place_file(path)
		xml2lua.parser(tree):parse(xml2lua.loadFile(path))
		recurse_rbxlx_node(tree.root)
	end

	function lovlox.hostPlace(path, address, port)
		local place_title = path:sub(1, -7)

		local serial = require('serial')
		local serialize = serial.serialize

		love.filesystem.setIdentity(place_title)
		love.window.setTitle(place_title)

		load_place_file(path)

		network.server(address, port)

		network.onConnect:Connect(function(peer)
			switchboard.sendTo(peer, 'place_title', place_title)

			local descendants = game:GetDescendants()
			for i = 1, #descendants do
				local instance = descendants[i]
				print(instance)
				switchboard.sendTo(peer, 'newInstance', instance.ClassName, instance._referent_id)
			end

			switchboard.sendTo(peer, 'endParts')
		end)

		local run_service = game:GetService('RunService')

		function lovlox.step(dt)
			network.pollPeers()

			switchboard.run()

			-- run scheduler
			scheduler.run()

			run_service.Heartbeat(time(), dt)

			for _, child in next, workspace:GetDescendants() do
				child.Parent = child.Parent
			end -- uhh render the geometry inefficiently
		end

		-- game.Players.LocalPlayer = game.Players[MY_IP_ADDRESS]

		--[[
		if runningAs.client then
			player.Chatted = RBXScriptSignal.new()

			function player:GetMouse()
				local self = {}
				self.Button1Down = RBXScriptSignal.new()
				self.Button1Up = RBXScriptSignal.new()
				self.Button2Down = RBXScriptSignal.new()
				self.Button2Up = RBXScriptSignal.new()
				self.KeyDown = RBXScriptSignal.new()
				self.KeyUp = RBXScriptSignal.new()
				return self
			end

			local playerGui = Instance.new('PlayerGui')
			playerGui.Parent = player

			game.Players.LocalPlayer = player
		end
		]]

		local function doItAll()
			remoteMap = {}
			if runningAs.server then
				game.ReplicatedStorage.ChildAdded:Connect(function(child)
					if child.ClassName == 'RemoteEvent' then
						remoteMap.event = game.ReplicatedStorage.RemoteEvent.OnServerEvent
					elseif child.ClassName == 'RemoteFunction' then
						remoteMap.invoke = game.ReplicatedStorage.RemoteFunction.OnServerInvoke
					end
				end)
			elseif runningAs.client then
				local remoteEvent = Instance.new('RemoteEvent')
				local remoteFunction = Instance.new('RemoteFunction')

				remoteEvent.Parent = game.ReplicatedStorage
				remoteFunction.Parent = game.ReplicatedStorage

				remoteMap.event = game.ReplicatedStorage.RemoteEvent.OnClientEvent
				remoteMap.invoke = game.ReplicatedStorage.RemoteFunction.OnClientInvoke
			end

			love.keypressed:Connect(function(k)
				if k == 'c' then
					love.mouse.setRelativeMode(not love.mouse.getRelativeMode())
				elseif k == 'printscreen' then
					love.graphics.captureScreenshot(tick()..'.png')
				end
			end)

			local function create_projection_frustum(v, a, n, f)
				local i = 1/(n - f)
				return {
					a*v, 0, 0, 0,
					0, v, 0, 0,
					0, 0, (n + f)*i, 2*n*f*i,
					0, 0, -1, 0
				}
			end



			love.update:Connect(lovlox.step)



			local hdri = love.graphics.newImage('hdris/tennisnight.jpg')

			local camera = workspace.CurrentCamera

			love.draw:Connect(function()
				local cameraP = {camera.CFrame.Position:GetComponents()}
				local cameraO = {Quaternion.fromCFrame(camera.CFrame):GetComponents()}
				local cameraT = create_projection_frustum(1, csy/csx, 0.1, 100000)

				love.graphics.setDepthMode('less', true)
				love.graphics.setMeshCullMode('front')

				-- draw to geometry buffer
				love.graphics.setCanvas(geometryBuffer)
				love.graphics.clear()

				love.graphics.setShader(geometryShader)
				geometryShader:send('cameraP', cameraP)
				geometryShader:send('cameraO', cameraO)
				geometryShader:send('cameraT', cameraT)

				for i = 1, #meshes do
					meshes[i]:Draw()
				end

				-- sky?
				--[[
				love.graphics.setCanvas()

				love.graphics.setShader(skyShader)
				skyShader:send('cameraO', cameraO)
				-- skyShader:send('cameraT', cameraT)
				skyShader:send('skyTex', hdri)

				love.graphics.draw(compositeBuffer[1])
				]]

				-- draw to screen
				love.graphics.setCanvas()

				love.graphics.setShader(debandShader)
				debandShader:send('worldNs', geometryBuffer[2])
				debandShader:send('worldCs', geometryBuffer[3])

				love.graphics.draw(compositeBuffer[1])

				-- fps
				love.graphics.reset()
				love.graphics.print(love.timer.getFPS())
			end)
		end

		doItAll()

		-- network.onReceive('bounce')
		--[[
		love.update:Connect(function()
			local event = host:service()
			while event do
				event.switchboard.sendTo(peer, 'ping')

				if event.type == 'receive' then
					local data = deserialize(event.data)

					print('NETWORK', unpack(data))

					local player = game.Players[tostring(event.peer)]

					if data[1] == 'event' then
						if runningAs.server then
							remoteMap.event(player, unpack(data, 2))
						elseif runningAs.client then
							remoteMap.event(unpack(data, 2))
						end
					elseif data[1] == 'invoke' then
						if runningAs.server then
							event.switchboard.sendTo(peer, 'bounce', remoteMap.invoke(player, unpack(data, 2)))
						elseif runningAs.client then
							event.switchboard.sendTo(peer, 'bounce', remoteMap.invoke(unpack(data, 2)))
						end
					elseif data[1] == 'bounce' then
						--print(unpack(data))
						--print(invokingThread)
						scheduler.queueResumption(invokingThread, unpack(data, 2))
						invokingThread = nil -- only needed for when things go wrong.
					end
				elseif event.type == 'connect' then
					local player = Instance.new('Player')
					player.Name = tostring(event.peer)
					player._socket = event.peer
					player.Parent = game.Players
				elseif event.type == 'disconnect' then
					local player = game.Players[tostring(event.peer)]
					player:Destroy()
					print(event.peer, 'disconnected')
				end

				event = host:service()
			end
		end)
		]]

		-- return game
	end

	function lovlox.connectToServer(address, port)
		local serial = require('serial')
		local serialize = serial.serialize

		network.onReceive('place_title'):Connect(function(_, place_title)
			love.window.setTitle(place_title)
		end)

		local peer = network.client(address, port)

		love.update:Connect(switchboard.run)

		--[[
		love.update:Connect(function()
			local event = host:service()
			while event do
				event.switchboard.sendTo(peer, 'ping')

				if event.type == 'receive' then
					--print(data[1])

					--print('NETWORK', unpack(data))

					--local player = game.Players[tostring(event.peer)]

					local data = deserialize(event.data)
					network.receiveSignals[data[1]]-- (event.peer, unpack(data, 2))

					--[[
					if data[1] == 'event' then
						-- remoteMap.event(unpack(data, 2))
					elseif data[1] == 'invoke' then
						-- event.switchboard.sendTo(peer, 'bounce', remoteMap.invoke(unpack(data, 2)))
					elseif data[1] == 'bounce' then
						scheduler.queueResumption(invokingBounceThread, unpack(data, 2))
						invokingBounceThread = nil -- only needed for when things go wrong.
					elseif data[1] == 'uhh' then

					end
				elseif event.type == 'connect' then
					network.onConnect(event.peer)
					-- load_place_file()
					-- peer = event.peer
					-- doItAll()
					-- onParsedPlace()
				elseif event.type == 'disconnect' then
					network.onDisconnect(event.peer)
				end

				event = host:service()
			end
		end)
		]]

		local onParsedPlace = RBXScriptSignal.new()

		local onReceivePart
		onReceivePart = network.onReceive('newInstance'):Connect(function(peer, class_name, referent_id)
			local parent = instance_from_referent_id[referent_id]

			--print(parent)

			local instance = Instance.new(class_name)
			--instance.Parent = parent
		end)

		network.onReceive('endParts'):Once(function()
			print('No longer receiving initial parts')
			onReceivePart:Disconnect()
			onParsedPlace()
		end)

		onParsedPlace:Connect(function()
			function lovlox.step(dt)
				-- run scheduler
				scheduler.run()

				run_service.RenderStepped(dt)
				run_service.Heartbeat(time(), dt)

				for _, child in next, workspace:GetDescendants() do
					child.Parent = child.Parent
				end -- uhh render the geometry inefficiently
			end

			love.update:Connect(lovlox.step)
		end)

		--[[
		player.Chatted = RBXScriptSignal.new()

		function player:GetMouse()
			local self = {}
			self.Button1Down = RBXScriptSignal.new()
			self.Button1Up = RBXScriptSignal.new()
			self.Button2Down = RBXScriptSignal.new()
			self.Button2Up = RBXScriptSignal.new()
			self.KeyDown = RBXScriptSignal.new()
			self.KeyUp = RBXScriptSignal.new()
			return self
		end

		local playerGui = Instance.new('PlayerGui')
		playerGui.Parent = player

		game.Players.LocalPlayer = player
		]]










		--[[
		local MSC = 1/512

		love.keypressed:Connect(function(k)
			if k == 'c' then
				love.mouse.setRelativeMode(not love.mouse.getRelativeMode())
			elseif k == 'printscreen' then
				love.graphics.captureScreenshot(tick()..'.png')
			end
		end)

		local camera = workspace.Camera
		camera.CFrame = CFrame.new(0, 30, 50)

		local function fromAxisAngle(v)
			return v.Magnitude > 0 and CFrame.fromAxisAngle(v.Unit, v.Magnitude) or CFrame.new()
		end

		love.mousemoved:Connect(function(_, _, dx, dy)
			camera.CFrame = camera.CFrame*fromAxisAngle(Vector3.new(-MSC*dy, -MSC*dx, 0))
		end)

		love.update:Connect(function(dt)
			local targetVelocity = Vector3.new(
				(love.keyboard.isDown('d') and 1 or 0) + (love.keyboard.isDown('a') and -1 or 0),
				(love.keyboard.isDown('e') and 1 or 0) + (love.keyboard.isDown('q') and -1 or 0),
				(love.keyboard.isDown('s') and 1 or 0) + (love.keyboard.isDown('w') and -1 or 0)
			)

			camera.CFrame = camera.CFrame*CFrame.new(32*dt*targetVelocity)
		end)

		love.update:Connect(lovlox.step)
		]]


		local hdri = love.graphics.newImage('hdris/tennisnight.jpg')

		--[[
		love.draw:Connect(function()
			local cameraP = {camera.CFrame.p:GetComponents()}
			local cameraO = {Quaternion.fromCFrame(camera.CFrame):GetComponents()}
			local cameraT = create_projection_frustum(1, csy/csx, 0.1, 10000)

			love.graphics.setDepthMode('less', true)
			love.graphics.setMeshCullMode('front')

			-- draw to geometry buffer
			love.graphics.setCanvas(geometryBuffer)
			love.graphics.clear()

			love.graphics.setShader(geometryShader)
			geometryShader:send('cameraP', cameraP)
			geometryShader:send('cameraO', cameraO)
			geometryShader:send('cameraT', cameraT)

			for i = 1, #meshes do
				meshes[i]:Draw()
			end

			-- sky?
			--[[
			love.graphics.setCanvas()

			love.graphics.setShader(skyShader)
			skyShader:send('cameraO', cameraO)
			--skyShader:send('cameraT', cameraT)
			skyShader:send('skyTex', hdri)

			love.graphics.draw(compositeBuffer[1])
			]]

			--[[
			-- draw to screen
			love.graphics.setCanvas()

			love.graphics.setShader(debandShader)
			debandShader:send('worldNs', geometryBuffer[2])
			debandShader:send('worldCs', geometryBuffer[3])

			love.graphics.draw(compositeBuffer[1])

			-- fps
			love.graphics.reset()
			love.graphics.print(love.timer.getFPS())
		end)
		]]
	end
end















































































--[[
local light = {}

do
	-- outer radius of 1:
	--local u = sqrt(0.1*(5 - sqrt(5)))
	--local v = sqrt(0.1*(5 + sqrt(5)))
	-- inner radius of 1:
	local u = sqrt(1.5*(7 - 3*sqrt(5)))
	local v = sqrt(1.5*(3 - sqrt(5)))
	local a = {0, u, v}
	local b = {0, u, -v}
	local c = {0, -u, v}
	local d = {0, -u, -v}
	local e = {v, 0, u}
	local f = {-v, 0, u}
	local g = {v, 0, -u}
	local h = {-v, 0, -u}
	local i = {u, v, 0}
	local j = {u, -v, 0}
	local k = {-u, v, 0}
	local l = {-u, -v, 0}

	local vertices = {
		a, i, k,
		b, k, i,
		c, l, j,
		d, j, l,

		e, a, c,
		f, c, a,
		g, d, b,
		h, b, d,

		i, e, g,
		j, g, e,
		k, h, f,
		l, f, h,

		a, e, i,
		a, k, f,
		b, h, k,
		b, i, g,
		c, f, l,
		c, j, e,
		d, g, j,
		d, l, h,
	}

	lightMesh = love.graphics.newMesh(vertexAttributeMap.light, vertices, 'triangles', 'dynamic')
end

function light.new()
	local color = Color3.new(1, 1, 1)
	local pos = Vector3.new()

	local alpha = 0.5

	local self = {}

	function self.setPosition(newpos)
		pos = newpos
	end

	function self.setColor(netColor)
		color = netColor
	end

	function self.setAlpha(newAlpha)
		alpha = newAlpha
	end

	function self.getPos()
		return pos
	end

	function self.getColor()
		return color
	end

	function self.getAlpha()
		return alpha
	end

	local frequencyscale = Vector3.new(0.3, 0.59, 0.11)

	function self.getDrawData()
		local brightness = frequencyscale:Dot(color)
		local radius = sqrt(brightness/alpha)
		vertT[1] = radius
		vertT[4] = pos.x
		vertT[6] = radius
		vertT[8] = pos.y
		vertT[11] = radius
		vertT[12] = pos.z
		colorT[1] = color.x
		colorT[2] = color.y
		colorT[3] = color.z
	end

	return lightMesh, vertT, colorT
end

return self
]]

























--[[
randy.uniform1()
randy.uniform2()
randy.uniform3()
randy.uniform4()
	return uniform random variables between 0 and 1

randy.gaussian1()
randy.gaussian2()
randy.gaussian3()
randy.gaussian4()
	return gaussian random variables with a sigma of 1

randy.unit1()
randy.unit2()
randy.unit3()
randy.unit4()
	return random variables whose magnitude is 1

randy.newSampler(width, height, generator)
	returns an object with a image which can be sampled from
	width and height are the dimensions of the image
	generator is a function which returns up to 4 random variables

	sampler.getDrawData()
		returns image, size, randomoffset

Note:
	log(random()) is kinda wrong because it has a chance of
	evaluating to log(0), which isn't good. Use log(1 - random())
	if you're worried about this.
]]

local randy = {}
do
	local cos = math.cos
	local log = math.log
	local random = math.random
	local sin = math.sin
	local sqrt = math.sqrt

	local tau = 6.28318530

	randy.uniform1 = random

	function randy.uniform2()
		return random(), random()
	end

	function randy.uniform3()
		return random(), random(), random()
	end

	function randy.uniform4()
		return random(), random(), random(), random()
	end

	function randy.gaussian2()
		local m = sqrt(-2*log(random()))
		local a = tau*random()
		return m*cos(a), m*sin(a)
	end

	function randy.gaussian4()
		local m0 = sqrt(-2*log(random()))
		local m1 = sqrt(-2*log(random()))
		local a0 = tau*random()
		local a1 = tau*random()
		return m0*cos(a0), m0*sin(a0), m1*cos(a1), m1*sin(a1)
	end

	randy.gaussian1 = randy.gaussian2
	randy.gaussian3 = randy.gaussian4

	function randy.unit1()
		return random() < 0.5 and -1 or 1
	end

	function randy.unit2()
		local a = tau*random()
		return cos(a), sin(a)
	end

	function randy.unit3()
		local x = 2*random() - 1
		local i = sqrt(1 - x*x)
		local a = tau*random()
		return x, i*cos(a), i*sin(a)
	end

	function randy.unit4()
		local l0 = log(random())
		local l1 = log(random())
		local m0 = sqrt(l0/(l0 + l1))
		local m1 = sqrt(l1/(l0 + l1))
		local a0 = tau*random()
		local a1 = tau*random()
		return m0*cos(a0), m0*sin(a0), m1*cos(a1), m1*sin(a1)
	end

	local unit2 = randy.unit2
	local unit3 = randy.unit3
	local unit4 = randy.unit4

	function randy.triangular1()
		return random() + random() - 1
	end

	function randy.triangular2()
		return random() + random() - 1, random() + random() - 1
	end

	function randy.triangular3()
		return random() + random() - 1, random() + random() - 1, random() + random() - 1
	end

	function randy.triangular4()
		return random() + random() - 1, random() + random() - 1, random() + random() - 1, random() + random() - 1
	end

	function randy.triangular4x2()
		return 2*(random() + random() - 1), 2*(random() + random() - 1), 2*(random() + random() - 1), 2*(random() + random() - 1)
	end

	function randy.ball1()
		return 2*random() - 1
	end

	function randy.ball2()
		local s = sqrt(random())
		local x, y = unit2()
		return s*x, s*y
	end

	function randy.ball3()
		local s = random()^0.33333333
		local x, y, z = unit3()
		return s*x, s*y, s*z
	end

	function randy.ball3()
		local s = random()^0.25
		local x, y, z, w = unit4()
		return s*x, s*y, s*z, s*w
	end

	-- just make some random values that the buffers can use
	function randy.newSampler(w, h, generator, format)
		local self = {}
		local data = love.image.newImageData(w, h, format)

		-- uniform random variables can be transformed into other random variables with some effort

		for i = 0, w - 1 do
			for j = 0, h - 1 do
				data:setPixel(i, j, generator())
			end
		end

		local image = love.graphics.newImage(data)
		local size = {w, h}
		local offset = {0, 0}

		function self.getDrawData()
			offset[1] = random(w) - 1
			offset[2] = random(h) - 1
			return image, size, offset
		end

		return self
	end
end











































if runningAs.server then
	lovlox.hostPlace('bowmen2.rbxlx', 'localhost', 57005)
end

lovlox.connectToServer('localhost', 57005)