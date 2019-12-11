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

local bgChatFixer = {
	ERR_NOT_IN_INSTANCE_GROUP or "You aren't in an instance group.",
	ERR_NOT_IN_RAID or "You are not in a raid group"
}

local OnChatMessage = function(_, msg, ...)
	if msg then
		for _,filter in ipairs(K.PrivateChatEventSpam) do
			if string_match(msg, filter) then
				return true
			end
		end
		-- uncomment to break the chat
		-- for development purposes only. weird stuff happens when used.
		-- msg = string_gsub(msg, "|", "||")
	end
	return false, msg, ...
end


Module.OnInit = function(self)
	-- Here we are, doing nothing. 
	-- Will add a db creation here if we ever add more advanced filters and options. 
end

Module.OnEnable = function(self)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnChatMessage)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_BOSS_EMOTE", OnChatMessage)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", OnChatMessage)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", OnChatMessage)
end

Module.OnDisable = function(self)
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", OnChatMessage)
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_RAID_BOSS_EMOTE", OnChatMessage)
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CHANNEL", OnChatMessage)
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_YELL", OnChatMessage)
end