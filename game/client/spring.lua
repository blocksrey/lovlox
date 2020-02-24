--spring module
--made by octonions and blocksrocks1234

--localized
local cos = math.cos
local sin = math.sin
local exp = math.exp

--constants
local e = exp(1)

local function solved(p, b, v, k, d, t)
	if k > 0 then
		if d < 1 then
			local h = (1 - d*d)^(1/2)
			local si = sin(h*k*t)
			local co = h*cos(h*k*t)
			local ex = h*e^(d*k*t)
			return b + (k*(p - b)*(co + d*si) + v*si)/(k*ex), (k*(b - p)*si + v*(co - d*si))/ex
		else
			local ex = e^(k*t)
			return b + ((p - b)*(1 + k*t) + v*t)/ex, (v - (k*(p - b) + v)*k*t)/ex
		end
	else
		return p + t*v, v
	end
end

local spring = {solved = solved}

function spring.new(table)
	local self = {}
	
	--variables
	self.t = table.t or 0--time
	self.p = table.p or 0--position
	self.v = table.v or 0--velocity
	
	--constants
	self.b = table.b or 0--target
	self.k = table.k or 0--constant
	self.d = table.d or 0--dampness
	
	return self
end

function spring.update(self, t1)
	--variables
	local t0 = self.t
	local p0 = self.p
	local v0 = self.v
	
	--constants
	local b = self.b
	local k = self.k
	local d = self.d
	
	--calculation
	local td = t1 - t0
	local p1, v1 = solved(p0, b, v0, k, d, td)
	
	--output
	self.t = t1
	self.p = p1
	self.v = v1
end

return spring