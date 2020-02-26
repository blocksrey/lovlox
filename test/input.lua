--modules
local vector3 = _G.load("vector3")
local signal  = _G.load("signal")

--services
local getserv   = game.GetService
local inputserv = getserv(game, "UserInputService")

--localized
local sunit  = vector3.safeunitize
local v3     = Vector3.new
local nv3    = v3()
local isdown = inputserv.IsKeyDown

local mouse = {}

function mouse.hide()
	inputserv.MouseIconEnabled = false
end

function mouse.show()
	inputserv.MouseIconEnabled = true
end

function mouse.capture()
	inputserv.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
end

function mouse.release()
	inputserv.MouseBehavior = Enum.MouseBehavior.Default
end

function mouse.lockcenter()
	inputserv.MouseBehavior = Enum.MouseBehavior.LockCenter
end

local input = {}

input.mouse = mouse

function input.getdirection()
	local ka = isdown(inputserv, Enum.KeyCode.A)
	local kd = isdown(inputserv, Enum.KeyCode.D)
	local kq = isdown(inputserv, Enum.KeyCode.Q)
	local ke = isdown(inputserv, Enum.KeyCode.E)
	local ks = isdown(inputserv, Enum.KeyCode.S)
	local kw = isdown(inputserv, Enum.KeyCode.W)
	local ix = ka and not kd and -1 or not ka and kd and 1 or 0
	local iy = kq and not ke and -1 or not kq and ke and 1 or 0
	local iz = ks and not kw and -1 or not ks and kw and 1 or 0
	return sunit(v3(ix, iy, -iz))
end

signal(inputserv.InputBegan  , input, "began"  )
signal(inputserv.InputChanged, input, "changed")
signal(inputserv.InputEnded  , input, "ended"  )

return input
