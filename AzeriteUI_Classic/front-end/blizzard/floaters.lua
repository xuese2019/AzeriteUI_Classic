local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("BlizzardFloaterHUD", "LibEvent", "LibFrame", "LibTooltip", "LibDB", "LibBlizzard", "LibClientBuild")

-- Lua API
local _G = _G
local ipairs = ipairs
local table_remove = table.remove

-- Private API
local GetConfig = Private.GetConfig
local GetFont = Private.GetFont
local GetLayout = Private.GetLayout

-- Constants for client version
local IsClassic = Module:IsClassic()
local IsRetail = Module:IsRetail()

local MAPPY = Module:IsAddOnEnabled("Mappy")

-- Local caches
local HolderCache, StyleCache = {}, {}

-- Pure meta methods
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

local DisableTexture = function(texture, _, loop)
	if (loop) then
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

local ExtraActionButton_UpdateTooltip = function(self)
	if self.action and HasAction(self.action) then 
		local tooltip = Module:GetFloaterTooltip()
		tooltip:SetDefaultAnchor(self)
		tooltip:SetAction(self.action)
	end 
end

local ExtraActionButton_OnEnter = function(self)
	self.UpdateTooltip = ExtraActionButton_UpdateTooltip
	self:UpdateTooltip()
end

local ExtraActionButton_OnLeave = function(self)
	self.UpdateTooltip = nil
	local tooltip = Module:GetFloaterTooltip()
	tooltip:Hide()
end

local ZoneAbilityButton_UpdateTooltip = function(self)
	local spellID = self.currentSpellID or self.spellID or self.baseSpellID
	if spellID then 
		local tooltip = Module:GetFloaterTooltip()
		tooltip:SetDefaultAnchor(self)
		tooltip:SetSpellByID(spellID)
	end 
end

local ZoneAbilityButton_OnEnter = function(self)
	self.UpdateTooltip = ZoneAbilityButton_UpdateTooltip
	self:UpdateTooltip()
end

local ZoneAbilityButton_OnLeave = function(self)
	self.UpdateTooltip = nil
	local tooltip = Module:GetFloaterTooltip()
	tooltip:Hide()
end

local GroupLootContainer_PostUpdate = function(self)
	local lastIdx = nil
	local layout = Module.layout
	for i = 1, self.maxIndex do
		local frame = self.rollFrames[i]
		local prevFrame = self.rollFrames[i-1]
		if ( frame ) then
			frame:ClearAllPoints()
			if prevFrame and not (prevFrame == frame) then
				frame:SetPoint(layout.AlertFramesPosition, prevFrame, layout.AlertFramesAnchor, 0, layout.AlertFramesOffset)
			else
				frame:SetPoint(layout.AlertFramesPosition, self, layout.AlertFramesPosition, 0, 0)
			end
			lastIdx = i
		end
	end
	if (lastIdx) then
		self:SetHeight(self.reservedSize * lastIdx)
		self:Show()
	else
		self:Hide()
	end
end

local AlertSubSystem_AdjustAnchors = function(self, relativeAlert)
	if (self.alertFrame:IsShown()) then
		local layout = Module.layout
		self.alertFrame:ClearAllPoints()
		self.alertFrame:SetPoint(layout.AlertFramesPosition, relativeAlert, layout.AlertFramesAnchor, 0, layout.AlertFramesOffset)
		return self.alertFrame
	end
	return relativeAlert
end

local AlertSubSystem_AdjustAnchorsNonAlert = function(self, relativeAlert)
	if self.anchorFrame:IsShown() then
		local layout = Module.layout
		self.anchorFrame:ClearAllPoints()
		self.anchorFrame:SetPoint(layout.AlertFramesPosition, relativeAlert, layout.AlertFramesAnchor, 0, layout.AlertFramesOffset)
		return self.anchorFrame
	end
	return relativeAlert
end

local AlertSubSystem_AdjustQueuedAnchors = function(self, relativeAlert)
	for alertFrame in self.alertFramePool:EnumerateActive() do
		local layout = Module.layout
		alertFrame:ClearAllPoints()
		alertFrame:SetPoint(layout.AlertFramesPosition, relativeAlert, layout.AlertFramesAnchor, 0, layout.AlertFramesOffset)
		relativeAlert = alertFrame
	end
	return relativeAlert
end

local AlertSubSystem_AdjustPosition = function(self)
	if (self.alertFramePool) then --queued alert system
		self.AdjustAnchors = AlertSubSystem_AdjustQueuedAnchors
	elseif (not self.anchorFrame) then --simple alert system
		self.AdjustAnchors = AlertSubSystem_AdjustAnchors
	elseif (self.anchorFrame) then --anchor frame system
		self.AdjustAnchors = AlertSubSystem_AdjustAnchorsNonAlert
	end
end

local AlertFrame_PostUpdatePosition = function(self, subSystem)
	AlertSubSystem_AdjustPosition(subSystem)
end

local AlertFrame_PostUpdateAnchors = function(self)
	local layout = Module.layout
	local holder = HolderCache[AlertFrame]
	holder:ClearAllPoints()
	if (TalkingHeadFrame and Frame_IsShown(TalkingHeadFrame)) then 
		holder:Place(unpack(layout.AlertFramesPlaceTalkingHead))
	else 
		holder:Place(unpack(layout.AlertFramesPlace))
	end
	AlertFrame:ClearAllPoints()
	AlertFrame:SetAllPoints(holder)
	GroupLootContainer:ClearAllPoints()
	GroupLootContainer:SetPoint(layout.AlertFramesPosition, holder, layout.AlertFramesAnchor, 0, layout.AlertFramesOffset)
	if GroupLootContainer:IsShown() then
		GroupLootContainer_PostUpdate(GroupLootContainer)
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
	if (MAPPY) then 
		object.Mappy_DidHook = true -- set the flag indicating its already been set up for Mappy
		object.Mappy_SetPoint = function() end -- kill the IsVisible reference Mappy makes
		object.Mappy_HookedSetPoint = function() end -- kill this too
		object.SetPoint = nil -- return the SetPoint method to its original metamethod
		object.ClearAllPoints = nil -- return the SetPoint method to its original metamethod
	end 
end

Module.UpdateAlertFrames = function(self)
	local db = self.db
	local frame = AlertFrame
	if (db.enableAlerts) then 
		if (frame:GetParent() ~= UIParent) then 
			frame:SetParent(UIParent)
			frame:OnLoad()
		end
		return self:StyleAlertFrames()
	else
		self:DisableUIWidget("Alerts")
	end
end

Module.StyleAlertFrames = function(self)
	local layout = self.layout
	local alertFrame = AlertFrame
	local lootFrame = GroupLootContainer

	self:CreateHolder(alertFrame, unpack(layout.AlertFramesPlace)):SetSize(unpack(layout.AlertFramesSize))

	lootFrame.ignoreFramePositionManager = true
	alertFrame.ignoreFramePositionManager = true

	UIPARENT_MANAGED_FRAME_POSITIONS["GroupLootContainer"] = nil

	for _,alertFrameSubSystem in ipairs(alertFrame.alertFrameSubSystems) do
		AlertSubSystem_AdjustPosition(alertFrameSubSystem)
	end

	-- Only ever do this once
	if (not StyleCache[alertFrame]) then 
		hooksecurefunc(alertFrame, "AddAlertFrameSubSystem", AlertFrame_PostUpdatePosition)
		hooksecurefunc(alertFrame, "UpdateAnchors", AlertFrame_PostUpdateAnchors)
		hooksecurefunc("GroupLootContainer_Update", GroupLootContainer_PostUpdate)
	end
	StyleCache[alertFrame] = true
end

Module.StyleExtraActionButton = function(self)
	local layout = self.layout

	local frame = ExtraActionBarFrame
	frame:SetParent(self:GetFrame("UICenter"))
	frame.ignoreFramePositionManager = true

	self:CreateHolder(frame, unpack(layout.ExtraActionButtonFramePlace))
	self:CreatePointHook(frame)

	-- Take over the mouseover scripts, use our own tooltip
	local button = ExtraActionBarFrame.button
	button:ClearAllPoints()
	button:SetSize(unpack(layout.ExtraActionButtonSize))
	button:SetPoint(unpack(layout.ExtraActionButtonPlace))
	button:SetScript("OnEnter", ExtraActionButton_OnEnter)
	button:SetScript("OnLeave", ExtraActionButton_OnLeave)

	local layer, level = button.icon:GetDrawLayer()
	button.icon:SetAlpha(0) -- don't hide or remove, it will taint!

	-- This crazy stunt is needed to be able to set a mask 
	-- I honestly have no idea why. Somebody tell me?
	local newIcon = button:CreateTexture()
	newIcon:SetDrawLayer(layer, level)
	newIcon:ClearAllPoints()
	newIcon:SetPoint(unpack(layout.ExtraActionButtonIconPlace))
	newIcon:SetSize(unpack(layout.ExtraActionButtonIconSize))
	newIcon:SetMask(layout.ExtraActionButtonIconMaskTexture)
	hooksecurefunc(button.icon, "SetTexture", function(_,...) newIcon:SetTexture(...) end)

	button.Flash:SetTexture(nil)

	button.HotKey:ClearAllPoints()
	button.HotKey:SetPoint(unpack(layout.ExtraActionButtonKeybindPlace))
	button.HotKey:SetFontObject(layout.ExtraActionButtonKeybindFont)
	button.HotKey:SetJustifyH(layout.ExtraActionButtonKeybindJustifyH)
	button.HotKey:SetJustifyV(layout.ExtraActionButtonKeybindJustifyV)
	button.HotKey:SetShadowOffset(unpack(layout.ExtraActionButtonKeybindShadowOffset))
	button.HotKey:SetShadowColor(unpack(layout.ExtraActionButtonKeybindShadowColor))
	button.HotKey:SetTextColor(unpack(layout.ExtraActionButtonKeybindColor))

	button.Count:ClearAllPoints()
	button.Count:SetPoint(unpack(layout.ExtraActionButtonCountPlace))
	button.Count:SetFontObject(layout.ExtraActionButtonFont)
	button.Count:SetJustifyH(layout.ExtraActionButtonCountJustifyH)
	button.Count:SetJustifyV(layout.ExtraActionButtonCountJustifyV)

	button.cooldown:SetSize(unpack(layout.ExtraActionButtonCooldownSize))
	button.cooldown:ClearAllPoints()
	button.cooldown:SetPoint(unpack(layout.ExtraActionButtonCooldownPlace))
	button.cooldown:SetSwipeTexture(layout.ExtraActionButtonCooldownSwipeTexture)
	button.cooldown:SetSwipeColor(unpack(layout.ExtraActionButtonCooldownSwipeColor))
	button.cooldown:SetDrawSwipe(layout.ExtraActionButtonShowCooldownSwipe)
	button.cooldown:SetBlingTexture(layout.ExtraActionButtonCooldownBlingTexture, unpack(layout.ExtraActionButtonCooldownBlingColor)) 
	button.cooldown:SetDrawBling(layout.ExtraActionButtonShowCooldownBling)

	-- Attempting to fix the issue with too opaque swipe textures
	button.cooldown:HookScript("OnShow", function() 
		button.cooldown:SetSwipeColor(unpack(layout.ExtraActionButtonCooldownSwipeColor))
	end)

	-- Kill Blizzard's style texture
	button.style:SetTexture(nil)
	hooksecurefunc(button.style, "SetTexture", DisableTexture)

	button:GetNormalTexture():SetTexture(nil)
	button:GetHighlightTexture():SetTexture(nil)
	button:GetCheckedTexture():SetTexture(nil)

	button.BorderFrame = CreateFrame("Frame", nil, button)
	button.BorderFrame:SetFrameLevel(button:GetFrameLevel() + 5)
	button.BorderFrame:SetAllPoints(button)

	button.HotKey:SetParent(button.BorderFrame)
	button.Count:SetParent(button.BorderFrame)

	button.BorderTexture = button.BorderFrame:CreateTexture()
	button.BorderTexture:SetPoint(unpack(layout.ExtraActionButtonBorderPlace))
	button.BorderTexture:SetDrawLayer(unpack(layout.ExtraActionButtonBorderDrawLayer))
	button.BorderTexture:SetSize(unpack(layout.ExtraActionButtonBorderSize))
	button.BorderTexture:SetTexture(layout.ExtraActionButtonBorderTexture)
	button.BorderTexture:SetVertexColor(unpack(layout.ExtraActionButtonBorderColor))
end

Module.StyleZoneAbilityButton = function(self)
	local layout = self.layout

	local frame = ZoneAbilityFrame
	frame:SetParent(self:GetFrame("UICenter"))
	frame.ignoreFramePositionManager = true

	self:CreateHolder(frame, unpack(layout.ZoneAbilityButtonFramePlace))
	self:CreatePointHook(frame)

	-- Take over the mouseover scripts, use our own tooltip
	local button = frame.SpellButton
	button:ClearAllPoints()
	button:SetSize(unpack(layout.ZoneAbilityButtonSize))
	button:SetPoint(unpack(layout.ZoneAbilityButtonPlace))
	button:SetScript("OnEnter", ZoneAbilityButton_OnEnter)
	button:SetScript("OnLeave", ZoneAbilityButton_OnLeave)

	button.Icon:ClearAllPoints()
	button.Icon:SetPoint(unpack(layout.ZoneAbilityButtonIconPlace))
	button.Icon:SetSize(unpack(layout.ZoneAbilityButtonIconSize))
	button.Icon:SetMask(layout.ZoneAbilityButtonIconMaskTexture)

	button.Count:ClearAllPoints()
	button.Count:SetPoint(unpack(layout.ZoneAbilityButtonCountPlace))
	button.Count:SetFontObject(layout.ZoneAbilityButtonFont)
	button.Count:SetJustifyH(layout.ZoneAbilityButtonCountJustifyH)
	button.Count:SetJustifyV(layout.ZoneAbilityButtonCountJustifyV)

	button.Cooldown:SetSize(unpack(layout.ZoneAbilityButtonCooldownSize))
	button.Cooldown:ClearAllPoints()
	button.Cooldown:SetPoint(unpack(layout.ZoneAbilityButtonCooldownPlace))
	button.Cooldown:SetSwipeTexture(layout.ZoneAbilityButtonCooldownSwipeTexture)
	button.Cooldown:SetSwipeColor(unpack(layout.ZoneAbilityButtonCooldownSwipeColor))
	button.Cooldown:SetDrawSwipe(layout.ZoneAbilityButtonShowCooldownSwipe)
	button.Cooldown:SetBlingTexture(layout.ZoneAbilityButtonCooldownBlingTexture, unpack(layout.ZoneAbilityButtonCooldownBlingColor)) 
	button.Cooldown:SetDrawBling(layout.ZoneAbilityButtonShowCooldownBling)

	-- Attempting to fix the issue with too opaque swipe textures
	button.Cooldown:HookScript("OnShow", function() 
		button.Cooldown:SetSwipeColor(unpack(layout.ZoneAbilityButtonCooldownSwipeColor))
	end)
	
	-- Kill off the surrounding style texture
	button.Style:SetTexture(nil)
	hooksecurefunc(button.Style, "SetTexture", DisableTexture)

	button:GetNormalTexture():SetTexture(nil)
	button:GetHighlightTexture():SetTexture(nil)
	--button:GetCheckedTexture():SetTexture(nil)

	button.BorderFrame = CreateFrame("Frame", nil, button)
	button.BorderFrame:SetFrameLevel(button:GetFrameLevel() + 5)
	button.BorderFrame:SetAllPoints(button)


	button.BorderTexture = button.BorderFrame:CreateTexture()
	button.BorderTexture:SetPoint(unpack(layout.ZoneAbilityButtonBorderPlace))
	button.BorderTexture:SetDrawLayer(unpack(layout.ZoneAbilityButtonBorderDrawLayer))
	button.BorderTexture:SetSize(unpack(layout.ZoneAbilityButtonBorderSize))
	button.BorderTexture:SetTexture(layout.ZoneAbilityButtonBorderTexture)
	button.BorderTexture:SetVertexColor(unpack(layout.ZoneAbilityButtonBorderColor))

end

Module.StyleVehicleSeatIndicator = function(self)
	local layout = self.layout

	self:DisableMappy(VehicleSeatIndicator)
	self:CreateHolder(VehicleSeatIndicator, unpack(layout.VehicleSeatIndicatorPlace))
	self:CreatePointHook(VehicleSeatIndicator)

	-- This will prevent the vehicle seat indictaor frame size from affecting other blizzard anchors,
	-- it will also prevent the blizzard frame manager from moving it at all.
	VehicleSeatIndicator.IsShown = function() return false end
end

Module.UpdateTalkingHead = function(self, event, ...)
	if (event == "ADDON_LOADED") then
		local addon = ...
		if (addon ~= "Blizzard_TalkingHeadUI") then
			return
		end
		self:UnregisterEvent("ADDON_LOADED", "UpdateTalkingHead")
	end 
	local db = self.db
	local frame = TalkingHeadFrame
	if (db.enableTalkingHead) then 
		if (frame) then 
			-- The frame is loaded, so we re-register any needed events,
			-- just in case this is a manual user called re-enabling.
			-- Or in case another addon has disabled it.
			frame:RegisterEvent("TALKINGHEAD_REQUESTED")
			frame:RegisterEvent("TALKINGHEAD_CLOSE")
			frame:RegisterEvent("SOUNDKIT_FINISHED")
			frame:RegisterEvent("LOADING_SCREEN_ENABLED")

			self:StyleTalkingHeadFrame()
		else
			-- If the head hasn't been loaded yet, we queue the event.
			return self:RegisterEvent("ADDON_LOADED", "UpdateTalkingHead")
		end
	else
		if (frame) then 
			frame:UnregisterEvent("TALKINGHEAD_REQUESTED")
			frame:UnregisterEvent("TALKINGHEAD_CLOSE")
			frame:UnregisterEvent("SOUNDKIT_FINISHED")
			frame:UnregisterEvent("LOADING_SCREEN_ENABLED")
			frame:Hide()
		else
			-- If no frame is found, the addon hasn't been loaded yet,
			-- and it should have been enough to just prevent blizzard from showing it.
			UIParent:UnregisterEvent("TALKINGHEAD_REQUESTED")

			-- Since other addons might load it contrary to our settings, though,
			-- we register our addon listener to take control of it when it's loaded.
			return self:RegisterEvent("ADDON_LOADED", "UpdateTalkingHead")
		end
	end
end

Module.StyleTalkingHeadFrame = function(self)
	local db = self.db
	local layout = self.layout
	local frame = TalkingHeadFrame

	-- Prevent blizzard from moving this one around
	frame.ignoreFramePositionManager = true
	frame:SetScale(.8) -- shrink it, it's too big.

	self:CreateHolder(frame, unpack(layout.TalkingHeadFramePlace))
	self:CreatePointHook(frame)

	-- Iterate through all alert subsystems in order to find the one created for TalkingHeadFrame, and then remove it.
	-- We do this to prevent alerts from anchoring to this frame when it is shown.
	local AlertFrame = _G.AlertFrame
	for index, alertFrameSubSystem in ipairs(AlertFrame.alertFrameSubSystems) do
		if (alertFrameSubSystem.anchorFrame and (alertFrameSubSystem.anchorFrame == frame)) then
			table_remove(AlertFrame.alertFrameSubSystems, index)
		end
	end
	-- Only ever do this once
	if (not StyleCache[frame]) then 
		frame:HookScript("OnShow", AlertFrame_PostUpdateAnchors)
		frame:HookScript("OnHide", AlertFrame_PostUpdateAnchors)
	end
	StyleCache[frame] = true
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
	for _,frameName in ipairs({"RaidWarningFrame", "RaidBossEmoteFrame"}) do
		local frame = _G[frameName]
		frame:SetAlpha(.85)
		frame:SetHeight(85) -- 512,70
		frame.timings.RAID_NOTICE_MIN_HEIGHT = fontSize
		frame.timings.RAID_NOTICE_MAX_HEIGHT = fontSize
		frame.timings.RAID_NOTICE_SCALE_UP_TIME = 0
		frame.timings.RAID_NOTICE_SCALE_DOWN_TIME = 0

		local slot1 = _G[frameName.."Slot1"]
		slot1:SetFontObject(GetFont(fontSize,true,true))
		slot1:SetShadowColor(0,0,0,.5)
		slot1:SetWidth(frameWidth) -- 800
		slot1.SetTextHeight = function() end

		local slot2 = _G[frameName.."Slot2"]
		slot2:SetFontObject(GetFont(fontSize,true,true))
		slot2:SetShadowColor(0,0,0,.5)
		slot2:SetWidth(frameWidth) -- 800
		slot2.SetTextHeight = function() end
	end

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
	self.db.enableBGSanityFilter = nil
	self.layout = GetLayout(self:GetName())

	-- Create a secure proxy frame for the menu system
	local callbackFrame = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	callbackFrame.UpdateTalkingHead = function(proxy, ...) self:UpdateTalkingHead() end 

	-- Register module db with the secure proxy
	for key,value in pairs(self.db) do 
		callbackFrame:SetAttribute(key,value)
	end 

	-- Now that attributes have been defined, attach the onattribute script
	callbackFrame:SetAttribute("_onattributechanged", [=[
		if (name) then 
			name = string.lower(name); 
			if (name == "change-enabletalkinghead") then 
				self:SetAttribute("enableTalkingHead", value); 
				self:CallMethod("UpdateTalkingHead"); 
			end 
		end 
	]=])

	-- Attach a getter method for the menu to the module
	self.GetSecureUpdater = function(self) 
		return callbackFrame 
	end
	
end 

Module.OnEnable = function(self)
	if (IsRetail) then
		self:StyleVehicleSeatIndicator()
		self:StyleExtraActionButton()
		self:StyleZoneAbilityButton()
	end
	self:StyleErrorFrame()
	self:StyleRaidWarningFrame()
	if (IsClassic) then
		self:StyleQuestTimerFrame()
	end
	if (IsRetail) then
		self:UpdateAlertFrames()
		self:UpdateTalkingHead()
	end
end
