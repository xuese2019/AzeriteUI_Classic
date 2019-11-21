--[[--

The purpose of this file is to create general but
addon specific styling methods for all the unitframes.

This file is loaded after other general user databases, 
but prior to loading any of the module config files.
Meaning we can reference the general databases with certainty, 
but any layout data will have to be passed as function arguments.

TODO:
Remove most of the callbacks, and put them in the stylesheet file.

--]]--

local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

-- Primary Units
local UnitFramePlayer = Core:NewModule("UnitFramePlayer", "LibEvent", "LibUnitFrame", "LibFrame")
local UnitFramePlayerHUD = Core:NewModule("UnitFramePlayerHUD", "LibDB", "LibEvent", "LibUnitFrame", "LibFrame")
local UnitFrameTarget = Core:NewModule("UnitFrameTarget", "LibEvent", "LibUnitFrame", "LibSound")

-- Secondary Units
local UnitFramePet = Core:NewModule("UnitFramePet", "LibUnitFrame", "LibFrame")
local UnitFrameToT = Core:NewModule("UnitFrameToT", "LibUnitFrame")

-- Grouped Units
local UnitFrameBoss = Core:NewModule("UnitFrameBoss", "LibUnitFrame")
local UnitFrameParty = Core:NewModule("UnitFrameParty", "LibDB", "LibFrame", "LibUnitFrame")
local UnitFrameRaid = Core:NewModule("UnitFrameRaid", "LibDB", "LibFrame", "LibUnitFrame", "LibBlizzard")

-- Keep these local
local UnitStyles = {} 

-- Lua API
local date = date
local math_floor = math.floor
local math_pi = math.pi
local select = select
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match
local string_split = string.split
local tonumber = tonumber
local tostring = tostring
local unpack = unpack

-- WoW API
local RegisterAttributeDriver = RegisterAttributeDriver
local UnitClass = UnitClass
local UnitClassification = UnitClassification
local UnitCreatureType = UnitCreatureType
local UnitExists = UnitExists
local UnitIsEnemy = UnitIsEnemy
local UnitIsFriend = UnitIsFriend
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitLevel = UnitLevel

-- Private API
local Colors = Private.Colors
local GetConfig = Private.GetConfig
local GetDefaults = Private.GetDefaults
local GetLayout = Private.GetLayout

-- WoW Strings
local S_AFK = AFK
local S_DEAD = DEAD
local S_PLAYER_OFFLINE = PLAYER_OFFLINE

-- WoW Textures
local EDGE_NORMAL_TEXTURE = [[Interface\Cooldown\edge]]
local BLING_TEXTURE = [[Interface\Cooldown\star4]]

-- Player data
local _,PlayerClass = UnitClass("player")
local _,PlayerLevel = UnitLevel("player")

-----------------------------------------------------------
-- Secure Snippets
-----------------------------------------------------------
local SECURE = {

	-- Called on the group headers
	FrameTable_Create = [=[ 
		Frames = table.new(); 
	]=],
	FrameTable_InsertCurrentFrame = [=[ 
		local frame = self:GetFrameRef("CurrentFrame"); 
		table.insert(Frames, frame); 
	]=],

	-- Called on the HUD callback frame
	HUD_SecureCallback = [=[
		if name then 
			name = string.lower(name); 
		end 
		if (name == "change-enablecast") then 
			local owner = self:GetFrameRef("Owner"); 
			self:SetAttribute("enableCast", value); 
			if (value) then 
				owner:CallMethod("EnableElement", "Cast"); 
				owner:CallMethod("UpdateAllElements"); 
			else 
				owner:CallMethod("DisableElement", "Cast"); 
			end 
		elseif (name == "change-enableclasspower") then 
			local owner = self:GetFrameRef("Owner"); 
			self:SetAttribute("enableClassPower", value); 
			local forceDisable = self:GetAttribute("forceDisableClassPower"); 
			if (value) and (not forceDisable) then 
				owner:CallMethod("EnableElement", "ClassPower"); 
				owner:CallMethod("UpdateAllElements"); 
			else 
				owner:CallMethod("DisableElement", "ClassPower"); 
			end 
		end 
	]=],
	
	-- Called on the party group header
	Party_OnAttribute = [=[
		if (name == "state-vis") then
			if (value == "show") then 
				if (not self:IsShown()) then 
					self:Show(); 
				end 
			elseif (value == "hide") then 
				if (self:IsShown()) then 
					self:Hide(); 
				end 
			end 
		end
	]=], 

	-- Called on the party callback frame
	Party_SecureCallback = [=[
		if name then 
			name = string.lower(name); 
		end 
		if (name == "change-enablepartyframes") then 
			self:SetAttribute("enablePartyFrames", value); 
			local visibilityFrame = self:GetFrameRef("Owner");
			UnregisterAttributeDriver(visibilityFrame, "state-vis"); 
			if value then 
				RegisterAttributeDriver(visibilityFrame, "state-vis", "%s"); 
			else 
				RegisterAttributeDriver(visibilityFrame, "state-vis", "hide"); 
			end 
		elseif (name == "change-enablehealermode") then 

			local Owner = self:GetFrameRef("Owner"); 

			-- set flag for healer mode 
			Owner:SetAttribute("inHealerMode", value); 

			-- Update the layout 
			Owner:RunAttribute("sortFrames"); 
		end 
	]=],

	-- Called on the party frame group header
	Party_SortFrames = [=[
		local inHealerMode = self:GetAttribute("inHealerMode"); 

		local anchorPoint; 
		local anchorFrame; 
		local growthX; 
		local growthY; 

		if (not inHealerMode) then 
			anchorPoint = "%s"; 
			anchorFrame = self; 
			growthX = %.0f;
			growthY = %.0f; 
		else
			anchorPoint = "%s"; 
			anchorFrame = self:GetFrameRef("HealerModeAnchor"); 
			growthX = %.0f;
			growthY = %.0f; 
		end

		-- Iterate the frames
		for id,frame in ipairs(Frames) do 
			frame:ClearAllPoints(); 
			frame:SetPoint(anchorPoint, anchorFrame, anchorPoint, growthX*(id-1), growthY*(id-1)); 
		end 

	]=],

	-- Called on the raid frame group header
	Raid_OnAttribute = [=[
		if (name == "state-vis") then
			if (value == "show") then 
				if (not self:IsShown()) then 
					self:Show(); 
				end 
			elseif (value == "hide") then 
				if (self:IsShown()) then 
					self:Hide(); 
				end 
			end 

		elseif (name == "state-layout") then
			local groupLayout = self:GetAttribute("groupLayout"); 
			if (groupLayout ~= value) then 

				-- Store the new layout setting
				self:SetAttribute("groupLayout", value);

				-- Update the layout 
				self:RunAttribute("sortFrames"); 
			end 
		end
	]=],

	-- Called on the secure updater 
	Raid_SecureCallback = [=[
		if name then 
			name = string.lower(name); 
		end 
		if (name == "change-enableraidframes") then 
			self:SetAttribute("enableRaidFrames", value); 
			local visibilityFrame = self:GetFrameRef("Owner");
			UnregisterAttributeDriver(visibilityFrame, "state-vis"); 
			if value then 
				RegisterAttributeDriver(visibilityFrame, "state-vis", "%s"); 
			else 
				RegisterAttributeDriver(visibilityFrame, "state-vis", "hide"); 
			end 
		elseif (name == "change-enablehealermode") then 

			local Owner = self:GetFrameRef("Owner"); 

			-- set flag for healer mode 
			Owner:SetAttribute("inHealerMode", value); 

			-- Update the layout 
			Owner:RunAttribute("sortFrames"); 
		end 
	]=], 

	-- Called on the raid frame group header
	Raid_SortFrames = [=[
		local groupLayout = self:GetAttribute("groupLayout"); 
		local inHealerMode = self:GetAttribute("inHealerMode"); 

		local anchor; 
		local colSize; 
		local growthX;
		local growthY;
		local growthYHealerMode;
		local groupGrowthX;
		local groupGrowthY; 
		local groupGrowthYHealerMode; 
		local groupCols;
		local groupRows;
		local groupAnchor; 
		local groupAnchorHealerMode; 

		if (groupLayout == "normal") then 
			colSize = %.0f;
			growthX = %.0f;
			growthY = %.0f;
			growthYHealerMode = %.0f;
			groupGrowthX = %.0f;
			groupGrowthY = %.0f;
			groupGrowthYHealerMode = %.0f;
			groupCols = %.0f;
			groupRows = %.0f;
			groupAnchor = "%s";
			groupAnchorHealerMode = "%s"; 

		elseif (groupLayout == "epic") then 
			colSize = %.0f;
			growthX = %.0f;
			growthY = %.0f;
			growthYHealerMode = %.0f;
			groupGrowthX = %.0f;
			groupGrowthY = %.0f;
			groupGrowthYHealerMode = %.0f;
			groupCols = %.0f;
			groupRows = %.0f;
			groupAnchor = "%s";
			groupAnchorHealerMode = "%s"; 
		end

		-- This should never happen: it does!
		if (not colSize) then 
			return 
		end 

		if inHealerMode then 
			anchor = self:GetFrameRef("HealerModeAnchor"); 
			growthY = growthYHealerMode; 
			groupAnchor = groupAnchorHealerMode; 
			groupGrowthY = groupGrowthYHealerMode;
		else
			anchor = self; 
		end

		-- Iterate the frames
		for id,frame in ipairs(Frames) do 

			local groupID = floor((id-1)/colSize) + 1; 
			local groupX = mod(groupID-1,groupCols) * groupGrowthX; 
			local groupY = floor((groupID-1)/groupCols) * groupGrowthY; 

			local modID = mod(id-1,colSize) + 1;
			local unitX = growthX*(modID-1) + groupX;
			local unitY = growthY*(modID-1) + groupY;

			frame:ClearAllPoints(); 
			frame:SetPoint(groupAnchor, anchor, groupAnchor, unitX, unitY); 
		end 

	]=]
}

-----------------------------------------------------------
-- Utility Functions
-----------------------------------------------------------
local short = function(value)
	value = tonumber(value)
	if (not value) then return "" end
	if (value >= 1e9) then
		return ("%.1fb"):format(value / 1e9):gsub("%.?0+([kmb])$", "%1")
	elseif value >= 1e6 then
		return ("%.1fm"):format(value / 1e6):gsub("%.?0+([kmb])$", "%1")
	elseif value >= 1e3 or value <= -1e3 then
		return ("%.1fk"):format(value / 1e3):gsub("%.?0+([kmb])$", "%1")
	else
		return tostring(value - value%1)
	end	
end

local CreateSecureCallbackFrame = function(module, owner, db, script)

	-- Create a secure proxy frame for the menu system
	local callbackFrame = module:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")

	-- Attach the module's frame to the proxy
	callbackFrame:SetFrameRef("Owner", owner)

	-- Register module db with the secure proxy
	if db then 
		for key,value in pairs(db) do 
			callbackFrame:SetAttribute(key,value)
		end 
	end

	-- Now that attributes have been defined, attach the onattribute script
	callbackFrame:SetAttribute("_onattributechanged", script)

	-- Attach a getter method for the menu to the module
	module.GetSecureUpdater = function(self) 
		return callbackFrame 
	end

	-- Return the proxy updater to the module
	return callbackFrame
end

-----------------------------------------------------------
-- Callbacks
-----------------------------------------------------------

local SmallFrame_OverrideValue = function(element, unit, min, max, disconnected, dead, tapped)
	if (min >= 1e8) then 		element.Value:SetFormattedText("%.0fm", min/1e6) 		-- 100m, 1000m, 2300m, etc
	elseif (min >= 1e6) then 	element.Value:SetFormattedText("%.1fm", min/1e6) 	-- 1.0m - 99.9m 
	elseif (min >= 1e5) then 	element.Value:SetFormattedText("%.0fk", min/1e3) 		-- 100k - 999k
	elseif (min >= 1e3) then 	element.Value:SetFormattedText("%.1fk", min/1e3) 	-- 1.0k - 99.9k
	elseif (min > 0) then 		element.Value:SetText(min) 							-- 1 - 999
	else 						element.Value:SetText("")
	end 
end 

local SmallFrame_OverrideHealthValue = function(element, unit, min, max, disconnected, dead, tapped)
	if disconnected then 
		if element.Value then 
			element.Value:SetText(S_PLAYER_OFFLINE)
		end 
	elseif dead then 
		if element.Value then 
			return element.Value:SetText(S_DEAD)
		end
	else 
		if element.Value then 
			if element.Value.showPercent and (min < max) then 
				return element.Value:SetFormattedText("%.0f%%", min/max*100 - (min/max*100)%1)
			else 
				return SmallFrame_OverrideValue(element, unit, min, max, disconnected, dead, tapped)
			end 
		end 
	end 
end 

local TinyFrame_OverrideValue = function(element, unit, min, max, disconnected, dead, tapped)
	if (min >= 1e8) then 		element.Value:SetFormattedText("%.0fm", min/1e6)  -- 100m, 1000m, 2300m, etc
	elseif (min >= 1e6) then 	element.Value:SetFormattedText("%.1fm", min/1e6)  -- 1.0m - 99.9m 
	elseif (min >= 1e5) then 	element.Value:SetFormattedText("%.0fk", min/1e3)  -- 100k - 999k
	elseif (min >= 1e3) then 	element.Value:SetFormattedText("%.1fk", min/1e3)  -- 1.0k - 99.9k
	elseif (min > 0) then 		element.Value:SetText(min) 						  -- 1 - 999
	else 						element.Value:SetText("")
	end 
end 

local TinyFrame_OverrideHealthValue = function(element, unit, min, max, disconnected, dead, tapped)
	if dead then 
		if element.Value then 
			return element.Value:SetText(S_DEAD)
		end
	elseif (UnitIsAFK(unit)) then 
		if element.Value then 
			return element.Value:SetText(S_AFK)
		end
	else 
		if element.Value then 
			if element.Value.showPercent and (min < max) then 
				return element.Value:SetFormattedText("%.0f%%", min/max*100 - (min/max*100)%1)
			else 
				return TinyFrame_OverrideValue(element, unit, min, max, disconnected, dead, tapped)
			end 
		end 
	end 
end 

local TinyFrame_OnEvent = function(self, event, unit, ...)
	if (event == "PLAYER_FLAGS_CHANGED") then 
		-- Do some trickery to instantly update the afk status, 
		-- without having to add additional events or methods to the widget. 
		if UnitIsAFK(unit) then 
			self.Health:OverrideValue(unit)
		else 
			self.Health:ForceUpdate(event, unit)
		end 
	end 
end 

local Player_OverridePowerColor = function(element, unit, min, max, powerType, powerID, disconnected, dead, tapped)
	local self = element._owner
	local layout = self.layout
	local r, g, b
	if disconnected then
		r, g, b = unpack(self.colors.disconnected)
	elseif dead then
		r, g, b = unpack(self.colors.dead)
	elseif tapped then
		r, g, b = unpack(self.colors.tapped)
	else
		if layout.PowerColorSuffix then 
			r, g, b = unpack(powerType and self.colors.power[powerType .. layout.PowerColorSuffix] or self.colors.power[powerType] or self.colors.power.UNUSED)
		else 
			r, g, b = unpack(powerType and self.colors.power[powerType] or self.colors.power.UNUSED)
		end 
	end
	element:SetStatusBarColor(r, g, b)
end 

local Player_OverrideExtraPowerColor = function(element, unit, min, max, powerType, powerID, disconnected, dead, tapped)
	local self = element._owner
	local layout = self.layout
	local r, g, b
	if disconnected then
		r, g, b = unpack(self.colors.disconnected)
	elseif dead then
		r, g, b = unpack(self.colors.dead)
	elseif tapped then
		r, g, b = unpack(self.colors.tapped)
	else
		if layout.ManaColorSuffix then 
			r, g, b = unpack(powerType and self.colors.power[powerType .. layout.ManaColorSuffix] or self.colors.power[powerType] or self.colors.power.UNUSED)
		else 
			r, g, b = unpack(powerType and self.colors.power[powerType] or self.colors.power.UNUSED)
		end 
	end
	element:SetStatusBarColor(r, g, b)
end 

local Player_PostUpdateTextures = function(self, overrideLevel)
	local layout = self.layout
	local playerLevel = overrideLevel or UnitLevel("player")
	if (playerLevel >= 60) then 
		self.Health:SetSize(unpack(layout.SeasonedHealthSize))
		self.Health:SetStatusBarTexture(layout.SeasonedHealthTexture)
		self.Health.Bg:SetTexture(layout.SeasonedHealthBackdropTexture)
		self.Health.Bg:SetVertexColor(unpack(layout.SeasonedHealthBackdropColor))
		self.Power.Fg:SetTexture(layout.SeasonedPowerForegroundTexture)
		self.Power.Fg:SetVertexColor(unpack(layout.SeasonedPowerForegroundColor))
		self.Cast:SetSize(unpack(layout.SeasonedCastSize))
		self.Cast:SetStatusBarTexture(layout.SeasonedCastTexture)
		if (self.ExtraPower) then
			self.ExtraPower.Fg:SetTexture(layout.SeasonedManaOrbTexture)
			self.ExtraPower.Fg:SetVertexColor(unpack(layout.SeasonedManaOrbColor)) 
		end 
	elseif (playerLevel >= layout.HardenedLevel) then 
		self.Health:SetSize(unpack(layout.HardenedHealthSize))
		self.Health:SetStatusBarTexture(layout.HardenedHealthTexture)
		self.Health.Bg:SetTexture(layout.HardenedHealthBackdropTexture)
		self.Health.Bg:SetVertexColor(unpack(layout.HardenedHealthBackdropColor))
		self.Power.Fg:SetTexture(layout.HardenedPowerForegroundTexture)
		self.Power.Fg:SetVertexColor(unpack(layout.HardenedPowerForegroundColor))
		self.Cast:SetSize(unpack(layout.HardenedCastSize))
		self.Cast:SetStatusBarTexture(layout.HardenedCastTexture)
		if (self.ExtraPower) then 
			self.ExtraPower.Fg:SetTexture(layout.HardenedManaOrbTexture)
			self.ExtraPower.Fg:SetVertexColor(unpack(layout.HardenedManaOrbColor)) 
		end 
	else 
		self.Health:SetSize(unpack(layout.NoviceHealthSize))
		self.Health:SetStatusBarTexture(layout.NoviceHealthTexture)
		self.Health.Bg:SetTexture(layout.NoviceHealthBackdropTexture)
		self.Health.Bg:SetVertexColor(unpack(layout.NoviceHealthBackdropColor))
		self.Power.Fg:SetTexture(layout.NovicePowerForegroundTexture)
		self.Power.Fg:SetVertexColor(unpack(layout.NovicePowerForegroundColor))
		self.Cast:SetSize(unpack(layout.NoviceCastSize))
		self.Cast:SetStatusBarTexture(layout.NoviceCastTexture)
		if (self.ExtraPower) then 
			self.ExtraPower.Fg:SetTexture(layout.NoviceManaOrbTexture)
			self.ExtraPower.Fg:SetVertexColor(unpack(layout.NoviceManaOrbColor)) 
		end
	end 
end 

local Target_PostUpdateTextures = function(self)
	if (not UnitExists("target")) then 
		return
	end 
	local targetStyle

	-- Figure out if the various artwork and bar textures need to be updated
	-- We could put this into element post updates, 
	-- but to avoid needless checks we limit this to actual target updates. 
	local targetLevel = UnitLevel("target") or 0
	local classification = UnitClassification("target")
	local creatureType = UnitCreatureType("target")

	if UnitIsPlayer("target") then 
		if ((targetLevel < 1) or (targetLevel >= 60)) then 
			targetStyle = "Seasoned"
		elseif (targetLevel >= self.layout.HardenedLevel) then 
			targetStyle = "Hardened"
		else
			targetStyle = "Novice" 
		end 
	elseif ((classification == "worldboss") or (targetLevel < 1)) then 
		targetStyle = "Boss"
	elseif (targetLevel >= 60) then 
		targetStyle = "Seasoned"
	elseif (targetLevel >= self.layout.HardenedLevel) then 
		targetStyle = "Hardened"
	elseif (creatureType == "Critter") then 
		targetStyle = "Critter"
	else
		targetStyle = "Novice" 
	end 

	-- Silently return if there was no change
	if (targetStyle == self.currentStyle) or (not targetStyle) then 
		return 
	end 

	-- Store the new style
	self.currentStyle = targetStyle

	self.Health:Place(unpack(self.layout[self.currentStyle.."HealthPlace"]))
	self.Health:SetSize(unpack(self.layout[self.currentStyle.."HealthSize"]))
	self.Health:SetStatusBarTexture(self.layout[self.currentStyle.."HealthTexture"])
	self.Health:SetSparkMap(self.layout[self.currentStyle.."HealthSparkMap"])

	self.Health.Bg:ClearAllPoints()
	self.Health.Bg:SetPoint(unpack(self.layout[self.currentStyle.."HealthBackdropPlace"]))
	self.Health.Bg:SetSize(unpack(self.layout[self.currentStyle.."HealthBackdropSize"]))
	self.Health.Bg:SetTexture(self.layout[self.currentStyle.."HealthBackdropTexture"])
	self.Health.Bg:SetVertexColor(unpack(self.layout[self.currentStyle.."HealthBackdropColor"]))

	self.Health.Value:SetShown(self.layout[self.currentStyle.."HealthValueVisible"])
	self.Health.ValuePercent:SetShown(self.layout[self.currentStyle.."HealthPercentVisible"])

	self.Cast:Place(unpack(self.layout[self.currentStyle.."CastPlace"]))
	self.Cast:SetSize(unpack(self.layout[self.currentStyle.."CastSize"]))
	self.Cast:SetStatusBarTexture(self.layout[self.currentStyle.."CastTexture"])
	self.Cast:SetSparkMap(self.layout[self.currentStyle.."CastSparkMap"])

	self.Portrait.Fg:SetTexture(self.layout[self.currentStyle.."PortraitForegroundTexture"])
	self.Portrait.Fg:SetVertexColor(unpack(self.layout[self.currentStyle.."PortraitForegroundColor"]))
	
end 

local Target_PostUpdateName = function(self, event, ...)
	if (event == "GP_UNITFRAME_TOT_VISIBLE") then 
		self.totVisible = true
	elseif (event == "GP_UNITFRAME_TOT_INVISIBLE") then 
		self.totVisible = nil
	elseif (event == "GP_UNITFRAME_TOT_SHOWN") then 
		self.totShown = true
	elseif (event == "GP_UNITFRAME_TOT_HIDDEN") then
		self.totShown = nil
	end
	if (self.totShown and self.totVisible and (not self.Name.usingSmallWidth)) then 
		self.Name.maxChars = 30
		self.Name.usingSmallWidth = true
		self.Name:ForceUpdate()
		UnitFrameTarget:AddDebugMessageFormatted("UnitFrameTarget changed name element width to small.")
	elseif (self.Name.usingSmallWidth) then
		self.Name.maxChars = 64
		self.Name.usingSmallWidth = nil
		self.Name:ForceUpdate()
		UnitFrameTarget:AddDebugMessageFormatted("UnitFrameTarget changed name element width to full.")
	end 
end

local ToTFrame_PostUpdateAlpha = function(self)
	local unit = self.unit
	if (not unit) then 
		return 
	end 

	local targetStyle

	-- Hide it when tot is the same as the target
	if self.hideWhenUnitIsPlayer and (UnitIsUnit(unit, "player")) then 
		targetStyle = "Hidden"

	elseif self.hideWhenUnitIsTarget and (UnitIsUnit(unit, "target")) then 
		targetStyle = "Hidden"

	elseif self.hideWhenTargetIsCritter then 
		local level = UnitLevel("target")
		if ((level and level == 1) and (not UnitIsPlayer("target"))) then 
			targetStyle = "Hidden"
		else 
			targetStyle = "Shown"
		end 
	else 
		targetStyle = "Shown"
	end 

	-- Silently return if there was no change
	if (targetStyle == self.alphaStyle) then 
		return 
	end 

	-- Store the new style
	self.alphaStyle = targetStyle

	-- Apply the new style
	if (targetStyle == "Shown") then 
		self:SetAlpha(1)
		self:SendMessage("GP_UNITFRAME_TOT_VISIBLE")
	elseif (targetStyle == "Hidden") then 
		self:SetAlpha(0)
		self:SendMessage("GP_UNITFRAME_TOT_INVISIBLE")
	end

	if self.TargetHighlight then 
		self.TargetHighlight:ForceUpdate()
	end
end

-----------------------------------------------------------
-- Templates
-----------------------------------------------------------
-- Boss
local positionHeaderFrame = function(self, unit, id, layout)
	-- Todo: iterate on this for a grid layout
	local id = tonumber(id)
	if id then 
		local place = { unpack(layout.Place) }
		local growthX = layout.GrowthX
		local growthY = layout.GrowthY

		if (growthX and growthY) then 
			if (type(place[#place]) == "number") then 
				place[#place - 1] = place[#place - 1] + growthX*(id-1)
				place[#place] = place[#place] + growthY*(id-1)
			else 
				place[#place + 1] = growthX
				place[#place + 1] = growthY
			end 
		end 
		self:Place(unpack(place))
	else 
		self:Place(unpack(layout.Place)) 
	end
end

-- Boss, Pet, ToT
local StyleSmallFrame = function(self, unit, id, layout, ...)

	self.colors = Colors
	self.layout = layout

	self:SetSize(unpack(layout.Size)) 
	self:SetFrameLevel(self:GetFrameLevel() + layout.FrameLevel)

	if (unit:match("^boss(%d+)")) then 
		positionHeaderFrame(self, unit, id, layout)
	else
		self:Place(unpack(layout.Place)) 
	end 

	-- Scaffolds
	-----------------------------------------------------------
	-- frame to contain art backdrops, shadows, etc
	local backdrop = self:CreateFrame("Frame")
	backdrop:SetAllPoints()
	backdrop:SetFrameLevel(self:GetFrameLevel())
	
	-- frame to contain bars, icons, etc
	local content = self:CreateFrame("Frame")
	content:SetAllPoints()
	content:SetFrameLevel(self:GetFrameLevel() + 10)

	-- frame to contain art overlays, texts, etc
	local overlay = self:CreateFrame("Frame")
	overlay:SetAllPoints()
	overlay:SetFrameLevel(self:GetFrameLevel() + 20)

	-- Health Bar
	-----------------------------------------------------------	
	local health = content:CreateStatusBar()
	health:SetOrientation(layout.HealthBarOrientation or "RIGHT") 
	health:SetFlippedHorizontally(layout.HealthBarSetFlippedHorizontally)
	health:SetSparkMap(layout.HealthBarSparkMap) 
	health:SetStatusBarTexture(layout.HealthBarTexture)
	health:SetSize(unpack(layout.HealthSize))
	health:Place(unpack(layout.HealthPlace))
	health:SetSmoothingMode(layout.HealthSmoothingMode or "bezier-fast-in-slow-out") 
	health:SetSmoothingFrequency(layout.HealthSmoothingFrequency or .5) 
	health.colorTapped = layout.HealthColorTapped  -- color tap denied units 
	health.colorDisconnected = layout.HealthColorDisconnected -- color disconnected units
	health.colorClass = layout.HealthColorClass -- color players by class 
	health.colorPetAsPlayer = layout.HealthColorPetAsPlayer -- color your pet as you
	health.colorReaction = layout.HealthColorReaction -- color NPCs by their reaction standing with us
	health.colorHealth = layout.HealthColorHealth -- color anything else in the default health color
	health.frequent = layout.HealthFrequentUpdates -- listen to frequent health events for more accurate updates
	self.Health = health
	self.Health.PostUpdate = layout.HealthBarPostUpdate
	
	local healthBg = health:CreateTexture()
	healthBg:SetDrawLayer(unpack(layout.HealthBackdropDrawLayer))
	healthBg:SetSize(unpack(layout.HealthBackdropSize))
	healthBg:SetPoint(unpack(layout.HealthBackdropPlace))
	healthBg:SetTexture(layout.HealthBackdropTexture)
	healthBg:SetVertexColor(unpack(layout.HealthBackdropColor))
	self.Health.Bg = healthBg

	-- Health Value
	local healthPerc = health:CreateFontString()
	healthPerc:SetPoint(unpack(layout.HealthPercentPlace))
	healthPerc:SetDrawLayer(unpack(layout.HealthPercentDrawLayer))
	healthPerc:SetJustifyH(layout.HealthPercentJustifyH)
	healthPerc:SetJustifyV(layout.HealthPercentJustifyV)
	healthPerc:SetFontObject(layout.HealthPercentFont)
	healthPerc:SetTextColor(unpack(layout.HealthPercentColor))
	self.Health.ValuePercent = healthPerc
	
	-- Cast Bar
	-----------------------------------------------------------
	local cast = content:CreateStatusBar()
	cast:SetSize(unpack(layout.CastBarSize))
	cast:SetFrameLevel(health:GetFrameLevel() + 1)
	cast:Place(unpack(layout.CastBarPlace))
	cast:SetOrientation(layout.CastBarOrientation) 
	cast:SetSmoothingMode(layout.CastBarSmoothingMode) 
	cast:SetSmoothingFrequency(layout.CastBarSmoothingFrequency)
	cast:SetStatusBarColor(unpack(layout.CastBarColor)) 
	cast:SetStatusBarTexture(layout.CastBarTexture)
	cast:SetSparkMap(layout.CastBarSparkMap) 
	self.Cast = cast
	self.Cast.PostUpdate = layout.CastBarPostUpdate

	-- Cast Name
	local name = (layout.CastBarNameParent and self[layout.CastBarNameParent] or overlay):CreateFontString()
	name:SetPoint(unpack(layout.CastBarNamePlace))
	name:SetFontObject(layout.CastBarNameFont)
	name:SetDrawLayer(unpack(layout.CastBarNameDrawLayer))
	name:SetJustifyH(layout.CastBarNameJustifyH)
	name:SetJustifyV(layout.CastBarNameJustifyV)
	name:SetTextColor(unpack(layout.CastBarNameColor))
	name:SetSize(unpack(layout.CastBarNameSize))
	self.Cast.Name = name
	
	-- Target Highlighting
	-----------------------------------------------------------
	local owner = layout.TargetHighlightParent and self[layout.TargetHighlightParent] or self
	local targetHighlightFrame = CreateFrame("Frame", nil, owner)
	targetHighlightFrame:SetAllPoints()
	targetHighlightFrame:SetIgnoreParentAlpha(true)

	local targetHighlight = targetHighlightFrame:CreateTexture()
	targetHighlight:SetDrawLayer(unpack(layout.TargetHighlightDrawLayer))
	targetHighlight:SetSize(unpack(layout.TargetHighlightSize))
	targetHighlight:SetPoint(unpack(layout.TargetHighlightPlace))
	targetHighlight:SetTexture(layout.TargetHighlightTexture)
	targetHighlight.showTarget = layout.TargetHighlightShowTarget
	targetHighlight.colorTarget = layout.TargetHighlightTargetColor
	self.TargetHighlight = targetHighlight

	-- Auras
	-----------------------------------------------------------
	if (layout.AuraProperties) then 
		local auras = content:CreateFrame("Frame")
		auras:Place(unpack(layout.AuraFramePlace))
		auras:SetSize(unpack(layout.AuraFrameSize))
		for property,value in pairs(layout.AuraProperties) do 
			auras[property] = value
		end
		self.Auras = auras
		self.Auras.PostCreateButton = layout.Aura_PostCreateButton -- post creation styling
		self.Auras.PostUpdateButton = layout.Aura_PostUpdateButton -- post updates when something changes (even timers)
	end 

	-- Unit Name
	if layout.NamePlace then 
		local name = overlay:CreateFontString()
		name:SetPoint(unpack(layout.NamePlace))
		name:SetDrawLayer(unpack(layout.NameDrawLayer))
		name:SetJustifyH(layout.NameJustifyH)
		name:SetJustifyV(layout.NameJustifyV)
		name:SetFontObject(layout.NameFont)
		name:SetTextColor(unpack(layout.NameColor))
		self.Name = name
	end 

	if (unit == "targettarget") and (layout.HideWhenUnitIsPlayer or layout.HideWhenTargetIsCritter or layout.HideWhenUnitIsTarget) then 
		self.hideWhenUnitIsPlayer = layout.HideWhenUnitIsPlayer
		self.hideWhenUnitIsTarget = layout.HideWhenUnitIsTarget
		self.hideWhenTargetIsCritter = layout.HideWhenTargetIsCritter
		self.PostUpdate = ToTFrame_PostUpdateAlpha
		self:RegisterEvent("PLAYER_TARGET_CHANGED", ToTFrame_PostUpdateAlpha, true)
	end 
end

-- Party
local StylePartyFrame = function(self, unit, id, layout, ...)

	self:SetSize(unpack(layout.Size)) 
	self:SetHitRectInsets(0, 0, 0, 0)

	-- Assign our own global custom colors
	self.colors = Colors
	self.layout = layout

	-- Scaffolds
	-----------------------------------------------------------
	-- frame to contain art backdrops, shadows, etc
	local backdrop = self:CreateFrame("Frame")
	backdrop:SetAllPoints()
	backdrop:SetFrameLevel(self:GetFrameLevel())
	
	-- frame to contain bars, icons, etc
	local content = self:CreateFrame("Frame")
	content:SetAllPoints()
	content:SetFrameLevel(self:GetFrameLevel() + 10)

	-- frame to contain art overlays, texts, etc
	local overlay = self:CreateFrame("Frame")
	overlay:SetAllPoints()
	overlay:SetFrameLevel(self:GetFrameLevel() + 20)

	-- Health Bar
	-----------------------------------------------------------	
	local health = content:CreateStatusBar()
	health:SetFrameLevel(health:GetFrameLevel() + 2)
	health:Place(unpack(layout.HealthPlace))
	health:SetSize(unpack(layout.HealthSize))
	health:SetOrientation(layout.HealthBarOrientation or "RIGHT") 
	health:SetFlippedHorizontally(layout.HealthBarSetFlippedHorizontally)
	health:SetSparkMap(layout.HealthBarSparkMap) 
	health:SetStatusBarTexture(layout.HealthBarTexture)
	health:SetSmartSmoothing(true)
	health.colorTapped = layout.HealthColorTapped  -- color tap denied units 
	health.colorDisconnected = layout.HealthColorDisconnected -- color disconnected units
	health.colorClass = layout.HealthColorClass -- color players by class 
	health.colorPetAsPlayer = layout.HealthColorPetAsPlayer -- color your pet as you
	health.colorReaction = layout.HealthColorReaction -- color NPCs by their reaction standing with us
	health.colorHealth = layout.HealthColorHealth -- color anything else in the default health color
	health.frequent = layout.HealthFrequentUpdates -- listen to frequent health events for more accurate updates
	self.Health = health
	self.Health.PostUpdate = layout.HealthBarPostUpdate
	self.Health.OverrideValue = layout.HealthValueOverride or TinyFrame_OverrideHealthValue

	local healthBg = health:CreateTexture()
	healthBg:SetDrawLayer(unpack(layout.HealthBackdropDrawLayer))
	healthBg:SetSize(unpack(layout.HealthBackdropSize))
	healthBg:SetPoint(unpack(layout.HealthBackdropPlace))
	healthBg:SetTexture(layout.HealthBackdropTexture)
	healthBg:SetVertexColor(unpack(layout.HealthBackdropColor))
	self.Health.Bg = healthBg

	-- Health Value
	local healthVal = health:CreateFontString()
	healthVal:SetPoint(unpack(layout.HealthValuePlace))
	healthVal:SetDrawLayer(unpack(layout.HealthValueDrawLayer))
	healthVal:SetJustifyH(layout.HealthValueJustifyH)
	healthVal:SetJustifyV(layout.HealthValueJustifyV)
	healthVal:SetFontObject(layout.HealthValueFont)
	healthVal:SetTextColor(unpack(layout.HealthValueColor))
	healthVal.showPercent = layout.HealthShowPercent
	self.Health.Value = healthVal

	-- Health Value Callback
	self:RegisterEvent("PLAYER_FLAGS_CHANGED", TinyFrame_OnEvent)
	
	-- Range
	-----------------------------------------------------------
	self.Range = { outsideAlpha = layout.RangeOutsideAlpha }

	-- Portrait
	-----------------------------------------------------------
	local portrait = backdrop:CreateFrame("PlayerModel")
	portrait:SetPoint(unpack(layout.PortraitPlace))
	portrait:SetSize(unpack(layout.PortraitSize)) 
	portrait:SetAlpha(layout.PortraitAlpha)
	portrait.distanceScale = layout.PortraitDistanceScale
	portrait.positionX = layout.PortraitPositionX
	portrait.positionY = layout.PortraitPositionY
	portrait.positionZ = layout.PortraitPositionZ
	portrait.rotation = layout.PortraitRotation -- in degrees
	portrait.showFallback2D = layout.PortraitShowFallback2D -- display 2D portraits when unit is out of range of 3D models
	self.Portrait = portrait
		
	-- To allow the backdrop and overlay to remain 
	-- visible even with no visible player model, 
	-- we add them to our backdrop and overlay frames, 
	-- not to the portrait frame itself.
	local portraitBg = backdrop:CreateTexture()
	portraitBg:SetPoint(unpack(layout.PortraitBackgroundPlace))
	portraitBg:SetSize(unpack(layout.PortraitBackgroundSize))
	portraitBg:SetTexture(layout.PortraitBackgroundTexture)
	portraitBg:SetDrawLayer(unpack(layout.PortraitBackgroundDrawLayer))
	portraitBg:SetVertexColor(unpack(layout.PortraitBackgroundColor))
	self.Portrait.Bg = portraitBg

	local portraitShade = content:CreateTexture()
	portraitShade:SetPoint(unpack(layout.PortraitShadePlace))
	portraitShade:SetSize(unpack(layout.PortraitShadeSize)) 
	portraitShade:SetTexture(layout.PortraitShadeTexture)
	portraitShade:SetDrawLayer(unpack(layout.PortraitShadeDrawLayer))
	self.Portrait.Shade = portraitShade

	local portraitFg = content:CreateTexture()
	portraitFg:SetPoint(unpack(layout.PortraitForegroundPlace))
	portraitFg:SetSize(unpack(layout.PortraitForegroundSize))
	portraitFg:SetTexture(layout.PortraitForegroundTexture)
	portraitFg:SetDrawLayer(unpack(layout.PortraitForegroundDrawLayer))
	portraitFg:SetVertexColor(unpack(layout.PortraitForegroundColor))
	self.Portrait.Fg = portraitFg

	-- Cast Bar
	-----------------------------------------------------------
	local cast = content:CreateStatusBar()
	cast:SetSize(unpack(layout.CastBarSize))
	cast:SetFrameLevel(health:GetFrameLevel() + 1)
	cast:Place(unpack(layout.CastBarPlace))
	cast:SetOrientation(layout.CastBarOrientation) -- set the bar to grow towards the right.
	cast:SetSmoothingMode(layout.CastBarSmoothingMode) -- set the smoothing mode.
	cast:SetSmoothingFrequency(layout.CastBarSmoothingFrequency)
	cast:SetStatusBarColor(unpack(layout.CastBarColor)) -- the alpha won't be overwritten. 
	cast:SetStatusBarTexture(layout.CastBarTexture)
	cast:SetSparkMap(layout.CastBarSparkMap) -- set the map the spark follows along the bar.
	self.Cast = cast
	self.Cast.PostUpdate = layout.CastBarPostUpdate

	-- Auras
	-----------------------------------------------------------
	local auras = content:CreateFrame("Frame")
	auras:Place(unpack(layout.AuraFramePlace))
	auras:SetSize(unpack(layout.AuraFrameSize))
	for property,value in pairs(layout.AuraProperties) do 
		auras[property] = value
	end
	self.Auras = auras
	self.Auras.PostCreateButton = layout.Aura_PostCreateButton -- post creation styling
	self.Auras.PostUpdateButton = layout.Aura_PostUpdateButton -- post updates when something changes (even timers)

	-- Target Highlighting
	-----------------------------------------------------------
	local targetHighlightFrame = CreateFrame("Frame", nil, layout.TargetHighlightParent and self[layout.TargetHighlightParent] or self)
	targetHighlightFrame:SetAllPoints()
	targetHighlightFrame:SetIgnoreParentAlpha(true)

	local targetHighlight = targetHighlightFrame:CreateTexture()
	targetHighlight:SetDrawLayer(unpack(layout.TargetHighlightDrawLayer))
	targetHighlight:SetSize(unpack(layout.TargetHighlightSize))
	targetHighlight:SetPoint(unpack(layout.TargetHighlightPlace))
	targetHighlight:SetTexture(layout.TargetHighlightTexture)
	targetHighlight.showTarget = layout.TargetHighlightShowTarget
	targetHighlight.colorTarget = layout.TargetHighlightTargetColor
	self.TargetHighlight = targetHighlight

	-- Group Debuff (#1)
	-----------------------------------------------------------
	local groupAura = overlay:CreateFrame("Button")
	groupAura:SetFrameLevel(overlay:GetFrameLevel() - 4)
	groupAura:SetPoint(unpack(layout.GroupAuraPlace))
	groupAura:SetSize(unpack(layout.GroupAuraSize))
	groupAura.disableMouse = layout.GroupAuraButtonDisableMouse
	groupAura.tooltipDefaultPosition = layout.GroupAuraTooltipDefaultPosition
	groupAura.tooltipPoint = layout.GroupAuraTooltipPoint
	groupAura.tooltipAnchor = layout.GroupAuraTooltipAnchor
	groupAura.tooltipRelPoint = layout.GroupAuraTooltipRelPoint
	groupAura.tooltipOffsetX = layout.GroupAuraTooltipOffsetX
	groupAura.tooltipOffsetY = layout.GroupAuraTooltipOffsetY

	local groupAuraIcon = groupAura:CreateTexture()
	groupAuraIcon:SetPoint(unpack(layout.GroupAuraButtonIconPlace))
	groupAuraIcon:SetSize(unpack(layout.GroupAuraButtonIconSize))
	groupAuraIcon:SetTexCoord(unpack(layout.GroupAuraButtonIconTexCoord))
	groupAuraIcon:SetDrawLayer("ARTWORK", 1)
	groupAura.Icon = groupAuraIcon

	-- Frame to contain art overlays, texts, etc
	local groupAuraOverlay = groupAura:CreateFrame("Frame")
	groupAuraOverlay:SetFrameLevel(groupAura:GetFrameLevel() + 3)
	groupAuraOverlay:SetAllPoints(groupAura)
	groupAura.Overlay = groupAuraOverlay

	-- Cooldown frame
	local groupAuraCooldown = groupAura:CreateFrame("Cooldown", nil, groupAura, "CooldownFrameTemplate")
	groupAuraCooldown:Hide()
	groupAuraCooldown:SetAllPoints(groupAura)
	groupAuraCooldown:SetFrameLevel(groupAura:GetFrameLevel() + 1)
	groupAuraCooldown:SetReverse(false)
	groupAuraCooldown:SetSwipeColor(0, 0, 0, .75)
	groupAuraCooldown:SetBlingTexture(BLING_TEXTURE, .3, .6, 1, .75) 
	groupAuraCooldown:SetEdgeTexture(EDGE_NORMAL_TEXTURE)
	groupAuraCooldown:SetDrawSwipe(true)
	groupAuraCooldown:SetDrawBling(true)
	groupAuraCooldown:SetDrawEdge(false)
	groupAuraCooldown:SetHideCountdownNumbers(true) 
	groupAura.Cooldown = groupAuraCooldown

	local groupAuraTime = overlay:CreateFontString()
	groupAuraTime:SetDrawLayer("ARTWORK", 1)
	groupAuraTime:SetPoint(unpack(layout.GroupAuraButtonTimePlace))
	groupAuraTime:SetFontObject(layout.GroupAuraButtonTimeFont)
	groupAuraTime:SetJustifyH("CENTER")
	groupAuraTime:SetJustifyV("MIDDLE")
	groupAuraTime:SetTextColor(unpack(layout.GroupAuraButtonTimeColor))
	groupAura.Time = groupAuraTime

	local groupAuraCount = overlay:CreateFontString()
	groupAuraCount:SetDrawLayer("OVERLAY", 1)
	groupAuraCount:SetPoint(unpack(layout.GroupAuraButtonCountPlace))
	groupAuraCount:SetFontObject(layout.GroupAuraButtonCountFont)
	groupAuraCount:SetJustifyH("CENTER")
	groupAuraCount:SetJustifyV("MIDDLE")
	groupAuraCount:SetTextColor(unpack(layout.GroupAuraButtonCountColor))
	groupAura.Count = groupAuraCount

	local groupAuraBorder = groupAura:CreateFrame("Frame")
	groupAuraBorder:SetFrameLevel(groupAura:GetFrameLevel() + 2)
	groupAuraBorder:SetPoint(unpack(layout.GroupAuraButtonBorderFramePlace))
	groupAuraBorder:SetSize(unpack(layout.GroupAuraButtonBorderFrameSize))
	groupAuraBorder:SetBackdrop(layout.GroupAuraButtonBorderBackdrop)
	groupAuraBorder:SetBackdropColor(unpack(layout.GroupAuraButtonBorderBackdropColor))
	groupAuraBorder:SetBackdropBorderColor(unpack(layout.GroupAuraButtonBorderBackdropBorderColor))
	groupAura.Border = groupAuraBorder 

	self.GroupAura = groupAura
	self.GroupAura.PostUpdate = layout.GroupAuraPostUpdate

	-- Ready Check (#2)
	-----------------------------------------------------------
	local readyCheck = overlay:CreateTexture()
	readyCheck:SetPoint(unpack(layout.ReadyCheckPlace))
	readyCheck:SetSize(unpack(layout.ReadyCheckSize))
	readyCheck:SetDrawLayer(unpack(layout.ReadyCheckDrawLayer))
	self.ReadyCheck = readyCheck
	self.ReadyCheck.PostUpdate = layout.ReadyCheckPostUpdate

	-- Resurrection Indicator (#3)
	-----------------------------------------------------------
	local rezIndicator = overlay:CreateTexture()
	rezIndicator:SetPoint(unpack(layout.ResurrectIndicatorPlace))
	rezIndicator:SetSize(unpack(layout.ResurrectIndicatorSize))
	rezIndicator:SetDrawLayer(unpack(layout.ResurrectIndicatorDrawLayer))
	self.ResurrectIndicator = rezIndicator
	self.ResurrectIndicator.PostUpdate = layout.ResurrectIndicatorPostUpdate

	-- Unit Status (#4)
	-----------------------------------------------------------
	local unitStatus = overlay:CreateFontString()
	unitStatus:SetPoint(unpack(layout.UnitStatusPlace))
	unitStatus:SetDrawLayer(unpack(layout.UnitStatusDrawLayer))
	unitStatus:SetJustifyH(layout.UnitStatusJustifyH)
	unitStatus:SetJustifyV(layout.UnitStatusJustifyV)
	unitStatus:SetFontObject(layout.UnitStatusFont)
	unitStatus:SetTextColor(unpack(layout.UnitStatusColor))
	unitStatus.hideAFK = layout.UnitStatusHideAFK
	unitStatus.hideDead = layout.UnitStatusHideDead
	unitStatus.hideOffline = layout.UnitStatusHideOffline
	unitStatus.afkMsg = layout.UseUnitStatusMessageAFK
	unitStatus.deadMsg = layout.UseUnitStatusMessageDead
	unitStatus.offlineMsg = layout.UseUnitStatusMessageDC
	unitStatus.oomMsg = layout.UseUnitStatusMessageOOM
	self.UnitStatus = unitStatus
	self.UnitStatus.PostUpdate = layout.UnitStatusPostUpdate

end

-- Raid
local StyleRaidFrame = function(self, unit, id, layout, ...)

	self.layout = layout
	self.colors = Colors
	self:SetSize(unpack(layout.Size)) 
	self:SetHitRectInsets(0, 0, 0, 0)

	-- Scaffolds
	-----------------------------------------------------------
	-- frame to contain art backdrops, shadows, etc
	local backdrop = self:CreateFrame("Frame")
	backdrop:SetAllPoints()
	backdrop:SetFrameLevel(self:GetFrameLevel())
	
	-- frame to contain bars, icons, etc
	local content = self:CreateFrame("Frame")
	content:SetAllPoints()
	content:SetFrameLevel(self:GetFrameLevel() + 10)

	-- frame to contain art overlays, texts, etc
	local overlay = self:CreateFrame("Frame")
	overlay:SetAllPoints()
	overlay:SetFrameLevel(self:GetFrameLevel() + 20)

	-- Health Bar
	-----------------------------------------------------------	
	local health = content:CreateStatusBar()
	health:SetOrientation(layout.HealthBarOrientation or "RIGHT") 
	health:SetFlippedHorizontally(layout.HealthBarSetFlippedHorizontally)
	health:SetSparkMap(layout.HealthBarSparkMap) -- set the map the spark follows along the bar.
	health:SetStatusBarTexture(layout.HealthBarTexture)
	health:SetSize(unpack(layout.HealthSize))
	health:SetFrameLevel(health:GetFrameLevel() + 2)
	health:Place(unpack(layout.HealthPlace))
	health:SetSmartSmoothing(true)
	health.colorTapped = layout.HealthColorTapped  -- color tap denied units 
	health.colorDisconnected = layout.HealthColorDisconnected -- color disconnected units
	health.colorClass = layout.HealthColorClass -- color players by class 
	health.colorPetAsPlayer = layout.HealthColorPetAsPlayer -- color your pet as you
	health.colorReaction = layout.HealthColorReaction -- color NPCs by their reaction standing with us
	health.colorHealth = layout.HealthColorHealth -- color anything else in the default health color
	health.frequent = layout.HealthFrequentUpdates -- listen to frequent health events for more accurate updates
	self.Health = health
	self.Health.PostUpdate = layout.HealthBarPostUpdate
	
	local healthBg = health:CreateTexture()
	healthBg:SetDrawLayer(unpack(layout.HealthBackdropDrawLayer))
	healthBg:SetSize(unpack(layout.HealthBackdropSize))
	healthBg:SetPoint(unpack(layout.HealthBackdropPlace))
	healthBg:SetTexture(layout.HealthBackdropTexture)
	healthBg:SetVertexColor(unpack(layout.HealthBackdropColor))
	self.Health.Bg = healthBg

	-- Cast Bar
	-----------------------------------------------------------
	local cast = content:CreateStatusBar()
	cast:SetSize(unpack(layout.CastBarSize))
	cast:SetFrameLevel(health:GetFrameLevel() + 1)
	cast:Place(unpack(layout.CastBarPlace))
	cast:SetOrientation(layout.CastBarOrientation) -- set the bar to grow towards the right.
	cast:SetSmoothingMode(layout.CastBarSmoothingMode) -- set the smoothing mode.
	cast:SetSmoothingFrequency(layout.CastBarSmoothingFrequency)
	cast:SetStatusBarColor(unpack(layout.CastBarColor)) -- the alpha won't be overwritten. 
	cast:SetStatusBarTexture(layout.CastBarTexture)
	cast:SetSparkMap(layout.CastBarSparkMap) -- set the map the spark follows along the bar.
	self.Cast = cast
	self.Cast.PostUpdate = layout.CastBarPostUpdate

	-- Range
	-----------------------------------------------------------
	self.Range = { outsideAlpha = layout.RangeOutsideAlpha }

	-- Target Highlighting
	-----------------------------------------------------------
	local targetHighlightFrame = CreateFrame("Frame", nil, layout.TargetHighlightParent and self[layout.TargetHighlightParent] or self)
	targetHighlightFrame:SetAllPoints()
	targetHighlightFrame:SetIgnoreParentAlpha(true)

	local targetHighlight = targetHighlightFrame:CreateTexture()
	targetHighlight:SetDrawLayer(unpack(layout.TargetHighlightDrawLayer))
	targetHighlight:SetSize(unpack(layout.TargetHighlightSize))
	targetHighlight:SetPoint(unpack(layout.TargetHighlightPlace))
	targetHighlight:SetTexture(layout.TargetHighlightTexture)
	targetHighlight.showTarget = layout.TargetHighlightShowTarget
	targetHighlight.colorTarget = layout.TargetHighlightTargetColor
	self.TargetHighlight = targetHighlight

	-- Raid Role
	local raidRole = overlay:CreateTexture()
	raidRole:SetPoint(layout.RaidRolePoint, self[layout.RaidRoleAnchor], unpack(layout.RaidRolePlace))
	raidRole:SetSize(unpack(layout.RaidRoleSize))
	raidRole:SetDrawLayer(unpack(layout.RaidRoleDrawLayer))
	raidRole.roleTextures = { RAIDTARGET = layout.RaidRoleRaidTargetTexture }
	self.RaidRole = raidRole
	
	-- Unit Name
	local name = overlay:CreateFontString()
	name:SetPoint(unpack(layout.NamePlace))
	name:SetDrawLayer(unpack(layout.NameDrawLayer))
	name:SetJustifyH(layout.NameJustifyH)
	name:SetJustifyV(layout.NameJustifyV)
	name:SetFontObject(layout.NameFont)
	name:SetTextColor(unpack(layout.NameColor))
	name.maxChars = layout.NameMaxChars
	name.useDots = layout.NameUseDots
	self.Name = name

	-- Group Debuff (#1)
	-----------------------------------------------------------
	local groupAura = overlay:CreateFrame("Button")
	groupAura:SetFrameLevel(overlay:GetFrameLevel() - 4)
	groupAura:SetPoint(unpack(layout.GroupAuraPlace))
	groupAura:SetSize(unpack(layout.GroupAuraSize))
	groupAura.disableMouse = layout.GroupAuraButtonDisableMouse
	groupAura.tooltipDefaultPosition = layout.GroupAuraTooltipDefaultPosition
	groupAura.tooltipPoint = layout.GroupAuraTooltipPoint
	groupAura.tooltipAnchor = layout.GroupAuraTooltipAnchor
	groupAura.tooltipRelPoint = layout.GroupAuraTooltipRelPoint
	groupAura.tooltipOffsetX = layout.GroupAuraTooltipOffsetX
	groupAura.tooltipOffsetY = layout.GroupAuraTooltipOffsetY

	local groupAuraIcon = groupAura:CreateTexture()
	groupAuraIcon:SetPoint(unpack(layout.GroupAuraButtonIconPlace))
	groupAuraIcon:SetSize(unpack(layout.GroupAuraButtonIconSize))
	groupAuraIcon:SetTexCoord(unpack(layout.GroupAuraButtonIconTexCoord))
	groupAuraIcon:SetDrawLayer("ARTWORK", 1)
	groupAura.Icon = groupAuraIcon

	-- Frame to contain art overlays, texts, etc
	local groupAuraOverlay = groupAura:CreateFrame("Frame")
	groupAuraOverlay:SetFrameLevel(groupAura:GetFrameLevel() + 3)
	groupAuraOverlay:SetAllPoints(groupAura)
	groupAura.Overlay = groupAuraOverlay

	-- Cooldown frame
	local groupAuraCooldown = groupAura:CreateFrame("Cooldown", nil, groupAura, "CooldownFrameTemplate")
	groupAuraCooldown:Hide()
	groupAuraCooldown:SetAllPoints(groupAura)
	groupAuraCooldown:SetFrameLevel(groupAura:GetFrameLevel() + 1)
	groupAuraCooldown:SetReverse(false)
	groupAuraCooldown:SetSwipeColor(0, 0, 0, .75)
	groupAuraCooldown:SetBlingTexture(BLING_TEXTURE, .3, .6, 1, .75) 
	groupAuraCooldown:SetEdgeTexture(EDGE_NORMAL_TEXTURE)
	groupAuraCooldown:SetDrawSwipe(true)
	groupAuraCooldown:SetDrawBling(true)
	groupAuraCooldown:SetDrawEdge(false)
	groupAuraCooldown:SetHideCountdownNumbers(true) 
	groupAura.Cooldown = groupAuraCooldown
	
	local groupAuraTime = overlay:CreateFontString()
	groupAuraTime:SetDrawLayer("ARTWORK", 1)
	groupAuraTime:SetPoint(unpack(layout.GroupAuraButtonTimePlace))
	groupAuraTime:SetFontObject(layout.GroupAuraButtonTimeFont)
	groupAuraTime:SetJustifyH("CENTER")
	groupAuraTime:SetJustifyV("MIDDLE")
	groupAuraTime:SetTextColor(unpack(layout.GroupAuraButtonTimeColor))
	groupAura.Time = groupAuraTime

	local groupAuraCount = overlay:CreateFontString()
	groupAuraCount:SetDrawLayer("OVERLAY", 1)
	groupAuraCount:SetPoint(unpack(layout.GroupAuraButtonCountPlace))
	groupAuraCount:SetFontObject(layout.GroupAuraButtonCountFont)
	groupAuraCount:SetJustifyH("CENTER")
	groupAuraCount:SetJustifyV("MIDDLE")
	groupAuraCount:SetTextColor(unpack(layout.GroupAuraButtonCountColor))
	groupAura.Count = groupAuraCount

	local groupAuraBorder = groupAura:CreateFrame("Frame")
	groupAuraBorder:SetFrameLevel(groupAura:GetFrameLevel() + 2)
	groupAuraBorder:SetPoint(unpack(layout.GroupAuraButtonBorderFramePlace))
	groupAuraBorder:SetSize(unpack(layout.GroupAuraButtonBorderFrameSize))
	groupAuraBorder:SetBackdrop(layout.GroupAuraButtonBorderBackdrop)
	groupAuraBorder:SetBackdropColor(unpack(layout.GroupAuraButtonBorderBackdropColor))
	groupAuraBorder:SetBackdropBorderColor(unpack(layout.GroupAuraButtonBorderBackdropBorderColor))
	groupAura.Border = groupAuraBorder 
	self.GroupAura = groupAura
	self.GroupAura.PostUpdate = layout.GroupAuraPostUpdate

	-- Ready Check (#2)
	-----------------------------------------------------------
	local readyCheck = overlay:CreateTexture()
	readyCheck:SetPoint(unpack(layout.ReadyCheckPlace))
	readyCheck:SetSize(unpack(layout.ReadyCheckSize))
	readyCheck:SetDrawLayer(unpack(layout.ReadyCheckDrawLayer))
	self.ReadyCheck = readyCheck
	self.ReadyCheck.PostUpdate = layout.ReadyCheckPostUpdate

	-- Resurrection Indicator (#3)
	-----------------------------------------------------------
	local rezIndicator = overlay:CreateTexture()
	rezIndicator:SetPoint(unpack(layout.ResurrectIndicatorPlace))
	rezIndicator:SetSize(unpack(layout.ResurrectIndicatorSize))
	rezIndicator:SetDrawLayer(unpack(layout.ResurrectIndicatorDrawLayer))
	self.ResurrectIndicator = rezIndicator
	self.ResurrectIndicator.PostUpdate = layout.ResurrectIndicatorPostUpdate

	-- Unit Status (#4)
	local unitStatus = overlay:CreateFontString()
	unitStatus:SetPoint(unpack(layout.UnitStatusPlace))
	unitStatus:SetDrawLayer(unpack(layout.UnitStatusDrawLayer))
	unitStatus:SetJustifyH(layout.UnitStatusJustifyH)
	unitStatus:SetJustifyV(layout.UnitStatusJustifyV)
	unitStatus:SetFontObject(layout.UnitStatusFont)
	unitStatus:SetTextColor(unpack(layout.UnitStatusColor))
	unitStatus.hideAFK = layout.UnitStatusHideAFK
	unitStatus.hideDead = layout.UnitStatusHideDead
	unitStatus.hideOffline = layout.UnitStatusHideOffline
	unitStatus.afkMsg = layout.UseUnitStatusMessageAFK
	unitStatus.deadMsg = layout.UseUnitStatusMessageDead
	unitStatus.offlineMsg = layout.UseUnitStatusMessageDC
	unitStatus.oomMsg = layout.UseUnitStatusMessageOOM
	self.UnitStatus = unitStatus
	self.UnitStatus.PostUpdate = layout.UnitStatusPostUpdate

end

-----------------------------------------------------------
-- Singular Unit Styling
-----------------------------------------------------------
UnitStyles.StylePlayerFrame = function(self, unit, id, layout, ...)

	-- Frame
	-----------------------------------------------------------
	self.colors = Colors
	self.layout = layout
	self:SetSize(unpack(layout.Size)) 
	self:Place(unpack(layout.Place)) 
	self:SetHitRectInsets(unpack(layout.HitRectInsets))

	local topOffset, bottomOffset, leftOffset, rightOffset = unpack(layout.ExplorerHitRects)

	self.GetExplorerHitRects = function(self)
		return topOffset, bottomOffset, leftOffset, rightOffset
	end 

	-- Scaffolds
	-----------------------------------------------------------
	-- frame to contain art backdrops, shadows, etc
	local backdrop = self:CreateFrame("Frame")
	backdrop:SetAllPoints()
	backdrop:SetFrameLevel(self:GetFrameLevel())
	
	-- frame to contain bars, icons, etc
	local content = self:CreateFrame("Frame")
	content:SetAllPoints()
	content:SetFrameLevel(self:GetFrameLevel() + 10)

	-- frame to contain art overlays, texts, etc
	local overlay = self:CreateFrame("Frame")
	overlay:SetAllPoints()
	overlay:SetFrameLevel(self:GetFrameLevel() + 20)

	-- Health Bar
	-----------------------------------------------------------	
	local health = content:CreateStatusBar()
	health:SetOrientation(layout.HealthBarOrientation or "RIGHT") 
	health:SetSparkMap(layout.HealthBarSparkMap)
	health:SetFrameLevel(health:GetFrameLevel() + 2)
	health:Place(unpack(layout.HealthPlace))
	health:SetSmartSmoothing(true)
	health.colorTapped = layout.HealthColorTapped  -- color tap denied units 
	health.colorDisconnected = layout.HealthColorDisconnected -- color disconnected units
	health.colorClass = layout.HealthColorClass -- color players by class 
	health.colorReaction = layout.HealthColorReaction -- color NPCs by their reaction standing with us
	health.colorHealth = layout.HealthColorHealth -- color anything else in the default health color
	health.frequent = layout.HealthFrequentUpdates -- listen to frequent health events for more accurate updates
	health.predictThreshold = .01
	self.Health = health
	self.Health.PostUpdate = layout.CastBarPostUpdate
	
	local healthBgHolder = health:CreateFrame("Frame")
	healthBgHolder:SetAllPoints()
	healthBgHolder:SetFrameLevel(health:GetFrameLevel()-2)

	local healthBg = healthBgHolder:CreateTexture()
	healthBg:SetDrawLayer(unpack(layout.HealthBackdropDrawLayer))
	healthBg:SetSize(unpack(layout.HealthBackdropSize))
	healthBg:SetPoint(unpack(layout.HealthBackdropPlace))
	self.Health.Bg = healthBg

	-- Health Value
	local healthValHolder = overlay:CreateFrame("Frame")
	healthValHolder:SetAllPoints(health)

	local healthVal = healthValHolder:CreateFontString()
	healthVal:SetPoint(unpack(layout.HealthValuePlace))
	healthVal:SetDrawLayer(unpack(layout.HealthValueDrawLayer))
	healthVal:SetJustifyH(layout.HealthValueJustifyH)
	healthVal:SetJustifyV(layout.HealthValueJustifyV)
	healthVal:SetFontObject(layout.HealthValueFont)
	healthVal:SetTextColor(unpack(layout.HealthValueColor))
	self.Health.Value = healthVal

	-- Power 
	-----------------------------------------------------------
	local power = backdrop:CreateStatusBar()
	power:SetSize(unpack(layout.PowerSize))
	power:Place(unpack(layout.PowerPlace))
	power:SetStatusBarTexture(layout.PowerBarTexture)
	power:SetTexCoord(unpack(layout.PowerBarTexCoord))
	power:SetOrientation(layout.PowerBarOrientation or "RIGHT") -- set the bar to grow towards the top.
	power:SetSmoothingMode(layout.PowerBarSmoothingMode) -- set the smoothing mode.
	power:SetSmoothingFrequency(layout.PowerBarSmoothingFrequency or .5) -- set the duration of the smoothing.
	power:SetSparkMap(layout.PowerBarSparkMap) -- set the map the spark follows along the bar.
	power.frequent = true
	power.ignoredResource = layout.PowerIgnoredResource -- make the bar hide when MANA is the primary resource. 
	self.Power = power
	self.Power.OverrideColor = Player_OverridePowerColor

	local powerBg = power:CreateTexture()
	powerBg:SetDrawLayer(unpack(layout.PowerBackgroundDrawLayer))
	powerBg:SetSize(unpack(layout.PowerBackgroundSize))
	powerBg:SetPoint(unpack(layout.PowerBackgroundPlace))
	powerBg:SetTexture(layout.PowerBackgroundTexture)
	powerBg:SetVertexColor(unpack(layout.PowerBackgroundColor)) 
	self.Power.Bg = powerBg

	local powerFg = power:CreateTexture()
	powerFg:SetSize(unpack(layout.PowerForegroundSize))
	powerFg:SetPoint(unpack(layout.PowerForegroundPlace))
	powerFg:SetDrawLayer(unpack(layout.PowerForegroundDrawLayer))
	powerFg:SetTexture(layout.PowerForegroundTexture)
	self.Power.Fg = powerFg

	-- Power Value
	local powerVal = self.Power:CreateFontString()
	powerVal:SetPoint(unpack(layout.PowerValuePlace))
	powerVal:SetDrawLayer(unpack(layout.PowerValueDrawLayer))
	powerVal:SetJustifyH(layout.PowerValueJustifyH)
	powerVal:SetJustifyV(layout.PowerValueJustifyV)
	powerVal:SetFontObject(layout.PowerValueFont)
	powerVal:SetTextColor(unpack(layout.PowerValueColor))
	self.Power.Value = powerVal

	local day = tonumber(date("%d"))
	local month = tonumber(date("%m"))
	if ((month >= 12) and (day >=16 )) or ((month <= 1) and (day <= 2)) then 
		local winterVeilPower = power:CreateTexture()
		winterVeilPower:SetSize(unpack(layout.WinterVeilPowerSize))
		winterVeilPower:SetPoint(unpack(layout.WinterVeilPowerPlace))
		winterVeilPower:SetDrawLayer(unpack(layout.WinterVeilPowerDrawLayer))
		winterVeilPower:SetTexture(layout.WinterVeilPowerTexture)
		winterVeilPower:SetVertexColor(unpack(layout.WinterVeilPowerColor))
		self.Power.WinterVeil = winterVeilPower
	end

	-- Mana Orb
	-----------------------------------------------------------
	-- Only create this for actual mana classes
	local hasMana = (PlayerClass == "DRUID") or (PlayerClass == "HUNTER") 
				 or (PlayerClass == "PALADIN") or (PlayerClass == "SHAMAN")
				 or (PlayerClass == "MAGE") or (PlayerClass == "PRIEST") or (PlayerClass == "WARLOCK") 

	if hasMana then 

		local extraPower = backdrop:CreateOrb()
		extraPower:SetStatusBarTexture(unpack(layout.ManaOrbTextures)) 
		extraPower:Place(unpack(layout.ManaPlace))  
		extraPower:SetSize(unpack(layout.ManaSize)) 
		extraPower.frequent = true
		extraPower.exclusiveResource = layout.ManaExclusiveResource or "MANA" 
		self.ExtraPower = extraPower
		self.ExtraPower.OverrideColor = Player_OverrideExtraPowerColor
	
		local extraPowerBg = extraPower:CreateBackdropTexture()
		extraPowerBg:SetPoint(unpack(layout.ManaBackgroundPlace))
		extraPowerBg:SetSize(unpack(layout.ManaBackgroundSize))
		extraPowerBg:SetTexture(layout.ManaBackgroundTexture)
		extraPowerBg:SetDrawLayer(unpack(layout.ManaBackgroundDrawLayer))
		extraPowerBg:SetVertexColor(unpack(layout.ManaBackgroundColor)) 
		self.ExtraPower.bg = extraPowerBg

		local extraPowerShade = extraPower:CreateTexture()
		extraPowerShade:SetPoint(unpack(layout.ManaShadePlace))
		extraPowerShade:SetSize(unpack(layout.ManaShadeSize)) 
		extraPowerShade:SetTexture(layout.ManaShadeTexture)
		extraPowerShade:SetDrawLayer(unpack(layout.ManaShadeDrawLayer))
		extraPowerShade:SetVertexColor(unpack(layout.ManaShadeColor)) 
		self.ExtraPower.Shade = extraPowerShade

		local extraPowerFg = extraPower:CreateTexture()
		extraPowerFg:SetPoint(unpack(layout.ManaForegroundPlace))
		extraPowerFg:SetSize(unpack(layout.ManaForegroundSize))
		extraPowerFg:SetDrawLayer(unpack(layout.ManaForegroundDrawLayer))
		self.ExtraPower.Fg = extraPowerFg

		-- Mana Value
		local extraPowerVal = self.ExtraPower:CreateFontString()
		extraPowerVal:SetPoint(unpack(layout.ManaValuePlace))
		extraPowerVal:SetDrawLayer(unpack(layout.ManaValueDrawLayer))
		extraPowerVal:SetJustifyH(layout.ManaValueJustifyH)
		extraPowerVal:SetJustifyV(layout.ManaValueJustifyV)
		extraPowerVal:SetFontObject(layout.ManaValueFont)
		extraPowerVal:SetTextColor(unpack(layout.ManaValueColor))
		self.ExtraPower.Value = extraPowerVal
		
		local day = tonumber(date("%d"))
		local month = tonumber(date("%m"))
		if ((month >= 12) and (day >=16 )) or ((month <= 1) and (day <= 2)) then 
			local winterVeilMana = extraPower:CreateTexture()
			winterVeilMana:SetSize(unpack(layout.WinterVeilManaSize))
			winterVeilMana:SetPoint(unpack(layout.WinterVeilManaPlace))
			winterVeilMana:SetDrawLayer(unpack(layout.WinterVeilManaDrawLayer))
			winterVeilMana:SetTexture(layout.WinterVeilManaTexture)
			winterVeilMana:SetVertexColor(unpack(layout.WinterVeilManaColor))
			self.ExtraPower.WinterVeil = winterVeilMana
		end 

	end 

	-- Cast Bar
	-----------------------------------------------------------
	local cast = content:CreateStatusBar()
	cast:SetSize(unpack(layout.CastBarSize))
	cast:SetFrameLevel(health:GetFrameLevel() + 1)
	cast:Place(unpack(layout.CastBarPlace))
	cast:SetOrientation(layout.CastBarOrientation)
	cast:DisableSmoothing()
	cast:SetStatusBarColor(unpack(layout.CastBarColor))  
	cast:SetSparkMap(layout.CastBarSparkMap) 

	local name = (layout.CastBarNameParent and self[layout.CastBarNameParent] or overlay):CreateFontString()
	name:SetPoint(unpack(layout.CastBarNamePlace))
	name:SetFontObject(layout.CastBarNameFont)
	name:SetDrawLayer(unpack(layout.CastBarNameDrawLayer))
	name:SetJustifyH(layout.CastBarNameJustifyH)
	name:SetJustifyV(layout.CastBarNameJustifyV)
	name:SetTextColor(unpack(layout.CastBarNameColor))
	name:SetSize(unpack(layout.CastBarNameSize))
	cast.Name = name

	local value = (layout.CastBarValueParent and self[layout.CastBarValueParent] or overlay):CreateFontString()
	value:SetPoint(unpack(layout.CastBarValuePlace))
	value:SetFontObject(layout.CastBarValueFont)
	value:SetDrawLayer(unpack(layout.CastBarValueDrawLayer))
	value:SetJustifyH(layout.CastBarValueJustifyH)
	value:SetJustifyV(layout.CastBarValueJustifyV)
	value:SetTextColor(unpack(layout.CastBarValueColor))
	cast.Value = value

	self.Cast = cast
	self.Cast.PostUpdate = layout.CastBarPostUpdate

	-- Combat Indicator
	-----------------------------------------------------------
	local combat = overlay:CreateTexture()

	local prefix = "CombatIndicator"
	local day = tonumber(date("%d"))
	local month = tonumber(date("%m"))
	if ((month == 2) and (day >= 12) and (day <= 26)) then 
		prefix = "Love"..prefix
	end
	combat:SetSize(unpack(layout[prefix.."Size"]))
	combat:SetPoint(unpack(layout[prefix.."Place"])) 
	combat:SetTexture(layout[prefix.."Texture"])
	combat:SetDrawLayer(unpack(layout[prefix.."DrawLayer"]))
	self.Combat = combat

	-- Unit Classification (PvP Status)
	local classification = overlay:CreateFrame("Frame")
	classification:SetPoint(unpack(layout.ClassificationPlace))
	classification:SetSize(unpack(layout.ClassificationSize))
	classification.hideInCombat = true
	self.Classification = classification

	local alliance = classification:CreateTexture()
	alliance:SetPoint("CENTER", 0, 0)
	alliance:SetSize(unpack(layout.ClassificationSize))
	alliance:SetTexture(layout.ClassificationIndicatorAllianceTexture)
	alliance:SetVertexColor(unpack(layout.ClassificationColor))
	self.Classification.Alliance = alliance

	local horde = classification:CreateTexture()
	horde:SetPoint("CENTER", 0, 0)
	horde:SetSize(unpack(layout.ClassificationSize))
	horde:SetTexture(layout.ClassificationIndicatorHordeTexture)
	horde:SetVertexColor(unpack(layout.ClassificationColor))
	self.Classification.Horde = horde

	-- Auras
	-----------------------------------------------------------
	local auras = content:CreateFrame("Frame")
	auras:Place(unpack(layout.AuraFramePlace))
	auras:SetSize(unpack(layout.AuraFrameSize)) -- auras will be aligned in the available space, this size gives us 8x1 auras
	for property,value in pairs(layout.AuraProperties) do 
		auras[property] = value
	end
	self.Auras = auras
	self.Auras.PostCreateButton = layout.Aura_PostCreateButton -- post creation styling
	self.Auras.PostUpdateButton = layout.Aura_PostUpdateButton -- post updates when something changes (even timers)

	-- Mana Value when Mana isn't visible  
	local parent = self[layout.ManaTextParent or self.Power and "Power" or "Health"]
	local manaText = parent:CreateFontString()
	manaText:SetPoint(unpack(layout.ManaTextPlace))
	manaText:SetDrawLayer(unpack(layout.ManaTextDrawLayer))
	manaText:SetJustifyH(layout.ManaTextJustifyH)
	manaText:SetJustifyV(layout.ManaTextJustifyV)
	manaText:SetFontObject(layout.ManaTextFont)
	manaText:SetTextColor(unpack(layout.ManaTextColor))
	manaText.frequent = true
	self.ManaText = manaText
	self.ManaText.OverrideValue = layout.ManaTextOverride

	-- Update textures according to player level
	self.PostUpdateTextures = Player_PostUpdateTextures
	Player_PostUpdateTextures(self)
end

UnitStyles.StylePlayerHUDFrame = function(self, unit, id, layout, ...)

	self:SetSize(unpack(layout.Size)) 
	self:Place(unpack(layout.Place)) 

	-- We Don't want this clickable, 
	-- it's in the middle of the screen!
	self.ignoreMouseOver = layout.IgnoreMouseOver

	-- Assign our own global custom colors
	self.colors = Colors
	self.layout = layout

	-- Scaffolds
	-----------------------------------------------------------
	-- frame to contain art backdrops, shadows, etc
	local backdrop = self:CreateFrame("Frame")
	backdrop:SetAllPoints()
	backdrop:SetFrameLevel(self:GetFrameLevel())
	
	-- frame to contain bars, icons, etc
	local content = self:CreateFrame("Frame")
	content:SetAllPoints()
	content:SetFrameLevel(self:GetFrameLevel() + 10)

	-- frame to contain art overlays, texts, etc
	local overlay = self:CreateFrame("Frame")
	overlay:SetAllPoints()
	overlay:SetFrameLevel(self:GetFrameLevel() + 20)

	-- Cast Bar
	local cast = backdrop:CreateStatusBar()
	cast:Place(unpack(layout.CastBarPlace))
	cast:SetSize(unpack(layout.CastBarSize))
	cast:SetStatusBarTexture(layout.CastBarTexture)
	cast:SetStatusBarColor(unpack(layout.CastBarColor)) 
	cast:SetOrientation(layout.CastBarOrientation) -- set the bar to grow towards the top.
	cast:DisableSmoothing(true) -- don't smoothe castbars, it'll make it inaccurate
	cast.timeToHold = layout.CastTimeToHoldFailed
	self.Cast = cast
	
	local castBg = cast:CreateTexture()
	castBg:SetPoint(unpack(layout.CastBarBackgroundPlace))
	castBg:SetSize(unpack(layout.CastBarBackgroundSize))
	castBg:SetTexture(layout.CastBarBackgroundTexture)
	castBg:SetDrawLayer(unpack(layout.CastBarBackgroundDrawLayer))
	castBg:SetVertexColor(unpack(layout.CastBarBackgroundColor))
	self.Cast.Bg = castBg

	local castValue = cast:CreateFontString()
	castValue:SetPoint(unpack(layout.CastBarValuePlace))
	castValue:SetFontObject(layout.CastBarValueFont)
	castValue:SetDrawLayer(unpack(layout.CastBarValueDrawLayer))
	castValue:SetJustifyH(layout.CastBarValueJustifyH)
	castValue:SetJustifyV(layout.CastBarValueJustifyV)
	castValue:SetTextColor(unpack(layout.CastBarValueColor))
	self.Cast.Value = castValue

	local castName = cast:CreateFontString()
	castName:SetPoint(unpack(layout.CastBarNamePlace))
	castName:SetFontObject(layout.CastBarNameFont)
	castName:SetDrawLayer(unpack(layout.CastBarNameDrawLayer))
	castName:SetJustifyH(layout.CastBarNameJustifyH)
	castName:SetJustifyV(layout.CastBarNameJustifyV)
	castName:SetTextColor(unpack(layout.CastBarNameColor))
	self.Cast.Name = castName

	local castShield = cast:CreateTexture()
	castShield:SetPoint(unpack(layout.CastBarShieldPlace))
	castShield:SetSize(unpack(layout.CastBarShieldSize))
	castShield:SetTexture(layout.CastBarShieldTexture)
	castShield:SetDrawLayer(unpack(layout.CastBarShieldDrawLayer))
	castShield:SetVertexColor(unpack(layout.CastBarShieldColor))
	self.Cast.Shield = castShield

	-- Not going to work this into the plugin, so we just hook it here.
	hooksecurefunc(self.Cast.Shield, "Show", function() self.Cast.Bg:Hide() end)
	hooksecurefunc(self.Cast.Shield, "Hide", function() self.Cast.Bg:Show() end)

	local spellQueue = content:CreateStatusBar()
	--spellQueue:SetFrameLevel(self.Cast:GetFrameLevel() + 1)
	spellQueue:Place(unpack(layout.CastBarSpellQueuePlace))
	spellQueue:SetSize(unpack(layout.CastBarSpellQueueSize))
	spellQueue:SetOrientation(layout.CastBarSpellQueueOrientation) 
	spellQueue:SetStatusBarTexture(layout.CastBarSpellQueueTexture) 
	spellQueue:SetStatusBarColor(unpack(layout.CastBarSpellQueueColor)) 
	spellQueue:DisableSmoothing(true)
	self.Cast.SpellQueue = spellQueue

	-- Class Power
	local classPower = backdrop:CreateFrame("Frame")
	classPower:Place(unpack(layout.ClassPowerPlace)) -- center it smack in the middle of the screen
	classPower:SetSize(unpack(layout.ClassPowerSize)) -- minimum size, this is really just an anchor

	-- Only show it on hostile targets
	classPower.hideWhenUnattackable = layout.ClassPowerHideWhenUnattackable

	-- Maximum points displayed regardless 
	-- of max value and available point frames.
	-- This does not affect runes, which still require 6 frames.
	classPower.maxComboPoints = layout.ClassPowerMaxComboPoints

	-- Set the point alpha to 0 when no target is selected
	-- This does not affect runes 
	classPower.hideWhenNoTarget = layout.ClassPowerHideWhenNoTarget 

	-- Set all point alpha to 0 when we have no active points
	-- This does not affect runes 
	classPower.hideWhenEmpty = layout.ClassPowerHideWhenNoTarget

	-- Alpha modifier of inactive/not ready points
	classPower.alphaEmpty = layout.ClassPowerAlphaWhenEmpty 

	-- Alpha modifier when not engaged in combat
	-- This is applied on top of the inactive modifier above
	classPower.alphaNoCombat = layout.ClassPowerAlphaWhenOutOfCombat
	classPower.alphaNoCombatRunes = layout.ClassPowerAlphaWhenOutOfCombatRunes

	-- Set to true to flip the classPower horizontally
	-- Intended to be used alongside actioncam
	classPower.flipSide = layout.ClassPowerReverseSides 

	-- Sort order of the runes
	classPower.runeSortOrder = layout.ClassPowerRuneSortOrder 

	for i = 1,5 do 

		-- Main point object
		local point = classPower:CreateStatusBar() -- the widget require Wheel statusbars
		point:SetSmoothingFrequency(.25) -- keep bar transitions fairly fast
		point:SetMinMaxValues(0, 1)
		point:SetValue(1)

		-- Empty slot texture
		-- Make it slightly larger than the point textures, 
		-- to give a nice darker edge around the points. 
		point.slotTexture = point:CreateTexture()
		point.slotTexture:SetDrawLayer("BACKGROUND", -1)
		point.slotTexture:SetAllPoints(point)

		-- Overlay glow, aligned to the bar texture
		point.glow = point:CreateTexture()
		point.glow:SetDrawLayer("ARTWORK")
		point.glow:SetAllPoints(point:GetStatusBarTexture())

		layout.ClassPowerPostCreatePoint(classPower, i, point)

		classPower[i] = point
	end

	self.ClassPower = classPower
	self.ClassPower.PostUpdate = layout.ClassPowerPostUpdate
	self.ClassPower:PostUpdate()
end

UnitStyles.StyleTargetFrame = function(self, unit, id, layout, ...)

	self.layout = layout
	self.colors = Colors

	self:SetSize(unpack(layout.Size)) 
	self:Place(unpack(layout.Place)) 
	self:SetHitRectInsets(unpack(layout.HitRectInsets))

	-- frame to contain art backdrops, shadows, etc
	local backdrop = self:CreateFrame("Frame")
	backdrop:SetAllPoints()
	backdrop:SetFrameLevel(self:GetFrameLevel())
	
	-- frame to contain bars, icons, etc
	local content = self:CreateFrame("Frame")
	content:SetAllPoints()
	content:SetFrameLevel(self:GetFrameLevel() + 10)

	-- frame to contain art overlays, texts, etc
	local overlay = self:CreateFrame("Frame")
	overlay:SetAllPoints()
	overlay:SetFrameLevel(self:GetFrameLevel() + 20)

	-- Health 
	local health = content:CreateStatusBar()
	health:SetOrientation(layout.HealthBarOrientation or "RIGHT") 
	health:SetFlippedHorizontally(layout.HealthBarSetFlippedHorizontally)
	health:SetFrameLevel(health:GetFrameLevel() + 2)
	health:Place(unpack(layout.HealthPlace))
	health:SetSmartSmoothing(true)
	health.colorTapped = layout.HealthColorTapped  -- color tap denied units 
	health.colorDisconnected = layout.HealthColorDisconnected -- color disconnected units
	health.colorClass = layout.HealthColorClass -- color players by class 
	health.colorReaction = layout.HealthColorReaction -- color NPCs by their reaction standing with us
	health.colorHealth = layout.HealthColorHealth -- color anything else in the default health color
	health.frequent = layout.HealthFrequentUpdates -- listen to frequent health events for more accurate updates
	self.Health = health
	self.Health.PostUpdate = layout.CastBarPostUpdate
	
	local healthBgHolder = health:CreateFrame("Frame")
	healthBgHolder:SetAllPoints()
	healthBgHolder:SetFrameLevel(health:GetFrameLevel()-2)

	local healthBg = healthBgHolder:CreateTexture()
	healthBg:SetDrawLayer(unpack(layout.HealthBackdropDrawLayer))
	healthBg:SetSize(unpack(layout.HealthBackdropSize))
	healthBg:SetPoint(unpack(layout.HealthBackdropPlace))
	healthBg:SetTexture(layout.HealthBackdropTexture)
	healthBg:SetTexCoord(unpack(layout.HealthBackdropTexCoord))
	self.Health.Bg = healthBg

	-- Power 
	local power = overlay:CreateStatusBar()
	power:SetSize(unpack(layout.PowerSize))
	power:Place(unpack(layout.PowerPlace))
	power:SetStatusBarTexture(layout.PowerBarTexture)
	power:SetTexCoord(unpack(layout.PowerBarTexCoord))
	power:SetOrientation(layout.PowerBarOrientation or "RIGHT") -- set the bar to grow towards the top.
	power:SetSmoothingMode(layout.PowerBarSmoothingMode) -- set the smoothing mode.
	power:SetSmoothingFrequency(layout.PowerBarSmoothingFrequency or .5) -- set the duration of the smoothing.
	power:SetFlippedHorizontally(layout.PowerBarSetFlippedHorizontally)
	power:SetSparkTexture(layout.PowerBarSparkTexture)
	power.ignoredResource = layout.PowerIgnoredResource -- make the bar hide when MANA is the primary resource. 
	power.showAlternate = layout.PowerShowAlternate -- use this bar for alt power as well
	power.hideWhenEmpty = layout.PowerHideWhenEmpty -- hide the bar when it's empty
	power.hideWhenDead = layout.PowerHideWhenDead -- hide the bar when the unit is dead
	power.visibilityFilter = layout.PowerVisibilityFilter -- Use filters to decide what units to show for 
	power:SetAlpha(.75)
	self.Power = power

	local powerBg = power:CreateTexture()
	powerBg:SetDrawLayer(unpack(layout.PowerBackgroundDrawLayer))
	powerBg:SetSize(unpack(layout.PowerBackgroundSize))
	powerBg:SetPoint(unpack(layout.PowerBackgroundPlace))
	powerBg:SetTexture(layout.PowerBackgroundTexture)
	powerBg:SetVertexColor(unpack(layout.PowerBackgroundColor)) 
	powerBg:SetTexCoord(unpack(layout.PowerBackgroundTexCoord))
	powerBg:SetIgnoreParentAlpha(true)
	self.Power.Bg = powerBg

	local powerVal = self.Power:CreateFontString()
	powerVal:SetPoint(unpack(layout.PowerValuePlace))
	powerVal:SetDrawLayer(unpack(layout.PowerValueDrawLayer))
	powerVal:SetJustifyH(layout.PowerValueJustifyH)
	powerVal:SetJustifyV(layout.PowerValueJustifyV)
	powerVal:SetFontObject(layout.PowerValueFont)
	powerVal:SetTextColor(unpack(layout.PowerValueColor))
	self.Power.Value = powerVal
	self.Power.OverrideValue = layout.PowerValueOverride

	-- Cast Bar
	local cast = content:CreateStatusBar()
	cast:SetSize(unpack(layout.CastBarSize))
	cast:SetFrameLevel(health:GetFrameLevel() + 1)
	cast:Place(unpack(layout.CastBarPlace))
	cast:SetOrientation(layout.CastBarOrientation) 
	cast:SetFlippedHorizontally(layout.CastBarSetFlippedHorizontally)
	cast:SetSmoothingMode(layout.CastBarSmoothingMode) 
	cast:SetSmoothingFrequency(layout.CastBarSmoothingFrequency)
	cast:SetStatusBarColor(unpack(layout.CastBarColor)) 
	cast:SetSparkMap(layout.CastBarSparkMap) -- set the map the spark follows along the bar.
	self.Cast = cast
	self.Cast.PostUpdate = layout.CastBarPostUpdate

	local name = health:CreateFontString()
	name:SetPoint(unpack(layout.CastBarNamePlace))
	name:SetFontObject(layout.CastBarNameFont)
	name:SetDrawLayer(unpack(layout.CastBarNameDrawLayer))
	name:SetJustifyH(layout.CastBarNameJustifyH)
	name:SetJustifyV(layout.CastBarNameJustifyV)
	name:SetTextColor(unpack(layout.CastBarNameColor))
	name:SetSize(unpack(layout.CastBarNameSize))
	cast.Name = name

	local value = health:CreateFontString()
	value:SetPoint(unpack(layout.CastBarValuePlace))
	value:SetFontObject(layout.CastBarValueFont)
	value:SetDrawLayer(unpack(layout.CastBarValueDrawLayer))
	value:SetJustifyH(layout.CastBarValueJustifyH)
	value:SetJustifyV(layout.CastBarValueJustifyV)
	value:SetTextColor(unpack(layout.CastBarValueColor))
	cast.Value = value

	-- Portrait
	local portrait = backdrop:CreateFrame("PlayerModel")
	portrait:SetPoint(unpack(layout.PortraitPlace))
	portrait:SetSize(unpack(layout.PortraitSize)) 
	portrait:SetAlpha(layout.PortraitAlpha)
	portrait.distanceScale = layout.PortraitDistanceScale
	portrait.positionX = layout.PortraitPositionX
	portrait.positionY = layout.PortraitPositionY
	portrait.positionZ = layout.PortraitPositionZ
	portrait.rotation = layout.PortraitRotation -- in degrees
	portrait.showFallback2D = layout.PortraitShowFallback2D -- display 2D portraits when unit is out of range of 3D models
	self.Portrait = portrait
		
	-- To allow the backdrop and overlay to remain 
	-- visible even with no visible player model, 
	-- we add them to our backdrop and overlay frames, 
	-- not to the portrait frame itself.  
	local portraitBg = backdrop:CreateTexture()
	portraitBg:SetPoint(unpack(layout.PortraitBackgroundPlace))
	portraitBg:SetSize(unpack(layout.PortraitBackgroundSize))
	portraitBg:SetTexture(layout.PortraitBackgroundTexture)
	portraitBg:SetDrawLayer(unpack(layout.PortraitBackgroundDrawLayer))
	portraitBg:SetVertexColor(unpack(layout.PortraitBackgroundColor)) -- keep this dark
	self.Portrait.Bg = portraitBg

	local portraitShade = content:CreateTexture()
	portraitShade:SetPoint(unpack(layout.PortraitShadePlace))
	portraitShade:SetSize(unpack(layout.PortraitShadeSize)) 
	portraitShade:SetTexture(layout.PortraitShadeTexture)
	portraitShade:SetDrawLayer(unpack(layout.PortraitShadeDrawLayer))
	self.Portrait.Shade = portraitShade

	local portraitFg = content:CreateTexture()
	portraitFg:SetPoint(unpack(layout.PortraitForegroundPlace))
	portraitFg:SetSize(unpack(layout.PortraitForegroundSize))
	portraitFg:SetDrawLayer(unpack(layout.PortraitForegroundDrawLayer))
	self.Portrait.Fg = portraitFg

	-- Unit Level
	-- level text
	local level = overlay:CreateFontString()
	level:SetPoint(unpack(layout.LevelPlace))
	level:SetDrawLayer(unpack(layout.LevelDrawLayer))
	level:SetJustifyH(layout.LevelJustifyH)
	level:SetJustifyV(layout.LevelJustifyV)
	level:SetFontObject(layout.LevelFont)
	self.Level = level

	-- Hide the level of capped (or higher) players and NPcs 
	-- Doesn't affect high/unreadable level (??) creatures, as they will still get a skull.
	level.hideCapped = layout.LevelHideCapped 

	-- Hide the level of level 1's
	level.hideFloored = layout.LevelHideFloored

	-- Set the default level coloring when nothing special is happening
	level.defaultColor = layout.LevelColor
	level.alpha = layout.LevelAlpha

	-- Use a custom method to decide visibility
	level.visibilityFilter = layout.LevelVisibilityFilter

	-- Badge backdrop
	local levelBadge = overlay:CreateTexture()
	levelBadge:SetPoint("CENTER", level, "CENTER", 0, 1)
	levelBadge:SetSize(unpack(layout.LevelBadgeSize))
	levelBadge:SetDrawLayer(unpack(layout.LevelBadgeDrawLayer))
	levelBadge:SetTexture(layout.LevelBadgeTexture)
	levelBadge:SetVertexColor(unpack(layout.LevelBadgeColor))
	level.Badge = levelBadge

	-- Skull texture for bosses, high level (and dead units if the below isn't provided)
	local skull = overlay:CreateTexture()
	skull:Hide()
	skull:SetPoint("CENTER", level, "CENTER", 0, 0)
	skull:SetSize(unpack(layout.LevelSkullSize))
	skull:SetDrawLayer(unpack(layout.LevelSkullDrawLayer))
	skull:SetTexture(layout.LevelSkullTexture)
	skull:SetVertexColor(unpack(layout.LevelSkullColor))
	level.Skull = skull

	-- Skull texture for dead units only
	local dead = overlay:CreateTexture()
	dead:Hide()
	dead:SetPoint("CENTER", level, "CENTER", 0, 0)
	dead:SetSize(unpack(layout.LevelDeadSkullSize))
	dead:SetDrawLayer(unpack(layout.LevelDeadSkullDrawLayer))
	dead:SetTexture(layout.LevelDeadSkullTexture)
	dead:SetVertexColor(unpack(layout.LevelDeadSkullColor))
	level.Dead = dead

	-- Unit Classification (boss, elite, rare)
	local classification = overlay:CreateFrame("Frame")
	classification:SetPoint(unpack(layout.ClassificationPlace))
	classification:SetSize(unpack(layout.ClassificationSize))
	self.Classification = classification

	local boss = classification:CreateTexture()
	boss:SetPoint("CENTER", 0, 0)
	boss:SetSize(unpack(layout.ClassificationSize))
	boss:SetTexture(layout.ClassificationIndicatorBossTexture)
	boss:SetVertexColor(unpack(layout.ClassificationColor))
	self.Classification.Boss = boss

	local elite = classification:CreateTexture()
	elite:SetPoint("CENTER", 0, 0)
	elite:SetSize(unpack(layout.ClassificationSize))
	elite:SetTexture(layout.ClassificationIndicatorEliteTexture)
	elite:SetVertexColor(unpack(layout.ClassificationColor))
	self.Classification.Elite = elite

	local rare = classification:CreateTexture()
	rare:SetPoint("CENTER", 0, 0)
	rare:SetSize(unpack(layout.ClassificationSize))
	rare:SetTexture(layout.ClassificationIndicatorRareTexture)
	rare:SetVertexColor(unpack(layout.ClassificationColor))
	self.Classification.Rare = rare

	local alliance = classification:CreateTexture()
	alliance:SetPoint("CENTER", 0, 0)
	alliance:SetSize(unpack(layout.ClassificationSize))
	alliance:SetTexture(layout.ClassificationIndicatorAllianceTexture)
	alliance:SetVertexColor(unpack(layout.ClassificationColor))
	self.Classification.Alliance = alliance

	local horde = classification:CreateTexture()
	horde:SetPoint("CENTER", 0, 0)
	horde:SetSize(unpack(layout.ClassificationSize))
	horde:SetTexture(layout.ClassificationIndicatorHordeTexture)
	horde:SetVertexColor(unpack(layout.ClassificationColor))
	self.Classification.Horde = horde

	-- Targeting
	-- Indicates who your target is targeting
	self.Targeted = {}

	local prefix = "TargetIndicator"
	local day = tonumber(date("%d"))
	local month = tonumber(date("%m"))
	if ((month == 2) and (day >= 12) and (day <= 26)) then 
		prefix = "Love"..prefix
	end

	local friend = overlay:CreateTexture()
	friend:SetPoint(unpack(layout[prefix.."YouByFriendPlace"]))
	friend:SetSize(unpack(layout[prefix.."YouByFriendSize"]))
	friend:SetTexture(layout[prefix.."YouByFriendTexture"])
	friend:SetVertexColor(unpack(layout[prefix.."YouByFriendColor"]))
	self.Targeted.YouByFriend = friend

	local enemy = overlay:CreateTexture()
	enemy:SetPoint(unpack(layout[prefix.."YouByEnemyPlace"]))
	enemy:SetSize(unpack(layout[prefix.."YouByEnemySize"]))
	enemy:SetTexture(layout[prefix.."YouByEnemyTexture"])
	enemy:SetVertexColor(unpack(layout[prefix.."YouByEnemyColor"]))
	self.Targeted.YouByEnemy = enemy

	local pet = overlay:CreateTexture()
	pet:SetPoint(unpack(layout[prefix.."PetByEnemyPlace"]))
	pet:SetSize(unpack(layout[prefix.."PetByEnemySize"]))
	pet:SetTexture(layout[prefix.."PetByEnemyTexture"])
	pet:SetVertexColor(unpack(layout[prefix.."PetByEnemyColor"]))
	self.Targeted.PetByEnemy = pet

	-- Auras
	local auras = content:CreateFrame("Frame")
	auras:Place(unpack(layout.AuraFramePlace))
	auras:SetSize(unpack(layout.AuraFrameSize))
	for property,value in pairs(layout.AuraProperties) do 
		auras[property] = value
	end
	self.Auras = auras
	self.Auras.PostCreateButton = layout.Aura_PostCreateButton -- post creation styling
	self.Auras.PostUpdateButton = layout.Aura_PostUpdateButton -- post updates when something changes (even timers)

	-- Unit Name
	local name = overlay:CreateFontString()
	name:SetPoint(unpack(layout.NamePlace))
	name:SetDrawLayer(unpack(layout.NameDrawLayer))
	name:SetJustifyH(layout.NameJustifyH)
	name:SetJustifyV(layout.NameJustifyV)
	name:SetFontObject(layout.NameFont)
	name:SetTextColor(unpack(layout.NameColor))
	name.showLevel = true
	name.showLevelLast = true
	self.Name = name

	-- Health Value
	local healthValHolder = overlay:CreateFrame("Frame")
	healthValHolder:SetAllPoints(health)

	local healthVal = healthValHolder:CreateFontString()
	healthVal:SetPoint(unpack(layout.HealthValuePlace))
	healthVal:SetDrawLayer(unpack(layout.HealthValueDrawLayer))
	healthVal:SetJustifyH(layout.HealthValueJustifyH)
	healthVal:SetJustifyV(layout.HealthValueJustifyV)
	healthVal:SetFontObject(layout.HealthValueFont)
	healthVal:SetTextColor(unpack(layout.HealthValueColor))
	self.Health.Value = healthVal

	-- Health Percentage 
	local healthPerc = health:CreateFontString()
	healthPerc:SetPoint(unpack(layout.HealthPercentPlace))
	healthPerc:SetDrawLayer(unpack(layout.HealthPercentDrawLayer))
	healthPerc:SetJustifyH(layout.HealthPercentJustifyH)
	healthPerc:SetJustifyV(layout.HealthPercentJustifyV)
	healthPerc:SetFontObject(layout.HealthPercentFont)
	healthPerc:SetTextColor(unpack(layout.HealthPercentColor))
	self.Health.ValuePercent = healthPerc

	-- Update textures according to player level
	self.PostUpdateTextures = Target_PostUpdateTextures
	self:PostUpdateTextures()

	self:RegisterMessage("GP_UNITFRAME_TOT_VISIBLE", Target_PostUpdateName)
	self:RegisterMessage("GP_UNITFRAME_TOT_INVISIBLE", Target_PostUpdateName)
	self:RegisterMessage("GP_UNITFRAME_TOT_SHOWN", Target_PostUpdateName)
	self:RegisterMessage("GP_UNITFRAME_TOT_HIDDEN", Target_PostUpdateName)
end

UnitStyles.StyleToTFrame = function(self, unit, id, layout, ...)
	return StyleSmallFrame(self, unit, id, layout, ...)
end

UnitStyles.StylePetFrame = function(self, unit, id, layout, ...)
	return StyleSmallFrame(self, unit, id, layout, ...)
end

-----------------------------------------------------------
-- Grouped Unit Styling
-----------------------------------------------------------
-- Dummy counters for testing purposes only
local fakeBossId, fakePartyId, fakeRaidId = 0, 0, 0, 0

UnitStyles.StyleBossFrames = function(self, unit, id, layout, ...)
	if (not id) then 
		fakeBossId = fakeBossId + 1
		id = fakeBossId
	end 
	return StyleSmallFrame(self, unit, id, layout, ...)
end

UnitStyles.StylePartyFrames = function(self, unit, id, layout, ...)
	if (not id) then 
		fakePartyId = fakePartyId + 1
		id = fakePartyId
	end 
	return StylePartyFrame(self, unit, id, layout, ...)
end

UnitStyles.StyleRaidFrames = function(self, unit, id, layout, ...)
	if (not id) then 
		fakeRaidId = fakeRaidId + 1
		id = fakeRaidId
	end 
	return StyleRaidFrame(self, unit, id, layout, ...)
end

-----------------------------------------------------------
-----------------------------------------------------------
-- Modules
-----------------------------------------------------------
-----------------------------------------------------------

-----------------------------------------------------------
-- Player
-----------------------------------------------------------
UnitFramePlayer.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	self.frame = self:SpawnUnitFrame("player", "UICenter", function(frame, unit, id, _, ...)
		return UnitStyles.StylePlayerFrame(frame, unit, id, self.layout, ...)
	end)
end 

UnitFramePlayer.OnEnable = function(self)
	self:RegisterEvent("PLAYER_ALIVE", "OnEvent")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("DISABLE_XP_GAIN", "OnEvent")
	self:RegisterEvent("ENABLE_XP_GAIN", "OnEvent")
	self:RegisterEvent("PLAYER_LEVEL_UP", "OnEvent")
	self:RegisterEvent("PLAYER_XP_UPDATE", "OnEvent")
end

UnitFramePlayer.OnEvent = function(self, event, ...)
	if (event == "PLAYER_LEVEL_UP") then 
		local level = ...
		if (level and (level ~= PlayerLevel)) then
			PlayerLevel = level
		else
			local level = UnitLevel("player")
			if (level ~= PlayerLevel) then
				PlayerLevel = level
			end
		end
	end
	self.frame:PostUpdateTextures(PlayerLevel)
end

UnitFramePlayerHUD.OnInit = function(self)
	self.db = GetConfig(self:GetName())
	self.layout = GetLayout(self:GetName())
	self.frame = self:SpawnUnitFrame("player", "UICenter", function(frame, unit, id, _, ...)
		return UnitStyles.StylePlayerHUDFrame(frame, unit, id, self.layout, ...)
	end)

	-- Create a secure proxy updater for the menu system
	local callbackFrame = CreateSecureCallbackFrame(self, self.frame, self.db, SECURE.HUD_SecureCallback)
	callbackFrame:SetAttribute("forceDisableClassPower", self:IsAddOnEnabled("SimpleClassPower"))
end 

UnitFramePlayerHUD.OnEnable = function(self)
	if (not self.db.enableCast) then 
		self.frame:DisableElement("Cast")
	end
	if (not self.db.enableClassPower) or (self:IsAddOnEnabled("SimpleClassPower")) then 
		self.frame:DisableElement("ClassPower")
	end
end

-----------------------------------------------------------
-- Target
-----------------------------------------------------------
UnitFrameTarget.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	self.frame = self:SpawnUnitFrame("target", "UICenter", function(frame, unit, id, _, ...)
		return UnitStyles.StyleTargetFrame(frame, unit, id, self.layout, ...)
	end)
end 

UnitFrameTarget.OnEnable = function(self)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent")
end

UnitFrameTarget.OnEvent = function(self, event, ...)
	if (event == "PLAYER_TARGET_CHANGED") then
		if UnitExists("target") then
			-- Play a fitting sound depending on what kind of target we gained
			if UnitIsEnemy("target", "player") then
				self:PlaySoundKitID(SOUNDKIT.IG_CREATURE_AGGRO_SELECT, "SFX")
			elseif UnitIsFriend("player", "target") then
				self:PlaySoundKitID(SOUNDKIT.IG_CHARACTER_NPC_SELECT, "SFX")
			else
				self:PlaySoundKitID(SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT, "SFX")
			end
			self.frame:PostUpdateTextures()
		else
			-- Play a sound indicating we lost our target
			self:PlaySoundKitID(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT, "SFX")
		end
	end
end

-----------------------------------------------------------
-- Pet
-----------------------------------------------------------
UnitFramePet.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	self.frame = self:SpawnUnitFrame("pet", "UICenter", function(frame, unit, id, _, ...)
		return UnitStyles.StylePetFrame(frame, unit, id, self.layout, ...)
	end)

	-- Pet Happiness
	local GetPetHappiness = GetPetHappiness
	local HasPetUI = HasPetUI

	-- Parent it to the pet frame, so its visibility and fading follows that automatically. 
	local happyContainer = CreateFrame("Frame", nil, self.frame)
	local happy = happyContainer:CreateFontString()
	happy:SetFontObject(Private.GetFont(12,true))
	happy:SetPoint("BOTTOM", self:GetFrame("UICenter"), "BOTTOM", 0, 10)
	happy.msg = "|cffffffff"..HAPPINESS..":|r %s |cff888888(%s)|r |cffffffff- "..STAT_DPS_SHORT..":|r %s"
	happy.msgShort = "|cffffffff"..HAPPINESS..":|r %s |cffffffff- "..STAT_DPS_SHORT..":|r %s"

	happy.Update = function(element)

		local happiness, damagePercentage, loyaltyRate = GetPetHappiness()
		local _, hunterPet = HasPetUI()
		if (not (happiness or hunterPet)) then
			return element:Hide()
		end

		-- Happy
		local level, damage
		if (happiness == 3) then
			level = "|cff20c000" .. PET_HAPPINESS3 .. "|r"
			damage = "|cff20c000" .. damagePercentage .. "|r"

		-- Content
		elseif (happiness == 2) then
			level = "|cfffe8a0e" .. PET_HAPPINESS2 .. "|r"
			damage = "|cfffe8a0e" .. damagePercentage .. "|r"

		-- Unhappy
		else
			level = "|cffff0303" .. PET_HAPPINESS1 .. "|r"
			damage = "|cffff0303" .. damagePercentage .. "|r"
		end

		if (loyaltyRate and (loyaltyRate > 0)) then 
			element:SetFormattedText(element.msg, level, loyaltyRate, damage)
		else 
			element:SetFormattedText(element.msgShort, level, damage)
		end 

		element:Show()
	end

	happyContainer:SetScript("OnEvent", function(self, event, ...) 
		happy:Update()
	end)

	happyContainer:RegisterEvent("PLAYER_ENTERING_WORLD")
	happyContainer:RegisterEvent("PET_UI_UPDATE")
	happyContainer:RegisterEvent("UNIT_HAPPINESS")
	happyContainer:RegisterUnitEvent("UNIT_PET", "player")
end 

-----------------------------------------------------------
-- Target of Target
-----------------------------------------------------------
UnitFrameToT.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	self.frame = self:SpawnUnitFrame("targettarget", "UICenter", function(frame, unit, id, _, ...)
		return UnitStyles.StyleToTFrame(frame, unit, id, self.layout, ...)
	end)
	self.frame:HookScript("OnShow", function(self) self:SendMessage("GP_UNITFRAME_TOT_SHOWN") end)
	self.frame:HookScript("OnHide", function(self) self:SendMessage("GP_UNITFRAME_TOT_HIDDEN") end)
end 

-----------------------------------------------------------
-- Party
-----------------------------------------------------------
UnitFrameParty.OnInit = function(self)
	local dev --= true

	self.db = GetConfig(self:GetName())
	self.layout = GetLayout(self:GetName())
	
	self.frame = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	self.frame:SetSize(unpack(self.layout.Size))
	self.frame:Place(unpack(self.layout.Place))
	
	self.frame.healerAnchor = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	self.frame.healerAnchor:SetSize(unpack(self.layout.Size))
	self.frame.healerAnchor:Place(unpack(self.layout.AlternatePlace)) 
	self.frame:SetFrameRef("HealerModeAnchor", self.frame.healerAnchor)

	self.frame:Execute(SECURE.FrameTable_Create)
	self.frame:SetAttribute("inHealerMode", GetConfig(ADDON).enableHealerMode)
	self.frame:SetAttribute("sortFrames", SECURE.Party_SortFrames:format(
		self.layout.GroupAnchor, 
		self.layout.GrowthX, 
		self.layout.GrowthY, 
		self.layout.AlternateGroupAnchor, 
		self.layout.AlternateGrowthX, 
		self.layout.AlternateGrowthY 
	))
	self.frame:SetAttribute("_onattributechanged", SECURE.Party_OnAttribute)

	-- Hide it in raids of 6 or more players 
	-- Use an attribute driver to do it so the normal unitframe visibility handler can remain unchanged
	local visDriver = dev and "[@player,exists]show;hide" or "[@raid6,exists]hide;[group]show;hide"
	if (self.db.enablePartyFrames) then 
		RegisterAttributeDriver(self.frame, "state-vis", visDriver)
	else 
		RegisterAttributeDriver(self.frame, "state-vis", "hide")
	end 

	local style = function(frame, unit, id, _, ...)
		return UnitStyles.StylePartyFrames(frame, unit, id, self.layout, ...)
	end

	for i = 1,4 do 
		local frame = self:SpawnUnitFrame(dev and "player" or "party"..i, self.frame, style)

		-- Reference the frame in Lua
		self.frame[tostring(i)] = frame

		-- Reference the frame in the secure environment
		self.frame:SetFrameRef("CurrentFrame", frame)
		self.frame:Execute(SECURE.FrameTable_InsertCurrentFrame)
	end 

	self.frame:Execute(self.frame:GetAttribute("sortFrames"))

	-- Create a secure proxy updater for the menu system
	CreateSecureCallbackFrame(self, self.frame, self.db, SECURE.Party_SecureCallback:format(visDriver))
end 

-----------------------------------------------------------
-- Raid
-----------------------------------------------------------
UnitFrameRaid.OnInit = function(self)
	local dev --= true

	self.db = GetConfig(self:GetName())
	self.layout = GetLayout(self:GetName())

	self.frame = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	self.frame:SetSize(1,1)
	self.frame:Place(unpack(self.layout.Place)) 
	self.frame.healerAnchor = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	self.frame.healerAnchor:SetSize(1,1)
	self.frame.healerAnchor:Place(unpack(self.layout.AlternatePlace)) 
	self.frame:SetFrameRef("HealerModeAnchor", self.frame.healerAnchor)
	self.frame:Execute(SECURE.FrameTable_Create)
	self.frame:SetAttribute("inHealerMode", GetConfig(ADDON).enableHealerMode)
	self.frame:SetAttribute("sortFrames", SECURE.Raid_SortFrames:format(
		self.layout.GroupSizeNormal, 
		self.layout.GrowthXNormal,
		self.layout.GrowthYNormal,
		self.layout.GrowthYNormalHealerMode,
		self.layout.GroupGrowthXNormal,
		self.layout.GroupGrowthYNormal,
		self.layout.GroupGrowthYNormalHealerMode,
		self.layout.GroupColsNormal,
		self.layout.GroupRowsNormal,
		self.layout.GroupAnchorNormal, 
		self.layout.GroupAnchorNormalHealerMode, 

		self.layout.GroupSizeEpic,
		self.layout.GrowthXEpic,
		self.layout.GrowthYEpic,
		self.layout.GrowthYEpicHealerMode,
		self.layout.GroupGrowthXEpic,
		self.layout.GroupGrowthYEpic,
		self.layout.GroupGrowthYEpicHealerMode,
		self.layout.GroupColsEpic,
		self.layout.GroupRowsEpic,
		self.layout.GroupAnchorEpic,
		self.layout.GroupAnchorEpicHealerMode
	))
	self.frame:SetAttribute("_onattributechanged", SECURE.Raid_OnAttribute)

	if (not self.db.allowBlizzard) then 
		self:DisableUIWidget("UnitFrameRaid") 
	end

	-- Only show it in raids of 6 or more players 
	-- Use an attribute driver to do it so the normal unitframe visibility handler can remain unchanged
	local visDriver = dev and "[@player,exists]show;hide" or "[@raid6,exists]show;hide"
	RegisterAttributeDriver(self.frame, "state-vis", self.db.enableRaidFrames and visDriver or "hide")

	local style = function(frame, unit, id, _, ...)
		return UnitStyles.StyleRaidFrames(frame, unit, id, self.layout, ...)
	end
	for i = 1,40 do 
		local frame = self:SpawnUnitFrame(dev and "player" or "raid"..i, self.frame, style)
		self.frame[tostring(i)] = frame
		self.frame:SetFrameRef("CurrentFrame", frame)
		self.frame:Execute(SECURE.FrameTable_InsertCurrentFrame)
	end 

	-- Register the layout driver
	RegisterAttributeDriver(self.frame, "state-layout", dev and "[@target,exists]epic;normal" or "[@raid26,exists]epic;normal")

	-- Create a secure proxy updater for the menu system
	CreateSecureCallbackFrame(self, self.frame, self.db, SECURE.Raid_SecureCallback:format(visDriver))
end 

-----------------------------------------------------------
-- Boss
-----------------------------------------------------------
-- These don't really exist in classic, right?
UnitFrameBoss.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	self.frame = {}

	local style = function(frame, unit, id, _, ...)
		return UnitStyles.StyleBossFrames(frame, unit, id, self.layout, ...)
	end
	for i = 1,5 do 
		self.frame[tostring(i)] = self:SpawnUnitFrame("boss"..i, "UICenter", style)
	end 
end 
