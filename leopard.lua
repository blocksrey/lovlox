local sub, format, rep, byte, match, dump, gsub = string.sub, string.format, string.rep, string.byte, string.match, string.dump, string.gsub
local info = debug.getinfo
local huge, Type, Pairs, tostring, concat, ipairs = math.huge, type, pairs, tostring, table.concat, ipairs

local function ByteString(k)
	return format("\\%03d", byte(k))
end

local function FormatFunction(func)
	local proto = info and info(func, "u")
	if proto and proto.what ~= "C" then
		return format("function(...) return (load(\"%s\"))(...); end", gsub(dump(func), ".", ByteString))
	elseif proto then
		local params = {}
		if proto.nparams then
			for i = 1, proto.nparams do
				params[i] = format("p%d", i)
			end
			if proto.isvararg then
				params[#params+1] = "..."
			end
		end
		return format("function(%s) end", concat(params, ", "))
	end
	return "function()end"
end

local function FormatString(str)
	return (gsub(str, ".", function(c)
		return (c == "\n" and "\\n") or (c == "\t" and "\\t") or (c == "\"" and "\\\"") or (byte(c) < 32 or byte(c) > 126) and format("\\%03d", byte(c)) or c
	end))
end

local function FormatNumber(numb)
	if numb == huge then
		return "math.huge"
	elseif numb == -huge then
		return "-math.huge"
	end
	return tostring(numb)
end

local function FormatIndex(idx)
	local indexType = Type(idx)
	local finishedFormat = idx
	if indexType == "string" then
		if match(idx, "[^_%a%d]+") then
			finishedFormat = format("\"%s\"", FormatString(idx))
		end
	elseif indexType == "table" then
		finishedFormat = serialize(idx)
	elseif indexType == "number" or indexType == "boolean" then
		finishedFormat = FormatNumber(idx)
	elseif indexType == "function" then
		finishedFormat = FormatFunction(idx)
	elseif indexType == "nil" then
		finishedFormat = "nil"
	end
	return format("[%s]", finishedFormat)
end

local function serialize(...)
	local nargs = select('#', ...)
	local Serialized = ''
	for i = 1, nargs do
		local v = select(i, ...)

		local formattedIndex = FormatIndex(i)
		local valueType = Type(v)

		if valueType == "string" then
			Serialized = Serialized..format("%s\"%s\",", format(IndexNeeded and "%s = " or "", formattedIndex), FormatString(v))
		elseif valueType == "number" or valueType == "boolean" then
			Serialized = Serialized..format("%s%s,", format(IndexNeeded and "%s = " or "", formattedIndex), FormatNumber(v))
		elseif valueType == "table" then
			Serialized = Serialized..format("%s%s,", format(IndexNeeded and "%s = " or "", formattedIndex), serialize(v))
		elseif valueType == "userdata" then
			Serialized = Serialized..format("%snewproxy(),", format(IndexNeeded and "%s = " or "", formattedIndex))
		elseif valueType == "function" then
			Serialized = Serialized..format("%s%s,", format(IndexNeeded and "%s = " or "", formattedIndex), FormatFunction(v))
		else
			Serialized = Serialized..format("%s%s,", format(IndexNeeded and "%s = " or "", formattedIndex), tostring(valueType))
		end
	end

	return Serialized:sub(1, -2)..'\n'
end

local function deserialize(encoded)
	return load('return '..encoded)()
end

return {
	serialize = serialize;
	deserialize = deserialize;
}