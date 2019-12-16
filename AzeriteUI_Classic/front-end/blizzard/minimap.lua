local ADDON,Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local L = Wheel("LibLocale"):GetLocale(ADDON)
local Module = Core:NewModule("Minimap", "LibEvent", "LibDB", "LibMinimap", "LibTooltip", "LibTime", "LibSound", "LibPlayerData")

-- Don't grab buttons if these are active
local MBB = Module:IsAddOnEnabled("MBB") 
local MBF = Module:IsAddOnEnabled("MinimapButtonFrame")

-- Lua API
local _G = _G
local ipairs = ipairs
local math_floor = math.floor
local select = select
local string_format = string.format
local string_match = string.match
local table_insert = table.insert
local tonumber = tonumber
local unpack = unpack

-- WoW API
local CancelTrackingBuff = CancelTrackingBuff
local CastSpellByID = CastSpellByID
local GetFactionInfo = GetFactionInfo
local GetFramerate = GetFramerate
local GetNetStats = GetNetStats
local GetNumFactions = GetNumFactions
local GetSpellInfo = GetSpellInfo
local GetSpellTexture = GetSpellTexture
local GetTrackingTexture = GetTrackingTexture
local GetWatchedFactionInfo = GetWatchedFactionInfo
local IsPlayerSpell = IsPlayerSpell
local UnitLevel = UnitLevel
local UnitRace = UnitRace

-- Private API
local Colors = Private.Colors
local GetConfig = Private.GetConfig
local GetLayout = Private.GetLayout

-- WoW Strings
local REPUTATION = REPUTATION 
local STANDING = STANDING 
local UNKNOWN = UNKNOWN

-- Custom strings & constants
local Spinner = {}
local NEW = [[|TInterface\OptionsFrame\UI-OptionsFrame-NewFeatureIcon:0:0:0:0|t]]
local shortXPString = "%s%%"
local longXPString = "%s / %s"
local fullXPString = "%s / %s (%s)"
local restedString = " (%s%% %s)"
local shortLevelString = "%s %.0f"

-- Constant to track player level
local LEVEL = UnitLevel("player")

----------------------------------------------------
-- Utility Functions
----------------------------------------------------
local getTimeStrings = function(h, m, suffix, useStandardTime, abbreviateSuffix)
	if (useStandardTime) then 
		return "%.0f:%02.0f |cff888888%s|r", h, m, abbreviateSuffix and string_match(suffix, "^.") or suffix
	else 
		return "%02.0f:%02.0f", h, m
	end 
end 

local short = function(value)
	value = tonumber(value)
	if (not value) then return "" end
	if (value >= 1e9) then
		return ("%.1fb"):format(value / 1e9):gsub("%.?0+([kmb])$", "%1")
	elseif (value >= 1e6) then
		return ("%.1fm"):format(value / 1e6):gsub("%.?0+([kmb])$", "%1")
	elseif (value >= 1e3) or (value <= -1e3) then
		return ("%.1fk"):format(value / 1e3):gsub("%.?0+([kmb])$", "%1")
	else
		return tostring(math_floor(value))
	end	
end

-- zhCN exceptions
local gameLocale = GetLocale()
if (gameLocale == "zhCN") then 
	short = function(value)
		value = tonumber(value)
		if (not value) then return "" end
		if (value >= 1e8) then
			return ("%.1f亿"):format(value / 1e8):gsub("%.?0+([km])$", "%1")
		elseif (value >= 1e4) or (value <= -1e3) then
			return ("%.1f万"):format(value / 1e4):gsub("%.?0+([km])$", "%1")
		else
			return tostring(math_floor(value))
		end 
	end
end 

local MouseIsOver = function(frame)
	return (frame == GetMouseFocus())
end

----------------------------------------------------
-- Callbacks
----------------------------------------------------
local XP_PostUpdate = function(element, min, max, restedLeft, restedTimeLeft)
	local description = element.Value and element.Value.Description
	if description then 
		local level = LEVEL or UnitLevel("player")
		if (level and (level > 0)) then 
			description:SetFormattedText(L["to level %s"], level + 1)
		else 
			description:SetText("")
		end 
	end 
end

local Rep_PostUpdate = function(element, current, min, max, factionName, standingID, standingLabel)
	local description = element.Value and element.Value.Description
	if description then 
		if (standingID == MAX_REPUTATION_REACTION) then
			description:SetText(standingLabel)
		else
			local nextStanding = standingID and _G["FACTION_STANDING_LABEL"..(standingID + 1)]
			if nextStanding then 
				description:SetFormattedText(L["to %s"], nextStanding)
			else
				description:SetText("")
			end 
		end 
	end 
end

local Performance_UpdateTooltip = function(self)
	local tooltip = Module:GetMinimapTooltip()

	local bandwidthIn, bandwidthOut, latencyHome, latencyWorld = GetNetStats()
	local fps = GetFramerate()

	local colors = self._owner.colors 
	local rt, gt, bt = unpack(colors.title)
	local r, g, b = unpack(colors.normal)
	local rh, gh, bh = unpack(colors.highlight)
	local rg, gg, bg = unpack(colors.quest.green)

	tooltip:SetDefaultAnchor(self)
	tooltip:SetMaximumWidth(360)
	tooltip:AddLine(L["Network Stats"], rt, gt, bt)
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(L["World latency:"], ("%.0f|cff888888%s|r"):format(math_floor(latencyWorld), MILLISECONDS_ABBR), rh, gh, bh, r, g, b)
	tooltip:AddLine(L["This is the latency of the world server, and affects casting, crafting, interaction with other players and NPCs. This is the value that decides how delayed your combat actions are."], rg, gg, bg, true)
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(L["Home latency:"], ("%.0f|cff888888%s|r"):format(math_floor(latencyHome), MILLISECONDS_ABBR), rh, gh, bh, r, g, b)
	tooltip:AddLine(L["This is the latency of the home server, which affects things like chat, guild chat, the auction house and some other non-combat related things."], rg, gg, bg, true)
	tooltip:Show()
end 

local Performance_OnEnter = function(self)
	self.UpdateTooltip = Performance_UpdateTooltip
	self:UpdateTooltip()
end 

local Performance_OnLeave = function(self)
	Module:GetMinimapTooltip():Hide()
	self.UpdateTooltip = nil
end 

local Tracking_OnClick = function(self, button)
	if (button == "LeftButton") then
		self:ShowMenu()
	elseif (button == "RightButton") then
		CancelTrackingBuff()
	end
end

local Tracking_OnEnter = function(self)
	local tooltip = Module:GetMinimapTooltip()
	tooltip:SetDefaultAnchor(self)
	tooltip:SetMaximumWidth(360)
	tooltip:SetTrackingSpell()
end

local Tracking_OnLeave = function(self)
	Module:GetMinimapTooltip():Hide()
end

-- This is the XP and AP tooltip (and rep/honor later on) 
local Toggle_UpdateTooltip = function(toggle)

	local tooltip = Module:GetMinimapTooltip()
	local hasXP = Module.PlayerHasXP()
	local hasRep = Module.PlayerHasRep()

	local NC = "|r"
	local colors = toggle._owner.colors 
	local rt, gt, bt = unpack(colors.title)
	local r, g, b = unpack(colors.normal)
	local rh, gh, bh = unpack(colors.highlight)
	local rgg, ggg, bgg = unpack(colors.quest.gray)
	local rg, gg, bg = unpack(colors.quest.green)
	local rr, gr, br = unpack(colors.quest.red)
	local green = colors.quest.green.colorCode
	local normal = colors.normal.colorCode
	local highlight = colors.highlight.colorCode

	local resting, restState, restedName, mult
	local restedLeft, restedTimeLeft

	if (hasXP or hasRep) then 
		tooltip:SetDefaultAnchor(toggle)
		tooltip:SetMaximumWidth(360)
	end

	-- XP tooltip
	-- Currently more or less a clone of the blizzard tip, we should improve!
	if hasXP then 
		resting = IsResting()
		restState, restedName, mult = GetRestState()
		restedLeft, restedTimeLeft = GetXPExhaustion(), GetTimeToWellRested()
		
		local min, max = UnitXP("player"), UnitXPMax("player")

		tooltip:AddDoubleLine(POWER_TYPE_EXPERIENCE, LEVEL or UnitLevel("player"), rt, gt, bt, rt, gt, bt)
		tooltip:AddDoubleLine(L["Current XP: "], fullXPString:format(normal..short(min)..NC, normal..short(max)..NC, highlight..math_floor(min/max*100).."%"..NC), rh, gh, bh, rgg, ggg, bgg)

		-- add rested bonus if it exists
		if (restedLeft and (restedLeft > 0)) then
			tooltip:AddDoubleLine(L["Rested Bonus: "], fullXPString:format(normal..short(restedLeft)..NC, normal..short(max * 1.5)..NC, highlight..math_floor(restedLeft/(max * 1.5)*100).."%"..NC), rh, gh, bh, rgg, ggg, bgg)
		end
		
		if (restState == 1) then
			if resting and restedTimeLeft and restedTimeLeft > 0 then
				tooltip:AddLine(" ")
				--tooltip:AddLine(L["Resting"], rh, gh, bh)
				if restedTimeLeft > hour*2 then
					tooltip:AddLine(L["You must rest for %s additional hours to become fully rested."]:format(highlight..math_floor(restedTimeLeft/hour)..NC), r, g, b, true)
				else
					tooltip:AddLine(L["You must rest for %s additional minutes to become fully rested."]:format(highlight..math_floor(restedTimeLeft/minute)..NC), r, g, b, true)
				end
			else
				tooltip:AddLine(" ")
				--tooltip:AddLine(L["Rested"], rh, gh, bh)
				tooltip:AddLine(L["%s of normal experience gained from monsters."]:format(shortXPString:format((mult or 1)*100)), rg, gg, bg, true)
			end
		elseif (restState >= 2) then
			if not(restedTimeLeft and restedTimeLeft > 0) then 
				tooltip:AddLine(" ")
				tooltip:AddLine(L["You should rest at an Inn."], rr, gr, br)
			else
				-- No point telling people there's nothing to tell them, is there?
				--tooltip:AddLine(" ")
				--tooltip:AddLine(L["Normal"], rh, gh, bh)
				--tooltip:AddLine(L["%s of normal experience gained from monsters."]:format(shortXPString:format((mult or 1)*100)), rg, gg, bg, true)
			end
		end
	end 

	-- Rep tooltip
	if hasRep then 

		local name, reaction, min, max, current, factionID = GetWatchedFactionInfo()
	
		local standingID, isFriend, friendText
		local standingLabel, standingDescription
		for i = 1, GetNumFactions() do
			local factionName, description, standingId, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(i)
			
			if (factionName == name) then
				standingID = standingId
				break
			end
		end

		if standingID then 
			if hasXP then 
				tooltip:AddLine(" ")
			end 
			standingLabel = _G["FACTION_STANDING_LABEL"..standingID]
			tooltip:AddDoubleLine(name, standingLabel, rt, gt, bt, rt, gt, bt)

			local barMax = max - min 
			local barValue = current - min
			if (barMax > 0) then 
				tooltip:AddDoubleLine(L["Current Standing: "], fullXPString:format(normal..short(current-min)..NC, normal..short(max-min)..NC, highlight..math_floor((current-min)/(max-min)*100).."%"..NC), rh, gh, bh, rgg, ggg, bgg)
			else 
				tooltip:AddDoubleLine(L["Current Standing: "], "100%", rh, gh, bh, r, g, b)
			end 
		else 
			-- Don't add additional spaces if we can't display the information
			hasRep = nil
		end
	end
	
	-- Only adding the sticky toggle to the toggle button for now, not the frame.
	if MouseIsOver(toggle) then 
		tooltip:AddLine(" ")
		if Module.db.stickyBars then 
			tooltip:AddLine(L["%s to disable sticky bars."]:format(green..L["<Left-Click>"]..NC), rh, gh, bh)
		else 
			tooltip:AddLine(L["%s to enable sticky bars."]:format(green..L["<Left-Click>"]..NC), rh, gh, bh)
		end 
	end 

	tooltip:Show()
end 

local Toggle_OnUpdate = function(toggle, elapsed)

	if (toggle.fadeDelay > 0) then 
		local fadeDelay = toggle.fadeDelay - elapsed
		if fadeDelay > 0 then 
			toggle.fadeDelay = fadeDelay
			return 
		else 
			toggle.fadeDelay = 0
			toggle.timeFading = 0
		end 
	end 

	toggle.timeFading = toggle.timeFading + elapsed

	if (toggle.fadeDirection == "OUT") then 
		local alpha = 1 - (toggle.timeFading / toggle.fadeDuration)
		if (alpha > 0) then 
			toggle.Frame:SetAlpha(alpha)
		else 
			toggle:SetScript("OnUpdate", nil)
			toggle.Frame:Hide()
			toggle.Frame:SetAlpha(0)
			toggle.fading = nil 
			toggle.fadeDirection = nil
			toggle.fadeDuration = 0
			toggle.timeFading = 0
		end 

	elseif (toggle.fadeDirection == "IN") then 
		local alpha = toggle.timeFading / toggle.fadeDuration
		if (alpha < 1) then 
			toggle.Frame:SetAlpha(alpha)
		else 
			toggle:SetScript("OnUpdate", nil)
			toggle.Frame:SetAlpha(1)
			toggle.fading = nil
			toggle.fadeDirection = nil
			toggle.fadeDuration = 0
			toggle.timeFading = 0
		end 
	end 

end 

-- This method is called upon entering or leaving 
-- either the toggle button, the visible ring frame, 
-- or by clicking the toggle button. 
-- Its purpose should be to decide ring frame visibility. 
local Toggle_UpdateFrame = function(toggle)
	local db = Module.db
	local frame = toggle.Frame
	local frameIsShown = frame:IsShown()

	-- If sticky bars is enabled, we should only fade in, and keep it there, 
	-- and then just remove the whole update handler until the sticky setting is changed. 
	if db.stickyBars then 

		-- if the frame isn't shown, 
		-- reset the alpha and initiate fade-in
		if (not frameIsShown) then 
			frame:SetAlpha(0)
			frame:Show()

			toggle.fadeDirection = "IN"
			toggle.fadeDelay = 0
			toggle.fadeDuration = .25
			toggle.timeFading = 0
			toggle.fading = true

			if not toggle:GetScript("OnUpdate") then 
				toggle:SetScript("OnUpdate", Toggle_OnUpdate)
			end
	
		-- If it is shown, we should probably just keep going. 
		-- This is probably just called because the user moved 
		-- between the toggle button and the frame. 
		else 


		end

	-- Move towards full visibility if we're over the toggle or the visible frame
	elseif toggle.isMouseOver or frame.isMouseOver then 

		-- If we entered while fading, it's most likely a fade-out that needs to be reversed.
		if toggle.fading then 
			if toggle.fadeDirection == "OUT" then 
				toggle.fadeDirection = "IN"
				toggle.fadeDuration = .25
				toggle.fadeDelay = 0
				toggle.timeFading = 0

				if not toggle:GetScript("OnUpdate") then 
					toggle:SetScript("OnUpdate", Toggle_OnUpdate)
				end
			else 
				-- Can't see this happening?
			end 

		-- If it's not fading it's either because it's hidden, at full alpha,  
		-- or because sticky bars just got disabled and it's still fully visible. 
		else 
			if frameIsShown then 
				-- Sticky bars? 
			else 
				frame:SetAlpha(0)
				frame:Show()
				toggle.fadeDirection = "IN"
				toggle.fadeDuration = .25
				toggle.fadeDelay = 0
				toggle.timeFading = 0
				toggle.fading = true

				if not toggle:GetScript("OnUpdate") then 
					toggle:SetScript("OnUpdate", Toggle_OnUpdate)
				end
			end 
		end  


	-- We're not above the toggle or a visible frame, 
	-- so we should initiate a fade-out. 
	else 

		-- if the frame is visible, this should be a fade-out.
		if frameIsShown then 

			toggle.fadeDirection = "OUT"

			-- Only initiate the fade delay if the frame previously was fully shown,
			-- do not start a delay if we moved back into a fading frame then out again 
			-- before it could reach its full alpha, or the frame will appear to be "stuck"
			-- in a semi-transparent state for a few seconds. Ewwww. 
			if toggle.fading then 
				toggle.fadeDelay = 0
				toggle.fadeDuration = (.25 - (toggle.timeFading or 0))
				toggle.timeFading = toggle.timeFading or 0
			else 
				toggle.fadeDelay = .5
				toggle.fadeDuration = .25
				toggle.timeFading = 0
				toggle.fading = true
			end 

			if not toggle:GetScript("OnUpdate") then 
				toggle:SetScript("OnUpdate", Toggle_OnUpdate)
			end
	
		end
	end
end

local Toggle_OnMouseUp = function(toggle, button)
	local db = Module.db
	db.stickyBars = not db.stickyBars

	Toggle_UpdateFrame(toggle)

	if toggle.UpdateTooltip then 
		toggle:UpdateTooltip()
	end 

	if Module.db.stickyBars then 
		print(toggle._owner.colors.title.colorCode..L["Sticky Minimap bars enabled."].."|r")
	else
		print(toggle._owner.colors.title.colorCode..L["Sticky Minimap bars disabled."].."|r")
	end 	
end

local Toggle_OnEnter = function(toggle)
	toggle.UpdateTooltip = Toggle_UpdateTooltip
	toggle.isMouseOver = true

	Toggle_UpdateFrame(toggle)

	toggle:UpdateTooltip()
end

local Toggle_OnLeave = function(toggle)
	local db = Module.db

	toggle.isMouseOver = nil
	toggle.UpdateTooltip = nil

	-- Update this to avoid a flicker or delay 
	-- when moving directly from the toggle button to the ringframe.  
	toggle.Frame.isMouseOver = MouseIsOver(toggle.Frame)

	Toggle_UpdateFrame(toggle)
	
	if (not toggle.Frame.isMouseOver) then 
		Module:GetMinimapTooltip():Hide()
	end 
end

local RingFrame_UpdateTooltip = function(frame)
	local toggle = frame._owner

	Toggle_UpdateTooltip(toggle)
end 

local RingFrame_OnEnter = function(frame)
	local toggle = frame._owner

	frame.UpdateTooltip = RingFrame_UpdateTooltip
	frame.isMouseOver = true

	Toggle_UpdateFrame(toggle)

	frame:UpdateTooltip()
end

local RingFrame_OnLeave = function(frame)
	local db = Module.db
	local toggle = frame._owner

	frame.isMouseOver = nil
	frame.UpdateTooltip = nil

	-- Update this to avoid a flicker or delay 
	-- when moving directly from the ringframe to the toggle button.  
	toggle.isMouseOver = MouseIsOver(toggle)

	Toggle_UpdateFrame(toggle)
	
	if (not toggle.isMouseOver) then 
		Module:GetMinimapTooltip():Hide()
	end 
end

local Time_UpdateTooltip = function(self)
	local tooltip = Module:GetMinimapTooltip()

	local colors = self._owner.colors 
	local rt, gt, bt = unpack(colors.title)
	local r, g, b = unpack(colors.normal)
	local rh, gh, bh = unpack(colors.highlight)
	local rg, gg, bg = unpack(colors.quest.green)
	local green = colors.quest.green.colorCode
	local NC = "|r"

	local useStandardTime = Module.db.useStandardTime
	local useServerTime = Module.db.useServerTime

	-- client time
	local lh, lm, lsuffix = Module:GetLocalTime(useStandardTime)

	-- server time
	local sh, sm, ssuffix = Module:GetServerTime(useStandardTime)

	tooltip:SetDefaultAnchor(self)
	tooltip:SetMaximumWidth(360)
	tooltip:AddLine(TIMEMANAGER_TOOLTIP_TITLE, rt, gt, bt)
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_LOCALTIME, string_format(getTimeStrings(lh, lm, lsuffix, useStandardTime)), rh, gh, bh, r, g, b)
	tooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_REALMTIME, string_format(getTimeStrings(sh, sm, ssuffix, useStandardTime)), rh, gh, bh, r, g, b)
	tooltip:AddLine(" ")
	tooltip:AddLine(green..L["<Left-Click>"]..NC .. " " .. TIMEMANAGER_SHOW_STOPWATCH, rh, gh, bh)

	if useServerTime then 
		tooltip:AddLine(L["%s to use local computer time."]:format(green..L["<Middle-Click>"]..NC), rh, gh, bh)
	else 
		tooltip:AddLine(L["%s to use game server time."]:format(green..L["<Middle-Click>"]..NC), rh, gh, bh)
	end 

	if useStandardTime then 
		tooltip:AddLine(L["%s to use military (24-hour) time."]:format(green..L["<Right-Click>"]..NC), rh, gh, bh)
	else 
		tooltip:AddLine(L["%s to use standard (12-hour) time."]:format(green..L["<Right-Click>"]..NC), rh, gh, bh)
	end 

	tooltip:Show()
end 

local Time_OnEnter = function(self)
	self.UpdateTooltip = Time_UpdateTooltip
	self:UpdateTooltip()
end 

local Time_OnLeave = function(self)
	Module:GetMinimapTooltip():Hide()
	self.UpdateTooltip = nil
end 

local Time_OnClick = function(self, mouseButton)
	if (mouseButton == "LeftButton") then 
		if (not IsAddOnLoaded("Blizzard_TimeManager")) then
			UIParentLoadAddOn("Blizzard_TimeManager")
		end
		Stopwatch_Toggle()
		if (StopwatchFrame:IsShown()) then
			Module:PlaySoundKitID(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		else
			Module:PlaySoundKitID(SOUNDKIT.IG_MAINMENU_QUIT)
		end
	elseif (mouseButton == "MiddleButton") then 
		Module.db.useServerTime = not Module.db.useServerTime

		self.clock.useServerTime = Module.db.useServerTime
		self.clock:ForceUpdate()

		if self.UpdateTooltip then 
			self:UpdateTooltip()
		end 

		if Module.db.useServerTime then 
			print(self._owner.colors.title.colorCode..L["Now using game server time."].."|r")
		else
			print(self._owner.colors.title.colorCode..L["Now using local computer time."].."|r")
		end 

	elseif (mouseButton == "RightButton") then 
		Module.db.useStandardTime = not Module.db.useStandardTime

		self.clock.useStandardTime = Module.db.useStandardTime
		self.clock:ForceUpdate()

		if self.UpdateTooltip then 
			self:UpdateTooltip()
		end 

		if Module.db.useStandardTime then 
			print(self._owner.colors.title.colorCode..L["Now using standard (12-hour) time."].."|r")
		else
			print(self._owner.colors.title.colorCode..L["Now using military (24-hour) time."].."|r")
		end 
	end
end

local Zone_OnEnter = function(self)
	local tooltip = Module:GetMinimapTooltip()

end 

local Zone_OnLeave = function(self)
	Module:GetMinimapTooltip():Hide()
end 

----------------------------------------------------
-- Map Setup
----------------------------------------------------
Module.SetUpMinimap = function(self)
	local db = self.db
	local layout = self.layout

	-- Frame
	----------------------------------------------------
	-- This is needed to initialize the map to 
	-- the most recent version of the library.
	-- All other calls will fail without it.
	self:SyncMinimap() 

	-- Retrieve an unique element handler for our module
	local Handler = self:GetMinimapHandler()
	Handler.colors = Colors
	
	-- Reposition minimap tooltip 
	local tooltip = self:GetMinimapTooltip()

	for patch,path in pairs(layout.BlipTextures) do 
		self:SetMinimapBlips(path, patch)
	end
	self:SetMinimapScale(layout.BlipScale or 1)

	-- Minimap Buttons
	----------------------------------------------------
	-- Only allow these when MBB is loaded. 
	self:SetMinimapAllowAddonButtons(self.MBB)

	-- Minimap Compass
	self:SetMinimapCompassEnabled(true)
	self:SetMinimapCompassText(unpack(layout.CompassTexts)) 
	self:SetMinimapCompassTextFontObject(layout.CompassFont) 
	self:SetMinimapCompassTextColor(unpack(layout.CompassColor)) 
	self:SetMinimapCompassRadiusInset(layout.CompassRadiusInset) 
	
	-- Background
	local mapBackdrop = Handler:CreateBackdropTexture()
	mapBackdrop:SetDrawLayer("BACKGROUND")
	mapBackdrop:SetAllPoints()
	mapBackdrop:SetTexture(layout.MapBackdropTexture)
	mapBackdrop:SetVertexColor(unpack(layout.MapBackdropColor))

	-- Overlay
	local mapOverlay = Handler:CreateContentTexture()
	mapOverlay:SetDrawLayer("BORDER")
	mapOverlay:SetAllPoints()
	mapOverlay:SetTexture(layout.MapOverlayTexture)
	mapOverlay:SetVertexColor(unpack(layout.MapOverlayColor))
	
	-- Border
	local border = Handler:CreateOverlayTexture()
	border:SetDrawLayer("BACKGROUND")
	border:SetTexture(layout.MapBorderTexture)
	border:SetSize(unpack(layout.MapBorderSize))
	border:SetVertexColor(unpack(layout.MapBorderColor))
	border:SetPoint(unpack(layout.MapBorderPlace))
	Handler.Border = border

	-- Mail
	local mail = Handler:CreateOverlayFrame()
	mail:SetSize(unpack(layout.MailSize)) 
	mail:Place(unpack(layout.MailPlace)) 

	local icon = mail:CreateTexture()
	icon:SetTexture(layout.MailTexture)
	icon:SetDrawLayer(unpack(layout.MailTextureDrawLayer))
	icon:SetPoint(unpack(layout.MailTexturePlace))
	icon:SetSize(unpack(layout.MailTextureSize)) 
	icon:SetRotation(layout.MailTextureRotation)
	Handler.Mail = mail 

	-- Clock 
	local clockFrame = Handler:CreateBorderFrame("Button")
	Handler.ClockFrame = clockFrame

	local clock = Handler:CreateFontString()
	clock:SetPoint(unpack(layout.ClockPlace)) 
	clock:SetDrawLayer("OVERLAY")
	clock:SetJustifyH("RIGHT")
	clock:SetJustifyV("BOTTOM")
	clock:SetFontObject(layout.ClockFont)
	clock:SetTextColor(unpack(layout.ClockColor))
	clock.useStandardTime = db.useStandardTime -- standard (12-hour) or military (24-hour) time
	clock.useServerTime = db.useServerTime -- realm time or local time
	clock.showSeconds = false -- show seconds in the clock
	clock.OverrideValue = layout.Clock_OverrideValue

	-- Make the clock clickable to change time settings 
	clockFrame:SetAllPoints(clock)
	clockFrame:SetScript("OnEnter", Time_OnEnter)
	clockFrame:SetScript("OnLeave", Time_OnLeave)
	clockFrame:SetScript("OnClick", Time_OnClick)

	-- Register all buttons separately, as "AnyUp" doesn't include the middle button!
	clockFrame:RegisterForClicks("RightButtonUp", "LeftButtonUp", "MiddleButtonUp")
	clockFrame.clock = clock
	clockFrame._owner = Handler

	clock:SetParent(clockFrame)

	Handler.Clock = clock

	-- Zone Information
	local zoneFrame = Handler:CreateBorderFrame()
	Handler.ZoneFrame = zoneFrame

	local zone = zoneFrame:CreateFontString()
	zone:SetPoint(layout.ZonePlaceFunc(Handler)) 
	zone:SetDrawLayer("OVERLAY")
	zone:SetJustifyH("RIGHT")
	zone:SetJustifyV("BOTTOM")
	zone:SetFontObject(layout.ZoneFont)
	zone:SetAlpha(layout.ZoneAlpha or 1)
	zone.colorPvP = true -- color zone names according to their PvP type 
	zone.colorcolorDifficulty = true -- color instance names according to their difficulty

	-- Strap the frame to the text
	zoneFrame:SetAllPoints(zone)
	zoneFrame:SetScript("OnEnter", Zone_OnEnter)
	zoneFrame:SetScript("OnLeave", Zone_OnLeave)
	Handler.Zone = zone	

	-- Coordinates
	local coordinates = Handler:CreateBorderText()
	coordinates:SetPoint(unpack(layout.CoordinatePlace)) 
	coordinates:SetDrawLayer("OVERLAY")
	coordinates:SetJustifyH("CENTER")
	coordinates:SetJustifyV("BOTTOM")
	coordinates:SetFontObject(layout.CoordinateFont)
	coordinates:SetTextColor(unpack(layout.CoordinateColor)) 
	coordinates.OverrideValue = layout.Coordinates_OverrideValue
	Handler.Coordinates = coordinates
		
	-- Performance Information
	local performanceFrame = Handler:CreateBorderFrame()
	performanceFrame._owner = Handler
	Handler.PerformanceFrame = performanceFrame

	local framerate = performanceFrame:CreateFontString()
	framerate:SetDrawLayer("OVERLAY")
	framerate:SetJustifyH("RIGHT")
	framerate:SetJustifyV("BOTTOM")
	framerate:SetFontObject(layout.FrameRateFont)
	framerate:SetTextColor(unpack(layout.FrameRateColor))
	framerate.OverrideValue = layout.FrameRate_OverrideValue

	Handler.FrameRate = framerate

	local latency = performanceFrame:CreateFontString()
	latency:SetDrawLayer("OVERLAY")
	latency:SetJustifyH("CENTER")
	latency:SetJustifyV("BOTTOM")
	latency:SetFontObject(layout.LatencyFont)
	latency:SetTextColor(unpack(layout.LatencyColor))
	latency.OverrideValue = layout.Latency_OverrideValue

	Handler.Latency = latency
	
	-- Strap the frame to the text
	performanceFrame:SetScript("OnEnter", Performance_OnEnter)
	performanceFrame:SetScript("OnLeave", Performance_OnLeave)
	
	framerate:Place(layout.FrameRatePlaceFunc(Handler)) 
	latency:Place(layout.LatencyPlaceFunc(Handler)) 

	layout.PerformanceFramePlaceAdvancedFunc(performanceFrame, Handler)

	-- Ring frame
	local ringFrame = Handler:CreateOverlayFrame()
	ringFrame:Hide()
	ringFrame:SetAllPoints() -- set it to cover the map
	ringFrame:EnableMouse(true) -- make sure minimap blips and their tooltips don't punch through
	ringFrame:SetScript("OnEnter", RingFrame_OnEnter)
	ringFrame:SetScript("OnLeave", RingFrame_OnLeave)

	ringFrame:HookScript("OnShow", function() 
		local compassFrame = Wheel("LibMinimap"):GetCompassFrame()
		if (compassFrame) then 
			compassFrame.supressCompass = true
		end 
	end)

	ringFrame:HookScript("OnHide", function() 
		local compassFrame = Wheel("LibMinimap"):GetCompassFrame()
		if compassFrame then 
			compassFrame.supressCompass = nil
		end 
	end)

	-- Wait with this until now to trigger compass visibility changes
	ringFrame:SetShown(db.stickyBars) 

	-- ring frame backdrops
	local ringFrameBg = ringFrame:CreateTexture()
	ringFrameBg:SetPoint(unpack(layout.RingFrameBackdropPlace))
	ringFrameBg:SetSize(unpack(layout.RingFrameBackdropSize))  
	ringFrameBg:SetDrawLayer(unpack(layout.RingFrameBackdropDrawLayer))
	ringFrameBg:SetTexture(layout.RingFrameBackdropTexture)
	ringFrameBg:SetVertexColor(unpack(layout.RingFrameBackdropColor))
	ringFrame.Bg = ringFrameBg

	-- Toggle button for ring frame
	local toggle = Handler:CreateOverlayFrame()
	toggle:SetFrameLevel(toggle:GetFrameLevel() + 10) -- need this above the ring frame and the rings
	toggle:SetPoint("CENTER", Handler, "BOTTOM", 2, -6)
	toggle:SetSize(unpack(layout.ToggleSize))
	toggle:EnableMouse(true)
	toggle:SetScript("OnEnter", Toggle_OnEnter)
	toggle:SetScript("OnLeave", Toggle_OnLeave)
	toggle:SetScript("OnMouseUp", Toggle_OnMouseUp)
	toggle._owner = Handler
	ringFrame._owner = toggle
	toggle.Frame = ringFrame

	local toggleBackdrop = toggle:CreateTexture()
	toggleBackdrop:SetDrawLayer("BACKGROUND")
	toggleBackdrop:SetSize(unpack(layout.ToggleBackdropSize))
	toggleBackdrop:SetPoint("CENTER", 0, 0)
	toggleBackdrop:SetTexture(layout.ToggleBackdropTexture)
	toggleBackdrop:SetVertexColor(unpack(layout.ToggleBackdropColor))

	Handler.Toggle = toggle
	
	-- outer ring
	local ring1 = ringFrame:CreateSpinBar()
	ring1:SetPoint(unpack(layout.OuterRingPlace))
	ring1:SetSize(unpack(layout.OuterRingSize)) 
	ring1:SetSparkOffset(layout.OuterRingSparkOffset)
	ring1:SetSparkFlash(unpack(layout.OuterRingSparkFlash))
	ring1:SetSparkBlendMode(layout.OuterRingSparkBlendMode)
	ring1:SetClockwise(layout.OuterRingClockwise) 
	ring1:SetDegreeOffset(layout.OuterRingDegreeOffset) 
	ring1:SetDegreeSpan(layout.OuterRingDegreeSpan)
	ring1.showSpark = layout.OuterRingShowSpark 
	ring1.colorXP = layout.OuterRingColorXP
	ring1.colorPower = layout.OuterRingColorPower 
	ring1.colorStanding = layout.OuterRingColorStanding 
	ring1.colorValue = layout.OuterRingColorValue 
	ring1.backdropMultiplier = layout.OuterRingBackdropMultiplier 
	ring1.sparkMultiplier = layout.OuterRingSparkMultiplier

	-- outer ring value text
	local ring1Value = ring1:CreateFontString()
	ring1Value:SetPoint(unpack(layout.OuterRingValuePlace))
	ring1Value:SetJustifyH(layout.OuterRingValueJustifyH)
	ring1Value:SetJustifyV(layout.OuterRingValueJustifyV)
	ring1Value:SetFontObject(layout.OuterRingValueFont)
	ring1Value.showDeficit = layout.OuterRingValueShowDeficit 
	ring1.Value = ring1Value

	-- outer ring value description text
	local ring1ValueDescription = ring1:CreateFontString()
	ring1ValueDescription:SetPoint(unpack(layout.OuterRingValueDescriptionPlace))
	ring1ValueDescription:SetWidth(layout.OuterRingValueDescriptionWidth)
	ring1ValueDescription:SetTextColor(unpack(layout.OuterRingValueDescriptionColor))
	ring1ValueDescription:SetJustifyH(layout.OuterRingValueDescriptionJustifyH)
	ring1ValueDescription:SetJustifyV(layout.OuterRingValueDescriptionJustifyV)
	ring1ValueDescription:SetFontObject(layout.OuterRingValueDescriptionFont)
	ring1ValueDescription:SetIndentedWordWrap(false)
	ring1ValueDescription:SetWordWrap(true)
	ring1ValueDescription:SetNonSpaceWrap(false)
	ring1.Value.Description = ring1ValueDescription

	local outerPercent = toggle:CreateFontString()
	outerPercent:SetDrawLayer("OVERLAY")
	outerPercent:SetJustifyH("CENTER")
	outerPercent:SetJustifyV("MIDDLE")
	outerPercent:SetFontObject(layout.OuterRingValuePercentFont)
	outerPercent:SetShadowOffset(0, 0)
	outerPercent:SetShadowColor(0, 0, 0, 0)
	outerPercent:SetPoint("CENTER", 1, -1)
	ring1.Value.Percent = outerPercent

	-- inner ring 
	local ring2 = ringFrame:CreateSpinBar()
	ring2:SetPoint(unpack(layout.InnerRingPlace))
	ring2:SetSize(unpack(layout.InnerRingSize)) 
	ring2:SetSparkSize(unpack(layout.InnerRingSparkSize))
	ring2:SetSparkInset(layout.InnerRingSparkInset)
	ring2:SetSparkOffset(layout.InnerRingSparkOffset)
	ring2:SetSparkFlash(unpack(layout.InnerRingSparkFlash))
	ring2:SetSparkBlendMode(layout.InnerRingSparkBlendMode)
	ring2:SetClockwise(layout.InnerRingClockwise) 
	ring2:SetDegreeOffset(layout.InnerRingDegreeOffset) 
	ring2:SetDegreeSpan(layout.InnerRingDegreeSpan)
	ring2:SetStatusBarTexture(layout.InnerRingBarTexture)
	ring2.showSpark = layout.InnerRingShowSpark 
	ring2.colorXP = layout.InnerRingColorXP
	ring2.colorPower = layout.InnerRingColorPower 
	ring2.colorStanding = layout.InnerRingColorStanding 
	ring2.colorValue = layout.InnerRingColorValue 
	ring2.backdropMultiplier = layout.InnerRingBackdropMultiplier 
	ring2.sparkMultiplier = layout.InnerRingSparkMultiplier

	-- inner ring value text
	local ring2Value = ring2:CreateFontString()
	ring2Value:SetPoint("BOTTOM", ringFrameBg, "CENTER", 0, 2)
	ring2Value:SetJustifyH("CENTER")
	ring2Value:SetJustifyV("TOP")
	ring2Value:SetFontObject(layout.InnerRingValueFont)
	ring2Value.showDeficit = true  
	ring2.Value = ring2Value

	local innerPercent = ringFrame:CreateFontString()
	innerPercent:SetDrawLayer("OVERLAY")
	innerPercent:SetJustifyH("CENTER")
	innerPercent:SetJustifyV("MIDDLE")
	innerPercent:SetFontObject(layout.InnerRingValuePercentFont)
	innerPercent:SetShadowOffset(0, 0)
	innerPercent:SetShadowColor(0, 0, 0, 0)
	innerPercent:SetPoint("CENTER", ringFrameBg, "CENTER", 2, -64)
	ring2.Value.Percent = innerPercent

	-- Store the bars locally
	Spinner[1] = ring1
	Spinner[2] = ring2

	-- Tracking button
	local tracking = Handler:CreateOverlayFrame("Button")
	tracking:SetFrameLevel(tracking:GetFrameLevel() + 10) -- need this above the ring frame and the rings
	tracking:SetPoint(unpack(layout.TrackingButtonPlace))
	tracking:SetSize(unpack(layout.TrackingButtonSize))
	tracking:EnableMouse(true)
	tracking:RegisterForClicks("AnyUp")
	tracking._owner = Handler

	local trackingBackdrop = tracking:CreateTexture()
	trackingBackdrop:SetDrawLayer("BACKGROUND")
	trackingBackdrop:SetSize(unpack(layout.TrackingButtonBackdropSize))
	trackingBackdrop:SetPoint("CENTER", 0, 0)
	trackingBackdrop:SetTexture(layout.TrackingButtonBackdropTexture)
	trackingBackdrop:SetVertexColor(unpack(layout.TrackingButtonBackdropColor))

	local trackingTextureBg = tracking:CreateTexture()
	trackingTextureBg:SetDrawLayer("ARTWORK", 0)
	trackingTextureBg:SetPoint("CENTER")
	trackingTextureBg:SetSize(unpack(layout.TrackingButtonIconBgSize))
	trackingTextureBg:SetTexture(layout.TrackingButtonIconBgTexture)
	trackingTextureBg:SetVertexColor(0,0,0,1)

	local trackingTexture = tracking:CreateTexture()
	trackingTexture:SetDrawLayer("ARTWORK", 1)
	trackingTexture:SetPoint("CENTER")
	trackingTexture:SetSize(unpack(layout.TrackingButtonIconSize))
	trackingTexture:SetMask(layout.TrackingButtonIconMask)
	trackingTexture:SetTexture(GetTrackingTexture())
	tracking.Texture = trackingTexture

	local trackingMenuFrame = CreateFrame("Frame", ADDON.."MinimapTrackingButtonMenu", tracking, "UIDropDownMenuTemplate")

	tracking.ShowMenu = function(self)
		local hasTracking
		local trackingMenu = { { text = "Select Tracking", isTitle = true } }
		for _,spellID in ipairs({
			 1494, --Track Beasts
			19883, --Track Humanoids
			19884, --Track Undead
			19885, --Track Hidden
			19880, --Track Elementals
			19878, --Track Demons
			19882, --Track Giants
			19879, --Track Dragonkin
				5225, --Track Humanoids: Druid
				5500, --Sense Demons
				5502, --Sense Undead
				2383, --Find Herbs
				2580, --Find Minerals
				2481  --Find Treasure
		}) do
			if (IsPlayerSpell(spellID)) then
				hasTracking = true
				local spellName = GetSpellInfo(spellID)
				local spellTexture = GetSpellTexture(spellID)
				table_insert(trackingMenu, {
					text = spellName,
					icon = spellTexture,
					func = function() CastSpellByID(spellID) end
				})
			end
		end
		if hasTracking then 
			EasyMenu(trackingMenu, trackingMenuFrame, "cursor", 0 , 0, "MENU")
		end 
	end

	tracking:SetScript("OnClick", Tracking_OnClick)
	tracking:SetScript("OnEnter", Tracking_OnEnter)
	tracking:SetScript("OnLeave", Tracking_OnLeave)

	Minimap:SetScript("OnMouseUp", function(_, button)
		if (button == "RightButton") then
			tracking:ShowMenu()
		else
			Minimap_OnClick(Minimap)
		end
	end)

	self:RegisterEvent("UNIT_AURA", "OnEvent")

	Handler.Tracking = tracking

	local BGFrame = MiniMapBattlefieldFrame
	local BGFrameBorder = MiniMapBattlefieldBorder
	local BGIcon = MiniMapBattlefieldIcon

	if BGFrame then
		local button = Handler:CreateOverlayFrame()
		button:SetFrameLevel(button:GetFrameLevel() + 10) 
		button:Place(unpack(layout.BattleGroundEyePlace))
		button:SetSize(unpack(layout.BattleGroundEyeSize))

		local point, x, y = unpack(layout.BattleGroundEyePlace)

		-- For some reason any other points 
		BGFrame:ClearAllPoints()
		BGFrame:SetPoint("TOPRIGHT", Minimap, -4, -2)
		BGFrame:SetHitRectInsets(-8, -8, -8, -8)
		BGFrameBorder:Hide()
		BGIcon:SetAlpha(0)
	
		local eye = button:CreateTexture()
		eye:SetDrawLayer("OVERLAY", 1)
		eye:SetPoint("CENTER", 0, 0)
		eye:SetSize(unpack(layout.BattleGroundEyeSize))
		eye:SetTexture(layout.BattleGroundEyeTexture)
		eye:SetVertexColor(unpack(layout.BattleGroundEyeColor))
		eye:SetShown(BGFrame:IsShown())

		tracking:Place(unpack(BGFrame:IsShown() and layout.TrackingButtonPlaceAlternate or layout.TrackingButtonPlace))
		BGFrame:HookScript("OnShow", function() 
			eye:Show()
			tracking:Place(unpack(layout.TrackingButtonPlaceAlternate))
		end)
		BGFrame:HookScript("OnHide", function() 
			eye:Hide()
			tracking:Place(unpack(layout.TrackingButtonPlace))
		end)
	end

end 

-- Set up the MBB (MinimapButtonBag) integration
Module.SetUpMBB = function(self)
	local layout = self.layout

	local Handler = self:GetMinimapHandler()

	local button = Handler:CreateOverlayFrame()
	button:SetFrameLevel(button:GetFrameLevel() + 10) 
	button:Place(unpack(layout.MBBPlace))
	button:SetSize(unpack(layout.MBBSize))
	button:SetFrameStrata("MEDIUM") 

	local mbbFrame = _G.MBB_MinimapButtonFrame
	mbbFrame:SetParent(button)
	mbbFrame:RegisterForDrag()
	mbbFrame:SetSize(unpack(layout.MBBSize)) 
	mbbFrame:ClearAllPoints()
	mbbFrame:SetFrameStrata("MEDIUM") 
	mbbFrame:SetPoint("CENTER", 0, 0)
	mbbFrame:SetHighlightTexture("") 
	mbbFrame:DisableDrawLayer("OVERLAY") 

	mbbFrame.ClearAllPoints = function() end
	mbbFrame.SetPoint = function() end
	mbbFrame.SetAllPoints = function() end

	local mbbIcon = _G.MBB_MinimapButtonFrame_Texture
	mbbIcon:ClearAllPoints()
	mbbIcon:SetPoint("CENTER", 0, 0)
	mbbIcon:SetSize(unpack(layout.MBBSize))
	mbbIcon:SetTexture(layout.MBBTexture)
	mbbIcon:SetTexCoord(0,1,0,1)
	mbbIcon:SetAlpha(.85)
	
	local down, over
	local setalpha = function()
		if (down and over) then
			mbbIcon:SetAlpha(1)
		elseif (down or over) then
			mbbIcon:SetAlpha(.95)
		else
			mbbIcon:SetAlpha(.85)
		end
	end

	mbbFrame:SetScript("OnMouseDown", function(self) 
		down = true
		setalpha()
	end)

	mbbFrame:SetScript("OnMouseUp", function(self) 
		down = false
		setalpha()
	end)

	mbbFrame:SetScript("OnEnter", function(self) 
		over = true
		_G.MBB_ShowTimeout = -1

		local tooltip = Module:GetMinimapTooltip()
		tooltip:SetDefaultAnchor(self)
		tooltip:SetMaximumWidth(320)
		tooltip:AddLine("MinimapButtonBag v" .. MBB_Version)
		tooltip:AddLine(MBB_TOOLTIP1, 0, 1, 0, true)
		tooltip:Show()

		setalpha()
	end)

	mbbFrame:SetScript("OnLeave", function(self) 
		over = false
		_G.MBB_ShowTimeout = 0

		local tooltip = Module:GetMinimapTooltip()
		tooltip:Hide()

		setalpha()
	end)
end

-- Perform and initial update of all elements, 
-- as this is not done automatically by the back-end.
Module.EnableAllElements = function(self)
	local Handler = self:GetMinimapHandler()
	Handler:EnableAllElements()
end 

----------------------------------------------------
-- Map Post Updates
----------------------------------------------------
-- Set the mask texture
Module.UpdateMinimapMask = function(self)
	-- Transparency in these textures also affect the indoors opacity 
	-- of the minimap, something changing the map alpha directly does not. 
	self:SetMinimapMaskTexture(self.layout.MaskTexture)
end 

-- Set the size and position 
-- Can't change this in combat, will cause taint!
Module.UpdateMinimapSize = function(self)
	if InCombatLockdown() then 
		return self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	end

	local layout = self.layout

	self:SetMinimapSize(unpack(layout.Size)) 
	self:SetMinimapPosition(unpack(layout.Place)) 
end 

Module.UpdateBars = function(self, event, ...)
	local layout = self.layout

	local Handler = self:GetMinimapHandler()
	local hasXP = self:PlayerHasXP()
	local hasRep = self:PlayerHasRep()

	local first, second 
	if (hasXP) then 
		first = "XP"
		second = hasRep and "Reputation"
	elseif (hasRep) then 
		first = "Reputation"
	end 

	if (first or second) then
		if (not Handler.Toggle:IsShown()) then  
			Handler.Toggle:Show()
		end

		-- Dual bars
		if (first and second) then

			-- Setup the bars and backdrops for dual bar mode
			if self.spinnerMode ~= "Dual" then 

				-- Set the backdrop to the two bar backdrop
				Handler.Toggle.Frame.Bg:SetTexture(layout.RingFrameBackdropDoubleTexture)

				-- Update the look of the outer spinner
				Spinner[1]:SetStatusBarTexture(layout.RingFrameOuterRingTexture)
				Spinner[1]:SetSparkSize(unpack(layout.RingFrameOuterRingSparkSize))
				Spinner[1]:SetSparkInset(unpack(layout.RingFrameOuterRingSparkInset))

				layout.RingFrameOuterRingValueFunc(Spinner[1].Value, Handler)

				Spinner[1].PostUpdate = nil
			end

			-- Assign the spinners to the elements
			if (self.spinner1 ~= first) then 

				-- Disable the old element 
				self:DisableMinimapElement(first)

				-- Link the correct spinner
				Handler[first] = Spinner[1]

				-- Assign the correct post updates
				if (first == "XP") then 
					Handler[first].OverrideValue = layout.XP_OverrideValue
	
				elseif (first == "Reputation") then 
					Handler[first].OverrideValue = layout.Rep_OverrideValue
				end 

				-- Enable the updated element 
				self:EnableMinimapElement(first)

				-- Run an update
				Handler[first]:ForceUpdate()
			end

			if (self.spinner2 ~= second) then 

				-- Disable the old element 
				self:DisableMinimapElement(second)

				-- Link the correct spinner
				Handler[second] = Spinner[2]

				-- Assign the correct post updates
				if (second == "XP") then 
					Handler[second].OverrideValue = layout.XP_OverrideValue
	
				elseif (second == "Reputation") then 
					Handler[second].OverrideValue = layout.Rep_OverrideValue
				end 

				-- Enable the updated element 
				self:EnableMinimapElement(second)

				-- Run an update
				Handler[second]:ForceUpdate()
			end
			-- Store the current modes
			self.spinnerMode = "Dual"
			self.spinner1 = first
			self.spinner2 = second

		-- Single bar
		else

			-- Setup the bars and backdrops for single bar mode
			if (self.spinnerMode ~= "Single") then 

				-- Set the backdrop to the single thick bar backdrop
				Handler.Toggle.Frame.Bg:SetTexture(layout.RingFrameBackdropTexture)

				-- Update the look of the outer spinner to the big single bar look
				Spinner[1]:SetStatusBarTexture(layout.RingFrameSingleRingTexture)
				Spinner[1]:SetSparkSize(unpack(layout.RingFrameSingleRingSparkSize))
				Spinner[1]:SetSparkInset(unpack(layout.RingFrameSingleRingSparkInset))

				layout.RingFrameSingleRingValueFunc(Spinner[1].Value, Handler)

				-- Hide 2nd spinner values
				Spinner[2].Value:SetText("")
				Spinner[2].Value.Percent:SetText("")
			end 		

			-- Disable any previously active secondary element
			if self.spinner2 and Handler[self.spinner2] then 
				self:DisableMinimapElement(self.spinner2)
				Handler[self.spinner2] = nil
			end 

			-- Update the element if needed
			if (self.spinner1 ~= first) then 

				-- Update pointers and callbacks to the active element
				Handler[first] = Spinner[1]
				Handler[first].OverrideValue = hasXP and layout.XP_OverrideValue or hasRep and layout.Rep_OverrideValue
				Handler[first].PostUpdate = hasXP and XP_PostUpdate or hasRep and Rep_PostUpdate

				-- Enable the active element
				self:EnableMinimapElement(first)

				-- Make sure descriptions are updated
				Handler[first].Value.Description:Show()

				-- Update the visible element
				Handler[first]:ForceUpdate()
			end 
			-- If the second spinner is still shown, hide it!
			if (Spinner[2]:IsShown()) then 
				Spinner[2]:Hide()
			end 
			-- Store the current modes
			self.spinnerMode = "Single"
			self.spinner1 = first
			self.spinner2 = nil
		end 

		-- Post update the frame, could be sticky
		Toggle_UpdateFrame(Handler.Toggle)
	else 
		Handler.Toggle:Hide()
		Handler.Toggle.Frame:Hide()
	end 
end

Module.UpdateTracking = function(self)
	local Handler = self:GetMinimapHandler()
	local icon = GetTrackingTexture()
	if (icon) then
		Handler.Tracking.Texture:SetTexture(icon)
		Handler.Tracking:Show()
	else
		Handler.Tracking:Hide()
	end
end

----------------------------------------------------
-- Module Initialization
----------------------------------------------------
Module.OnEvent = function(self, event, ...)
	if (event == "PLAYER_LEVEL_UP") then 
		local level = ...
		if (level and (level ~= LEVEL)) then
			LEVEL = level
		else
			local level = UnitLevel("player")
			if (not LEVEL) or (LEVEL < level) then
				LEVEL = level
			end
		end
	elseif (event == "PLAYER_REGEN_ENABLED") then 
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		self:UpdateMinimapSize()
		return 
	elseif (event == "PLAYER_ENTERING_WORLD") or (event == "VARIABLES_LOADED") then 
		self:UpdateMinimapSize()
		self:UpdateMinimapMask()
		self:UpdateTracking()
	elseif (event == "ADDON_LOADED") then 
		local addon = ...
		if (addon == "MBB") then 
			self:SetUpMBB()
			self:UnregisterEvent("ADDON_LOADED", "OnEvent")
			return 
		end 
	elseif (event == "UNIT_AURA") then 
		self:UpdateTracking()
	end
	self:UpdateBars()
end 

Module.OnInit = function(self)
	self.db = GetConfig(self:GetName())
	self.layout = GetLayout(self:GetName())
	self.MBB = self:IsAddOnEnabled("MBB")
	
	self:SetUpMinimap()

	if (self.MBB) then 
		if (IsAddOnLoaded("MBB")) then 
			self:SetUpMBB()
		else 
			self:RegisterEvent("ADDON_LOADED", "OnEvent")
		end 
	end 

	self:UpdateBars()
end 

Module.OnEnable = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("VARIABLES_LOADED", "OnEvent") -- size and mask must be updated after this
	self:RegisterEvent("PLAYER_ALIVE", "OnEvent")
	self:RegisterEvent("PLAYER_FLAGS_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_LEVEL_UP", "OnEvent")
	self:RegisterEvent("PLAYER_XP_UPDATE", "OnEvent")
	self:RegisterEvent("UPDATE_FACTION", "OnEvent")
	self:EnableAllElements()
end 
