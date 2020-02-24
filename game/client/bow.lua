--localized
local instance = Instance.new
local nex      = next
local v3       = Vector3.new
local cf       = CFrame.new
local ncf      = cf()
local angles   = CFrame.Angles
local atan     = math.atan
local atan2    = math.atan2

--modules
local spring = _G.load("spring")

--constants
local pi = math.pi

local partdefaults = {
	Anchored      = true;
	CanCollide    = false;
	Material      = Enum.Material.SmoothPlastic;
	BottomSurface = Enum.SurfaceType.Smooth;
	TopSurface    = Enum.SurfaceType.Smooth;
}

local function newobj(t, p, l)
	local o = instance(t, l)
	for i, v in nex, p do
		o[i] = v
	end
	return o
end

local function layer(l, t)
	local t = t or {}
	for i = 1, #l do
		for i, v in nex, l[i] do
			t[i] = v
		end
	end
	return t
end

local function solverestposition(y, a, b)
	return (b*b - a*a - y*y + 2*(a*a*y*y)^(1/2))^(1/2)
end

local function solveintersection(x, y, a, b)
	local d = x*x + y*y
	local s = a + b
	local c = a - b
	local n = s*c + d
	local m = (y*y*(c*c - d)*(d - s*s))^(1/2)
	local i = (x*n +     m)/(2*d)
	local j = (y*n - x/y*m)/(2*d)
	--local i = (x*n -     m)/(2*d)
	--local j = (y*n + x/y*m)/(2*d)
	return i, j
end

local function solveangles(x, y, a, b)
	local i, j = solveintersection(x, y, a, b)
	return atan2(i, j), atan2(i - x, j - y)
end

local function stringframe(m, f, s, x, y, a, b)
	local a0, a1 = solveangles(x, y, a, b)
	f.CFrame = m*cf(0, -y, 0)*angles(a0, 0, 0)*cf(0, 1/2*a, 0)
	s.CFrame = m*cf(0, 0, x)*angles(a1, 0, 0)*cf(0, 1/2*b, 0)
end

local bow = {}

function bow.newmodel(self, parent)
	local framesize   = self.framesize
	local stringsize  = self.stringsize
	local stringcolor = self.framecolor
	local framecolor  = self.stringcolor
	
	--frame init
	local framecosmetic = {
		Color = framecolor
	}
	local framedefaults = layer({
		partdefaults;
		framecosmetic;
		{
			Size = framesize;
		}
	})
	local frameedgedefaults = layer({
		partdefaults;
		framedefaults;
		{
			Size  = v3(framesize.x, framesize.x, framesize.z);
			Shape = Enum.PartType.Cylinder;
		}
	})
	
	--string init
	local stringcosmetic = {
		Color = stringcolor;
	}
	local stringdefaults = layer({
		partdefaults;
		stringcosmetic;
		{
			Size = stringsize;
		}
	})
	local stringedgedefaults = layer({
		partdefaults;
		stringcosmetic;
		{
			Size  = v3(stringsize.x, stringsize.x, stringsize.z);
			Shape = Enum.PartType.Cylinder;
		}
	})
	
	--construct
	local model = newobj("Model", {Name = "bow"}, parent)
	
	newobj("Part", layer({framedefaults     , {Name = "framebottom" }}), model)
	newobj("Part", layer({framedefaults     , {Name = "framemiddle" }}), model)
	newobj("Part", layer({framedefaults     , {Name = "frametop"    }}), model)
	newobj("Part", layer({frameedgedefaults , {Name = "frameedge0"  }}), model)
	newobj("Part", layer({frameedgedefaults , {Name = "frameedge1"  }}), model)
	newobj("Part", layer({frameedgedefaults , {Name = "frameedge2"  }}), model)
	newobj("Part", layer({frameedgedefaults , {Name = "frameedge3"  }}), model)
	newobj("Part", layer({stringdefaults    , {Name = "stringbottom"}}), model)
	newobj("Part", layer({stringdefaults    , {Name = "stringtop"   }}), model)
	newobj("Part", layer({stringedgedefaults, {Name = "stringedge"  }}), model)
	
	return model
end

function bow.match(model, self)
	local fb  = model.framebottom
	local fm  = model.framemiddle
	local ft  = model.frametop
	local fe0 = model.frameedge0
	local fe1 = model.frameedge1
	local fe2 = model.frameedge2
	local fe3 = model.frameedge3
	local sb  = model.stringbottom
	local st  = model.stringtop
	local se  = model.stringedge
	
	local m = self.cf
	local x = self.s.p
	
	fm.CFrame = m
	stringframe(m, fb, sb, x,  1/2*fm.Size.y, fb.Size.y, sb.Size.y)
	stringframe(m, ft, st, x, -1/2*fm.Size.y, ft.Size.y, st.Size.y)
	se.CFrame  = m*cf(0, 0, x)
	fe0.CFrame = fb.CFrame*cf(0,  1/2*fb.Size.y, 0)
	fe1.CFrame = fm.CFrame*cf(0, -1/2*fm.Size.y, 0)
	fe2.CFrame = fm.CFrame*cf(0,  1/2*fm.Size.y, 0)
	fe3.CFrame = ft.CFrame*cf(0,  1/2*ft.Size.y, 0)
end

function bow.draw(self)
	local s = self.s
	if s.b == self.r then
		s.b = 4/3
		s.k = 16
		s.d = 1
		return true
	else
		return false
	end
end

function bow.rest(self)
	local s = self.s
	if s.b == self.r then
		return false
	else
		s.b = self.r
		s.k = 16
		s.d = 1
		return true
	end
end

function bow.release(self)
	local s = self.s
	if s.b == self.r then
		return false
	else
		s.b = self.r
		s.k = 32
		s.d = 1/4
		return true
	end
end

function bow.new(table)
	local cf = table.cf or ncf
	local s  = spring.new(table.s or {})
	local r  = solverestposition(1/2, 7/5, 1)
	
	local self = {}
	
	self.cf = cf
	self.s  = s
	self.r  = r
	
	bow.release(self)
	
	return self
end

function bow.update(b, t1)
	spring.update(b.s, t1)
end

return bow
