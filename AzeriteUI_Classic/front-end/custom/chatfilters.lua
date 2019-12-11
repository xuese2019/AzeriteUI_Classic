local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("ChatFilters")
Module:SetIncompatible("Prat-3.0")

-- Lua API
local ipairs = ipairs
local string_gsub = string.gsub
local string_match = string.match

-- WoW API
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local ChatFrame_RemoveMessageEventFilter = ChatFrame_RemoveMessageEventFilter

-- Clearly chat events have changed since I used them last, some hundred years ago.
local OnChatMessage = function(self, event, message, author, ...)
	if (message == ERR_NOT_IN_RAID) then
		return true
	else 
		return false, message, author, ...
	end
end


Module.OnInit = function(self)
	-- Here we are, doing nothing. 
	-- Will add a db creation here if we ever add more advanced filters and options. 
end

Module.OnEnable = function(self)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnChatMessage)
end
