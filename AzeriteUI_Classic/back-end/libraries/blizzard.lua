local LibBlizzard = Wheel:Set("LibBlizzard", 40)
if (not LibBlizzard) then 
	return
end

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibBlizzard requires LibEvent to be loaded.")

-- Embed event functionality into this
LibEvent:Embed(LibBlizzard)

-- Lua API
local _G = _G
local assert = assert
local debugstack = debugstack
local error = error
local pairs = pairs
local select = select
local string_format = string.format
local string_join = string.join
local string_match = string.match
local type = type

-- WoW API
local CreateFrame = _G.CreateFrame
local FCF_GetCurrentChatFrame = _G.FCF_GetCurrentChatFrame
local IsAddOnLoaded = _G.IsAddOnLoaded
local RegisterStateDriver = _G.RegisterStateDriver
local SetCVar = _G.SetCVar
local TargetofTarget_Update = _G.TargetofTarget_Update

-- WoW Objects
local UIParent = _G.UIParent

LibBlizzard.embeds = LibBlizzard.embeds or {}
LibBlizzard.queue = LibBlizzard.queue or {}

-- Frame to securely hide items
if (not LibBlizzard.frame) then
	local frame = CreateFrame("Frame", nil, UIParent, "SecureHandlerAttributeTemplate")
	frame:Hide()
	frame:SetPoint("TOPLEFT", 0, 0)
	frame:SetPoint("BOTTOMRIGHT", 0, 0)
	frame.children = {}
	RegisterAttributeDriver(frame, "state-visibility", "hide")

	-- Attach it to our library
	LibBlizzard.frame = frame
end

local UIHider = LibBlizzard.frame
local UIWidgets = {}
local UIWidgetDependency = {}

-- Syntax check 
local check = function(value, num, ...)
	assert(type(num) == "number", ("Bad argument #%.0f to '%s': %s expected, got %s"):format(2, "Check", "number", type(num)))
	for i = 1,select("#", ...) do
		if (type(value) == select(i, ...)) then 
			return 
		end
	end
	local types = string_join(", ", ...)
	local name = string_match(debugstack(2, 2, 0), ": in function [`<](.-)['>]")
	error(("Bad argument #%.0f to '%s': %s expected, got %s"):format(num, name, types, type(value)), 3)
end

-- Proxy function to retrieve the actual frame whether 
-- the input is a frame or a global frame name 
local getFrame = function(baseName)
	if (type(baseName) == "string") then
		return _G[baseName]
	else
		return baseName
	end
end

-- Kill off an existing frame in a secure, taint free way
-- @usage kill(object, [keepEvents], [silent])
-- @param object <table, string> frame, fontstring or texture to hide
-- @param keepEvents <boolean, nil> 'true' to leave a frame's events untouched
-- @param silent <boolean, nil> 'true' to return 'false' instead of producing an error for non existing objects
local kill = function(object, keepEvents, silent)
	check(object, 1, "string", "table")
	check(keepEvents, 2, "boolean", "nil")
	if (type(object) == "string") then
		if (silent and (not _G[object])) then
			return false
		end
		assert(_G[object], ("Bad argument #%.0f to '%s'. No object named '%s' exists."):format(1, "Kill", object))
		object = _G[object]
	end
	if (not UIHider[object]) then
		UIHider[object] = {
			parent = object:GetParent(),
			isshown = object:IsShown(),
			point = { object:GetPoint() }
		}
	end
	object:SetParent(UIHider)
	if (object.UnregisterAllEvents and (not keepEvents)) then
		object:UnregisterAllEvents()
	end
	return true
end

local killUnitFrame = function(baseName, keepParent)
	local frame = getFrame(baseName)
	if frame then
		if (not keepParent) then
			kill(frame, false, true)
		end
		frame:Hide()
		frame:ClearAllPoints()
		frame:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT", -400, 500)

		local health = frame.healthbar
		if health then
			health:UnregisterAllEvents()
		end

		local power = frame.manabar
		if power then
			power:UnregisterAllEvents()
		end

		local spell = frame.spellbar
		if spell then
			spell:UnregisterAllEvents()
		end

		local altpowerbar = frame.powerBarAlt
		if altpowerbar then
			altpowerbar:UnregisterAllEvents()
		end
	end
end

UIWidgets["ActionBars"] = function(self)

	for _,object in pairs({
		"MainMenuBarVehicleLeaveButton",
		"PetActionBarFrame",
		"StanceBarFrame",
		"TutorialFrameAlertButton1",
		"TutorialFrameAlertButton2",
		"TutorialFrameAlertButton3",
		"TutorialFrameAlertButton4",
		"TutorialFrameAlertButton5",
		"TutorialFrameAlertButton6",
		"TutorialFrameAlertButton7",
		"TutorialFrameAlertButton8",
		"TutorialFrameAlertButton9",
		"TutorialFrameAlertButton10",
	}) do 
		if (_G[object]) then 
			_G[object]:UnregisterAllEvents()
		else 
			print(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
		end
	end 
	for _,object in pairs({
		"FramerateLabel",
		"FramerateText",
		"MainMenuBarArtFrame",
		"MainMenuBarOverlayFrame",
		"MainMenuExpBar",
		"MainMenuBarVehicleLeaveButton",
		"MultiBarBottomLeft",
		"MultiBarBottomRight",
		"MultiBarLeft",
		"MultiBarRight",
		"PetActionBarFrame",
		"StanceBarFrame",
		"StreamingIcon"
	}) do 
		if (_G[object]) then 
			_G[object]:SetParent(UIHider)
		else 
			print(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
		end
	end 
	for _,object in pairs({
		"MainMenuBarArtFrame",
		"PetActionBarFrame",
		"StanceBarFrame"
	}) do 
		if (_G[object]) then 
			_G[object]:Hide()
		else 
			print(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
		end
	end 
	for _,object in pairs({
		"ActionButton", 
		"MultiBarBottomLeftButton", 
		"MultiBarBottomRightButton", 
		"MultiBarRightButton",
		"MultiBarLeftButton"
	}) do 
		for i = 1,NUM_ACTIONBAR_BUTTONS do
			local button = _G[object..i]
			button:Hide()
			button:UnregisterAllEvents()
			button:SetAttribute("statehidden", true)
		end
	end 

	MainMenuBar:EnableMouse(false)
	MainMenuBar:SetAlpha(0)
	MainMenuBar:UnregisterEvent("DISPLAY_SIZE_CHANGED")
	MainMenuBar:UnregisterEvent("UI_SCALE_CHANGED")
	MainMenuBar.slideOut:GetAnimations():SetOffset(0,0)

	-- Gets rid of the loot anims
	MainMenuBarBackpackButton:UnregisterEvent("ITEM_PUSH") 
	for slot = 0,3 do
		_G["CharacterBag"..slot.."Slot"]:UnregisterEvent("ITEM_PUSH") 
	end

	UIPARENT_MANAGED_FRAME_POSITIONS["MainMenuBar"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["StanceBarFrame"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["PETACTIONBAR_YPOS"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["MultiCastActionBarFrame"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["MULTICASTACTIONBAR_YPOS"] = nil

	--UIWidgets["ActionBarsMainBar"](self)
	--UIWidgets["ActionBarsBagBarAnims"](self)
end 

UIWidgets["Alerts"] = function(self)
	local AlertFrame = _G.AlertFrame
	if AlertFrame then
		AlertFrame:UnregisterAllEvents()
		AlertFrame:SetParent(UIHider)
	end
end 

UIWidgets["Auras"] = function(self)
	BuffFrame:SetScript("OnLoad", nil)
	BuffFrame:SetScript("OnUpdate", nil)
	BuffFrame:SetScript("OnEvent", nil)
	BuffFrame:SetParent(UIHider)
	BuffFrame:UnregisterAllEvents()
	if TemporaryEnchantFrame then 
		TemporaryEnchantFrame:SetScript("OnUpdate", nil)
		TemporaryEnchantFrame:SetParent(UIHider)
	end 
end 

UIWidgets["CaptureBar"] = function(self)
	UIWidgetBelowMinimapContainerFrame:SetParent(UIHider)
	UIWidgetBelowMinimapContainerFrame:SetScript("OnEvent", nil)
	UIWidgetBelowMinimapContainerFrame:UnregisterAllEvents()
end

UIWidgets["CastBars"] = function(self)
	local CastingBarFrame = _G.CastingBarFrame
	local PetCastingBarFrame = _G.PetCastingBarFrame

	-- player's castbar
	CastingBarFrame:SetScript("OnEvent", nil)
	CastingBarFrame:SetScript("OnUpdate", nil)
	CastingBarFrame:SetParent(UIHider)
	CastingBarFrame:UnregisterAllEvents()
	
	-- player's pet's castbar
	PetCastingBarFrame:SetScript("OnEvent", nil)
	PetCastingBarFrame:SetScript("OnUpdate", nil)
	PetCastingBarFrame:SetParent(UIHider)
	PetCastingBarFrame:UnregisterAllEvents()
end 

UIWidgets["Durability"] = function(self)
	DurabilityFrame:UnregisterAllEvents()
	DurabilityFrame:SetScript("OnShow", nil)
	DurabilityFrame:SetScript("OnHide", nil)

	-- Will this taint? 
	-- This is to prevent the durability frame size 
	-- affecting other anchors
	DurabilityFrame:SetParent(UIHider)
	DurabilityFrame:Hide()
	DurabilityFrame.IsShown = function() return false end
end

UIWidgets["Minimap"] = function(self)

	GameTimeFrame:SetParent(UIHider)
	GameTimeFrame:UnregisterAllEvents()

	MinimapBorder:SetParent(UIHider)
	MinimapBorderTop:SetParent(UIHider)
	MinimapCluster:SetParent(UIHider)
	MiniMapMailBorder:SetParent(UIHider)
	MiniMapMailFrame:SetParent(UIHider)
	MinimapBackdrop:SetParent(UIHider) 
	MinimapNorthTag:SetParent(UIHider)
	if MiniMapTracking then MiniMapTracking:SetParent(UIHider) end
	if MiniMapTrackingButton then MiniMapTrackingButton:SetParent(UIHider) end
	if MiniMapTrackingFrame then MiniMapTrackingFrame:SetParent(UIHider) end
	MiniMapWorldMapButton:SetParent(UIHider)
	MinimapZoomIn:SetParent(UIHider)
	MinimapZoomOut:SetParent(UIHider)
	MinimapZoneTextButton:SetParent(UIHider)
	
	-- Classic Battleground Queue Button
	if MiniMapBattlefieldFrame then 
		MiniMapBattlefieldIcon:SetParent(UIHider)
		MiniMapBattlefieldIcon:SetAlpha(0)
		MiniMapBattlefieldBorder:SetParent(UIHider)
		MiniMapBattlefieldBorder:SetTexture(nil) -- the butt fugly standard border
		BattlegroundShine:SetTexture(nil) -- annoying background "shine"
		--MiniMapBattlefieldDropDown
	end

	-- Can we do this?
	self:DisableUIWidget("MinimapClock")
end

UIWidgets["MinimapClock"] = function(self)
	if TimeManagerClockButton then 
		TimeManagerClockButton:SetParent(UIHider)
		TimeManagerClockButton:UnregisterAllEvents()
	end 
end
UIWidgetDependency["MinimapClock"] = "Blizzard_TimeManager"

UIWidgets["MirrorTimer"] = function(self)
	for i = 1,MIRRORTIMER_NUMTIMERS do
		local timer = _G["MirrorTimer"..i]
		timer:SetScript("OnEvent", nil)
		timer:SetScript("OnUpdate", nil)
		timer:SetParent(UIHider)
		timer:UnregisterAllEvents()
	end
end 

UIWidgets["QuestTimerFrame"] = function(self)
	QuestTimerFrame:SetScript("OnLoad", nil)
	QuestTimerFrame:SetScript("OnEvent", nil)
	QuestTimerFrame:SetScript("OnUpdate", nil)
	QuestTimerFrame:SetScript("OnShow", nil)
	QuestTimerFrame:SetScript("OnHide", nil)
	QuestTimerFrame:SetParent(UIHider)
	QuestTimerFrame:Hide()
	QuestTimerFrame.numTimers = 0
	QuestTimerFrame.updating = nil
	for i = 1,MAX_QUESTS do
		_G["QuestTimer"..i]:Hide()
	end
end

UIWidgets["QuestWatchFrame"] = function(self)
	if QuestWatchFrame then 
		QuestWatchFrame:SetParent(UIHider)
	end
end 

UIWidgets["Tutorials"] = function(self)
	TutorialFrame:UnregisterAllEvents()
	TutorialFrame:Hide()
	TutorialFrame.Show = TutorialFrame.Hide
end

UIWidgets["UnitFramePlayer"] = function(self)
	killUnitFrame("PlayerFrame")

	-- A lot of blizz modules relies on PlayerFrame.unit
	-- This includes the aura frame and several others. 
	_G.PlayerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

	-- User placed frames don't animate
	_G.PlayerFrame:SetUserPlaced(true)
	_G.PlayerFrame:SetDontSavePosition(true)
end

UIWidgets["UnitFramePet"] = function(self)
	killUnitFrame("PetFrame")
end

UIWidgets["UnitFrameTarget"] = function(self)
	killUnitFrame("TargetFrame")
	killUnitFrame("ComboFrame")
end

UIWidgets["UnitFrameToT"] = function(self)
	killUnitFrame("TargetFrameToT")
	TargetofTarget_Update(TargetFrameToT)
end

UIWidgets["UnitFrameParty"] = function(self)
	for i = 1,5 do
		killUnitFrame(("PartyMemberFrame%.0f"):format(i))
	end

	-- Kill off the party background
	_G.PartyMemberBackground:SetParent(UIHider)
	_G.PartyMemberBackground:Hide()
	_G.PartyMemberBackground:SetAlpha(0)

	--hooksecurefunc("CompactPartyFrame_Generate", function() 
	--	killUnitFrame(_G.CompactPartyFrame)
	--	for i=1, _G.MEMBERS_PER_RAID_GROUP do
	--		killUnitFrame(_G["CompactPartyFrameMember" .. i])
	--	end	
	--end)
end

UIWidgets["UnitFrameRaid"] = function(self)
	-- dropdowns cause taint through the blizz compact unit frames, so we disable them
	-- http://www.wowinterface.com/forums/showpost.php?p=261589&postcount=5
	if _G.CompactUnitFrameProfiles then
		_G.CompactUnitFrameProfiles:UnregisterAllEvents()
	end

	if _G.CompactRaidFrameManager and (_G.CompactRaidFrameManager:GetParent() ~= UIHider) then
		_G.CompactRaidFrameManager:SetParent(UIHider)
	end

	_G.UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE")
end

UIWidgets["UnitFrameBoss"] = function(self)
	for i = 1,MAX_BOSS_FRAMES do
		killUnitFrame(("Boss%.0fTargetFrame"):format(i))
	end
end

UIWidgets["WorldMap"] = function(self)
	local Canvas = WorldMapFrame
	Canvas.BlackoutFrame:Hide()
	Canvas:SetIgnoreParentScale(false)
	Canvas:RefreshDetailLayers()

	-- Contains the actual map. 
	local Container = WorldMapFrame.ScrollContainer
	Container.GetCanvasScale = function(self)
		return self:GetScale()
	end

	local Saturate = Saturate
	Container.NormalizeUIPosition = function(self, x, y)
		return Saturate(self:NormalizeHorizontalSize(x / self:GetCanvasScale() - self.Child:GetLeft())),
		       Saturate(self:NormalizeVerticalSize(self.Child:GetTop() - y / self:GetCanvasScale()))
	end

	Container.GetCursorPosition = function(self)
		local currentX, currentY = GetCursorPosition()
		local scale = UIParent:GetScale()
		if not(currentX and currentY and scale) then 
			return 0,0
		end 
		local scaledX, scaledY = currentX/scale, currentY/scale
		return scaledX, scaledY
	end

	Container.GetNormalizedCursorPosition = function(self)
		local x,y = self:GetCursorPosition()
		return self:NormalizeUIPosition(x,y)
	end

	local frame = CreateFrame("Frame")
	frame.elapsed = 0
	frame.stopAlpha = .9
	frame.moveAlpha = .65
	frame.stepIn = .05
	frame.stepOut = .05
	frame.throttle = .02
	frame:SetScript("OnEvent", function(selv, event) 
		if (event == "PLAYER_STARTED_MOVING") then 
			frame.alpha = Canvas:GetAlpha()
			frame:SetScript("OnUpdate", frame.Starting)

		elseif (event == "PLAYER_STOPPED_MOVING") or (event == "PLAYER_ENTERING_WORLD") then 
			frame.alpha = Canvas:GetAlpha()
			frame:SetScript("OnUpdate", frame.Stopping)
		end
	end)

	frame.Stopping = function(self, elapsed) 
		self.elapsed = self.elapsed + elapsed
		if (self.elapsed < frame.throttle) then
			return 
		end 
		if (frame.alpha + frame.stepIn < frame.stopAlpha) then 
			frame.alpha = frame.alpha + frame.stepIn
		else 
			frame.alpha = frame.stopAlpha
			frame:SetScript("OnUpdate", nil)
		end 
		Canvas:SetAlpha(frame.alpha)
	end

	frame.Starting = function(self, elapsed) 
		self.elapsed = self.elapsed + elapsed
		if (self.elapsed < frame.throttle) then
			return 
		end 
		if (frame.alpha - frame.stepOut > frame.moveAlpha) then 
			frame.alpha = frame.alpha - frame.stepOut
		else 
			frame.alpha = frame.moveAlpha
			frame:SetScript("OnUpdate", nil)
		end 
		Canvas:SetAlpha(frame.alpha)
	end

	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_STARTED_MOVING")
	frame:RegisterEvent("PLAYER_STOPPED_MOVING")
end
UIWidgetDependency["WorldMap"] = "Blizzard_WorldMap"

UIWidgets["ZoneText"] = function(self)
	local ZoneTextFrame = _G.ZoneTextFrame
	local SubZoneTextFrame = _G.SubZoneTextFrame
	local AutoFollowStatus = _G.AutoFollowStatus

	ZoneTextFrame:SetParent(UIHider)
	ZoneTextFrame:UnregisterAllEvents()
	ZoneTextFrame:SetScript("OnUpdate", nil)
	-- ZoneTextFrame:Hide()
	
	SubZoneTextFrame:SetParent(UIHider)
	SubZoneTextFrame:UnregisterAllEvents()
	SubZoneTextFrame:SetScript("OnUpdate", nil)
	-- SubZoneTextFrame:Hide()
	
	AutoFollowStatus:SetParent(UIHider)
	AutoFollowStatus:UnregisterAllEvents()
	AutoFollowStatus:SetScript("OnUpdate", nil)
	-- AutoFollowStatus:Hide()
end 

LibBlizzard.OnEvent = function(self, event, ...)
	local arg1 = ...
	if (event == "ADDON_LOADED") then
		local queueCount = 0
		for widgetName,addonName in pairs(self.queue) do 
			if (addonName == arg1) then 
				self.queue[widgetName] = nil
				UIWidgets[widgetName](self)
			else 
				queueCount = queueCount + 1
			end 
		end 
		if (queueCount == 0) then 
			if self:IsEventRegistered("ADDON_LOADED", "OnEvent") then 
				self:UnregisterEvent("ADDON_LOADED", "OnEvent")
			end 
		end 
	end 
end 

LibBlizzard.DisableUIWidget = function(self, name, ...)
	-- Just silently fail for widgets that don't exist.
	-- Makes it much simpler during development, 
	-- and much easier in the future to upgrade.
	if (not UIWidgets[name]) then 
		print(("LibBlizzard: The UI widget '%s' does not exist."):format(name))
		return 
	end 
	local dependency = UIWidgetDependency[name]
	if dependency then 
		if (not IsAddOnLoaded(dependency)) then 
			LibBlizzard.queue[name] = dependency
			if (not LibBlizzard:IsEventRegistered("ADDON_LOADED", "OnEvent")) then 
				LibBlizzard:RegisterEvent("ADDON_LOADED", "OnEvent")
			end 
			return 
		end 
	end 
	UIWidgets[name](LibBlizzard, ...)
end

LibBlizzard.DisableUIMenuOption = function(self, option_shrink, option_name)
	local option = _G[option_name]
	if not(option) or not(option.IsObjectType) or not(option:IsObjectType("Frame")) then
		print(("LibBlizzard: The menu option '%s' does not exist."):format(option_name))
		return
	end
	option:SetParent(UIHider)
	if option.UnregisterAllEvents then
		option:UnregisterAllEvents()
	end
	if option_shrink then
		option:SetHeight(0.00001)
		option:SetScale(0.00001) -- needed for the options to shrink properly. Watch out for side effects(?)
	end
	option.cvar = ""
	option.uvar = ""
	option.value = nil
	option.oldValue = nil
	option.defaultValue = nil
	option.setFunc = function() end
end

LibBlizzard.DisableUIMenuPage = function(self, panel_id, panel_name)
	local button,window
	-- remove an entire blizzard options panel, 
	-- and disable its automatic cancel/okay functionality
	-- this is needed, or the option will be reset when the menu closes
	-- it is also a major source of taint related to the Compact group frames!
	if panel_id then
		local category = _G["InterfaceOptionsFrameCategoriesButton" .. panel_id]
		if category then
			category:SetScale(0.00001)
			category:SetAlpha(0)
			button = true
		end
	end
	if panel_name then
		local panel = _G[panel_name]
		if panel then
			panel:SetParent(UIHider)
			if panel.UnregisterAllEvents then
				panel:UnregisterAllEvents()
			end
			panel.cancel = function() end
			panel.okay = function() end
			panel.refresh = function() end
			window = true
		end
	end
	if (panel_id and not button) then
		print(("LibBlizzard: The panel button with id '%.0f' does not exist."):format(panel_id))
	end 
	if (panel_name and not window) then
		print(("LibBlizzard: The menu panel named '%s' does not exist."):format(panel_name))
	end 
end

-- Module embedding
local embedMethods = {
	DisableUIMenuOption = true,
	DisableUIMenuPage = true,
	DisableUIWidget = true
}

LibBlizzard.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibBlizzard.embeds) do
	LibBlizzard:Embed(target)
end
