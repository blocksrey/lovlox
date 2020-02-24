local v3   = Vector3.new
local nv3  = v3()
local dot  = nv3.Dot
local rand = math.random
local pi   = math.pi
local cos  = math.cos
local sin  = math.sin
local acos = math.acos

local vector3 = {}

function vector3.safeunitize(v)
	local x, y, z = v.x, v.y, v.z
	local l = (x*x + y*y + z*z)^(1/2)
	return l > 0 and v3(x/l, y/l, z/l) or nv3
end

function vector3.random()
	local r = rand()^(1/2)
	local t = 2*pi*rand()
	local x = r*cos(t)
	local y = r*sin(t)
	local z = (1 - x*x - y*y)^(1/2)
	return v3(2*x*z, 2*y*z, 2*(x*x + y*y) - 1)
end

function vector3.quaternion(q)
	local w, x, y, z = q[1], q[2], q[3], q[4]
	local l = (x*x + y*y + z*z)^(1/2)
	local t = 2*acos(w)
	local s = (1 - w*w)^(1/2)
	return v3(t*x/l, t*y/l, t*z/l)
end

function vector3.quatworld(q, v)
	local w, x, y, z = q[1], q[2], q[3], q[4]
	local i, j, k = v[1], v[2], v[3]
	return v3(
		i - 2*(i*(y*y + z*z) - j*(x*y - z*w) - k*(x*z + y*w)),
		j + 2*(i*(x*y + z*w) - j*(x*x + z*z) + k*(y*z - x*w)),
		k + 2*(i*(x*z - y*w) + j*(y*z + x*w) - k*(x*x + y*y))
	)
end

function vector3.quatlocal(q, v)
	local w, x, y, z = q[1], q[2], q[3], q[4]
	local i, j, k = v[1], v[2], v[3]
	return v3(
		i - 2*(i*(y*y + z*z) - j*(x*y + z*w) - k*(x*z - y*w)),
		j + 2*(i*(x*y - z*w) - j*(x*x + z*z) + k*(y*z + x*w)),
		k + 2*(i*(x*z + y*w) + j*(y*z - x*w) - k*(x*x + y*y))
	)
end

function vector3.slerp(a, b, p)
	local ax, ay, az = a.x, a.y, a.z
	local bx, by, bz = b.x, b.y, b.z
	local t = acos(ax*bx + ay*by + az*bz)
	local s = sin(p*t)
	local c = cos(p*t)
	local nx = ay*(ay*bx - ax*by) + az*(az*bx - ax*bz)
	local ny = ax*(ax*by - ay*bx) + az*(az*by - ay*bz)
	local nz = bz*(ax*ax + ay*ay) - az*(ax*bx + ay*by)
	local l = (nx*nx + ny*ny + nz*nz)^(1/2)
	return v3(
		ax*c + nx/l*s,
		ay*c + ny/l*s,
		az*c + nz/l*s
	)
end

function vector3.dotself(v)
	return dot(v, v)
end

return vector3