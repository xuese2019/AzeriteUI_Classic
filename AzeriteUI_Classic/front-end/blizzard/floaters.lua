local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("BlizzardFloaterHUD", "LibEvent", "LibFrame", "LibTooltip", "LibDB", "LibBlizzard")

-- Private API
local GetConfig = Private.GetConfig
local GetFont = Private.GetFont
local GetLayout = Private.GetLayout

local HolderCache, StyleCache = {}, {}

local mt = getmetatable(CreateFrame("Frame")).__index
local Frame_ClearAllPoints = mt.ClearAllPoints
local Frame_IsShown = mt.IsShown
local Frame_SetParent = mt.SetParent
local Frame_SetPoint = mt.SetPoint

local blackList = {
	msgTypes = {
		[LE_GAME_ERR_ABILITY_COOLDOWN] = true,
		[LE_GAME_ERR_SPELL_COOLDOWN] = true,
		[LE_GAME_ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS] = true,
		[LE_GAME_ERR_OUT_OF_SOUL_SHARDS] = true,
		[LE_GAME_ERR_OUT_OF_FOCUS] = true,
		[LE_GAME_ERR_OUT_OF_COMBO_POINTS] = true,
		[LE_GAME_ERR_OUT_OF_HEALTH] = true,
		[LE_GAME_ERR_OUT_OF_RAGE] = true,
		[LE_GAME_ERR_OUT_OF_RANGE] = true,
		[LE_GAME_ERR_OUT_OF_ENERGY] = true
	},
	[ ERR_ABILITY_COOLDOWN ] = true, 						-- Ability is not ready yet.
	[ ERR_ATTACK_CHARMED ] = true, 							-- Can't attack while charmed. 
	[ ERR_ATTACK_CONFUSED ] = true, 						-- Can't attack while confused.
	[ ERR_ATTACK_DEAD ] = true, 							-- Can't attack while dead. 
	[ ERR_ATTACK_FLEEING ] = true, 							-- Can't attack while fleeing. 
	[ ERR_ATTACK_PACIFIED ] = true, 						-- Can't attack while pacified. 
	[ ERR_ATTACK_STUNNED ] = true, 							-- Can't attack while stunned.
	[ ERR_AUTOFOLLOW_TOO_FAR ] = true, 						-- Target is too far away.
	[ ERR_BADATTACKFACING ] = true, 						-- You are facing the wrong way!
	[ ERR_BADATTACKPOS ] = true, 							-- You are too far away!
	[ ERR_CLIENT_LOCKED_OUT ] = true, 						-- You can't do that right now.
	[ ERR_ITEM_COOLDOWN ] = true, 							-- Item is not ready yet. 
	[ ERR_OUT_OF_ENERGY ] = true, 							-- Not enough energy
	[ ERR_OUT_OF_FOCUS ] = true, 							-- Not enough focus
	[ ERR_OUT_OF_HEALTH ] = true, 							-- Not enough health
	[ ERR_OUT_OF_MANA ] = true, 							-- Not enough mana
	[ ERR_OUT_OF_RAGE ] = true, 							-- Not enough rage
	[ ERR_OUT_OF_RANGE ] = true, 							-- Out of range.
	[ ERR_SPELL_COOLDOWN ] = true, 							-- Spell is not ready yet.
	[ ERR_SPELL_FAILED_ALREADY_AT_FULL_HEALTH ] = true, 	-- You are already at full health.
	[ ERR_SPELL_OUT_OF_RANGE ] = true, 						-- Out of range.
	[ ERR_USE_TOO_FAR ] = true, 							-- You are too far away.
	[ SPELL_FAILED_CANT_DO_THAT_RIGHT_NOW ] = true, 		-- You can't do that right now.
	[ SPELL_FAILED_CASTER_AURASTATE ] = true, 				-- You can't do that yet
	[ SPELL_FAILED_CASTER_DEAD ] = true, 					-- You are dead
	[ SPELL_FAILED_CASTER_DEAD_FEMALE ] = true, 			-- You are dead
	[ SPELL_FAILED_CHARMED ] = true, 						-- Can't do that while charmed
	[ SPELL_FAILED_CONFUSED ] = true, 						-- Can't do that while confused
	[ SPELL_FAILED_FLEEING ] = true, 						-- Can't do that while fleeing
	[ SPELL_FAILED_ITEM_NOT_READY ] = true, 				-- Item is not ready yet
	[ SPELL_FAILED_NO_COMBO_POINTS ] = true, 				-- That ability requires combo points
	[ SPELL_FAILED_NOT_BEHIND ] = true, 					-- You must be behind your target.
	[ SPELL_FAILED_NOT_INFRONT ] = true, 					-- You must be in front of your target.
	[ SPELL_FAILED_OUT_OF_RANGE ] = true, 					-- Out of range
	[ SPELL_FAILED_PACIFIED ] = true, 						-- Can't use that ability while pacified
	[ SPELL_FAILED_SPELL_IN_PROGRESS ] = true, 				-- Another action is in progress
	[ SPELL_FAILED_STUNNED ] = true, 						-- Can't do that while stunned
	[ SPELL_FAILED_UNIT_NOT_INFRONT ] = true, 				-- Target needs to be in front of you.
	[ SPELL_FAILED_UNIT_NOT_BEHIND ] = true, 				-- Target needs to be behind you.
}

local ResetPoint = function(object, _, anchor) 
	local holder = object and HolderCache[object]
	if (holder) then 
		if (anchor ~= holder) then
			Frame_SetParent(object, holder)
			Frame_ClearAllPoints(object)
			Frame_SetPoint(object, "CENTER", holder, "CENTER", 0, 0)
		end
	end 
end

Module.CreateHolder = function(self, object, ...)
	HolderCache[object] = HolderCache[object] or self:CreateFrame("Frame", nil, "UICenter")
	HolderCache[object]:Place(...)
	HolderCache[object]:SetSize(2,2)
	return HolderCache[object]
end

Module.CreatePointHook = function(self, object)
	-- Always do this.
	ResetPoint(object)

	-- Don't create multiple hooks
	if (not StyleCache[object]) then 
		hooksecurefunc(object, "SetPoint", ResetPoint)
	end
end 

Module.StyleErrorFrame = function(self)
	local frame = UIErrorsFrame
	frame:SetFrameStrata("LOW")
	frame:SetHeight(20)
	frame:SetAlpha(.75)
	frame:UnregisterEvent("UI_ERROR_MESSAGE")
	frame:UnregisterEvent("UI_INFO_MESSAGE")
	frame:SetFontObject(GetFont(16,true))
	frame:SetShadowColor(0,0,0,.5)
	self.UIErrorsFrame = frame

	self:RegisterEvent("UI_ERROR_MESSAGE", "OnEvent")
	self:RegisterEvent("UI_INFO_MESSAGE", "OnEvent")
end 

Module.StyleRaidWarningFrame = function(self)
	local fontSize = 20
	local frameWidth = 600

	-- The RaidWarnings have a tendency to look really weird,
	-- as the SetTextHeight method scales the text after it already
	-- has been turned into a bitmap and turned into a texture.
	-- So I'm just going to turn it off. Completely.
	local frame = RaidWarningFrame
	frame:SetAlpha(.85)
	frame:SetHeight(85) -- 512,70
	frame.timings.RAID_NOTICE_MIN_HEIGHT = fontSize
	frame.timings.RAID_NOTICE_MAX_HEIGHT = fontSize
	frame.timings.RAID_NOTICE_SCALE_UP_TIME = 0
	frame.timings.RAID_NOTICE_SCALE_DOWN_TIME = 0

	local slot1 = RaidWarningFrameSlot1
	slot1:SetFontObject(GetFont(fontSize,true,true))
	slot1:SetShadowColor(0,0,0,.5)
	slot1:SetWidth(frameWidth) -- 800
	slot1.SetTextHeight = function() end

	local slot2 = RaidWarningFrameSlot2
	slot2:SetFontObject(GetFont(fontSize,true,true))
	slot2:SetShadowColor(0,0,0,.5)
	slot2:SetWidth(frameWidth) -- 800
	slot2.SetTextHeight = function() end

	-- Just a little in-game test for dev purposes!
	-- /run RaidNotice_AddMessage(RaidWarningFrame, "Testing how texts will be displayed with my changes! Testing how texts will be displayed with my changes!", ChatTypeInfo["RAID_WARNING"])
end

Module.StyleQuestTimerFrame = function(self)
	self:CreateHolder(QuestTimerFrame, unpack(self.layout.QuestTimerFramePlace))
	self:CreatePointHook(QuestTimerFrame)
end

Module.GetFloaterTooltip = function(self)
	return self:GetTooltip("GP_FloaterTooltip") or self:CreateTooltip("GP_FloaterTooltip")
end

Module.OnEvent = function(self, event, ...)
	if (event == "UI_ERROR_MESSAGE") then 
		local messageType, msg = ...
		if (not msg) or (blackList.msgTypes[messageType]) or (blackList[msg]) then 
			return 
		end 
		self.UIErrorsFrame:AddMessage(msg, 1, 0, 0, 1)
		
	elseif (event == "UI_INFO_MESSAGE") then 
		local messageType, msg = ...
		if (not msg) then 
			return 
		end 
		self.UIErrorsFrame:AddMessage(msg, 1, .82, 0, 1)
	end
end

Module.OnInit = function(self)
	self.db = GetConfig(self:GetName())
	self.layout = GetLayout(self:GetName())
end 

Module.OnEnable = function(self)
	self:StyleErrorFrame()
	self:StyleRaidWarningFrame()
	self:StyleQuestTimerFrame()
end
