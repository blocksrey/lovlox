--blocksrocks1234

--modules
local event = _G.load("event")

--vars
local signal     = game.Changed
local connect    = signal.Connect
local connection = connect(signal, function() end)
local disconnect = connection.Disconnect
disconnect(connection)

local function new(sig, tab, name)
	local run, add = event(tab, name)
	
	local con = connect(sig, run)
	
	local function del()
		disconnect(con)
	end
	
	return add, del
end

return new
