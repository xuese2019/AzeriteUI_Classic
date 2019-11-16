local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("BlizzardFonts", "LibEvent")

-- Lua API
local ipairs = ipairs

-- WoW API
local GetLocale = GetLocale
local InCombatLockdown = InCombatLockdown
local IsAddOnLoaded = IsAddOnLoaded
local hooksecurefunc = hooksecurefunc

-- Private API
local GetLayout = Private.GetLayout

Module.SetFontObjects = function(self)
	-- Various chat constants
	--CHAT_FONT_HEIGHTS = { 12, 13, 14, 15, 16, 17, 18, 20, 22, 24, 28, 32 }
	if CHAT_FONT_HEIGHTS then 
		for i = #CHAT_FONT_HEIGHTS, 1, -1 do  
			CHAT_FONT_HEIGHTS[i] = nil
		end 
		for i,v in ipairs({ 14, 16, 18, 20, 22, 24, 28, 32 }) do 
			CHAT_FONT_HEIGHTS[i] = v
		end
	end 

	-- Chat Font
	-- This is the cont used by chat windows and inputboxes. 
	-- When set early enough in the loading process, all windows inherit this.
	ChatFontNormal:SetFontObject(self.layout.ChatFont)

	-- Chat Bubble Font
	-- This is what chat bubbles inherit from. 
	-- We should use this in our custom bubbles too.
	ChatBubbleFont:SetFontObject(self.layout.ChatBubbleFont)
end

Module.SetCombatText = function(self)
	if (InCombatLockdown()) then 
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		return 
	end 

	-- Various globals controlling the FCT
	NUM_COMBAT_TEXT_LINES = 10 -- 20
	COMBAT_TEXT_CRIT_MAXHEIGHT = 70 -- 60
	COMBAT_TEXT_CRIT_MINHEIGHT = 35 -- 30
	--COMBAT_TEXT_CRIT_SCALE_TIME = 0.05
	--COMBAT_TEXT_CRIT_SHRINKTIME = 0.2
	COMBAT_TEXT_FADEOUT_TIME = .75 -- 1.3 -- got a taint message on this. Combat taint?
	COMBAT_TEXT_HEIGHT = 25 -- 25
	--COMBAT_TEXT_LOW_HEALTH_THRESHOLD = 0.2
	--COMBAT_TEXT_LOW_MANA_THRESHOLD = 0.2
	--COMBAT_TEXT_MAX_OFFSET = 130
	COMBAT_TEXT_SCROLLSPEED = 1.3 -- 1.9
	COMBAT_TEXT_SPACING = 2 * COMBAT_TEXT_Y_SCALE --10
	--COMBAT_TEXT_STAGGER_RANGE = 20
	--COMBAT_TEXT_X_ADJUSTMENT = 80

	-- Hooking changes to text positions after blizz setting changes, 
	-- to show the text in positions that work well with our UI. 
	hooksecurefunc("CombatText_UpdateDisplayedMessages", function() self:UpdateDisplayedMessages() end)
end 

Module.UpdateDisplayedMessages = function(self, event, ...)
	if (InCombatLockdown()) then 
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateDisplayedMessages")
		return 
	elseif (event == "PLAYER_REGEN_ENABLED") then 
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "UpdateDisplayedMessages")
	end
	-- Important that we do NOT replace the table down here, 
	-- as that appears to sometimes taint the UIDropDowns.
	-- Todo: check if it taints after having been in combat, then opening guild controls.
	if (COMBAT_TEXT_FLOAT_MODE == "1") then
		COMBAT_TEXT_SCROLL_FUNCTION = CombatText_StandardScroll
		COMBAT_TEXT_LOCATIONS.startX = 0
		COMBAT_TEXT_LOCATIONS.startY = 259 * COMBAT_TEXT_Y_SCALE
		COMBAT_TEXT_LOCATIONS.endX = 0
		COMBAT_TEXT_LOCATIONS.endY = 389 * COMBAT_TEXT_Y_SCALE

	elseif (COMBAT_TEXT_FLOAT_MODE == "2") then
		COMBAT_TEXT_SCROLL_FUNCTION = CombatText_StandardScroll
		COMBAT_TEXT_LOCATIONS.startX = 0
		COMBAT_TEXT_LOCATIONS.startY = 389 * COMBAT_TEXT_Y_SCALE
		COMBAT_TEXT_LOCATIONS.endX = 0
		COMBAT_TEXT_LOCATIONS.endY =  259 * COMBAT_TEXT_Y_SCALE
	else
		COMBAT_TEXT_SCROLL_FUNCTION = CombatText_FountainScroll
		COMBAT_TEXT_LOCATIONS.startX = 0
		COMBAT_TEXT_LOCATIONS.startY = 389 * COMBAT_TEXT_Y_SCALE
		COMBAT_TEXT_LOCATIONS.endX = 0
		COMBAT_TEXT_LOCATIONS.endY = 609 * COMBAT_TEXT_Y_SCALE
	end
	CombatText_ClearAnimationList()
end

Module.OnEvent = function(self, event, ...)
	if (event == "ADDON_LOADED") then 
		local addon = ...
		if (addon == "Blizzard_CombatText") then 
			self:UnregisterEvent("ADDON_LOADED", "OnEvent")
			self:SetCombatText()
		end 

	elseif (event == "PLAYER_REGEN_ENABLED") then 
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		self:SetCombatText()
	end
end

Module.OnInit = function(self)
	self.layout = GetLayout(self:GetName())

	-- This new one only affects the style and shadow of the chat font, 
	-- and the size, style and shadow of the chat bubble font.  
	self:SetFontObjects()

	-- Note: This whole damn thing taints in Classic, or is it from somewhere else?
	-- After disabling it, the same guildcontrol taint still occurred, just with no named source. Weird. 
	if (IsAddOnLoaded("Blizzard_CombatText")) then
		self:SetCombatText()
	else
		self:RegisterEvent("ADDON_LOADED", "OnEvent")
	end
end
