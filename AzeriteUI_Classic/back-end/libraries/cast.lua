local LibCast = CogWheel:Set("LibAura", 1)
if (not LibCast) then
	return
end

local LibMessage = CogWheel("LibMessage")
assert(LibMessage, "LibCast requires LibMessage to be loaded.")

local LibEvent = CogWheel("LibEvent")
assert(LibEvent, "LibCast requires LibEvent to be loaded.")

local LibFrame = CogWheel("LibFrame")
assert(LibFrame, "LibCast requires LibFrame to be loaded.")

LibMessage:Embed(LibCast)
LibEvent:Embed(LibCast)
LibFrame:Embed(LibCast)

-- Lua API
local _G = _G
local assert = assert
local date = date
local debugstack = debugstack
local error = error
local pairs = pairs
local select = select
local string_join = string.join
local string_match = string.match
local tonumber = tonumber
local type = type

-- Library registries
LibCast.embeds = LibCast.embeds or {}

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
	GetTime = true, 
	GetLocalTime = true, 
	GetServerTime = true, 
	ComputeMilitaryHours = true, 
	ComputeStandardHours = true
}

LibCast.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibCast.embeds) do
	LibCast:Embed(target)
end
