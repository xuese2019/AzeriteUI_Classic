local ADDON, Private = ...
local Core = CogWheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end
local Module = Core:NewModule("BlizzardFloaterHUD", "LibEvent", "LibFrame", "LibTooltip", "LibDB", "LibBlizzard")

-- Lua API
local _G = _G
local ipairs = ipairs
local table_remove = table.remove

local MAPPY = Module:IsAddOnEnabled("Mappy")

local mt = getmetatable(CreateFrame("Frame")).__index
local Frame_ClearAllPoints = mt.ClearAllPoints
local Frame_IsShown = mt.IsShown
local Frame_SetParent = mt.SetParent
local Frame_SetPoint = mt.SetPoint

local HolderCache, StyleCache = {}, {}
local Layout

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
		[LE_GAME_ERR_OUT_OF_ENERGY] = true,
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

-- Default settings
local defaults = {}

local DisableTexture = function(texture, _, loop)
	if loop then
		return
	end
	texture:SetTexture(nil, true)
end

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

Module.DisableMappy = function(object)
	if MAPPY then 
		object.Mappy_DidHook = true -- set the flag indicating its already been set up for Mappy
		object.Mappy_SetPoint = function() end -- kill the IsVisible reference Mappy makes
		object.Mappy_HookedSetPoint = function() end -- kill this too
		object.SetPoint = nil -- return the SetPoint method to its original metamethod
		object.ClearAllPoints = nil -- return the SetPoint method to its original metamethod
	end 
end

Module.StyleDurabilityFrame = function(self)
	if (not Layout.StyleDurabilityFrame) then 
		return 
	end

	self:DisableMappy(DurabilityFrame)
	self:CreateHolder(DurabilityFrame, unpack(Layout.DurabilityFramePlace))
	self:CreatePointHook(DurabilityFrame)

	-- This will prevent the durability frame size from affecting other blizzard anchors
	DurabilityFrame.IsShown = function() return false end
end 

Module.StyleErrorFrame = function(self)
	local frame = UIErrorsFrame
	frame:SetFrameStrata("LOW")
	frame:SetHeight(20)
	frame:SetAlpha(.75)
	frame:UnregisterEvent("UI_ERROR_MESSAGE")
	frame:UnregisterEvent("UI_INFO_MESSAGE")
	frame:SetFontObject(Private.GetFont(16))
	self.UIErrorsFrame = frame

	self:RegisterEvent("UI_ERROR_MESSAGE", "OnEvent")
	self:RegisterEvent("UI_INFO_MESSAGE", "OnEvent")
end 

Module.StyleQuestTimerFrame = function(self)
	if (not Layout.StyleQuestTimerFrame) then 
		return 
	end 
	self:CreateHolder(QuestTimerFrame, unpack(Layout.QuestTimerFramePlace))
	self:CreatePointHook(QuestTimerFrame)
end

Module.GetFloaterTooltip = function(self)
	return self:GetTooltip("CG_FloaterTooltip") or self:CreateTooltip("CG_FloaterTooltip")
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

Module.PreInit = function(self)
	local PREFIX = Core:GetPrefix()
	Layout = CogWheel("LibDB"):GetDatabase(PREFIX..":[BlizzardFloaterHUD]")
end 

Module.OnInit = function(self)
	self.db = self:NewConfig("FloaterHUD", defaults, "global")
end 

Module.OnEnable = function(self)
	self:StyleDurabilityFrame()
	self:StyleErrorFrame()
	self:StyleQuestTimerFrame()
end
