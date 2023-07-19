local insert = table.insert
local remove = table.remove

local function init()
	local obj = {root = {}}
	obj._stack = {obj.root}
	return obj
end

local tree = init()
tree.__index = tree

---Instantiates a new handler object.
--Each instance can handle a single XML.
--By using such a constructor, you can parse
--multiple XML files in the same application.
--@return the handler instance
function tree:new()
	local obj = init()
	obj.__index = self
	setmetatable(obj, self)
	return obj
end

---If an object is not an array,
--creates an empty array and insert that object as the 1st element.
--
--It's a workaround for duplicated XML tags outside an inner tag. Check issue #55 for details.
--It checks if a given tag already exists on the parsing stack.
--In such a case, if that tag is represented as a single element,
--an array is created and that element is inserted on it.
--The existing tag is then replaced by the created array.
--For instance, if we have a tag x = {attr1 = 1, attr2 = 2}
--and another x tag is found, the previous entry will be changed to an array
--x = {{attr1 = 1, attr2 = 2}}. This way, the duplicated tag will be
--inserted into this array as x = {{attr1 = 1, attr2 = 2}, {attr1 = 3, attr2 = 4}}
--https://github.com/manoelcampos/xml2lua/issues/55
--
--@param obj the object to try to convert to an array
--@return the same object if it's already an array or a new array with the object
--as the 1st element.
local function convertObjectToArray(obj)
	--#obj == 0 verifies if the field is not an array
	if #obj == 0 then
		local array = {}
		insert(array, obj)
		return array
	end

	return obj
end

---Parses a start tag.
--@param tag a {name, attrs} table
--where name is the name of the tag and attrs
--is a table containing the atributtes of the tag
function tree:starttag(tag)
	local node = {}
	if self.parseAttributes == true then
		node._attr = tag.attrs
	end

	--Table in the stack representing the tag being processed
	local current = self._stack[#self._stack]

	if current[tag.name] then
		local array = convertObjectToArray(current[tag.name])
		insert(array, node)
		current[tag.name] = array
	else
		current[tag.name] = {node}
	end

	insert(self._stack, node)
end

---Parses an end tag.
--@param tag a {name, attrs} table
--where name is the name of the tag and attrs
--is a table containing the atributtes of the tag
function tree:endtag()
	remove(self._stack)
end

---Parses a tag content.
--@param t text to process
function tree:text(text)
	local current = self._stack[#self._stack]
	insert(current, text)
end

---Parses CDATA tag content.
tree.cdata = tree.text

return tree