local LibAuraData = Wheel:Set("LibAuraData", -1)
if (not LibAuraData) then	
	return
end

-- Lua API
local _G = _G
local assert = assert
local date = date
local debugstack = debugstack
local error = error
local pairs = pairs
local select = select
local string_byte = string.byte
local string_find = string.find
local string_join = string.join
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local type = type

-- Library registries
---------------------------------------------------------------------	
LibAuraData.embeds = LibAuraData.embeds or {}

-- Quality of Life
---------------------------------------------------------------------	

-- Local constants & tables
---------------------------------------------------------------------	

-- Utility Functions
---------------------------------------------------------------------	
-- Syntax check 
local check = function(value, num, ...)
	assert(type(num) == "number", ("Bad argument #%.0f to '%s': %s expected, got %s"):format(2, "Check", "number", type(num)))
	for i = 1,select("#", ...) do
		if type(value) == select(i, ...) then 
			return 
		end
	end
	local types = string_join(", ", ...)
	local name = string_match(debugstack(2, 2, 0), ": in function [`<](.-)['>]")
	error(("Bad argument #%.0f to '%s': %s expected, got %s"):format(num, name, types, type(value)), 3)
end

local embedMethods = {
}

LibAuraData.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	LibAuraData.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibAuraData.embeds) do
	LibAuraData:Embed(target)
end

-- Databases
---------------------------------------------------------------------	
