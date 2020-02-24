--created by axisangle
--rewrite by blocksrocks1234

local remove = table.remove

local function event(tab, name)
	local count = 0
	local funcs = {}
	
	local function run(...)
		for ind = 1, count do
			funcs[ind](...)
		end
	end
	
	local function add(func)
		count = count + 1
		funcs[count] = func
		
		local function del()
			for ind = 1, count do
				if funcs[ind] == func then
					count = count - 1
					remove(funcs, ind)
					break
				end
			end
		end
		
		return del
	end
	
	if tab then
		tab[name] = add
	end
	
	return run, add
end

return event
