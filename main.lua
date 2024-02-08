-- TODO: Get a working wait command, we need threads to be able to pause individually. it's needed for InvokeServer/InvokeClient
-- Instead of always creating new objects for operations, why not just modify the inputted objects and return them?




local debug_mode = false


assert(arg[2] == 'server' or arg[2] == 'client', 'invalid run mode')
local running_as = {[arg[2]] = true}







local vertex_attribute_map = {
	mesh = {
		{'vertexP', 'float', 3},
		{'vertexN', 'float', 3}
	}; 
	light = {
		{'vertexP', 'float', 3}
	}; 
}



local deband_shader = love.graphics.newShader('shaders/deband.glsl')
local geometry_shader = love.graphics.newShader('shaders/geometry.glsl')
local sky_shader = love.graphics.newShader('shaders/sky.glsl')

































local scheduler = {}
do
	local remove = table.remove
	local resume = coroutine.resume
	local status = coroutine.status
	local yield = coroutine.yield

	local queue = {}
	local death_routines = {}

	local function queue_resumption(thread, ...)
		queue[#queue + 1] = {thread, ...}
	end

	local function pop()
		queue[#queue] = nil
	end

	-- The expectation is for the yielder to resume the thread on its own
	local function manual_yield(thread)
		for i = 1, #queue do
			if queue[i][1] == thread then
				remove(queue, i)
				return yield()
			end
		end
		--assert(not debug_mode, '[Error] Incorrect call to manual yield')
	end

	local function run()
		while #queue > 0 do
			local current = queue[#queue]

			local thread = current[1]

			local yield_data = {resume(thread, unpack(current, 2))}
			local status = status(thread)

			--print(thread, status, unpack(current, 2))
			--print(thread, status, unpack(yield_data))

			pop()

			if status == 'suspended' then
				local yield_type = yield_data[2]
				if yield_type == 'die' then
					local dependency_thread = yield_data[3]
					queue_resumption(dependency_thread) -- move the dependency thread to step threads
					death_routines[dependency_thread] = thread -- create the die callback to resume the original dependor thread
				end
				--[[
				elseif yield_type == 'second' then
					--assert(not debug_mode, '[Debug] Wait was called')
					queue_resumption(thread)
				elseif yield_type == 'invoke' then
					--assert(not debug_mode, '[Debug] Invoking the scheduler')
				end
				]]
			elseif status == 'dead' then
				if death_routines[thread] then
					queue_resumption(death_routines[thread], unpack(yield_data, 2)) -- dependency thread is finished, so now we can resume the dependor thread
					death_routines[thread] = nil
				end
			end
		end
	end

	scheduler = {
		queue_resumption = queue_resumption; 
		pop = pop; 
		manual_yield = manual_yield; 
		run = run; 
	}
end

















-- Enum
do
	Enum = {}

	local function register_enum(name, values)
		Enum[name] = {}
		for i = 1, #values do
			local v = values[i]
			Enum[name][v] = i - 1
		end
	end

	register_enum('PartType', {'Ball', 'Block', 'Cylinder', 'Tetahedron'})
	register_enum('CameraType', {'Scriptable'})
	register_enum('meshType', {'Wedge'})
	register_enum('KeyCode', {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'Space', 'F8'})
	register_enum('MouseBehavior', {'LockCenter', 'Default', 'LockCurrentPosition'})
end






local meshes = {}
local mesh = {}
do
	local sqrt = math.sqrt

	function mesh.new(mesh)
		local position = Vector3.zero
		local orientation = Quaternion.identity
		local size = Vector3.zero
		local color = Color3.new()

		local self = {}

		function self.draw()
			geometry_shader:send('objectP', {position:GetComponents()})
			geometry_shader:send('objectO', {orientation:GetComponents()})
			geometry_shader:send('objectS', {size:GetComponents()})
			geometry_shader:send('objectC', {color.r, color.g, color.b, 1})
			love.graphics.draw(mesh)
		end

		function self.match(part)
			position = part.CFrame.Position
			orientation = Quaternion.fromCFrame(part.CFrame)
			size = part.Size
			color = part.Color
		end

		function self:Destroy()
		end

		meshes[#meshes + 1] = self

		return self
	end

	local new = mesh.new

	local cached_sphere_geometry = {}

	local function interp(a, b, c, n, i, j)
		return i/n*b + j/n*c - (i + j - n)/n*a
	end

	mesh[Enum.PartType.Ball] = function(n)
		n = n or 1

		if not cached_sphere_geometry[n] then
			-- outer radius of 1:
			local u = 0.5257311 -- sqrt(0.1*(5 - sqrt(5)))
			local v = 0.8506508 -- sqrt(0.1*(5 + sqrt(5)))
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

						vertices[#vertices + 1] = {ux, uy, uz, ux, uy, uz}
						vertices[#vertices + 1] = {vx, vy, vz, vx, vy, vz}
						vertices[#vertices + 1] = {wx, wy, wz, wx, wy, wz}
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

						vertices[#vertices + 1] = {ux, uy, uz, ux, uy, uz}
						vertices[#vertices + 1] = {vx, vy, vz, vx, vy, vz}
						vertices[#vertices + 1] = {wx, wy, wz, wx, wy, wz}
					end
				end
			end

			cached_sphere_geometry[n] = love.graphics.newMesh(vertex_attribute_map.mesh, vertices, 'triangles', 'dynamic')
		end

		return new(cached_sphere_geometry[n])
	end

	local R = sqrt(0.5)

	local function get_wedge_part_vertices()
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

	function mesh.wedge_part()
		return new(love.graphics.newMesh(vertex_attribute_map.mesh, get_wedge_part_vertices(), 'triangles', 'dynamic'))
	end

	local function get_block_vertices()
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

	mesh[Enum.PartType.Block] = function()
		return new(love.graphics.newMesh(vertex_attribute_map.mesh, get_block_vertices(), 'triangles', 'dynamic'))
	end




	local n = 0.5773503 -- 1/sqrt(3)

	local function get_tetahedron_vertices()
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

	mesh[Enum.PartType.Tetahedron] = function()
		return new(love.graphics.newMesh(vertex_attribute_map.mesh, get_tetahedron_vertices(), 'triangles', 'dynamic'))
	end
end

















































--[[
local function roblox_base_part_to_mesh(base_part)
	local position
	local orientation
	local size
	local color
	local shape

	if base_part.ClassName then
		local m = base_part.CFrame
		local s = base_part.Size
		local c = base_part.Color

		local sx, sy, sz = s:GetComponents()
		local cr, cg, cb = c:GetComponents()

		if base_part.ClassName == 'WedgePart' then
			position = base_part.CFrame.Position
			orientation = Quaternion.fromCFrame(base_part.CFrame)
			size = Vector3.new(sx, sy, sz)
			color = Color3.new(cr, cg, cb)
			shape = 'WedgePart'
		else
			position = base_part.CFrame.Position
			orientation = Quaternion.fromCFrame(base_part.CFrame)
			size = Vector3.new(sx, sy, sz)
			color = Color3.new(cr, cg, cb)
			shape = base_part.Shape
		end
	else
		position = base_part[1]
		orientation = base_part[2]
		size = base_part[3]
		color = base_part[4]
		shape = base_part[5]
	end

	local mesh = object[shape]()
	-- mesh.set_color(color.x, color.y, color.z)
	-- mesh.set_position(position)
	-- mesh.setRotation(orientation)
	-- mesh.setScale(size)
	return mesh
end
]]













local function access_or_table(table, i0, i1, v)
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
	local resume = coroutine.resume
	local yield = coroutine.yield

	RBXScriptSignal = {}

	RBXScriptSignal.__index = RBXScriptSignal

	function RBXScriptSignal.new()
		return setmt({_threads = {}; _callbacks = {};}, RBXScriptSignal)
	end

	function RBXScriptSignal:__call(...)
		for i = #self._threads, 1, -1 do
			scheduler.queue_resumption(self._threads[i], ...)
			self._threads[i] = nil
		end
		for _, callback in next, self._callbacks do
			callback(...)
		end
	end

	function RBXScriptSignal:Wait()
		local thread = running()
		self._threads[#self._threads + 1] = thread
		return scheduler.manual_yield(thread)
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

	local hyp = 1.4142136
	local tau = 6.2831853

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

	Quaternion.identity = new(0, 0, 0, 1)

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

		local magnitude = sqrt(x*x + y*y + z*z)

		return setmt({
			x = x; 
			y = y; 
			z = z; 

			Magnitude = magnitude; 

			Unit = setmt({
				x = x/magnitude; 
				y = y/magnitude; 
				z = z/magnitude; 
			}, Vector3); 
		}, Vector3)
	end

	local new = Vector3.new

	Vector3.zero = new(0, 0, 0)
	Vector3.one = new(1, 1, 1)

	function Vector3.__add(a, b)
		return new(a.x + b.x, a.y + b.y, a.z + b.z)
	end

	function Vector3.__sub(a, b)
		return new(a.x - b.x, a.y - b.y, a.z - b.z)
	end

	local multiplication_from_type = {}

	access_or_table(multiplication_from_type, 'number', 'Vector3', function(a, b)
		return a*b.x, a*b.y, a*b.z
	end)

	access_or_table(multiplication_from_type, 'Vector3', 'Vector3', function(a, b)
		return a.x*b.x, a.y*b.y, a.z*b.z
	end)

	access_or_table(multiplication_from_type, 'Vector3', 'Quaternion', function(a, b)
		local i, j, k = a:GetComponents()
		local x, y, z, w = b:GetComponentsDiagonal()
		return i*(1 - y*y - z*z) + j*(x*y - w*z) + k*(x*z + w*y), i*(x*y + w*z) + j*(1 - x*x - z*z) + k*(y*z - w*x), i*(x*z - w*y) + j*(y*z + w*x) + k*(1 - x*x - y*y)
	end)

	function Vector3.__mul(a, b)
		return new(multiplication_from_type[typeof(a)][typeof(b)](a, b))
	end

	local division_from_type = {}

	access_or_table(division_from_type, 'Vector3', 'Vector3', function(a, b)
		return a.x/b.x, a.y/b.y, a.z/b.z
	end)

	access_or_table(division_from_type, 'Vector3', 'number', function(a, b)
		return a.x/b, a.y/b, a.z/b
	end)

	function Vector3.__div(a, b)
		return new(division_from_type[typeof(a)][typeof(b)](a, b))
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

	function Ray.new(origin, direction)
		return setmt({Origin = origin or Vector3.zero; Direction = direction or Vector3.zero;}, Ray)
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

	function Color3.fromColor3uint8(color_value)
		return new(
			0.0039216*band(rshift(color_value, 16), 0xff),
			0.0039216*band(rshift(color_value, 8), 0xff),
			0.0039216*band(color_value, 0xff)
		)
	end

	function Color3.fromRGB(r, g, b)
		return new(0.0039216*r, 0.0039216*g, 0.0039216*b)
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

	local constructor_from_size = {}

	constructor_from_size[0] = function()
		return {}
	end

	constructor_from_size[1] = function(v)
		return {
			x = v.x; 
			y = v.y; 
			z = v.z; 
		}
	end

	constructor_from_size[2] = function(v0, v1)
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

	constructor_from_size[3] = function(x, y, z)
		return {
			x = x; 
			y = y; 
			z = z; 
		}
	end

	constructor_from_size[7] = function(x, y, z, qx, qy, qz, qw)
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

	constructor_from_size[12] = function(x, y, z, xx, yx, zx, xy, yy, zy, xz, yz, zz)
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
		return setmt(constructor_from_size[select('#', ...)](...), CFrame)
	end

	local new = CFrame.new

	CFrame.identity = new(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)

	local value_from_index = {}

	function value_from_index.Position(self)
		return Vector3.new(self.x, self.y, self.z)
	end

	function value_from_index.p(self)
		return Vector3.new(self.x, self.y, self.z)
	end

	function CFrame:__index(i)
		return value_from_index[i] and value_from_index[i](self) or rawget(self, i) or CFrame[i]
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

	local multiplication_from_type = {}

	access_or_table(multiplication_from_type, 'CFrame', 'CFrame', function(a, b)
		local ax, ay, az, axx, ayx, azx, axy, ayy, azy, axz, ayz, azz = a:GetComponents()
		local bx, by, bz, bxx, byx, bzx, bxy, byy, bzy, bxz, byz, bzz = b:GetComponents()
		return new(
			bx*axx + by*ayx + bz*azx + ax, bx*axy + by*ayy + bz*azy + ay, bx*axz + by*ayz + bz*azz + az,
			bxx*axx + bxy*ayx + bxz*azx, byx*axx + byy*ayx + byz*azx, bzx*axx + bzy*ayx + bzz*azx,
			bxx*axy + bxy*ayy + bxz*azy, byx*axy + byy*ayy + byz*azy, bzx*axy + bzy*ayy + bzz*azy,
			bxx*axz + bxy*ayz + bxz*azz, byx*axz + byy*ayz + byz*azz, bzx*axz + bzy*ayz + bzz*azz
		)
	end)

	access_or_table(multiplication_from_type, 'CFrame', 'Vector3', function(a, b)
		return Vector3.new(a.x + b.x*a.xx + b.y*a.yx + b.z*a.zx, a.y + b.x*a.xy + b.y*a.yy + b.z*a.zy, a.z + b.x*a.xz + b.y*a.yz + b.z*a.zz)
	end)

	function CFrame.__mul(a, b)
		return multiplication_from_type[typeof(a)][typeof(b)](a, b)
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
	local resume = coroutine.resume
	local running = coroutine.running

	function wait(seconds)
		--[[
		-- Single-threaded
		yield('second', seconds)
		return true
		]]
		-- Multi-threaded
		local thread = running()
		scheduler.elapsed(seconds).once(function()
			resume(thread, true) -- Roblox returns true for some reason
		end)
		return yield()
	end
end





































local attributes_from_instance = {}

local instance_from_referent_id = {}

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

local function new_instance_class(class_name, ...) -- Class names that you want to inherit
	local setmt = setmetatable

	local class = {}

	local inherits = {...}
	for i = 1, #inherits do
		class = combine({classes[inherits[i]], class})
	end

	classes[class_name] = class

	class.Name = class_name
	class.ClassName = class_name
	class.TypeName = 'Instance'

	function class:Clone()
		return self
	end -- TODO

	function class:__tostring()
		return self.Name
	end

	function class:FindFirstChild(name)
		for instance in next, self._children do
			if instance.Name == name then
				return instance
			end
		end
	end

	function class:_setReferentId(referent_id) -- This should only be called once per instance
		local referent_id0 = self._referentId
		if referent_id0 then
			instance_from_referent_id[referent_id0] = nil
		end
		self._referentId = referent_id
		instance_from_referent_id[referent_id] = self
	end

	-- Store references to the 'coroutine.running' and 'coroutine.yield' functions for convenience.
	local running = coroutine.running
	local yield = coroutine.yield

	-- Define the 'WaitForChild' function within the class.
	function class:WaitForChild(name)
		-- Attempt to find a instance with the given 'name' within the instance.
		local instance = self:FindFirstChild(name)

		-- If the instance is not found, execute the following block.
		if not instance then
			-- Print a message indicating that the code is waiting for the specified instance.
			print('Gotta wait for instance', name)

			-- Get the current coroutine thread.
			local thread = running()

			-- Declare a local variable 'connection', which will hold a connection to the 'ChildAdded' event.
			local connection

			-- Connect a callback function to the 'ChildAdded' event of the instance.
			-- The callback will be executed every time a new instance is added to the instance.
			connection = self.ChildAdded:Connect(function(instance)
				-- Check if the added instance has the desired 'name'.
				if instance.Name == name then
					-- If the instance with the desired 'name' is found, disconnect the event connection.
					connection:Disconnect()

					-- Print a message indicating that the desired instance has been found, along with the coroutine thread.
					print('THE CHILD HAS COME', thread)

					-- Queue a resumption of the specified coroutine thread along with the found instance as a parameter.
					scheduler.queue_resumption(thread, instance)
				end
			end)

			-- Manually yield the coroutine thread to the scheduler.
			-- The coroutine will be paused until it is explicitly resumed by the scheduler.
			return scheduler.manual_yield(thread)
		end

		-- If the instance is found, return the reference to the instance.
		return instance
	end

	local random = math.random

	function class.new()
		local self = setmt({}, class)

		attributes_from_instance[self] = {}

		self.Changed = RBXScriptSignal.new()
		self.ChildAdded = RBXScriptSignal.new()
		self.ChildRemoved = RBXScriptSignal.new()
		self._children = {}
		self:_setReferentId(random())

		return self
	end

	-- This could probably be faster if we weren't utilizing only the index and newindex metamethods
	-- TODO: convert to table class and maybe things will be faster as attributes_from_instance can just be attributes in local scope
	function class:__index(i)
		return attributes_from_instance[self][i] or class[i] or self:FindFirstChild(i)
	end

	function class:__newindex(i, v)
		attributes_from_instance[self][i] = v
		if i == 'Parent' then
			self:_triggerNewParent(v)
		end
		self.Changed(i)
	end

	function class:GetChildren()
		local children = {}
		for instance in next, self._children do
			children[#children + 1] = instance
		end
		return children
	end

	function class:GetDescendants()
		local descendants = {}
		local descendants_count = 0
		local stack = {self}
		local stack_count = 1 -- TODO: is #whatever faster than whatever_count for this?
		while stack_count > 0 do
			local instance = stack[stack_count]
			stack_count = stack_count - 1
			for instance in next, instance._children do
				descendants_count = descendants_count + 1
				descendants[descendants_count] = instance
				stack_count = stack_count + 1
				stack[stack_count] = instance
			end
		end
		return descendants
	end

	function class:IsDescendantOf(target)
		assert(target, 'IsDescendantOf target is invalid')
		while self do -- self ~= nil might be better
			if self.Parent == target then
				return true
			end
			self = self.Parent
		end
		return false
	end

	function class:_triggerNewParent(parent)
		--print('_triggerNewParent', self, parent, '~~~ .Parent = (ref) ', parent._referentId)
		self.Parent._children[self] = nil
		self.Parent.ChildRemoved(self) -- TODO: idk if this gets called before or after the instance removal
		if parent then -- Whatever
			parent._children[self] = true
			parent.ChildAdded(self)
		end
	end

	function class:Destroy()
		self:_triggerNewParent(nil)
		self:ClearAllChildren() -- Inline is faster but whatever
	end

	function class:ClearAllChildren()
		for instance in next, self._children do
			instance:Destroy()
		end
	end

	return class
end





Instance = {}

function Instance.new(class_name, parent)
	assert(classes[class_name], '[Error] Trying to instantiate a non-existing class: '..class_name)

	if parent == nil then
		return classes[class_name].new()
	else
		print('[Warning] Avoid use of parent argument in instance constructor')

		local self = classes[class_name].new()
		self.Parent = parent
		return self
	end
end





























new_instance_class('BlockMesh')
new_instance_class('BubbleChatConfiguration')
new_instance_class('Chat')
new_instance_class('ChatInputBarConfiguration')
new_instance_class('ChatWindowConfiguration')
new_instance_class('Debris')
new_instance_class('Decal')
new_instance_class('EqualizerSoundEffect')
new_instance_class('Folder')
new_instance_class('Frame')
new_instance_class('Geometry')
new_instance_class('Humanoid')
new_instance_class('ImageLabel')
new_instance_class('Lighting')
new_instance_class('ManualWeld')
new_instance_class('Model')
new_instance_class('Player')
new_instance_class('PlayerGui')
new_instance_class('ScreenGui')
new_instance_class('Selection')
new_instance_class('SelectionBox')
new_instance_class('ServerStorage')
new_instance_class('Sky')
new_instance_class('Sound')
new_instance_class('SpecialMesh')
new_instance_class('SpotLight')
new_instance_class('StarterCharacterScripts')
new_instance_class('StarterGui')
new_instance_class('StarterPack')
new_instance_class('StarterPlayer')
new_instance_class('StarterPlayerScripts')
new_instance_class('StringValue')
new_instance_class('StudioData')
new_instance_class('SurfaceGui')
new_instance_class('Teams')
new_instance_class('Terrain')
new_instance_class('TextLabel')
new_instance_class('UnionOperation')
new_instance_class('VirtualInputManager')




do
	local RemoteEvent = new_instance_class('RemoteEvent')

	local new = RemoteEvent.new

	function RemoteEvent.new()
		local self = new()

		self.OnServerEvent = RBXScriptSignal.new()
		self.OnClientEvent = RBXScriptSignal.new()

		return self
	end

	function RemoteEvent:FireServer(...)
		self:_replicateCall(server, 'OnServerEvent', ...)
	end

	function RemoteEvent:FireClient(player, ...)
		self:_replicateCall(player, 'OnClientEvent', ...)
	end

	function RemoteEvent:FireAllClients(...)
		local players = game.Players:GetChildren()
		for i = 1, #players do
			self:_replicateCall(players[i], 'OnClientEvent', ...)
		end
	end
end

do
	local yield = coroutine.yield
	local running = coroutine.running

	local RemoteFunction = new_instance_class('RemoteFunction')

	function RemoteFunction.OnServerInvoke()
	end

	function RemoteFunction.OnClientInvoke()
	end

	function RemoteFunction:InvokeServer(...)
		local thread = running()
		print('InvokeServer', self, ...)
		local code = math.random() -- This should probably be the referent id
		switchboard.send_to(peer, 'invoke', code, ...)
		local invoke_connection
		invoke_connection = switchboard.on_receive('invoke'):Connect(function(_, code1, ...)
			if code1 == code then
				invoke_connection:Disconnect()
				--RemoteFunction.OnServerInvoke(...)
				resume(thread, ...)
			end
		end)
		return yield()
	end

	function RemoteFunction:InvokeClient(player, ...)
		local thread = running()
		print('InvokeClient', self, player, ...)
		local code = math.random() -- This should probably be the referent id
		switchboard.send_to(player._socket, 'invoke', code, ...)
		local invoke_connection
		invoke_connection = switchboard.on_receive('invoke'):Connect(function(_, code1, ...)
			if code1 == code then
				invoke_connection:Disconnect()
				--RemoteFunction.OnClientInvoke(...)
				resume(thread, ...)
			end
		end)
		return yield()
	end
end

new_instance_class('LocalScript')
new_instance_class('ModuleScript')
new_instance_class('Script')

do
	local Workspace = new_instance_class('Workspace')

	local new = Workspace.new

	function Workspace.new()
		local self = new()

		workspace = self

		return self
	end

	function Workspace:FindPartsInRegion3()
		print('FindPartsInRegion3', self)
		return {}
	end -- TODO

	function Workspace:Raycast()
		print('Raycast', self)
		return {}
	end -- TODO
end

do
	local BasePart = new_instance_class('BasePart')

	BasePart.CFrame = CFrame.identity
	BasePart.Size = Vector3.new(2, 1, 4)
	BasePart.Color = Color3.new(0.75, 0.75, 0.75)
	BasePart.Anchored = false
	BasePart.CanCollide = true
end

do
	local Camera = new_instance_class('Camera', 'BasePart')

	Camera.FieldOfView = 70
end

--[[
local function get_base_part_shape(base_part)
	return base_part.ClassName == 'Part' and base_part.Shape or base_part.ClassName
end
]]

do
	local Part = new_instance_class('Part', 'BasePart')

	local new_index = {}

	function new_index.Parent(self, parent0, parent)
		self:_triggerNewParent(parent)
		if self:IsDescendantOf(workspace) then
			if not self._mesh then
				self._mesh = mesh[self.Shape]()
				function new_index.CFrame()
					self._mesh.match(self)
				end
				function new_index.Size()
					self._mesh.match(self)
				end
				self._mesh.match(self)
			end
		elseif self._mesh then
			self._mesh:Destroy()
			new_index.CFrame = nil
			new_index.Size = nil
			assert(self._mesh == nil, 'Mesh should be nil as it was deleted')
			--self._mesh = nil
		end
	end

	function Part:__newindex(i, v)
		local v0 = attributes_from_instance[self][i]
		attributes_from_instance[self][i] = v
		if new_index[i] then
			new_index[i](self, v0, v)
		end
		self.Changed(i)
	end

	Part.Shape = Enum.PartType.Block
end

do
	local WedgePart = new_instance_class('WedgePart', 'BasePart')

	local new_index = {}

	function new_index.Parent(self, parent0, parent)
		self:_triggerNewParent(parent)
		if self:IsDescendantOf(workspace) then
			if not self._mesh then
				self._mesh = mesh.wedge_part()
				function new_index.CFrame()
					self._mesh.match(self)
				end
				function new_index.Size()
					self._mesh.match(self)
				end
				self._mesh.match(self)
			end
		elseif self._mesh then
			self._mesh:Destroy()
			new_index.CFrame = nil
			new_index.Size = nil
			assert(self._mesh == nil, 'Mesh should be nil as it was deleted')
			--self._mesh = nil
		end
	end

	function WedgePart:__newindex(i, v)
		local v0 = attributes_from_instance[self][i]
		attributes_from_instance[self][i] = v
		if new_index[i] then
			new_index[i](self, v0, v)
		end
		self.Changed(i)
	end
end

local services = {}

-- services
new_instance_class('AnalyticsService')
new_instance_class('AssetService')
new_instance_class('CollectionService')
new_instance_class('ContextActionService')
new_instance_class('CookiesService')
new_instance_class('CSGDictionaryService')
new_instance_class('GamePassService')
new_instance_class('GuidRegistryService')
new_instance_class('HttpService')
new_instance_class('InsertService')
new_instance_class('LanguageService')
new_instance_class('LocalizationService')
new_instance_class('LodDataService')
new_instance_class('LuaWebService')
new_instance_class('MaterialService')
new_instance_class('NonReplicatedCSGDictionaryService')
new_instance_class('PermissionsService')
new_instance_class('PhysicsService')
new_instance_class('PlayerEmulatorService')
new_instance_class('ProcessInstancePhysicsService')
new_instance_class('ProximityPromptService')
new_instance_class('ScriptService')
new_instance_class('ServerScriptService')
new_instance_class('ServiceVisibilityService')
new_instance_class('SoundService')
new_instance_class('TeleportService')
new_instance_class('TestService')
new_instance_class('TextChatService')
new_instance_class('TimerService')
new_instance_class('TouchInputService')
new_instance_class('TweenService')
new_instance_class('VoiceChatService')
new_instance_class('VRService')

do
	local UserInputService = {}

	UserInputService.InputBegan = RBXScriptSignal.new()
	UserInputService.InputChanged = RBXScriptSignal.new()
	UserInputService.InputEnded = RBXScriptSignal.new()
	UserInputService.IsKeyDown = love.keyboard.isDown

	services.UserInputService = UserInputService
end

do
	local ReplicatedFirst = new_instance_class('ReplicatedFirst')

	function ReplicatedFirst:RemoveDefaultLoadingScreen()
		print('RemoveDefaultLoadingScreen', self)
	end -- TODO

	services.ReplicatedFirst = ReplicatedFirst
end

do
	local RunService = {}

	RunService.RenderStepped = RBXScriptSignal.new()
	RunService.Heartbeat = RBXScriptSignal.new()

	services.RunService = RunService
end

do
	local Players = new_instance_class('Players')

	local new = Players.new

	function Players.new()
		local self = new()

		self.PlayerRemoving = RBXScriptSignal.new()

		services.Players = self

		return self
	end
end

do
	local ReplicatedStorage = new_instance_class('ReplicatedStorage')

	local new = ReplicatedStorage.new

	function ReplicatedStorage.new()
		local self = new()

		services.ReplicatedStorage = self

		return self
	end
end

do
	local Game = new_instance_class('Game')

	local new = Game.new

	function Game.new()
		local self = new()

		self:_setReferentId('null')

		game = self

		return self
	end

	function Game:GetService(service_name)
		return services[service_name]
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
		ffi.cdef('void Sleep(int); ')

		local Sleep = ffi.C.Sleep

		function wait(s)
			Sleep(1000*(s or 0))
			return true
		end
	else
		ffi.cdef('int poll(struct pollfd *, unsigned long, int); ')

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

	local cached_scripts = {}

	function roblox_require(script)
		if not script._lostVirginity then
			script._lostVirginity = true
			cached_scripts[script] = yield('die', script._thread)
		end
		return cached_scripts[script]
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
	viewport_size_x = sx
	viewport_size_y = sy

	local depth_buffer = love.graphics.newCanvas(viewport_size_x, viewport_size_y, {type = '2d'; format = 'depth24';})

	geometry_buffer = {
		love.graphics.newCanvas(viewport_size_x, viewport_size_y, {type = '2d'; format = 'rgba8';}),
		love.graphics.newCanvas(viewport_size_x, viewport_size_y, {type = '2d'; format = 'rgba8';}),
		love.graphics.newCanvas(viewport_size_x, viewport_size_y, {type = '2d'; format = 'rgba8';}),
		love.graphics.newCanvas(viewport_size_x, viewport_size_y, {type = '2d'; format = 'rgba8';}),
		depthstencil = depth_buffer; 
	}

	composite_buffer = {
		love.graphics.newCanvas(viewport_size_x, viewport_size_y, {type = '2d'; format = 'rgba8';}),
		depthstencil = depth_buffer; 
	}
end)

love.resize(love.graphics.getDimensions())





















local switchboard = {}
do
	local buffer_receive_argument = '*l'

	local leopard = require('leopard')
	local socket = require('socket')

	local deserialize = leopard.deserialize
	local serialize = leopard.serialize
	local remove = table.remove

	local peers = {}
	local peers_inverse = {}

	switchboard.on_connect = RBXScriptSignal.new()
	switchboard.on_disconnect = RBXScriptSignal.new()
	switchboard.on_receive = RBXScriptSignal.new()

	function switchboard.Connect(peer)
		peers_inverse[peer] = true
		peers[#peers + 1] = peer
		switchboard.on_connect(peer)
	end

	function switchboard.run()
		for i = 1, #peers do
			local peer = peers[i]

			while true do
				local bytes, receive_status = peer:receive(buffer_receive_argument)

				if bytes then
					switchboard.on_receive(peer, deserialize(bytes))
				elseif receive_status == 'closed' then
					switchboard.on_disconnect(peer)
					peers_inverse[peer] = nil
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
			for peer in next, peers_inverse do
			local bytes, status = peer:receive(buffer_receive_argument)

			print(bytes, status)

			if bytes then
				local data = deserialize(bytes)

				switchboard.on_receive(peer, unpack(data)) -- tuple unpacking
			elseif status == 'closed' then
				switchboard.on_disconnect(peer)
				peers_inverse[peer] = nil
				peer:close()
			end
		end
		]]
	end

	function switchboard.send_all(...)
		for i = 1, #peers do
			switchboard.send_to(peers[i], ...)
		end
	end

	function switchboard.send_but(ignored_peer, ...)
		-- Lie for a little bit
		peers_inverse[ignored_peer] = nil

		for peer in next, peers_inverse do
			switchboard.send_to(peer, ...)
		end

		-- And then undo the lie
		peers_inverse[ignored_peer] = true
	end

	function switchboard.send_to(peer, ...)
		peer:send(serialize(...))
	end
end






















local network = {}
do
	network.on_connect = switchboard.on_connect
	network.on_disconnect = switchboard.on_disconnect

	local socket = require('socket')

	local callers = {}

	function network.on_receive(name)
		if not callers[name] then
			callers[name] = RBXScriptSignal.new()
		end
		return callers[name]
	end

	switchboard.on_receive:Connect(function(socket, name, ...)
		assert(callers[name], 'No caller by name: '..name)
		callers[name](socket, ...)
	end)

	function network.client(address, port)
		local host = socket.tcp()
		host:settimeout(0) -- non-blocking mode

		host:connect(address, port) -- host -> peer

		local peer = host

		switchboard.Connect(peer)

		return peer
	end

	function network.server(address, port)
		local host = socket.bind(address, port)
		host:settimeout(0) -- non-blocking mode

		function network.poll_peers()
			local peer = host:accept()
			while peer do
				peer:settimeout(0)
				switchboard.Connect(peer)
				peer = host:accept()
			end
		end

		return host
	end
end







































do
	local xml2lua = require('xml2lua/xml2lua')
	local tree = require('xml2lua/tree')

	local create = coroutine.create

	local match = {}

	local function recurse_rbxlx_node(dom_node, previous)
		for i, v in next, dom_node do
			if i ~= '_attr' and type(i) == 'string' then
				for _, instance_node in next, v do
					if match[i] then
						match[i](instance_node, previous)
					else
						-- Branch (Not a leaf?)
					end
				end
			end
		end
	end

	function match.roblox(dom_node)
		local game = Instance.new('Game')
		--game.Name = path
		recurse_rbxlx_node(dom_node, game)
	end

	local random = math.random

	-- Create a new Instance of the class
	function match.Item(dom_node, parent)
		local referent_id = dom_node._attr.referent
		local class_name = dom_node._attr.class

		local instance = Instance.new(class_name)
		instance:_setReferentId(referent_id) -- Set the referent_id to this object
		instance.Parent = parent

		recurse_rbxlx_node(dom_node, instance)
	end

	function match.Ref(dom_node, instance)
		local referent_id = dom_node[1]
		local attribute_name = dom_node._attr.name
		pending_referents[#pending_referents + 1] = {instance, attribute_name, referent_id}
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

	local script_initializers = {}

	function script_initializers.Script(script, thread)
		scheduler.queue_resumption(thread)
	end

	function script_initializers.LocalScript(script, thread)
		scheduler.queue_resumption(thread)
	end

	function script_initializers.ModuleScript(script, thread)
		script._thread = thread
	end

	if running_as.server then
		function script_initializers.LocalScript()
		end
	elseif running_as.client then
		function script_initializers.Script()
		end
	end

	function match.ProtectedString(dom_node, script)
		local entry = load('return function(script, require) return function()'..dom_node[1]..' end end')()(script, roblox_require)
		local thread = create(entry)
		--print(thread)
		script_initializers[script.ClassName](script, thread)
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

	local function link_pending_referents()
		for i = 1, #pending_referents do
			pending_referents[i][1][pending_referents[i][2]] = instance_from_referent_id[pending_referents[i][3]]
		end
	end

	local function new_place_from_path(path)
		local place_handle = io.open(path, 'r')
		local place_source = place_handle:read('*a')
		place_handle:close()
		--[[
		for tag_name, attributes, inside in ('<roblox fuck="ASD"><roblox fuck="ASD">nigga</roblox></roblox>'):gmatch('<([%w-]+)[%s]*([^>]*)>(.-)</%1>') do
			print(tag_name..' '..attributes..' '..inside)
			break
		end
		--]]
		xml2lua.parser(tree):parse(xml2lua.loadString(place_source))
		pending_referents = {}
		recurse_rbxlx_node(tree.root)
		link_pending_referents()
		game.Name = path -- place title
		love.filesystem.setIdentity(path)
		love.window.setTitle(path)
	end

	function serve_place(path, address, port)
		new_place_from_path(path)

		network.server(address, port)

		network.on_connect:Connect(function(peer)
			print(peer, 'connected to us')
		end)

		--[[
		network.on_connect:Connect(function(peer)
			--switchboard.send_to(peer, 'game', game)
			switchboard.send_to(peer, 'new_instance', game.ClassName, game._referentId, game.Parent._referentId)
			local descendants = game:GetDescendants()
			for i = 1, #descendants do
				local instance = descendants[i]
				--print(instance.ClassName, instance._referentId)
				switchboard.send_to(peer, 'new_instance', instance.ClassName, instance._referentId, instance.Parent._referentId)
			end
			switchboard.send_to(peer, 'end_instances')
		end)
		]]

		local run_service = game:GetService('RunService')

		local function main_step(dt)
			network.poll_peers()
			switchboard.run()
			scheduler.run()
			run_service.Heartbeat(time(), dt)
		end

		love.update:Connect(main_step)

		-- game.Players.LocalPlayer = game.Players[MY_IP_ADDRESS]

		--[[
		if running_as.client then
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

			local player_gui = Instance.new('PlayerGui')
			player_gui.Parent = player

			game.Players.LocalPlayer = player
		end
		]]

		--do_it_all()

		-- network.on_receive('bounce')
		--[[
		love.update:Connect(function()
			local event = host:service()
			while event do
				event.switchboard.send_to(peer, 'ping')

				if event.type == 'receive' then
					local data = deserialize(event.data)

					print('NETWORK', unpack(data))

					local player = game.Players[tostring(event.peer)]

					if data[1] == 'event' then
						if running_as.server then
							remote_map.event(player, unpack(data, 2))
						elseif running_as.client then
							remote_map.event(unpack(data, 2))
						end
					elseif data[1] == 'invoke' then
						if running_as.server then
							event.switchboard.send_to(peer, 'bounce', remote_map.invoke(player, unpack(data, 2)))
						elseif running_as.client then
							event.switchboard.send_to(peer, 'bounce', remote_map.invoke(unpack(data, 2)))
						end
					elseif data[1] == 'bounce' then
						--print(unpack(data))
						--print(invoking_thread)
						scheduler.queue_resumption(invoking_thread, unpack(data, 2))
						invoking_thread = nil -- only needed for when things go wrong.
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

	function join_place(address, port)
		--[[
		network.on_receive('place_source'):Once(function(_, place_source)
			print(place_source, #place_source)
			new_place_from_path(place_source)
		end)
		]]

		new_place_from_path('bowmen2.rbxlx')

		network.client(address, port)

		love.keypressed:Connect(function(key)
			if key == 'c' then
				print('Mouse lock toggle')
				love.mouse.setRelativeMode(not love.mouse.getRelativeMode())
			elseif key == 'printscreen' then
				print('Screenshot')
				love.graphics.captureScreenshot(tick()..'.png')
			end
		end)

		local function new_projection_frustum(v, a, n, f)
			local i = 1/(n - f)
			return {
				a*v, 0, 0, 0,
				0, v, 0, 0,
				0, 0, (n + f)*i, 2*n*f*i,
				0, 0, -1, 0
			}
		end

		--[[
		local function do_it_all()
			remote_map = {}
			if running_as.server then
				game.ReplicatedStorage.ChildAdded:Connect(function(instance)
					if instance.ClassName == 'RemoteEvent' then
						remote_map.event = game.ReplicatedStorage.RemoteEvent.OnServerEvent
					elseif instance.ClassName == 'RemoteFunction' then
						remote_map.invoke = game.ReplicatedStorage.RemoteFunction.OnServerInvoke
					end
				end)
			elseif running_as.client then
				local remote_event = Instance.new('RemoteEvent')
				local remote_function = Instance.new('RemoteFunction')

				remote_event.Parent = game.ReplicatedStorage
				remote_function.Parent = game.ReplicatedStorage

				remote_map.event = game.ReplicatedStorage.RemoteEvent.OnClientEvent
				remote_map.invoke = game.ReplicatedStorage.RemoteFunction.OnClientInvoke
			end
		end
		]]

		--[[
		love.update:Connect(function()
			local event = host:service()
			while event do
				event.switchboard.send_to(peer, 'ping')

				if event.type == 'receive' then
					--print(data[1])

					--print('NETWORK', unpack(data))

					--local player = game.Players[tostring(event.peer)]

					local data = deserialize(event.data)
					network.receiveSignals[data[1]]-- (event.peer, unpack(data, 2))

					--[[
					if data[1] == 'event' then
						-- remote_map.event(unpack(data, 2))
					elseif data[1] == 'invoke' then
						-- event.switchboard.send_to(peer, 'bounce', remote_map.invoke(unpack(data, 2)))
					elseif data[1] == 'bounce' then
						scheduler.queue_resumption(invoking_bounce_thread, unpack(data, 2))
						invoking_bounce_thread = nil -- only needed for when things go wrong.
					elseif data[1] == 'uhh' then

					end
				elseif event.type == 'connect' then
					network.on_connect(event.peer)
					-- new_place_from_path()
					-- peer = event.peer
					-- do_it_all()
					-- parsed_place()
				elseif event.type == 'disconnect' then
					network.on_disconnect(event.peer)
				end

				event = host:service()
			end
		end)
		]]

		local parsed_place = RBXScriptSignal.new()

		--[[
		local receive_instance
		receive_instance = network.on_receive('new_instance'):Connect(function(peer, class_name, referent_id, parent_referent_id)
			local parent = instance_from_referent_id[parent_referent_id]
			local instance = Instance.new(class_name)
			instance:_setReferentId(referent_id)
			instance.Parent = parent
			--print(instance, instance._referentId)
		end)
		]]

		--[[
		network.on_receive('end_instances'):Once(function()
			print('No longer receiving initial parts')
			receive_instance:Disconnect()
			parsed_place()
		end)
		]]

		parsed_place:Connect(function()
			local run_service = game:GetService('RunService')
			local replicated_storage = game:GetService('ReplicatedStorage')

			---[[
			local l = 400
			for _, v in next, replicated_storage:GetDescendants() do
				v.Parent = workspace
				l = l - 1
				if l < 0 then
					break
				end
			end
			--]]

			local function main_step(dt)
				switchboard.run()
				scheduler.run()
				run_service.Heartbeat(time(), dt)
				run_service.RenderStepped(dt)
			end

			love.update:Connect(main_step)









			local hdri = love.graphics.newImage('hdris/tennisnight.jpg')

			local current_camera = workspace.CurrentCamera

			love.draw:Connect(function()
				local cameraP = {current_camera.CFrame.Position:GetComponents()}
				local cameraO = {Quaternion.fromCFrame(current_camera.CFrame):GetComponents()}
				local cameraT = new_projection_frustum(1, viewport_size_y/viewport_size_x, 0.1, 100000)

				love.graphics.setDepthMode('less', true)
				love.graphics.setMeshCullMode('front')

				-- draw to geometry buffer
				love.graphics.setCanvas(geometry_buffer)
				love.graphics.clear()

				love.graphics.setShader(geometry_shader)
				geometry_shader:send('cameraP', cameraP)
				geometry_shader:send('cameraO', cameraO)
				geometry_shader:send('cameraT', cameraT)

				for i = 1, #meshes do
					meshes[i].draw()
				end

				-- sky?
				--[[
				love.graphics.setCanvas()

				love.graphics.setShader(sky_shader)
				sky_shader:send('cameraO', cameraO)
				-- sky_shader:send('cameraT', cameraT)
				sky_shader:send('skyTex', hdri)

				love.graphics.draw(composite_buffer[1])
				]]

				-- draw to screen
				love.graphics.setCanvas()

				love.graphics.setShader(deband_shader)
				deband_shader:send('worldNs', geometry_buffer[2])
				deband_shader:send('worldCs', geometry_buffer[3])

				love.graphics.draw(composite_buffer[1])

				-- fps
				love.graphics.reset()
				love.graphics.print(love.timer.getFPS())
			end)


			---[[
			local mouse_coefficient = 1/256

			local function from_axis_angle(v)
				return v.Magnitude > 0 and CFrame.fromAxisAngle(v.Unit, v.Magnitude) or CFrame.identity
			end

			love.mousemoved:Connect(function(_, _, dx, dy)
				current_camera.CFrame = current_camera.CFrame*from_axis_angle(Vector3.new(-mouse_coefficient*dy, -mouse_coefficient*dx, 0))
			end)

			love.update:Connect(function(dt)
				local target_velocity = Vector3.new(
					(love.keyboard.isDown('d') and 1 or 0) + (love.keyboard.isDown('a') and -1 or 0),
					(love.keyboard.isDown('e') and 1 or 0) + (love.keyboard.isDown('q') and -1 or 0),
					(love.keyboard.isDown('s') and 1 or 0) + (love.keyboard.isDown('w') and -1 or 0)
				)

				current_camera.CFrame = current_camera.CFrame*CFrame.new(32*dt*target_velocity)
			end)

			love.update:Connect(step)
			--]]
		end)

		parsed_place()

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

		local player_gui = Instance.new('PlayerGui')
		player_gui.Parent = player

		game.Players.LocalPlayer = player
		]]













		local hdri = love.graphics.newImage('hdris/tennisnight.jpg')

		--[[
		love.draw:Connect(function()
			local cameraP = {current_camera.CFrame.p:GetComponents()}
			local cameraO = {Quaternion.fromCFrame(current_camera.CFrame):GetComponents()}
			local cameraT = new_projection_frustum(1, viewport_size_y/viewport_size_x, 0.1, 10000)

			love.graphics.setDepthMode('less', true)
			love.graphics.setMeshCullMode('front')

			-- draw to geometry buffer
			love.graphics.setCanvas(geometry_buffer)
			love.graphics.clear()

			love.graphics.setShader(geometry_shader)
			geometry_shader:send('cameraP', cameraP)
			geometry_shader:send('cameraO', cameraO)
			geometry_shader:send('cameraT', cameraT)

			for i = 1, #meshes do
				meshes[i].draw()
			end

			-- sky?
			--[[
			love.graphics.setCanvas()

			love.graphics.setShader(sky_shader)
			sky_shader:send('cameraO', cameraO)
			--sky_shader:send('cameraT', cameraT)
			sky_shader:send('skyTex', hdri)

			love.graphics.draw(composite_buffer[1])
			]]

			--[[
			-- draw to screen
			love.graphics.setCanvas()

			love.graphics.setShader(deband_shader)
			deband_shader:send('worldNs', geometry_buffer[2])
			deband_shader:send('worldCs', geometry_buffer[3])

			love.graphics.draw(composite_buffer[1])

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

	light_mesh = love.graphics.newMesh(vertex_attribute_map.light, vertices, 'triangles', 'dynamic')
end

function light.new()
	local color = Color3.new(1, 1, 1)
	local position = Vector3.zero

	local alpha = 0.5

	local self = {}

	function self.set_position(position1)
		position = position1
	end

	function self.set_color(color1)
		color = color1
	end

	function self.set_alpha(alpha1)
		alpha = alpha1
	end

	function self.get_position()
		return position
	end

	function self.get_color()
		return color
	end

	function self.get_alpha()
		return alpha
	end

	local frequency_scale = Vector3.new(0.3, 0.59, 0.11)

	function self.get_draw_data()
		local brightness = frequency_scale:Dot(color)
		local radius = sqrt(brightness/alpha)
		vertT[1] = radius
		vertT[4] = position.x
		vertT[6] = radius
		vertT[8] = position.y
		vertT[11] = radius
		vertT[12] = position.z
		colorT[1] = color.x
		colorT[2] = color.y
		colorT[3] = color.z
	end

	return light_mesh, vertT, colorT
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

	sampler.get_draw_data()
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

	local tau = 6.2831853

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
		local s = random()^0.3333333
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

		function self.get_draw_data()
			offset[1] = random(w) - 1
			offset[2] = random(h) - 1
			return image, size, offset
		end

		return self
	end
end











































if running_as.server then
	serve_place('bowmen2.rbxlx', 'localhost', 57005)
elseif running_as.client then
	join_place('localhost', 57005)
end