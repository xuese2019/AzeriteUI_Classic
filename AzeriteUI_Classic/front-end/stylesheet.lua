--[[--

The purpose of this file is to supply all the front-end modules 
with static layout data used during the setup phase. 

--]]--

local ADDON, Private = ...
local L = Wheel("LibLocale"):GetLocale(ADDON)
local LibDB = Wheel("LibDB")

------------------------------------------------
-- Addon Environment
------------------------------------------------
-- Lua API
local _G = _G
local math_ceil = math.ceil
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_pi = math.pi 
local math_sin = math.sin
local setmetatable = setmetatable
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match
local string_upper = string.upper
local tonumber = tonumber
local tostring = tostring
local unpack = unpack

-- WoW API
local GetCVarDefault = GetCVarDefault
local UnitCanAttack = UnitCanAttack
local UnitClassification = UnitClassification
local UnitCreatureType = UnitCreatureType
local UnitExists = UnitExists
local UnitCastingInfo = CastingInfo
local UnitChannelInfo = ChannelInfo
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsEnemy = UnitIsEnemy
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitLevel = UnitLevel

-- Private Addon API
local GetAuraFilterFunc = Private.GetAuraFilterFunc
local GetFont = Private.GetFont
local GetMedia = Private.GetMedia
local Colors = Private.Colors

-- Just because we repeat them so many times
local MenuButtonFontSize, MenuButtonW, MenuButtonH = 14, 300, 50

-- Generic single colored texture
local BLANK_TEXTURE = [[Interface\ChatFrame\ChatFrameBackground]]

-- Use a metatable to dynamically create the colors
local spellTypeColor = setmetatable({
	["Custom"] = { 1, .9294, .7607 } 
}, { __index = function(tbl,key)
		local v = DebuffTypeColor[key]
		if v then
			tbl[key] = { v.r, v.g, v.b }
			return tbl[key]
		end
	end
})

------------------------------------------------
-- Utility Functions
------------------------------------------------
local degreesToRadiansConstant = 360 * 2*math_pi
local degreesToRadians = function(degrees)
	return degrees/degreesToRadiansConstant
end 

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

------------------------------------------------
-- Module Callbacks
------------------------------------------------
-- Not really following any plan here,
-- except trying to keep anything related to
-- styling out of the module front-end code.
local Core_Window_CreateBorder = function(self)
	local mod = 1 -- .75
	local border = self:CreateFrame("Frame")
	border:SetFrameLevel(self:GetFrameLevel()-1)
	border:SetPoint("TOPLEFT", -6, 8)
	border:SetPoint("BOTTOMRIGHT", 6, -8)
	border:SetBackdrop({
		bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
		edgeFile = GetMedia("tooltip_border_blizzcompatible"),
		edgeSize = 32, 
		tile = false, 
		insets = { 
			top = 9, 
			bottom = 9, 
			left = 9, 
			right = 9 
		}
	})
	border:SetBackdropBorderColor(1, 1, 1, 1)
	border:SetBackdropColor(.05, .05, .05, .85)

	return border
end

local Core_Window_OnHide = function(self)
	self:GetParent():Update()
end

local Core_Window_OnShow = function(self)
	self:GetParent():Update()
end

local Core_MenuButton_PostCreate = function(self, text, ...)
	local msg = self:CreateFontString()
	msg:SetPoint("CENTER", 0, 0)
	msg:SetFontObject(GetFont(MenuButtonFontSize, false))
	msg:SetJustifyH("RIGHT")
	msg:SetJustifyV("TOP")
	msg:SetIndentedWordWrap(false)
	msg:SetWordWrap(false)
	msg:SetNonSpaceWrap(false)
	msg:SetTextColor(0,0,0)
	msg:SetShadowOffset(0, -.85)
	msg:SetShadowColor(1,1,1,.5)
	msg:SetText(text)
	self.Msg = msg

	local bg = self:CreateTexture()
	bg:SetDrawLayer("ARTWORK")
	bg:SetTexture(GetMedia("menu_button_disabled"))
	bg:SetVertexColor(.9, .9, .9)
	bg:SetSize(1024 *1/3 *.75, 256 *1/3 *.75)
	bg:SetPoint("CENTER", msg, "CENTER", 0, 0)
	self.NormalBackdrop = bg

	local pushed = self:CreateTexture()
	pushed:SetDrawLayer("ARTWORK")
	pushed:SetTexture(GetMedia("menu_button_pushed"))
	pushed:SetVertexColor(.9, .9, .9)
	pushed:SetSize(1024 *1/3 *.75, 256 *1/3 *.75)
	pushed:SetPoint("CENTER", msg, "CENTER", 0, 0)
	self.PushedBackdrop = pushed

	local arrowUp = self:CreateTexture()
	arrowUp:Hide()
	arrowUp:SetDrawLayer("OVERLAY")
	arrowUp:SetSize(20,20)
	arrowUp:SetTexture([[Interface\BUTTONS\Arrow-Down-Down]])
	arrowUp:SetDesaturated(true)
	arrowUp:SetTexCoord(0,1,1,1,0,0,1,0) 
	arrowUp:SetPoint("LEFT", 2, 1)
	self.ArrowUp = arrowUp

	local arrowDown = self:CreateTexture()
	arrowDown:Hide()
	arrowDown:SetDrawLayer("OVERLAY")
	arrowDown:SetSize(20,20)
	arrowDown:SetTexture([[Interface\BUTTONS\Arrow-Down-Down]])
	arrowDown:SetTexCoord(0,1,1,1,0,0,1,0) 
	arrowDown:SetPoint("LEFT", 2, -1)
	self.ArrowDown = arrowDown

	return self
end

local Core_MenuButton_PostCreate_Scaled = function(self, text, ...)
	local msg = self:CreateFontString()
	msg:SetPoint("CENTER", 0, 0)
	msg:SetFontObject(GetFont(MenuButtonFontSize, false))
	msg:SetJustifyH("RIGHT")
	msg:SetJustifyV("TOP")
	msg:SetIndentedWordWrap(false)
	msg:SetWordWrap(false)
	msg:SetNonSpaceWrap(false)
	msg:SetTextColor(0,0,0)
	msg:SetShadowOffset(0, -.85)
	msg:SetShadowColor(1,1,1,.5)
	msg:SetText(text)
	self.Msg = msg

	local bg = self:CreateTexture()
	bg:SetDrawLayer("ARTWORK")
	bg:SetTexture(GetMedia("menu_button_disabled"))
	bg:SetVertexColor(.9, .9, .9)
	bg:SetSize(1024 *1/3 *.75, 256 *1/3 *.75)
	bg:SetPoint("CENTER", msg, "CENTER", 0, 0)
	self.NormalBackdrop = bg

	local pushed = self:CreateTexture()
	pushed:SetDrawLayer("ARTWORK")
	pushed:SetTexture(GetMedia("menu_button_pushed"))
	pushed:SetVertexColor(.9, .9, .9)
	pushed:SetSize(1024 *1/3 *.75, 256 *1/3 *.75)
	pushed:SetPoint("CENTER", msg, "CENTER", 0, 0)
	self.PushedBackdrop = pushed

	local arrowUp = self:CreateTexture()
	arrowUp:Hide()
	arrowUp:SetDrawLayer("OVERLAY")
	arrowUp:SetSize(20,20)
	arrowUp:SetTexture([[Interface\BUTTONS\Arrow-Down-Down]])
	arrowUp:SetDesaturated(true)
	arrowUp:SetTexCoord(0,1,1,1,0,0,1,0) 
	arrowUp:SetPoint("LEFT", 2, 1)
	self.ArrowUp = arrowUp

	local arrowDown = self:CreateTexture()
	arrowDown:Hide()
	arrowDown:SetDrawLayer("OVERLAY")
	arrowDown:SetSize(20,20)
	arrowDown:SetTexture([[Interface\BUTTONS\Arrow-Down-Down]])
	arrowDown:SetTexCoord(0,1,1,1,0,0,1,0) 
	arrowDown:SetPoint("LEFT", 2, -1)
	self.ArrowDown = arrowDown

	return self
end

local Core_MenuButton_Layers_PostUpdate = function(self)
	local isPushed = self.isDown or self.isChecked or self.windowIsShown
	local show = isPushed and self.PushedBackdrop or self.NormalBackdrop
	local hide = isPushed and self.NormalBackdrop or self.PushedBackdrop

	hide:SetAlpha(0)
	show:SetAlpha(1)

	if isPushed then
		self.ArrowDown:SetShown(self.hasWindow)
		self.ArrowUp:Hide()
		self.Msg:SetPoint("CENTER", 0, -2)
		if self:IsMouseOver() then
			show:SetVertexColor(1, 1, 1)
		elseif (self.isChecked or self.windowIsShown) then 
			show:SetVertexColor(.9, .9, .9)
		else
			show:SetVertexColor(.75, .75, .75)
		end
	else
		self.ArrowDown:Hide()
		self.ArrowUp:SetShown(self.hasWindow)
		self.Msg:SetPoint("CENTER", 0, 0)
		if self:IsMouseOver() then
			show:SetVertexColor(1, 1, 1)
		else
			show:SetVertexColor(.75, .75, .75)
		end
	end
end

local Core_MenuButton_PostUpdate = function(self, updateType, db, option, checked)
	if (updateType == "GET_VALUE") then 
	elseif (updateType == "SET_VALUE") then 
		if checked then 
			self.isChecked = true
		else
			self.isChecked = false
		end 
	elseif (updateType == "TOGGLE_VALUE") then 
		if option then 
			self.Msg:SetText(self.enabledTitle or L["Disable"])
			self.isChecked = true
		else 
			self.Msg:SetText(self.disabledTitle or L["Enable"])
			self.isChecked = false
		end 
	elseif (updateType == "TOGGLE_MODE") then 
		if option then 
			self.Msg:SetText(self.enabledTitle or L["Disable"])
			self.isChecked = true
		else 
			self.Msg:SetText(self.disabledTitle or L["Enable"])
			self.isChecked = false
		end 
	end 
	Core_MenuButton_Layers_PostUpdate(self, updateType, db, option, checked)
end

-- ActionButton stack/charge count Post Update
local ActionButton_StackCount_PostUpdate = function(self, count)
	count = tonumber(count) or 0
	local font = GetFont((count < 10) and 18 or 14, true) 
	if (self.Count:GetFontObject() ~= font) then 
		self.Count:SetFontObject(font)
	end
	-- Hide the rank text element if a count exists. 
	-- I don't think this'll ever happen (?), 
	-- but better safe than sorry. 
	if self.Rank then 
		self.Rank:SetShown((count == 0))
	end 
end

-- General bind mode border creation method
local BindMode_MenuWindow_CreateBorder = Core_Window_CreateBorder

-- Binding Dialogue MenuButton
local BindMode_MenuButton_PostCreate = Core_MenuButton_PostCreate
local BindMode_MenuButton_PostUpdate = Core_MenuButton_Layers_PostUpdate

-- BindButton PostCreate 
local BindMode_BindButton_PostCreate = function(self)
	self.bg:ClearAllPoints()
	self.bg:SetPoint("CENTER", 0, 0)
	self.bg:SetTexture(GetMedia("actionbutton_circular_mask"))
	self.bg:SetSize(64 + 8, 64 + 8) -- icon is 44, 44
	self.bg:SetVertexColor(.4, .6, .9, .75)
	self.msg:SetFontObject(GetFont(16, true))
end

-- BindButton PostUpdate
local BindMode_BindButton_PostUpdate = function(self)
	self.bg:SetVertexColor(.4, .6, .9, .75)
end

-- BindButton PostEnter graphic updates 
local BindMode_BindButton_PostEnter = function(self)
	self.bg:SetVertexColor(.4, .6, .9, 1)
end

-- BindButton PostLeave graphic updates
local BindMode_BindButton_PostLeave = function(self)
	self.bg:SetVertexColor(.4, .6, .9, .75)
end

-- Blizzard GameMenu Button Post Updates
local Blizzard_GameMenu_Button_PostCreate = Core_MenuButton_PostCreate 
local Blizzard_GameMenu_Button_PostUpdate = Core_MenuButton_Layers_PostUpdate

-- Blizzard MicroMenu Button Post Updates
local BlizzardMicroMenu_Button_PostCreate = Core_MenuButton_PostCreate
local BlizzardMicroMenu_Button_PostUpdate = Core_MenuButton_Layers_PostUpdate

-- Blizzard Popup PostCreate styling
local BlizzardPopup_PostCreate = function(self, popup)
	popup:SetBackdrop(nil)
	popup:SetBackdropColor(0,0,0,0)
	popup:SetBackdropBorderColor(0,0,0,0)

	-- 8.2.0 Additions
	if (popup.Border) then 
		popup.Border:Hide()
		popup.Border:SetAlpha(0)
	end

	-- add a bigger backdrop frame with room for our larger buttons
	if (not popup.backdrop) then
		local backdrop = CreateFrame("Frame", nil, popup)
		backdrop:SetFrameLevel(popup:GetFrameLevel())
		backdrop:SetPoint("TOPLEFT", -10, 10)
		backdrop:SetPoint("BOTTOMRIGHT", 10, -10)
		popup.backdrop = backdrop
	end	

	local backdrop = popup.backdrop
	backdrop:SetBackdrop({
		bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
		edgeFile = GetMedia("tooltip_border_blizzcompatible"),
		edgeSize = 32, 
		tile = false, -- tiles don't tile vertically (?)
		--tile = true, tileSize = 256, 
		insets = { top = 2.5, bottom = 2.5, left = 2.5, right = 2.5 }
	})
	backdrop:SetBackdropColor(.05, .05, .05, .85)
	backdrop:SetBackdropBorderColor(1,1,1,1)

	-- remove button artwork
	for i = 1,4 do
		local button = popup["button"..i]
		if button then
			button:GetNormalTexture():SetVertexColor(0, 0, 0, 0)
			button:GetHighlightTexture():SetVertexColor(0, 0, 0, 0)
			button:GetPushedTexture():SetVertexColor(0, 0, 0, 0)
			button:GetDisabledTexture():SetVertexColor(0, 0, 0, 0)
			button:SetBackdrop(nil)
			button:SetBackdropColor(0,0,0,0)
			button:SetBackdropBorderColor(0,0,0.0)

			-- Create our own custom border.
			-- Using our new thick tooltip border, just scaled down slightly.
			local sizeMod = 3/4
			local border = CreateFrame("Frame", nil, button)
			border:SetFrameLevel(button:GetFrameLevel() - 1)
			border:SetPoint("TOPLEFT", -23*sizeMod, 23*sizeMod -2)
			border:SetPoint("BOTTOMRIGHT", 23*sizeMod, -23*sizeMod -2)
			border:SetBackdrop({
				bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
				edgeFile = GetMedia("tooltip_border"),
				edgeSize = 32*sizeMod,
				insets = {
					left = 22*sizeMod,
					right = 22*sizeMod,
					top = 22*sizeMod +2,
					bottom = 22*sizeMod -2
				}
			})
			border:SetBackdropColor(.05, .05, .05, .75)
			border:SetBackdropBorderColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
		
			button:HookScript("OnEnter", function() 
				button:SetBackdropColor(0,0,0,0)
				button:SetBackdropBorderColor(0,0,0.0)
				border:SetBackdropColor(.1, .1, .1, .75)
				border:SetBackdropBorderColor(Colors.highlight[1], Colors.highlight[2], Colors.highlight[3])
			end)

			button:HookScript("OnLeave", function() 
				button:SetBackdropColor(0,0,0,0)
				button:SetBackdropBorderColor(0,0,0.0)
				border:SetBackdropColor(.05, .05, .05, .75)
				border:SetBackdropBorderColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
			end)
		end
	end

	-- remove editbox artwork
	local name = popup:GetName()

	local editbox = _G[name .. "EditBox"]
	local editbox_left = _G[name .. "EditBoxLeft"]
	local editbox_mid = _G[name .. "EditBoxMid"]
	local editbox_right = _G[name .. "EditBoxRight"]

	-- these got added in... uh... cata?
	if editbox_left then editbox_left:SetTexture(nil) end
	if editbox_mid then editbox_mid:SetTexture(nil) end
	if editbox_right then editbox_right:SetTexture(nil) end

	editbox:SetBackdrop(nil)
	editbox:SetBackdrop({
		bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
		edgeFile = [[Interface\ChatFrame\ChatFrameBackground]],
		edgeSize = 1,
		tile = false,
		tileSize = 0,
		insets = {
			left = -6,
			right = -6,
			top = 0,
			bottom = 0
		}
	})
	editbox:SetBackdropColor(0, 0, 0, 0)
	editbox:SetBackdropBorderColor(.15, .1, .05, 1)
	editbox:SetTextInsets(6,6,0,0)
end

-- Blizzard Popup anchor points post updates
local BlizzardPopup_Anchors_PostUpdate = function(self)
	local previous
	for i = 1, _G.STATICPOPUP_NUMDIALOGS do
		local popup = _G["StaticPopup"..i]
		local point, anchor, rpoint, x, y = popup:GetPoint()
		if (anchor == previous) then
			-- We only change the offsets values, not the anchor points, 
			-- since experience tells me that this is a safer way to avoid potential taint!
			popup:ClearAllPoints()
			popup:SetPoint(point, anchor, rpoint, 0, -32)
		end
		previous = popup
	end
end

-- Group Tools Menu Button Creation 
local GroupTools_Button_PostCreate = function(self) end 

-- Group Tools Menu Button Disable
local GroupTools_Button_OnDisable = function(self) end

-- Group Tools Menu Button Enable
local GroupTools_Button_OnEnable = function(self) end

-- Group Tools Menu Window Border
local GroupTools_Window_CreateBorder = function(self)
	local mod = 1 -- not .75 as the rest?
	local border = self:CreateFrame("Frame")
	border:SetFrameLevel(self:GetFrameLevel()-1)
	border:SetPoint("TOPLEFT", -23*mod, 23*mod)
	border:SetPoint("BOTTOMRIGHT", 23*mod, -23*mod)
	border:SetBackdrop({
		bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
		edgeFile = GetMedia("tooltip_border"),
		edgeSize = 32*mod, 
		tile = false, 
		insets = { 
			top = 23*mod, 
			bottom = 23*mod, 
			left = 23*mod, 
			right = 23*mod 
		}
	})
	border:SetBackdropBorderColor(1, 1, 1, 1)
	border:SetBackdropColor(.05, .05, .05, .85)

	return border
end

local Minimap_Clock_OverrideValue = function(element, h, m, suffix)
	element:SetFormattedText(getTimeStrings(h, m, suffix, element.useStandardTime, true))
end 

local Minimap_Coordinates_OverrideValue = function(element, x, y)
	local xval = string_gsub(string_format("%.1f", x*100), "%.(.+)", "|cff888888.%1|r")
	local yval = string_gsub(string_format("%.1f", y*100), "%.(.+)", "|cff888888.%1|r")
	element:SetFormattedText("%s %s", xval, yval) 
end 

local Minimap_FrameRate_OverrideValue = function(element, fps)
	element:SetFormattedText("|cff888888%.0f %s|r", math_floor(fps), string_upper(string_match(FPS_ABBR, "^.")))
end 

local Minimap_Latency_OverrideValue = function(element, home, world)
	element:SetFormattedText("|cff888888%s|r %.0f - |cff888888%s|r %.0f", string_upper(string_match(HOME, "^.")), math_floor(home), string_upper(string_match(WORLD, "^.")), math_floor(world))
end 

local Minimap_RingFrame_SingleRing_ValueFunc = function(Value, Handler) 
	Value:ClearAllPoints()
	Value:SetPoint("BOTTOM", Handler.Toggle.Frame.Bg, "CENTER", 2, -2)
	Value:SetFontObject(GetFont(24, true)) 
end

local Minimap_RingFrame_OuterRing_ValueFunc = function(Value, Handler) 
	Value:ClearAllPoints()
	Value:SetPoint("TOP", Handler.Toggle.Frame.Bg, "CENTER", 1, -2)
	Value:SetFontObject(GetFont(16, true)) 
	Value.Description:Hide()
end

local Minimap_Performance_PlaceFunc = function(performanceFrame, Handler)
	performanceFrame:ClearAllPoints()
	performanceFrame:SetPoint("TOPLEFT", Handler.Latency, "TOPLEFT", 0, 0)
	performanceFrame:SetPoint("BOTTOMRIGHT", Handler.FrameRate, "BOTTOMRIGHT", 0, 0)
end

local Minimap_Performance_Latency_PlaceFunc = function(Handler) 
	return "BOTTOMRIGHT", Handler.Zone, "TOPRIGHT", 0, 6 
end

local Minimap_Performance_FrameRate_PlaceFunc = function(Handler) 
	return "BOTTOM", Handler.Clock, "TOP", 0, 6 
end 

local Minimap_Rep_OverrideValue = function(element, current, min, max, factionName, standingID, standingLabel)
	local value = element.Value or element:IsObjectType("FontString") and element 
	local barMax = max - min 
	local barValue = current - min
	if value.showDeficit then 
		if (barMax - barValue > 0) then 
			value:SetFormattedText(short(barMax - barValue))
		else 
			value:SetText("100%")
		end 
	else 
		value:SetFormattedText(short(current - min))
	end
	local percent = value.Percent
	if percent then 
		if (max - min > 0) then 
			local percValue = math_floor((current - min)/(max - min)*100)
			if (percValue > 0) then 
				-- removing the percentage sign
				percent:SetFormattedText("%.0f", percValue)
			else 
				percent:SetText(NEW) 
			end 
		else 
			percent:SetText(NEW) 
		end 
	end 
	if element.colorValue then 
		local color = element._owner.colors.reaction[standingID]
		value:SetTextColor(color[1], color[2], color[3])
		if percent then 
			percent:SetTextColor(color[1], color[2], color[3])
		end 
	end 
end

local Minimap_XP_OverrideValue = function(element, min, max, restedLeft, restedTimeLeft)
	local value = element.Value or element:IsObjectType("FontString") and element 
	if value.showDeficit then 
		value:SetFormattedText(short(max - min))
	else 
		value:SetFormattedText(short(min))
	end
	local percent = value.Percent
	if percent then 
		if (max > 0) then 
			local percValue = math_floor(min/max*100)
			if (percValue > 0) then 
				-- removing the percentage sign
				percent:SetFormattedText("%.0f", percValue)
			else 
				percent:SetText(NEW)
			end 
		else 
			percent:SetText(NEW)
		end 
	end 
	if element.colorValue then 
		local color
		if restedLeft then 
			local colors = element._owner.colors
			color = colors.restedValue or colors.rested or colors.xpValue or colors.xp
		else 
			local colors = element._owner.colors
			color = colors.xpValue or colors.xp
		end 
		value:SetTextColor(color[1], color[2], color[3])
		if percent then 
			percent:SetTextColor(color[1], color[2], color[3])
		end 
	end 
end 

local Minimap_ZoneName_PlaceFunc = function(Handler) 
	return "BOTTOMRIGHT", Handler.Clock, "BOTTOMLEFT", -8, 0 
end

local NamePlates_RaidTarget_PostUpdate = function(element, unit)
	local self = element._owner
	if self:IsElementEnabled("Auras") then 
		self.Auras:ForceUpdate()
	else 
		element:ClearAllPoints()
		element:SetPoint(unpack(self.layout.RaidTargetPlace))
	end 
end

local NamePlates_Auras_PostCreateButton = function(element, button)
	local layout = element._owner.layout

	button.Icon:SetTexCoord(unpack(layout.AuraIconTexCoord))
	button.Icon:SetSize(unpack(layout.AuraIconSize))
	button.Icon:ClearAllPoints()
	button.Icon:SetPoint(unpack(layout.AuraIconPlace))

	button.Count:SetFontObject(layout.AuraCountFont)
	button.Count:SetJustifyH("CENTER")
	button.Count:SetJustifyV("MIDDLE")
	button.Count:ClearAllPoints()
	button.Count:SetPoint(unpack(layout.AuraCountPlace))
	button.Count:SetTextColor(unpack(layout.AuraCountColor))

	button.Time:SetFontObject(layout.AuraTimeFont)
	button.Time:ClearAllPoints()
	button.Time:SetPoint(unpack(layout.AuraTimePlace))

	local layer, level = button.Icon:GetDrawLayer()

	button.Darken = button.Darken or button:CreateTexture()
	button.Darken:SetDrawLayer(layer, level + 1)
	button.Darken:SetSize(button.Icon:GetSize())
	button.Darken:SetPoint("CENTER", 0, 0)
	button.Darken:SetColorTexture(0, 0, 0, .25)

	button.Overlay:SetFrameLevel(button:GetFrameLevel() + 10)
	button.Overlay:ClearAllPoints()
	button.Overlay:SetPoint("CENTER", 0, 0)
	button.Overlay:SetSize(button.Icon:GetSize())

	button.Border = button.Border or button.Overlay:CreateFrame("Frame", nil, button.Overlay)
	button.Border:SetFrameLevel(button.Overlay:GetFrameLevel() - 5)
	button.Border:ClearAllPoints()
	button.Border:SetPoint(unpack(layout.AuraBorderFramePlace))
	button.Border:SetSize(unpack(layout.AuraBorderFrameSize))
	button.Border:SetBackdrop(layout.AuraBorderBackdrop)
	button.Border:SetBackdropColor(unpack(layout.AuraBorderBackdropColor))
	button.Border:SetBackdropBorderColor(unpack(layout.AuraBorderBackdropBorderColor))
end

local NamePlates_Auras_PostUpdateButton = function(element, button)
	local colors = element._owner.colors
	local layout = element._owner.layout
	if UnitIsFriend("player", button.unit) then 
		if button.isBuff then 
			local color = layout.AuraBorderBackdropBorderColor
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			end 
		else
			local color = colors.debuff[button.debuffType or "none"] or layout.AuraBorderBackdropBorderColor
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			end 
		end
	else 
		if button.isStealable then 
			local color = colors.power.ARCANE_CHARGES or layout.AuraBorderBackdropBorderColor
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			end 
		elseif button.isBuff then 
			local color = colors.quest.green or layout.AuraBorderBackdropBorderColor
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			end 
		else
			local color = colors.debuff[button.debuffType or "none"] or layout.AuraBorderBackdropBorderColor
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			end 
		end
	end 
end

local NamePlates_Auras_PostUpdate = function(element, unit, visible)
	local self = element._owner
	if (not self) then 
		return 
	end 

	element:ClearAllPoints()
	if element.point then 
		element:SetPoint(element.point, element.anchor, element.relPoint, element.offsetX, element.offsetY)
	else 
		element:SetPoint(unpack(self.layout.AuraFramePlace))
	end 

	local raidTarget = self.RaidTarget
	if raidTarget then 
		raidTarget:ClearAllPoints()
		if visible then
			if visible > 3 then 
				raidTarget:SetPoint(unpack(self.layout.RaidTargetPlace_AuraRows))
			elseif visible > 0 then
				raidTarget:SetPoint(unpack(self.layout.RaidTargetPlace_AuraRow))
			else 
				raidTarget:SetPoint(unpack(self.layout.RaidTargetPlace))
			end  
		else
			raidTarget:SetPoint(unpack(self.layout.RaidTargetPlace))
		end
	end 
end

local NamePlate_CastBar_PostUpdate = function(cast, unit)
	if cast.notInterruptible then

		-- Set it to the protected look 
		if (cast.currentStyle ~= "protected") then 
			cast:SetSize(68, 9)
			cast:ClearAllPoints()
			cast:SetPoint("TOP", 0, -26)
			cast:SetStatusBarTexture(GetMedia("cast_bar"))
			cast:SetTexCoord(0, 1, 0, 1)
			cast.Bg:SetSize(68, 9)
			cast.Bg:SetTexture(GetMedia("cast_bar"))
			cast.Bg:SetVertexColor(.15, .15, .15, 1)
			cast.Name:ClearAllPoints()
			cast.Name:SetPoint("TOP",0,-20)
			cast.currentStyle = "protected"
		end 

		-- Color the bar appropriately
		if UnitIsPlayer(unit) then 
			if UnitIsEnemy(unit, "player") then 
				cast:SetStatusBarColor(Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3]) 
			else 
				cast:SetStatusBarColor(Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3]) 
			end  
		elseif UnitCanAttack("player", unit) then 
			cast:SetStatusBarColor(Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3]) 
		else 
			cast:SetStatusBarColor(Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3]) 
		end 
	else 
		-- Return to standard castbar styling and position 
		if (cast.currentStyle == "protected") then 
			cast:SetSize(84, 14)
			cast:ClearAllPoints()
			cast:SetPoint("TOP", 0, -20)
			cast:SetStatusBarTexture(GetMedia("nameplate_bar"))
			cast:SetTexCoord(14/256, 242/256, 14/64, 50/64)
			cast.Bg:SetSize(84*256/228, 14*64/36)
			cast.Bg:SetTexture(GetMedia("nameplate_backdrop"))
			cast.Bg:SetVertexColor(1, 1, 1, 1)
			cast.Name:ClearAllPoints()
			cast.Name:SetPoint("TOP",0,-18)
			cast.currentStyle = nil 
		end 

		-- Standard bar coloring
		cast:SetStatusBarColor(Colors.cast[1], Colors.cast[2], Colors.cast[3]) 
	end 
end

-- Tooltip Bar post updates
-- Show health values for tooltip health bars, and hide others.
-- Will expand on this later to tailer all tooltips to our needs.  
local Tooltip_StatusBar_PostUpdate = function(tooltip, bar, value, min, max, isRealValue)
	if (bar.barType == "health") then 
		if (isRealValue) then 
			if (value >= 1e8) then 			bar.Value:SetFormattedText("%.0fm", value/1e6) 		-- 100m, 1000m, 2300m, etc
			elseif (value >= 1e6) then 		bar.Value:SetFormattedText("%.1fm", value/1e6) 		-- 1.0m - 99.9m 
			elseif (value >= 1e5) then 		bar.Value:SetFormattedText("%.0fk", value/1e3) 		-- 100k - 999k
			elseif (value >= 1e3) then 		bar.Value:SetFormattedText("%.1fk", value/1e3) 		-- 1.0k - 99.9k
			elseif (value > 0) then 		bar.Value:SetText(tostring(math_floor(value))) 		-- 1 - 999
			else 							bar.Value:SetText("")
			end 
		else 
			if (value > 0) then 
				bar.Value:SetFormattedText("%.0f%%", value)
			else 
				bar.Value:SetText("")
			end
		end
		if (not bar.Value:IsShown()) then 
			bar.Value:Show()
		end
	else 
		if (bar.Value:IsShown()) then 
			bar.Value:Hide()
			bar.Value:SetText("")
		end
	end 
end 

local Tooltip_LinePair_PostCreate = function(tooltip, lineIndex, left, right)
	local oldLeftObject = left:GetFontObject()
	local oldRightObject = right:GetFontObject()
	local leftObject = (lineIndex == 1) and GetFont(15, true) or GetFont(13, true)
	local rightObject = (lineIndex == 1) and GetFont(15, true) or GetFont(13, true)
	if (leftObject ~= oldLeftObject) then 
		left:SetFontObject(leftObject)
	end
	if (rightObject ~= oldRightObject) then 
		right:SetFontObject(rightObject)
	end
end

local Tooltip_Bar_PostCreate = function(tooltip, bar)
	if bar.Value then 
		bar.Value:SetFontObject(GetFont(13, true))
	end
end

local Tooltip_PostCreate = function(tooltip)
	-- Turn off UIParent scale matching
	tooltip:SetCValue("autoCorrectScale", false)

	-- What items will be displayed automatically when available
	tooltip.showHealthBar =  true
	tooltip.showPowerBar =  true

	-- Unit tooltips
	tooltip.colorUnitClass = true -- color the unit class on the info line
	tooltip.colorUnitPetRarity = true -- color unit names by combat pet rarity
	tooltip.colorUnitNameClass = true -- color unit names by player class
	tooltip.colorUnitNameReaction = true -- color unit names by NPC standing
	tooltip.colorHealthClass = true -- color health bars by player class
	tooltip.colorHealthPetRarity = true -- color health by combat pet rarity
	tooltip.colorHealthReaction = true -- color health bars by NPC standing 
	tooltip.colorHealthTapped = true -- color health bars if unit is tap denied
	tooltip.colorPower = true -- color power bars by power type
	tooltip.colorPowerTapped = true -- color power bars if unit is tap denied
	tooltip.showLevelWithName = true

	-- Force our colors into all tooltips created so far
	tooltip.colors = Colors

	-- Add our post updates for statusbars
	tooltip.PostUpdateStatusBar = Tooltip_StatusBar_PostUpdate
end

local PlayerFrame_CastBarPostUpdate = function(element, unit)
	local self = element._owner
	local cast = self.Cast
	local health = self.Health

	local isPlayer = UnitIsPlayer(unit) -- and UnitIsEnemy(unit)
	local unitLevel = UnitLevel(unit)
	local unitClassification = (unitLevel and (unitLevel < 1)) and "worldboss" or UnitClassification(unit)
	local isBoss = unitClassification == "boss" or unitClassification == "worldboss"
	local isEliteOrRare = unitClassification == "rare" or unitClassification == "elite" or unitClassification == "rareelite"

	if ((unitLevel and unitLevel == 1) and (not UnitIsPlayer("player"))) then 
		health.Value:Hide()
		cast.Value:Hide()
		cast.Name:Hide()
	elseif (cast.casting or cast.channeling) then 
		health.Value:Hide()
		cast.Value:Show()
		cast.Name:Show()
	else 
		health.Value:Show()
		cast.Value:Hide()
		cast.Name:Hide()
	end 
end

local PlayerFrame_ExtraPowerOverrideColor = function(element, unit, min, max, powerType, powerID, disconnected, dead, tapped)
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

local PlayerFrame_PowerOverrideColor = function(element, unit, min, max, powerType, powerID, disconnected, dead, tapped)
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

local PlayerFrame_TexturesPostUpdate = function(self, overrideLevel)
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

local PlayerHUD_ClassPowerPostCreatePoint = function(element, id, point)
	point.case = point:CreateTexture()
	point.case:SetDrawLayer("BACKGROUND", -2)
	point.case:SetVertexColor(211/255, 200/255, 169/255)

	point.slotTexture:SetPoint("TOPLEFT", -1.5, 1.5)
	point.slotTexture:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
	point.slotTexture:SetVertexColor(130/255 *.3, 133/255 *.3, 130/255 *.3, 2/3)

	point:SetOrientation("UP") -- set the bars to grow from bottom to top.
	point:SetSparkTexture(GetMedia("blank")) -- this will be too tricky to rotate and map
	
end

local PlayerHUD_ClassPowerPostUpdate = function(element, unit, min, max, newMax, powerType)
	local style
	if (powerType == "COMBO_POINTS") then 
		style = "ComboPoints"
	end 
	if (style ~= element.powerStyle) then 
		local posMod = element.flipSide and -1 or 1
		if (style == "ComboPoints") then
			local point1, point2, point3, point4, point5 = element[1], element[2], element[3], element[4], element[5]

			point1:SetPoint("CENTER", -203*posMod,-137)
			point1:SetSize(13,13)
			point1:SetStatusBarTexture(GetMedia("point_crystal"))
			point1:GetStatusBarTexture():SetRotation(degreesToRadians(6*posMod))
			point1.slotTexture:SetTexture(GetMedia("point_crystal"))
			point1.slotTexture:SetRotation(degreesToRadians(6*posMod))
			point1.case:SetPoint("CENTER", 0, 0)
			point1.case:SetSize(58,58)
			point1.case:SetRotation(degreesToRadians(6*posMod))
			point1.case:SetTexture(GetMedia("point_plate"))

			point2:SetPoint("CENTER", -221*posMod,-111)
			point2:SetSize(13,13)
			point2:SetStatusBarTexture(GetMedia("point_crystal"))
			point2:GetStatusBarTexture():SetRotation(degreesToRadians(5*posMod))
			point2.slotTexture:SetTexture(GetMedia("point_crystal"))
			point2.slotTexture:SetRotation(degreesToRadians(5*posMod))
			point2.case:SetPoint("CENTER", 0, 0)
			point2.case:SetSize(60,60)
			point2.case:SetRotation(degreesToRadians(5*posMod))
			point2.case:SetTexture(GetMedia("point_plate"))

			point3:SetPoint("CENTER", -231*posMod,-79)
			point3:SetSize(13,13)
			point3:SetStatusBarTexture(GetMedia("point_crystal"))
			point3:GetStatusBarTexture():SetRotation(degreesToRadians(4*posMod))
			point3.slotTexture:SetTexture(GetMedia("point_crystal"))
			point3.slotTexture:SetRotation(degreesToRadians(4*posMod))
			point3.case:SetPoint("CENTER", 0,0)
			point3.case:SetSize(60,60)
			point3.case:SetRotation(degreesToRadians(4*posMod))
			point3.case:SetTexture(GetMedia("point_plate"))
		
			point4:SetPoint("CENTER", -225*posMod,-44)
			point4:SetSize(13,13)
			point4:SetStatusBarTexture(GetMedia("point_crystal"))
			point4:GetStatusBarTexture():SetRotation(degreesToRadians(3*posMod))
			point4.slotTexture:SetTexture(GetMedia("point_crystal"))
			point4.slotTexture:SetRotation(degreesToRadians(3*posMod))
			point4.case:SetPoint("CENTER", 0, 0)
			point4.case:SetSize(60,60)
			point4.case:SetRotation(0)
			point4.case:SetTexture(GetMedia("point_plate"))
		
			point5:SetPoint("CENTER", -203*posMod,-11)
			point5:SetSize(14,21)
			point5:SetStatusBarTexture(GetMedia("point_crystal"))
			point5:GetStatusBarTexture():SetRotation(degreesToRadians(1*posMod))
			point5.slotTexture:SetTexture(GetMedia("point_crystal"))
			point5.slotTexture:SetRotation(degreesToRadians(1*posMod))
			point5.case:SetRotation(degreesToRadians(1*posMod))
			point5.case:SetPoint("CENTER",0,0)
			point5.case:SetSize(82,96)
			point5.case:SetRotation(degreesToRadians(1*posMod))
			point5.case:SetTexture(GetMedia("point_diamond"))

		end 
		element.powerStyle = style
	end 
end

local TargetFrame_CastBarPostUpdate = function(element, unit)
	local self = element._owner
	local layout = self.layout
	local cast = self.Cast
	local health = self.Health

	local isPlayer = UnitIsPlayer(unit) -- and UnitIsEnemy(unit)
	local unitLevel = UnitLevel(unit)
	local unitClassification = (unitLevel and (unitLevel < 1)) and "worldboss" or UnitClassification(unit)
	local isBoss = unitClassification == "boss" or unitClassification == "worldboss"
	local isEliteOrRare = unitClassification == "rare" or unitClassification == "elite" or unitClassification == "rareelite"

	if ((unitLevel and unitLevel == 1) and (not UnitIsPlayer("target"))) then 
		health.Value:Hide()
		health.ValuePercent:Hide()
		cast.Value:Hide()
		cast.Name:Hide()
	elseif (cast.casting or cast.channeling) then 
		health.Value:Hide()
		health.ValuePercent:Hide()
		cast.Value:Show()
		cast.Name:Show()
	else 
		health.Value:SetShown(self.layout[self.currentStyle.."HealthValueVisible"])
		health.ValuePercent:SetShown(self.layout[self.currentStyle.."HealthPercentVisible"])
		cast.Value:Hide()
		cast.Name:Hide()
	end 
end

local TargetFrame_LevelVisibilityFilter = function(element, unit) 
	if UnitIsDeadOrGhost(unit) then 
		return true 
	else 
		return false
	end 
end

local TargetFrame_NamePostUpdate = function(self, event, ...)
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
		local Core = Wheel("LibModule"):GetModule(ADDON, true)
		if (Core) then 
			local UnitFrameTarget = Core:GetModule("UnitFrameTarget", true)
			if (UnitFrameTarget) then 
				UnitFrameTarget:AddDebugMessageFormatted("UnitFrameTarget changed name element width to small.")
			end
		end
	elseif (self.Name.usingSmallWidth) then
		self.Name.maxChars = 64
		self.Name.usingSmallWidth = nil
		self.Name:ForceUpdate()
		local Core = Wheel("LibModule"):GetModule(ADDON, true)
		if (Core) then 
			local UnitFrameTarget = Core:GetModule("UnitFrameTarget", true)
			if (UnitFrameTarget) then 
				UnitFrameTarget:AddDebugMessageFormatted("UnitFrameTarget changed name element width to full.")
			end
		end
	end 
end

local TargetFrame_PowerValueOverride = function(element, unit, min, max, powerType, powerID, disconnected, dead, tapped)
	local value = element.Value
	if (min == 0 or max == 0) and (not value.showAtZero) then
		value:SetText("")
	else
		value:SetFormattedText("%.0f", math_floor(min/max * 100))
	end 
end

local TargetFrame_PowerVisibilityFilter = function(element, unit) 
	if UnitIsDeadOrGhost(unit) then 
		return false 
	else 
		return true
	end 
end

local TargetFrame_TexturesPostUpdate = function(self)
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
	elseif (creatureType == "Critter") or (targetLevel == 1) then 
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

local SmallFrame_AlphaPostUpdate = function(self)
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

local SmallFrame_CastBarPostUpdate = function(element, unit)
	local self = element._owner
	local cast = self.Cast
	local healthPercent = self.Health.ValuePercent

	-- Bug in the back-end, hotfixing it here for now. 
	if UnitIsDeadOrGhost(unit) then 
		cast.Name:Hide()
		healthPercent:SetText(DEAD)
		healthPercent:Show()
	elseif (cast.casting or cast.channeling) then 
		healthPercent:Hide()
		cast.Name:Show()
	else 
		cast.Name:Hide()
		healthPercent:Show()
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
			return element.Value:SetText(DEAD)
		end
	elseif (UnitIsAFK(unit)) then 
		if element.Value then 
			return element.Value:SetText(AFK)
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

local UnitFrame_Aura_PostCreateButton = function(element, button)
	local layout = element._owner.layout

	button.Icon:SetTexCoord(unpack(layout.AuraIconTexCoord))
	button.Icon:SetSize(unpack(layout.AuraIconSize))
	button.Icon:ClearAllPoints()
	button.Icon:SetPoint(unpack(layout.AuraIconPlace))

	button.Count:SetFontObject(layout.AuraCountFont)
	button.Count:SetJustifyH("CENTER")
	button.Count:SetJustifyV("MIDDLE")
	button.Count:ClearAllPoints()
	button.Count:SetPoint(unpack(layout.AuraCountPlace))
	if layout.AuraCountColor then 
		button.Count:SetTextColor(unpack(layout.AuraCountColor))
	end 

	button.Time:SetFontObject(layout.AuraTimeFont)
	button.Time:ClearAllPoints()
	button.Time:SetPoint(unpack(layout.AuraTimePlace))

	local layer, level = button.Icon:GetDrawLayer()

	button.Darken = button.Darken or button:CreateTexture()
	button.Darken:SetDrawLayer(layer, level + 1)
	button.Darken:SetSize(button.Icon:GetSize())
	button.Darken:SetPoint("CENTER", 0, 0)
	button.Darken:SetColorTexture(0, 0, 0, .25)

	button.Overlay:SetFrameLevel(button:GetFrameLevel() + 10)
	button.Overlay:ClearAllPoints()
	button.Overlay:SetPoint("CENTER", 0, 0)
	button.Overlay:SetSize(button.Icon:GetSize())

	button.Border = button.Border or button.Overlay:CreateFrame("Frame", nil, button.Overlay)
	button.Border:SetFrameLevel(button.Overlay:GetFrameLevel() - 5)
	button.Border:ClearAllPoints()
	button.Border:SetPoint(unpack(layout.AuraBorderFramePlace))
	button.Border:SetSize(unpack(layout.AuraBorderFrameSize))
	button.Border:SetBackdrop(layout.AuraBorderBackdrop)
	button.Border:SetBackdropColor(unpack(layout.AuraBorderBackdropColor))
	button.Border:SetBackdropBorderColor(unpack(layout.AuraBorderBackdropBorderColor))
end

local UnitFrame_Aura_PostUpdateButton = function(element, button)
	local colors = element._owner.colors
	local layout = element._owner.layout
	if UnitIsFriend("player", button.unit) then 
		if button.isBuff then 
			local color = layout.AuraBorderBackdropBorderColor
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			end 
		else
			local color = colors.debuff[button.debuffType or "none"] or layout.AuraBorderBackdropBorderColor
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			end 
		end
	else 
		if button.isStealable then 
			local color = colors.power.ARCANE_CHARGES or layout.AuraBorderBackdropBorderColor
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			end 
		elseif button.isBuff then 
			local color = colors.quest.green or layout.AuraBorderBackdropBorderColor
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			end 
		else
			local color = colors.debuff[button.debuffType or "none"] or layout.AuraBorderBackdropBorderColor
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			end 
		end
	end 
end

------------------------------------------------------------------
-- UnitFrame Config Templates
------------------------------------------------------------------
-- Table containing common values for the unit frame templates.
local Constant = {
	SmallAuraSize = 30, 
	SmallBar = { 112, 11 }, 
	SmallBarTexture = GetMedia("cast_bar"),
	SmallFrame = { 136, 47 },
	RaidBar = { 80 *.94, 14  *.94}, 
	RaidFrame = { 110 *.94, 30 *.94 }, 
	TinyBar = { 80, 14 }, 
	TinyBarTexture = GetMedia("cast_bar"),
	TinyFrame = { 130, 30 }
}

-- Used for Pet, also the base for the variants below.
local Template_SmallFrame = {
	AlphaPostUpdate = SmallFrame_AlphaPostUpdate,
	CastBarColor = { 1, 1, 1, .15 },
	CastBarNameColor = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
	CastBarNameDrawLayer = { "OVERLAY", 1 }, 
	CastBarNameFont = GetFont(12, true),
	CastBarNameJustifyH = "CENTER", 
	CastBarNameJustifyV = "MIDDLE",
	CastBarNameParent = "Health",
	CastBarNamePlace = { "CENTER", 0, 1 },
	CastBarNameSize = { Constant.SmallBar[1] - 20, Constant.SmallBar[2] }, 
	CastBarOrientation = "RIGHT", 
	CastBarPlace = { "CENTER", 0, 0 },
	CastBarPostUpdate =	SmallFrame_CastBarPostUpdate,
	CastBarSize = Constant.SmallBar,
	CastBarSmoothingFrequency = .15,
	CastBarSmoothingMode = "bezier-fast-in-slow-out", 
	CastBarSparkMap = {
		top = {
			{ keyPercent =   0/128, offset = -16/32 }, 
			{ keyPercent =   4/128, offset = -16/32 }, 
			{ keyPercent =  10/128, offset =   0/32 }, 
			{ keyPercent = 119/128, offset =   0/32 }, 
			{ keyPercent = 126/128, offset = -16/32 },
			{ keyPercent = 128/128, offset = -16/32 }
		},
		bottom = {
			{ keyPercent =   0/128, offset = -16/32 }, 
			{ keyPercent =   4/128, offset = -16/32 }, 
			{ keyPercent =  10/128, offset =   0/32 }, 
			{ keyPercent = 119/128, offset =   0/32 }, 
			{ keyPercent = 126/128, offset = -16/32 },
			{ keyPercent = 128/128, offset = -16/32 }
		}
	},
	CastBarTexture = Constant.SmallBarTexture, 
	FrameLevel = 20, 
	HealthBackdropColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] }, 
	HealthBackdropDrawLayer = { "BACKGROUND", -1 },
	HealthBackdropPlace = { "CENTER", 1, -2 },
	HealthBackdropSize = { 193,93 },
	HealthBackdropTexture = GetMedia("cast_back"), 
	HealthBarTexture = Constant.SmallBarTexture, 
	HealthBarOrientation = "RIGHT", 
	HealthBarPostUpdate = SmallFrame_CastBarPostUpdate, 
	HealthBarSetFlippedHorizontally = false, 
	HealthBarSparkMap = {
		top = {
			{ keyPercent =   0/128, offset = -16/32 }, 
			{ keyPercent =   4/128, offset = -16/32 }, 
			{ keyPercent =  10/128, offset =   0/32 }, 
			{ keyPercent = 119/128, offset =   0/32 }, 
			{ keyPercent = 128/128, offset = -16/32 }
		},
		bottom = {
			{ keyPercent =   0/128, offset = -16/32 }, 
			{ keyPercent =   4/128, offset = -16/32 }, 
			{ keyPercent =  10/128, offset =   0/32 }, 
			{ keyPercent = 119/128, offset =   0/32 }, 
			{ keyPercent = 126/128, offset = -16/32 },
			{ keyPercent = 128/128, offset = -16/32 }
		}
	},
	HealthFrequentUpdates = true, 
	HealthPercentColor = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
	HealthPercentDrawLayer = { "OVERLAY", 1 },
	HealthPercentFont = GetFont(14, true),
	HealthPercentJustifyH = "CENTER", 
	HealthPercentJustifyV = "MIDDLE", 
	HealthPercentPlace = { "CENTER", 0, 0 },
	HealthPlace = { "CENTER", 0, 0 }, 
	HealthSize = Constant.SmallBar,
	HealthSmoothingFrequency = .2, 
	HealthSmoothingMode = "bezier-fast-in-slow-out", 
	Size = Constant.SmallFrame,
	TargetHighlightDrawLayer = { "BACKGROUND", 0 },
	TargetHighlightParent = "Health", 
	TargetHighlightPlace = { "CENTER", 1, -2 },
	TargetHighlightSize = { 193,93 },
	TargetHighlightShowFocus = true, TargetHighlightFocusColor = { 144/255, 195/255, 255/255, 1 }, 
	TargetHighlightShowTarget = true, TargetHighlightTargetColor = { 255/255, 239/255, 169/255, 1 }, 
	TargetHighlightTexture = GetMedia("cast_back_outline")
}

-- Really just a base for the reversed variant below.
local Template_SmallFrame_Auras = setmetatable({
	Aura_PostCreateButton = UnitFrame_Aura_PostCreateButton,
	Aura_PostUpdateButton = UnitFrame_Aura_PostUpdateButton,
	AuraBorderBackdrop = { edgeFile = GetMedia("aura_border"), edgeSize = 16 },
	AuraBorderBackdropColor = { 0, 0, 0, 0 },
	AuraBorderBackdropBorderColor = { Colors.ui.stone[1] *.3, Colors.ui.stone[2] *.3, Colors.ui.stone[3] *.3 },
	AuraBorderFramePlace = { "CENTER", 0, 0 }, 
	AuraBorderFrameSize = { Constant.SmallAuraSize + 14, Constant.SmallAuraSize + 14 },
	AuraCountColor = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
	AuraCountFont = GetFont(12, true),
	AuraCountPlace = { "BOTTOMRIGHT", 9, -6 },
	AuraFramePlace = { "LEFT", Constant.SmallFrame[1] + 13, -1 },
	AuraFrameSize = { Constant.SmallAuraSize*6 + 4*5, Constant.SmallAuraSize },
	AuraIconPlace = { "CENTER", 0, 0 },
	AuraIconSize = { Constant.SmallAuraSize - 6, Constant.SmallAuraSize - 6 },
	AuraIconTexCoord = { 5/64, 59/64, 5/64, 59/64 },
	AuraProperties = {
		auraHeight = nil, 
		auraSize = Constant.SmallAuraSize, 
		auraWidth = nil, 
		debuffsFirst = false, 
		disableMouse = false, 
		filter = nil, 
		filterBuffs = "HELPFUL", 
		filterDebuffs = "HARMFUL", 
		func = nil, 
		funcBuffs = nil, 
		funcDebuffs = nil, 
		growthX = "RIGHT", 
		growthY = "UP", 
		maxBuffs = nil, 
		maxDebuffs = nil, 
		maxVisible = 6, 
		showDurations = true, 
		showSpirals = false, 
		showLongDurations = true,
		spacingH = 4, 
		spacingV = 4, 
		tooltipAnchor = nil,
		tooltipDefaultPosition = false, 
		tooltipOffsetX = 8,
		tooltipOffsetY = 16,
		tooltipPoint = "BOTTOMLEFT",
		tooltipRelPoint = "TOPLEFT"
	},
	AuraTimeFont = GetFont(11, true),
	AuraTimePlace = { "TOPLEFT", -6, 6 }
}, { __index = Template_SmallFrame })

-- Used for ToT.
local Template_SmallFrameReversed = setmetatable({
	CastBarOrientation = "LEFT", 
	CastBarSetFlippedHorizontally = true, 
	HealthBarOrientation = "LEFT", 
	HealthBarSetFlippedHorizontally = true 
}, { __index = Template_SmallFrame })

-- Used for Boss.
local Template_SmallFrameReversed_Auras = setmetatable({
	AuraFramePlace = { "RIGHT", -(Constant.SmallFrame[1] + 13), -1 },
	AuraProperties = setmetatable({
		growthX = "LEFT", 
		growthY = "DOWN", 
		tooltipOffsetX = -8,
		tooltipOffsetY = -16,
		tooltipPoint = "TOPRIGHT",
		tooltipRelPoint = "BOTTOMRIGHT"
	}, { __index = Template_SmallFrame_Auras.AuraProperties}),
	CastBarOrientation = "LEFT", 
	CastBarSetFlippedHorizontally = true, 
	HealthBarOrientation = "LEFT", 
	HealthBarSetFlippedHorizontally = true
}, { __index = Template_SmallFrame_Auras })

-- Used for Raid and Party frames.
local Template_TinyFrame = {
	Size = Constant.TinyFrame,

	RangeOutsideAlpha = .6, -- was .35, but that's too hard to see

	HealthPlace = { "BOTTOM", 0, 0 }, 
	HealthSize = Constant.TinyBar,  -- health size
	HealthBarTexture = Constant.TinyBarTexture, 
	HealthBarOrientation = "RIGHT", -- bar orientation
	HealthBarSetFlippedHorizontally = false, 
	HealthBarSparkMap = {
		top = {
			{ keyPercent =   0/128, offset = -16/32 }, 
			{ keyPercent =  10/128, offset =   0/32 }, 
			{ keyPercent = 119/128, offset =   0/32 }, 
			{ keyPercent = 128/128, offset = -16/32 }
		},
		bottom = {
			{ keyPercent =   0/128, offset = -16/32 }, 
			{ keyPercent =  10/128, offset =   0/32 }, 
			{ keyPercent = 119/128, offset =   0/32 }, 
			{ keyPercent = 128/128, offset = -16/32 }
		}
	},
	HealthSmoothingMode = "bezier-fast-in-slow-out", -- smoothing method
	HealthSmoothingFrequency = .2, -- speed of the smoothing method
	HealthFrequentUpdates = true, -- listen to frequent health events for more accurate updates
	HealthBackdropPlace = { "CENTER", 1, -2 },
	HealthBackdropSize = { 140,90 },
	HealthBackdropTexture = GetMedia("cast_back"), 
	HealthBackdropDrawLayer = { "BACKGROUND", -1 },
	HealthBackdropColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] }, 
	HealthValueOverride = TinyFrame_OverrideHealthValue,

	CastBarPlace = { "BOTTOM", 0, 0 },
	CastBarSize = Constant.TinyBar,
	CastBarOrientation = "RIGHT", 
	CastBarSmoothingMode = "bezier-fast-in-slow-out", 
	CastBarSmoothingFrequency = .15,
	CastBarSparkMap = {
		top = {
			{ keyPercent =   0/128, offset = -16/32 }, 
			{ keyPercent =  10/128, offset =   0/32 }, 
			{ keyPercent = 119/128, offset =   0/32 }, 
			{ keyPercent = 128/128, offset = -16/32 }
		},
		bottom = {
			{ keyPercent =   0/128, offset = -16/32 }, 
			{ keyPercent =  10/128, offset =   0/32 }, 
			{ keyPercent = 119/128, offset =   0/32 }, 
			{ keyPercent = 128/128, offset = -16/32 }
		}
	},
	CastBarTexture = Constant.TinyBarTexture, 
	CastBarColor = { 1, 1, 1, .15 },

	TargetHighlightParent = "Health", 
	TargetHighlightPlace = { "CENTER", 1, -2 },
	TargetHighlightSize = { 140, 90 },
	TargetHighlightTexture = GetMedia("cast_back_outline"), 
	TargetHighlightDrawLayer = { "BACKGROUND", 0 },
	TargetHighlightShowTarget = true, TargetHighlightTargetColor = { 255/255, 229/255, 109/255, 1 }, 
	TargetHighlightShowFocus = true, TargetHighlightFocusColor = { 44/255, 165/255, 255/255, 1 }, 
}

------------------------------------------------
-- Module Defaults
------------------------------------------------
-- The purpose of this is to supply all the front-end modules
-- with default settings for all the user configurable choices.
-- 
-- Note that changing these won't change anything for existing characters,
-- they only affect new characters or the first install.
-- I generally advice tinkerers to leave these as they are. 
local Defaults = {}

Defaults[ADDON] = {
	-- Enables a layout switch targeted towards healers
	enableHealerMode = false,

	-- Loads all child modules with debug functionality, 
	-- doesn't actually load any consoles. 
	loadDebugConsole = true, 

	-- Enable console visibility. 
	-- Requires the above to be true. 
	enableDebugConsole = false,

	-- Block group invite spam
	blockGroupInvites = false, 
	allowGuildInvites = true,
	allowFriendInvites = true, 
	blockCounter = {}
}

Defaults.BlizzardFloaterHUD = {
}

Defaults.ActionBarMain = {

	-- unlock buttons
	buttonLock = true, 

	-- Valid range is 0 to 17. anything outside will be limited to this range. 
	extraButtonsCount = 5, -- default this to a full standard bar, just to make it slightly easier for people

	-- Valid values are 'always','hover','combat'
	extraButtonsVisibility = "combat", -- defaulting this to combat, so new users can access their full default bar

	-- Whether actions are performed when pressing the button or releasing it
	castOnDown = true,

	-- TODO! 
	-- *Options below are not yet implemented!

	-- Modifier keys required to drag spells, 
	-- if none are selected, buttons aren't locked. 
	dragRequireAlt = true, 
	dragRequireCtrl = true, 
	dragRequireShift = true, 

	petBarEnabled = true, 
	petBarVisibility = "hover",

	stanceBarEnabled = true, 
	stanceBarVisibility = "hover"
}

Defaults.Minimap = {
	useStandardTime = true, -- as opposed to military/24-hour time
	useServerTime = false, -- as opposed to your local computer time
	stickyBars = false
}

Defaults.NamePlates = {
	enableAuras = true,
	clickThroughEnemies = false, 
	clickThroughFriends = false, 
	clickThroughSelf = false
}

Defaults.UnitFramePlayerHUD = {
	enableCast = true,
	enableClassPower = true
}

Defaults.UnitFrameParty = {
	enablePartyFrames = true
}

Defaults.UnitFrameRaid = {
	enableRaidFrames = true
}

------------------------------------------------
-- Module Layouts
------------------------------------------------
-- The purpose of this is to supply all the front-end modules
-- with static layout data used during the setup phase.
-- 
-- I advice tinkerers to be careful when changing these,
-- as most modules assume that other modules have the settings I gave them.
-- This means that if you change somethng like let's say the position
-- of the minimap, you'll also have to change a variety of other things
-- like which way tooltips grow, where the default position of all tooltips are,
-- where the integrated MBB button is placed, and so on. 
-- Not all of those can be changed through the layout, some things are in the modules.
-- 
-- I know you like to tinker, but regardless of what some of you think, 
-- it's never enough "just to change a few lines of code" to modify the layouts.
local Layouts = {}

-- Addon Core
Layouts[ADDON] = {
	DisableUIWidgets = {
		ActionBars = true, 
		Auras = true,
		CaptureBar = true,
		CastBars = true,
		Durability = true,
		Minimap = true,
		--QuestWatchFrame = true, 
		UnitFramePlayer = true,
		UnitFramePet = true,
		UnitFrameTarget = true,
		UnitFrameToT = true,
		UnitFrameParty = true,
		--UnitFrameRaid = true,
		UnitFrameBoss = true,
		--Warnings = true,
		ZoneText = true
	},
	DisableUIMenuPages = {
		{ ID = 5, Name = "InterfaceOptionsActionBarsPanel" },
		--{ ID = 10, Name = "CompactUnitFrameProfiles" }
	},
	FadeInDelay = 1.5,
	FadeInSpeed = .75,
	FadeInUI = true, 
	MenuBorderBackdropBorderColor = { 1, 1, 1, 1 },
	MenuBorderBackdropColor = { .05, .05, .05, .85 },
	MenuButton_PostCreate = Core_MenuButton_PostCreate, 
	MenuButton_PostUpdate = Core_MenuButton_PostUpdate,
	MenuButtonSize = { MenuButtonW, MenuButtonH },
	MenuButtonSizeMod = .75, 
	MenuButtonSpacing = 10, 
	MenuPlace = { "BOTTOMRIGHT", -41, 32 },
	MenuSize = { 320 -10, 70 }, 
	MenuToggleButtonSize = { 48, 48 }, 
	MenuToggleButtonPlace = { "BOTTOMRIGHT", -4, 4 }, 
	MenuToggleButtonIcon = GetMedia("config_button"), 
	MenuToggleButtonIconPlace = { "CENTER", 0, 0 }, 
	MenuToggleButtonIconSize = { 96, 96 }, 
	MenuToggleButtonIconColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] }, 
	MenuWindow_CreateBorder = Core_Window_CreateBorder,
	MenuWindow_OnHide = Core_Window_OnHide, 
	MenuWindow_OnShow = Core_Window_OnShow
}

-- Blizzard Chat Frames
Layouts.BlizzardChatFrames = {
	AlternateChatFramePlace = { "TOPLEFT", 85, -64 },
	AlternateChatFrameSize = { 499, 176 }, 
	AlternateClampRectInsets = { -54, -54, -310, -350 },
	ButtonFrameWidth = 48, ScrollBarWidth = 32, 
	ButtonTextureChatEmotes = GetMedia("config_button_emotes"),
	ButtonTextureColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] }, 
	ButtonTextureMinimizeButton = GetMedia("icon_chat_minus"),
	ButtonTextureNormal = GetMedia("point_block"),
	ButtonTextureScrollUpButton = GetMedia("icon_chat_up"), 
	ButtonTextureScrollDownButton = GetMedia("icon_chat_down"), 
	ButtonTextureScrollToBottomButton = GetMedia("icon_chat_bottom"), 
	ButtonTextureSize = { 64, 64 },
	ChatFadeTime = 5, 
	ChatIndentedWordWrap = false, 
	ChatVisibleTime = 15, 
	DefaultChatFramePlace = { "BOTTOMLEFT", 85, 350 }, 
	DefaultChatFrameSize = { 499, 176 }, 
	DefaultClampRectInsets = { -54, -54, -310, -350 },
	EditBoxHeight = 45, 
	EditBoxOffsetH = 15
}

-- Blizzard Floaters
Layouts.BlizzardFloaterHUD = {
	StyleErrorFrame = true, ErrorFrameStrata = "LOW",
	StyleQuestTimerFrame = true, QuestTimerFramePlace = { "CENTER", UIParent, "CENTER", 0, 220 }
}

-- Blizzard font replacements
Layouts.BlizzardFonts = {
	ChatBubbleFont = GetFont(10, true),
	ChatFont = GetFont(15, true)
}

-- Blizzard Game Menu (Esc)
Layouts.BlizzardGameMenu = {
	MenuButton_PostCreate = Blizzard_GameMenu_Button_PostCreate,
	MenuButton_PostUpdate = Blizzard_GameMenu_Button_PostUpdate,
	MenuButtonSize = { MenuButtonW, MenuButtonH },
	MenuButtonSizeMod = .75, 
	MenuButtonSpacing = 10
}

-- Blizzard MicroMenu
Layouts.BlizzardMicroMenu = {
	ButtonFont = GetFont(MenuButtonFontSize, false),
	ButtonFontColor = { 0, 0, 0 }, 
	ButtonFontShadowColor = { 1, 1, 1, .5 },
	ButtonFontShadowOffset = { 0, -.85 },
	ConfigWindowBackdrop = {
		bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
		edgeFile = GetMedia("tooltip_border"),
		edgeSize = 32 *.75, 
		insets = { 
			top = 23 *.75, 
			bottom = 23 *.75, 
			left = 23 *.75, 
			right = 23 *.75 
		}
	},
	MenuButton_PostCreate = BlizzardMicroMenu_Button_PostCreate,
	MenuButton_PostUpdate = BlizzardMicroMenu_Button_PostUpdate, 
	MenuButtonNormalColor = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3] }, 
	MenuButtonSize = { MenuButtonW, MenuButtonH },
	MenuButtonSizeMod = .75, 
	MenuButtonSpacing = 10, 
	MenuButtonTitleColor = { Colors.title[1], Colors.title[2], Colors.title[3] },
	MenuWindow_CreateBorder = Core_Window_CreateBorder
}

-- Blizzard Timers (mirror, quest)
Layouts.BlizzardTimers = {
	MirrorAnchor = Wheel("LibFrame"):GetFrame(),
	MirrorAnchorOffsetX = 0,
	MirrorAnchorOffsetY = -370, 
	MirrorAnchorPoint = "TOP",
	MirrorBackdropColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	MirrorBackdropDrawLayer = { "BACKGROUND", -5 },
	MirrorBackdropPlace = { "CENTER", 1, -2 }, 
	MirrorBackdropSize = { 193,93 }, 
	MirrorBackdropTexture = GetMedia("cast_back"),
	MirrorBarColor = { Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3] }, 
	MirrorBarPlace = { "CENTER", 0, 0 },
	MirrorBarSize = { 111, 12 }, 
	MirrorBarSparkMap = {
		top = {
			{ keyPercent =   0/128, offset = -16/32 }, 
			{ keyPercent =  10/128, offset =   0/32 }, 
			{ keyPercent = 119/128, offset =   0/32 }, 
			{ keyPercent = 128/128, offset = -16/32 }
		},
		bottom = {
			{ keyPercent =   0/128, offset = -16/32 }, 
			{ keyPercent =  10/128, offset =   0/32 }, 
			{ keyPercent = 119/128, offset =   0/32 }, 
			{ keyPercent = 128/128, offset = -16/32 }
		}
	},
	MirrorBarTexture = GetMedia("cast_bar"), 
	MirrorBarValueColor = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .7 },
	MirrorBarValueFont = GetFont(14, true),
	MirrorBarValuePlace = { "CENTER", 0, 0 }, 
	MirrorBlankTexture = GetMedia("blank"), 
	MirrorGrowth = -50, 
	MirrorSize = { 111, 14 }
}

-- Blizzard Objectives Tracker
Layouts.BlizzardObjectivesTracker = {
	FontObject = GetFont(13, true),
	FontObjectTitle = GetFont(15, true),
	HideInBossFights = true,
	HideInCombat = false, 
	MaxHeight = 1080 - (260 + 380),
	Place = { "BOTTOMRIGHT", -60, 380 },
	Scale = 1.0, 
	SpaceBottom = 380, 
	SpaceTop = 260, 
	Width = 255 -- 280 is classic default
}

-- Blizzard Popup Styling
Layouts.BlizzardPopupStyling = {
	PostCreatePopup = BlizzardPopup_PostCreate,
	PostUpdateAnchors = BlizzardPopup_Anchors_PostUpdate
}

-- Blizzard Tooltips
Layouts.BlizzardTooltips = {
	TooltipBackdrop = {
		bgFile = [[Interface\ChatFrame\ChatFrameBackground]], tile = false, 
		edgeFile = GetMedia("tooltip_border_blizzcompatible"), edgeSize = 32, 
		insets = { top = 2.5, bottom = 2.5, left = 2.5, right = 2.5 }
	},
	TooltipBackdropBorderColor = { 1, 1, 1, 1 },
	TooltipBackdropColor = { .05, .05, .05, .85 },
	TooltipStatusBarTexture = GetMedia("statusbar_normal")
}

-- Blizzard World Map
Layouts.BlizzardWorldMap = {}

-- ActionBars
Layouts.ActionBarMain = {
	BackdropDrawLayer = { "BACKGROUND", 1 },
	BackdropPlace = { "CENTER", 0, 0 },
	BackdropSize = { 64/(122/256), 64/(122/256) },
	BackdropTexture = GetMedia("actionbutton-backdrop"),
	BorderColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3], 1 },
	BorderDrawLayer = { "BORDER", 1 },
	BorderPlace = { "CENTER", 0, 0 },
	BorderSize = { 64/(122/256), 64/(122/256) },
	BorderTexture = GetMedia("actionbutton-border"),
	ButtonHitRects = { -4, -4, -4, -4 },
	ButtonSize = { 64, 64 },
	ChargeCooldownBlingColor = { 0, 0, 0, 0 },
	ChargeCooldownBlingTexture = GetMedia("blank"),
	ChargeCooldownPlace = { "CENTER", 0, 0 },
	ChargeCooldownSize = { 44, 44 },
	ChargeCooldownSwipeColor = { 0, 0, 0, .5 },
	ChargeCooldownSwipeTexture = GetMedia("actionbutton_circular_mask"),
	CheckedBlendMode = "ADD",
	CheckedColor = { .9, .8, .1, .3 },
	CheckedDrawLayer = { "ARTWORK", 2 },
	CheckedPlace = { "CENTER", 0, 0 },
	CheckedSize = { 44, 44 },
	CooldownBlingColor = { 0, 0, 0 , 0 },
	CooldownBlingTexture = GetMedia("blank"),
	CooldownCountColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .85 },
	CooldownCountFont = GetFont(16, true),
	CooldownCountJustifyH = "CENTER",
	CooldownCountJustifyV = "MIDDLE",
	CooldownCountPlace = { "CENTER", 1, 0 },
	CooldownCountShadowOffset = { 0, 0 },
	CooldownCountShadowColor = { 0, 0, 0, 1 },
	CooldownPlace = { "CENTER", 0, 0 },
	CooldownSize = { 44, 44 },
	CooldownSwipeColor = { 0, 0, 0, .75 },
	CooldownSwipeTexture = GetMedia("actionbutton_circular_mask"),
	CountColor = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
	CountFont = GetFont(18, true),
	CountJustifyH = "CENTER",
	CountJustifyV = "BOTTOM",
	CountMaxDisplayed = 99,
	CountPlace = { "BOTTOMRIGHT", -3, 3 },
	CountPostUpdate = ActionButton_StackCount_PostUpdate, 
	CountShadowColor = { 0, 0, 0, 1 },
	CountShadowOffset = { 0, 0 },
	ExitButtonPlace = { "CENTER", "Minimap", "CENTER", -math_cos(45*math_pi/180) * (213/2 + 10), math_sin(45*math_pi/180) * (213/2 + 10) }, 
	ExitButtonSize = { 32, 32 },
	ExitButtonTexturePath = GetMedia("icon_exit_flight"),
	ExitButtonTexturePlace = { "CENTER", 0, 0 }, 
	ExitButtonTextureSize = { 80, 80 }, 
	FlashColor = { 1, 0, 0, .25 },
	FlashDrawLayer = { "ARTWORK", 2 },
	FlashPlace = { "CENTER", 0, 0 },
	FlashSize = { 44, 44 },
	FlashTexture = [[Interface\ChatFrame\ChatFrameBackground]],
	GlowBlendMode = "ADD",
	GlowColor = { 1, 1, 1, .5 },
	GlowDrawLayer = { "ARTWORK", 1 },
	GlowPlace = { "CENTER", 0, 0 },
	GlowSize = { 44/(122/256),44/(122/256) },
	GlowTexture = GetMedia("actionbutton-glow-white"),
	IconPlace = { "CENTER", 0, 0 },
	IconSize = { 44, 44 },
	KeybindColor = { Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3], .75 },
	KeybindFont = GetFont(15, true),
	KeybindJustifyH = "CENTER",
	KeybindJustifyV = "BOTTOM",
	KeybindPlace = { "TOPLEFT", 5, -5 },
	KeybindShadowColor = { 0, 0, 0, 1 },
	KeybindShadowOffset = { 0, 0 },
	MaskTexture = GetMedia("actionbutton_circular_mask"),
	PushedBlendMode = "ADD",
	PushedColor = { 1, 1, 1, .15 },
	PushedDrawLayer = { "ARTWORK", 1 },
	PushedPlace = { "CENTER", 0, 0 },
	PushedSize = { 44, 44 },
	ShowChargeCooldownBling = false,
	ShowChargeCooldownSwipe = true,
	ShowCooldownSwipe = true,
	ShowCooldownBling = true,
	SpellAutoCastAntsColor = { Colors.cast[1], Colors.cast[2], Colors.cast[3] },
	SpellAutoCastAntsTexture = GetMedia("actionbutton-ants-small"),
	SpellAutoCastGlowColor = { Colors.cast[1], Colors.cast[2], Colors.cast[3] },
	SpellAutoCastGlowTexture = GetMedia("actionbutton-ants-small-glow"),
	SpellAutoCastPlace = { "CENTER", 0, 0 },
	SpellAutoCastSize = { 64/(122/256), 64/(122/256) },
	TooltipColorNameAsSpellWithUse = true, -- color item name as a spell (not by rarity) when it has a Use effect
	TooltipHideBindsWithUse = true, -- hide item bind status when it has a Use effect
	TooltipHideEquipTypeWithUse = false, -- hide item equip location and item type with Use effect
	TooltipHideItemLevelWithUse = true, -- hide item level when it has a Use effect 
	TooltipHideStatsWithUse = true, -- hide item stats when it has a Use effect
	TooltipHideUniqueWithUse = true -- hide item unique status when it has a Use effect
}

-- Bind Mode
Layouts.Bindings = {
	BindButton_PostCreate = BindMode_BindButton_PostCreate,
	BindButton_PostEnter = BindMode_BindButton_PostEnter,
	BindButton_PostLeave = BindMode_BindButton_PostLeave,
	BindButton_PostUpdate = BindMode_BindButton_PostUpdate,
	MenuButton_PostCreate = BindMode_MenuButton_PostCreate,
	MenuButton_PostUpdate = BindMode_MenuButton_PostUpdate, 
	MenuButtonSize = { MenuButtonW, MenuButtonH },
	MenuButtonSizeMod = .75, 
	MenuButtonSpacing = 10, 
	MenuWindow_CreateBorder = BindMode_MenuWindow_CreateBorder,
	Place = { "TOP", "UICenter", "TOP", 0, -100 }, 
	Size = { 520, 180 }
}

-- Floaters. Durability only currently. 
Layouts.FloaterHUD = {
	Place = { "CENTER", "UICenter", "CENTER", 190, 0 }
}

-- Group Leader Tools
Layouts.GroupTools = {
	ConvertButtonPlace = { "TOP", 0, -360 + 140 }, 
	ConvertButtonSize = { 300*.75, 50*.75 },
	ConvertButtonTextColor = { 0, 0, 0 }, 
	ConvertButtonTextFont = GetFont(14, false), 
	ConvertButtonTextShadowColor = { 1, 1, 1, .5 }, 
	ConvertButtonTextShadowOffset = { 0, -.85 }, 
	ConvertButtonTextureNormal = GetMedia("menu_button_disabled"), 
	ConvertButtonTextureSize = { 1024 *1/3 *.75, 256 *1/3 *.75 },
	MemberCountNumberColor = { Colors.title[1], Colors.title[2], Colors.title[3] },
	MemberCountNumberFont = GetFont(14, true),
	MemberCountNumberJustifyH = "CENTER",
	MemberCountNumberJustifyV = "MIDDLE", 
	MemberCountNumberPlace = { "TOP", 0, -20 }, 
	MenuAlternatePlace = { "BOTTOMLEFT", "UICenter", "BOTTOMLEFT", 22, 350 },
	MenuPlace = { "TOPLEFT", "UICenter", "TOPLEFT", 22, -42 },
	MenuSize = { 300*.75 +30, 410 - 140 }, 
	MenuToggleButtonSize = { 48, 48 }, 
	MenuToggleButtonPlace = { "TOPLEFT", "UICenter", "TOPLEFT", -18, -40 }, 
	MenuToggleButtonAlternatePlace = { "BOTTOMLEFT", "UICenter", "BOTTOMLEFT", -18, 348 }, 
	MenuToggleButtonIcon = GetMedia("raidtoolsbutton"), 
	MenuToggleButtonIconPlace = { "CENTER", 0, 0 }, 
	MenuToggleButtonIconSize = { 64*.75, 128*.75 }, 
	MenuToggleButtonIconColor = { 1, 1, 1 }, 
	MenuWindow_CreateBorder = GroupTools_Window_CreateBorder,
	OnButtonDisable = GroupTools_Button_OnDisable, 
	OnButtonEnable = GroupTools_Button_OnEnable,
	PostCreateButton = GroupTools_Button_PostCreate, 
	RaidRoleRaidTargetTexture = GetMedia("raid_target_icons"),
	RaidTargetIcon1Place = { "TOP", -80, -140 + 86 },
	RaidTargetIcon2Place = { "TOP", -28, -140 + 86 },
	RaidTargetIcon3Place = { "TOP",  28, -140 + 86 },
	RaidTargetIcon4Place = { "TOP",  80, -140 + 86 },
	RaidTargetIcon5Place = { "TOP", -80, -190 + 86 },
	RaidTargetIcon6Place = { "TOP", -28, -190 + 86 },
	RaidTargetIcon7Place = { "TOP",  28, -190 + 86 },
	RaidTargetIcon8Place = { "TOP",  80, -190 + 86 },
	RaidTargetIconsSize = { 48, 48 }, 
	ReadyCheckButtonPlace = { "TOP", -30, -310 + 140 }, 
	ReadyCheckButtonSize = { 300*.75 - 80, 50*.75 },
	ReadyCheckButtonTextColor = { 0, 0, 0 }, 
	ReadyCheckButtonTextFont = GetFont(14, false), 
	ReadyCheckButtonTextShadowColor = { 1, 1, 1, .5 }, 
	ReadyCheckButtonTextShadowOffset = { 0, -.85 }, 
	ReadyCheckButtonTextureNormal = GetMedia("menu_button_smaller"), 
	ReadyCheckButtonTextureSize = { 1024 *1/3 *.75, 256 *1/3 *.75 },
}

-- Minimap
Layouts.Minimap = {
	BattleGroundEyeColor = { .90, .95, 1 }, 
	BattleGroundEyePlace = { "CENTER", math_cos(45*math_pi/180) * (213/2 + 10), math_sin(45*math_pi/180) * (213/2 + 10) }, 
	BattleGroundEyeSize = { 64, 64 }, 
	BattleGroundEyeTexture = GetMedia("group-finder-eye-green"),
	BlipScale = 1.15, 
	BlipTextures = {
		["1.13.2"] = GetMedia("Blip-Nandini-New-113_2"),
		["1.13.3"] = GetMedia("Blip-Nandini-New-113_2"),
		["1.13.4"] = [[Interface\Minimap\ObjectIconsAtlas.blp]] -- Blizzard Fallback
	},
	Clock_OverrideValue = Minimap_Clock_OverrideValue,
	ClockColor = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3] }, 
	ClockFont = GetFont(15, true),
	ClockPlace = { "BOTTOMRIGHT", -(13 + 213), -8 },
	CompassColor = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .75 }, 
	CompassFont = GetFont(12, true), 
	CompassRadiusInset = 10, -- move the text 10 points closer to the center of the map
	CompassTexts = { L["N"] }, -- only setting the North tag text, as we don't want a full compass ( order is NESW )
	CoordinateColor = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 }, 
	CoordinateFont = GetFont(12, true), 
	CoordinatePlace = { "BOTTOM", 3, 23 },
	Coordinates_OverrideValue = Minimap_Coordinates_OverrideValue,
	FrameRate_OverrideValue = Minimap_FrameRate_OverrideValue,
	FrameRateColor = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .5 },
	FrameRateFont = GetFont(12, true), 
	FrameRatePlaceFunc = Minimap_Performance_FrameRate_PlaceFunc, 
	InnerRingBackdropMultiplier = 1, 
	InnerRingBarTexture = GetMedia("minimap-bars-two-inner"),
	InnerRingClockwise = true, 
	InnerRingColorPower = true,
	InnerRingColorStanding = true,
	InnerRingColorValue = true,
	InnerRingColorXP = true,
	InnerRingDegreeOffset = 90*3 - 21,
	InnerRingDegreeSpan = 360 - 21*2, 
	InnerRingPlace = { "CENTER", 0, 2 }, 
	InnerRingShowSpark = true, 
	InnerRingSize = { 208, 208 }, 
	InnerRingSparkBlendMode = "ADD",
	InnerRingSparkFlash = { nil, nil, 1, 1 }, 
	InnerRingSparkInset = 46 * 208/256,  
	InnerRingSparkMultiplier = 1, 
	InnerRingSparkOffset = -1/10,
	InnerRingSparkSize = { 6, 27 * 208/256 },
	InnerRingValueFont = GetFont(15, true),
	InnerRingValuePercentFont = GetFont(15, true), 
	Latency_OverrideValue = Minimap_Latency_OverrideValue,
	LatencyColor = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .5 },
	LatencyFont = GetFont(12, true), 
	LatencyPlaceFunc = Minimap_Performance_Latency_PlaceFunc, 
	MailPlace = Wheel("LibModule"):IsAddOnEnabled("MBB") and { "BOTTOMRIGHT", -(31 + 213 + 40), 35 } or { "BOTTOMRIGHT", -(31 + 213), 35 },
	MailSize = { 43, 32 },
	MailTexture = GetMedia("icon_mail"),
	MailTextureDrawLayer = { "ARTWORK", 1 },
	MailTexturePlace = { "CENTER", 0, 0 }, 
	MailTextureRotation = 15 * (2*math_pi)/360,
	MailTextureSize = { 66, 66 },
	MapBackdropColor = { 0, 0, 0, .75 }, 
	MapBackdropTexture = GetMedia("minimap_mask_circle"),
	MapBorderColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] }, 
	MapBorderPlace = { "CENTER", 0, 0 }, 
	MapBorderSize = { 419, 419 }, 
	MapBorderTexture = GetMedia("minimap-border"),
	MapOverlayColor = { 0, 0, 0, .15 },
	MapOverlayTexture = GetMedia("minimap_mask_circle"),
	MaskTexture = GetMedia("minimap_mask_circle_transparent"),
	MBBPlace = { "BOTTOMRIGHT", -(31 + 213), 35 },
	MBBSize = { 32, 32 },
	MBBTexture = GetMedia("plus"),
	OuterRingBackdropMultiplier = 1, 
	OuterRingClockwise = true, 
	OuterRingColorPower = true,
	OuterRingColorStanding = true,
	OuterRingColorValue = true,
	OuterRingColorXP = true,
	OuterRingDegreeOffset = 90*3 - 14,
	OuterRingDegreeSpan = 360 - 14*2, 
	OuterRingPlace = { "CENTER", 0, 2 }, 
	OuterRingSize = { 208, 208 }, 
	OuterRingShowSpark = true, 
	OuterRingSparkBlendMode = "ADD",
	OuterRingSparkFlash = { nil, nil, 1, 1 }, 
	OuterRingSparkOffset = -1/10, 
	OuterRingSparkMultiplier = 1, 
	OuterRingValueFont = GetFont(15, true),
	OuterRingValuePlace = { "CENTER", 0, -9 },
	OuterRingValueJustifyH = "CENTER",
	OuterRingValueJustifyV = "MIDDLE",
	OuterRingValueShowDeficit = true, 
	OuterRingValueDescriptionColor = { Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3] }, 
	OuterRingValueDescriptionFont = GetFont(12, true),
	OuterRingValueDescriptionJustifyH = "CENTER", 
	OuterRingValueDescriptionJustifyV = "MIDDLE", 
	OuterRingValueDescriptionPlace = { "CENTER", 0, -(15/2 + 2) }, 
	OuterRingValueDescriptionWidth = 100, 
	OuterRingValuePercentFont = GetFont(16, true),
	PerformanceFramePlaceAdvancedFunc = Minimap_Performance_PlaceFunc,
	Place = { "BOTTOMRIGHT", "UICenter", "BOTTOMRIGHT", -58, 59 }, 
	Rep_OverrideValue = Minimap_Rep_OverrideValue,
	RingFrameBackdropColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] }, 
	RingFrameBackdropDoubleTexture = GetMedia("minimap-twobars-backdrop"), 
	RingFrameBackdropDrawLayer = { "BACKGROUND", 1 }, 
	RingFrameBackdropPlace = { "CENTER", 0, 0 },
	RingFrameBackdropSize = { 413, 413 }, 
	RingFrameBackdropTexture = GetMedia("minimap-onebar-backdrop"), 
	RingFrameOuterRingSparkInset = { 15 * 208/256 }, 
	RingFrameOuterRingSparkSize = { 6,20 * 208/256 }, 
	RingFrameOuterRingTexture = GetMedia("minimap-bars-two-outer"), 
	RingFrameOuterRingValueFunc = Minimap_RingFrame_OuterRing_ValueFunc,
	RingFrameSingleRingSparkInset = { 22 * 208/256 }, 
	RingFrameSingleRingSparkSize = { 6,34 * 208/256 }, 
	RingFrameSingleRingValueFunc = Minimap_RingFrame_SingleRing_ValueFunc,
	RingFrameSingleRingTexture = GetMedia("minimap-bars-single"), 
	Size = { 213, 213 }, 
	ToggleBackdropColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] }, 
	ToggleBackdropTexture = GetMedia("point_plate"), 
	ToggleBackdropSize = { 100, 100 },
	ToggleSize = { 56, 56 }, 
	TrackingButtonBackdropColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] }, 
	TrackingButtonBackdropSize = { 100, 100 },
	TrackingButtonBackdropTexture = GetMedia("point_plate"), 
	TrackingButtonIconBgSize = { 32, 32 },
	TrackingButtonIconBgTexture = GetMedia("hp_critter_case_glow"),
	TrackingButtonIconMask = GetMedia("hp_critter_case_glow"), -- actionbutton_circular_mask
	TrackingButtonIconSize = { 28, 28 },
	TrackingButtonPlace = { "CENTER", math_cos(22.*math_pi/180) * (213/2 + 10), math_sin(22.5*math_pi/180) * (213/2 + 10) }, 
	TrackingButtonSize = { 56, 56 }, 
	XP_OverrideValue = Minimap_XP_OverrideValue,
	ZonePlaceFunc = Minimap_ZoneName_PlaceFunc,
	ZoneFont = GetFont(15, true)
}

-- NamePlates
Layouts.NamePlates = {
	AuraAnchor = "Health", 
	AuraBorderBackdrop = { edgeFile = GetMedia("aura_border"), edgeSize = 12 },
	AuraBorderBackdropBorderColor = { Colors.ui.stone[1] *.3, Colors.ui.stone[2] *.3, Colors.ui.stone[3] *.3 },
	AuraBorderBackdropColor = { 0, 0, 0, 0 },
	AuraBorderFramePlace = { "CENTER", 0, 0 }, 
	AuraBorderFrameSize = { 30 + 10, 30 + 10 },
	AuraCountColor = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
	AuraCountFont = GetFont(12, true),
	AuraCountPlace = { "BOTTOMRIGHT", 9, -6 },
	AuraFramePlace = { "TOPLEFT", (84 - (30*3 + 4*2))/2, 30*2 + 4 + 10 },
	AuraFrameSize = { 30*3 + 4*2, 30*2 + 4  }, 
	AuraIconPlace = { "CENTER", 0, 0 },
	AuraIconSize = { 30 - 6, 30 - 6 },
	AuraIconTexCoord = { 5/64, 59/64, 5/64, 59/64 }, -- aura icon tex coords
	AuraOffsetX = (84 - (30*3 + 4*2))/2, 
	AuraOffsetY = 10 + 4,
	AuraPoint = "BOTTOMLEFT", 
	AuraProperties = {
		growthX = "LEFT", 
		growthY = "UP", 
		spacingH = 4, 
		spacingV = 4, 
		auraSize = 30, auraWidth = nil, auraHeight = nil, 
		maxVisible = 6, maxBuffs = nil, maxDebuffs = nil, 
		filter = nil, filterBuffs = "PLAYER HELPFUL", filterDebuffs = "PLAYER HARMFUL", 
		func = GetAuraFilterFunc("nameplate"), funcBuffs = GetAuraFilterFunc("nameplate"), funcDebuffs = GetAuraFilterFunc("nameplate"), 
		debuffsFirst = true, 
		disableMouse = true, 
		showSpirals = false, 
		showDurations = true, 
		showLongDurations = true,
		tooltipDefaultPosition = false, 
		tooltipPoint = "BOTTOMLEFT",
		tooltipAnchor = nil,
		tooltipRelPoint = "TOPLEFT",
		tooltipOffsetX = -8,
		tooltipOffsetY = -16
	},
	AuraRelPoint = "TOPLEFT",
	AuraTimeFont = GetFont(11, true),
	AuraTimePlace = { "TOPLEFT", -6, 6 },
	CastBackdropColor = { 1, 1, 1, 1 },
	CastBackdropDrawLayer = { "BACKGROUND", 0 },
	CastBackdropPlace = { "CENTER", 0, 0 },
	CastBackdropSize = { 84*256/(256-28), 14*64/(64-28) },
	CastBackdropTexture = GetMedia("nameplate_backdrop"),
	CastColor = { Colors.cast[1], Colors.cast[2], Colors.cast[3], 1 },
	CastNameColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	CastNameDrawLayer = { "OVERLAY", 1 }, 
	CastNameFont = GetFont(12, true),
	CastNameJustifyH = "CENTER", 
	CastNameJustifyV = "MIDDLE",
	CastNamePlace = { "TOP", 0, -18 },
	CastOrientation = "LEFT", 
	CastPlace = { "TOP", 0, -20 },
	CastPostUpdate = NamePlate_CastBar_PostUpdate,
	CastShieldColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	CastShieldDrawLayer = { "BACKGROUND", -5 },
	CastShieldPlace = { "CENTER", 0, -1 }, 
	CastShieldSize = { 124, 69 },
	CastShieldTexture = GetMedia("cast_back_spiked"),
	CastSize = { 84, 14 }, 
	CastSparkMap = {
		top = {
			{ keyPercent =   0/256, offset = -16/32 }, 
			{ keyPercent =   4/256, offset = -16/32 }, 
			{ keyPercent =  19/256, offset =   0/32 }, 
			{ keyPercent = 236/256, offset =   0/32 }, 
			{ keyPercent = 256/256, offset = -16/32 }
		},
		bottom = {
			{ keyPercent =   0/256, offset = -16/32 }, 
			{ keyPercent =   4/256, offset = -16/32 }, 
			{ keyPercent =  19/256, offset =   0/32 }, 
			{ keyPercent = 236/256, offset =   0/32 }, 
			{ keyPercent = 256/256, offset = -16/32 }
		}
	},
	CastTexture = GetMedia("nameplate_bar"),
	CastTexCoord = { 14/256,(256-14)/256,14/64,(64-14)/64 },
	CastTimeToHoldFailed = .5, 
	HealthBackdropColor = { 1, 1, 1, 1 },
	HealthBackdropDrawLayer = { "BACKGROUND", -2 },
	HealthBackdropPlace = { "CENTER", 0, 0 },
	HealthBackdropSize = { 84*256/(256-28), 14*64/(64-28) },
	HealthBackdropTexture = GetMedia("nameplate_backdrop"),
	HealthBarOrientation = "LEFT", 
	HealthColorCivilian = true, 
	HealthColorClass = true, 
	HealthColorDisconnected = true,
	HealthColorHealth = true,
	HealthColorPlayer = true, 
	HealthColorReaction = true,
	HealthColorTapped = true,
	HealthFrequent = true,
	HealthPlace = { "TOP", 0, -2 },
	HealthSize = { 84, 14 }, 
	HealthSparkMap = {
		top = {
			{ keyPercent =   0/256, offset = -16/32 }, 
			{ keyPercent =   4/256, offset = -16/32 }, 
			{ keyPercent =  19/256, offset =   0/32 }, 
			{ keyPercent = 236/256, offset =   0/32 }, 
			{ keyPercent = 256/256, offset = -16/32 }
		},
		bottom = {
			{ keyPercent =   0/256, offset = -16/32 }, 
			{ keyPercent =   4/256, offset = -16/32 }, 
			{ keyPercent =  19/256, offset =   0/32 }, 
			{ keyPercent = 236/256, offset =   0/32 }, 
			{ keyPercent = 256/256, offset = -16/32 }
		}
	},
	HealthTexCoord = { 14/256,(256-14)/256,14/64,(64-14)/64 },
	HealthTexture = GetMedia("nameplate_bar"),
	PostCreateAuraButton = NamePlates_Auras_PostCreateButton,
	PostUpdateAura = NamePlates_Auras_PostUpdate,
	PostUpdateAuraButton = NamePlates_Auras_PostUpdateButton,
	PostUpdateRaidTarget = NamePlates_RaidTarget_PostUpdate,
	RaidTargetDrawLayer = { "ARTWORK", 0 },
	RaidTargetPlace = { "TOP", 0, 20+ 44 }, -- no auras
	RaidTargetPlace_AuraRow = { "TOP", 0, 20+ 80 }, -- auras, 1 row
	RaidTargetPlace_AuraRows = { "TOP", 0, 20+ 112 }, -- auras, 2 rows
	RaidTargetSize = { 64, 64 },
	RaidTargetTexture = GetMedia("raid_target_icons"),
	SetConsoleVars = {
		-- Because we want friendly NPC nameplates
		-- We're toning them down a lot as it is, 
		-- but we still prefer to have them visible, 
		-- and not the fugly super sized names we get otherwise.
		--nameplateShowFriendlyNPCs = 1, -- Don't enforce this

		-- Insets at the top and bottom of the screen 
		-- which the target nameplate will be kept away from. 
		-- Used to avoid the target plate being overlapped 
		-- by the target frame or actionbars and keep it in view.
		nameplateLargeTopInset = false, -- default .1
		nameplateOtherTopInset = .1, -- default .08
		nameplateLargeBottomInset = .02, -- default .15
		nameplateOtherBottomInset = .02, -- default .1
		nameplateClassResourceTopInset = 0,
	
		-- Nameplate scale
		nameplateMinScale = false, -- .8
		nameplateMaxScale = 1, 
		nameplateLargerScale = 1, -- Scale modifier for large plates, used for important monsters
		nameplateGlobalScale = 1,
		NamePlateHorizontalScale = 1,
		NamePlateVerticalScale = 1,
	
		-- Alpha defaults (these are enforced to other values by the back-end now)
		nameplateMaxAlpha = false, 
		nameplateMinAlphaDistance = false, 
		nameplateMinAlpha = false,
		nameplateMaxAlphaDistance = false,
		nameplateOccludedAlphaMult = false, 
		nameplateSelectedAlpha = false, 
	
		-- The minimum distance from the camera plates will reach their minimum scale and alpha
		nameplateMinScaleDistance = false, 
		
		-- The maximum distance from the camera where plates will still have max scale and alpha
		nameplateMaxScaleDistance = 20, -- 10
	
		-- Show nameplates above heads or at the base (0 or 2,
		nameplateOtherAtBase = 0,
	
		-- Scale and Alpha of the selected nameplate (current target,
		nameplateSelectedScale = 1, -- default 1.2
	
		-- The max distance to show nameplates.
		nameplateMaxDistance = false, -- 20 is classic upper limit, 60 is BfA default
	
		-- The max distance to show the target nameplate when the target is behind the camera.
		nameplateTargetBehindMaxDistance = 15 -- default 15
	},
	Size = { 80, 32 }
}

-- Custom Tooltips
Layouts.Tooltips = {
	PostCreateBar = Tooltip_Bar_PostCreate,
	PostCreateLinePair = Tooltip_LinePair_PostCreate,
	PostCreateTooltip = Tooltip_PostCreate,
	TooltipBackdrop = {
		bgFile = [[Interface\ChatFrame\ChatFrameBackground]], 
		edgeFile = GetMedia("tooltip_border_blizzcompatible"), 
		edgeSize = 32, 
		insets = { top = 2.5, bottom = 2.5, left = 2.5, right = 2.5 },
		tile = false
	},
	TooltipBackdropBorderColor = { 1, 1, 1, 1 },
	TooltipBackdropColor = { .05, .05, .05, .85 },
	TooltipPlace = { "BOTTOMRIGHT", "UICenter", "BOTTOMRIGHT", -(48 + 58 + 213), (107 + 59) }, 
	TooltipStatusBarTexture = GetMedia("statusbar_normal")
}

------------------------------------------------
-- Unit Frame Layouts
------------------------------------------------
-- Player
Layouts.UnitFramePlayer = { 
	Aura_PostCreateButton = UnitFrame_Aura_PostCreateButton,
	Aura_PostUpdateButton = UnitFrame_Aura_PostUpdateButton,
	AuraBorderBackdrop = { edgeFile = GetMedia("aura_border"), edgeSize = 16 },
	AuraBorderBackdropColor = { 0, 0, 0, 0 },
	AuraBorderBackdropBorderColor = { Colors.ui.stone[1] *.3, Colors.ui.stone[2] *.3, Colors.ui.stone[3] *.3 },
	AuraBorderFramePlace = { "CENTER", 0, 0 }, 
	AuraBorderFrameSize = { 40 + 14, 40 + 14 },
	AuraCountColor = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
	AuraCountFont = GetFont(14, true),
	AuraCountPlace = { "BOTTOMRIGHT", 9, -6 },
	AuraFramePlace = { "BOTTOMLEFT", 27 + 10, 27 + 24 + 40 },
	AuraFrameSize = { 40*8 + 6*7, 40 },
	AuraIconPlace = { "CENTER", 0, 0 },
	AuraIconSize = { 40 - 6, 40 - 6 },
	AuraIconTexCoord = { 5/64, 59/64, 5/64, 59/64 },
	AuraProperties = {
		auraHeight = nil, 
		auraSize = 40, 
		auraWidth = nil, 
		debuffsFirst = true, 
		disableMouse = false, 
		filter = nil, 
		filterBuffs = "HELPFUL", 
		filterDebuffs = "HARMFUL", 
		func = nil, 
		funcBuffs = GetAuraFilterFunc("player"), 
		funcDebuffs = GetAuraFilterFunc("player"), 
		growthX = "RIGHT", 
		growthY = "UP", 
		maxBuffs = nil, 
		maxDebuffs = nil, 
		maxVisible = 16, 
		showDurations = true, 
		showSpirals = false, 
		showLongDurations = true,
		spacingH = 6, 
		spacingV = 6, 
		tooltipAnchor = nil,
		tooltipDefaultPosition = false, 
		tooltipOffsetX = 8,
		tooltipOffsetY = 16,
		tooltipPoint = "BOTTOMLEFT",
		tooltipRelPoint = "TOPLEFT"
	},
	AuraTimeFont = GetFont(14, true),
	AuraTimePlace = { "TOPLEFT", -6, 6 },
	CastBarColor = { 1, 1, 1, .25 }, 
	CastBarNameColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	CastBarNameDrawLayer = { "OVERLAY", 1 }, 
	CastBarNameFont = GetFont(16, true),
	CastBarNameJustifyH = "LEFT", 
	CastBarNameJustifyV = "MIDDLE",
	CastBarNameParent = "Health",
	CastBarNamePlace = { "LEFT", 27, 4 },
	CastBarNameSize = { 250, 40 }, 
	CastBarOrientation = "RIGHT",
	CastBarPlace = { "BOTTOMLEFT", 27, 27 },
	CastBarPostUpdate = PlayerFrame_CastBarPostUpdate,
	CastBarSize = { 385, 40 },
	CastBarSparkMap = {
		{ keyPercent =   0/512, topOffset = -24/64, bottomOffset = -39/64 }, 
		{ keyPercent =   9/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 460/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 478/512, topOffset =   0/64, bottomOffset =   0/64 }, 
		{ keyPercent = 483/512, topOffset =   0/64, bottomOffset =  -3/64 }, 
		{ keyPercent = 507/512, topOffset =   0/64, bottomOffset = -46/64 }, 
		{ keyPercent = 512/512, topOffset = -11/64, bottomOffset = -54/64 }  
	},
	CastBarValueColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	CastBarValueDrawLayer = { "OVERLAY", 1 },
	CastBarValueFont = GetFont(18, true),
	CastBarValueParent = "Health",
	CastBarValuePlace = { "RIGHT", -27, 4 },
	CastBarValueJustifyH = "CENTER",
	CastBarValueJustifyV = "MIDDLE",
	ClassificationColor = { 1, 1, 1 },
	ClassificationIndicatorAllianceTexture = GetMedia("icon_badges_alliance"),
	ClassificationIndicatorHordeTexture = GetMedia("icon_badges_horde"),
	ClassificationPlace ={ "BOTTOMLEFT", -(41 + 80/2), (22 - 80/2) },
	ClassificationSize = { 84, 84 },
	CombatIndicatorColor = { Colors.ui.stone[1] *.75, Colors.ui.stone[2] *.75, Colors.ui.stone[3] *.75 }, 
	CombatIndicatorDrawLayer = {"OVERLAY", -2 },
	CombatIndicatorPlace = { "BOTTOMLEFT", -(41 + 80/2), (22 - 80/2) },
	CombatIndicatorSize = { 80,80 },
	CombatIndicatorTexture = GetMedia("icon-combat"),
	ExplorerHitRects = { 60, 0, -140, 0 },
	HardenedCastSize = { 385, 37 },
	HardenedCastTexture = GetMedia("hp_lowmid_bar"),
	HardenedHealthBackdropColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	HardenedHealthBackdropTexture = GetMedia("hp_mid_case"),
	HardenedHealthSize = { 385, 37 },
	HardenedHealthSparkMap = {
		{ keyPercent =   0/512, topOffset = -24/64, bottomOffset = -39/64 }, 
		{ keyPercent =   9/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 460/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 478/512, topOffset =   0/64, bottomOffset =   0/64 }, 
		{ keyPercent = 483/512, topOffset =   0/64, bottomOffset =  -3/64 }, 
		{ keyPercent = 507/512, topOffset =   0/64, bottomOffset = -46/64 }, 
		{ keyPercent = 512/512, topOffset = -11/64, bottomOffset = -54/64 }  
	},
	HardenedHealthTexture = GetMedia("hp_lowmid_bar"),
	HardenedLevel = 40,
	HardenedManaOrbColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	HardenedManaOrbTexture = GetMedia("orb_case_hi"),
	HardenedPowerForegroundColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	HardenedPowerForegroundTexture = GetMedia("pw_crystal_case"),
	HealthBackdropDrawLayer = { "BACKGROUND", -1 },
	HealthBackdropPlace = { "CENTER", 1, -.5 },
	HealthBackdropSize = { 716, 188 },
	HealthBarOrientation = "RIGHT", 
	HealthBarSetFlippedHorizontally = false, 
	HealthBarSparkMap = {
		{ keyPercent =   0/512, topOffset = -24/64, bottomOffset = -39/64 }, 
		{ keyPercent =   9/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 460/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 478/512, topOffset =   0/64, bottomOffset =   0/64 }, 
		{ keyPercent = 483/512, topOffset =   0/64, bottomOffset =  -3/64 }, 
		{ keyPercent = 507/512, topOffset =   0/64, bottomOffset = -46/64 }, 
		{ keyPercent = 512/512, topOffset = -11/64, bottomOffset = -54/64 }  
	},
	HealthColorClass = false, -- color players by class 
	HealthColorDisconnected = false, -- color disconnected units
	HealthColorHealth = true, -- color anything else in the default health color
	HealthColorReaction = false, -- color NPCs by their reaction standing with us
	HealthColorTapped = false, -- color tap denied units 
	HealthFrequentUpdates = true, -- listen to frequent health events for more accurate updates
	HealthPlace = { "BOTTOMLEFT", 27, 27 },
	HealthSmoothingMode = "bezier-fast-in-slow-out", 
	HealthSmoothingFrequency = 3,
	HealthValueColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	HealthValueDrawLayer = { "OVERLAY", 1 },
	HealthValueFont = GetFont(18, true),
	HealthValueJustifyH = "LEFT", 
	HealthValueJustifyV = "MIDDLE", 
	HealthValuePlace = { "LEFT", 27, 4 },
	HitRectInsets = { 0, 0, 0, 6 }, 
	LoveCombatIndicatorColor = { Colors.ui.stone[1] *.75, Colors.ui.stone[2] *.75, Colors.ui.stone[3] *.75 }, 
	LoveCombatIndicatorDrawLayer = {"OVERLAY", -2 },
	LoveCombatIndicatorPlace = { "BOTTOMLEFT", -(41 + 48/2 -4), (22 - 48/2 +4) },
	LoveCombatIndicatorSize = { 48,48 },
	LoveCombatIndicatorTexture = GetMedia("icon-heart-red"),
	ManaBackgroundColor = { 22/255, 26/255, 22/255, .82 },
	ManaBackgroundDrawLayer = { "BACKGROUND", -2 }, 
	ManaBackgroundPlace = { "CENTER", 0, 0 }, 
	ManaBackgroundSize = { 113, 113 }, 
	ManaBackgroundTexture = GetMedia("pw_orb_bar3"),
	ManaColorSuffix = "_ORB", 
	ManaExclusiveResource = "MANA", 
	ManaForegroundDrawLayer = { "BORDER", 1 },
	ManaForegroundPlace = { "CENTER", 0, 0 }, 
	ManaForegroundSize = { 188, 188 }, 
	ManaOrbTextures = { GetMedia("pw_orb_bar4"), GetMedia("pw_orb_bar3"), GetMedia("pw_orb_bar3") },
	ManaOverridePowerColor = PlayerFrame_ExtraPowerOverrideColor,
	ManaPlace = { "BOTTOMLEFT", -97 +5, 22 + 5 }, 
	ManaShadeColor = { 1, 1, 1, 1 }, 
	ManaShadeDrawLayer = { "BORDER", -1 }, 
	ManaShadePlace = { "CENTER", 0, 0 }, 
	ManaShadeSize = { 127, 127 }, 
	ManaShadeTexture = GetMedia("shade_circle"), 
	ManaSize = { 103, 103 },
	ManaTextColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	ManaTextDrawLayer = { "OVERLAY", 1 },
	ManaTextFont = GetFont(14, true),
	ManaTextJustifyH = "CENTER", 
	ManaTextJustifyV = "MIDDLE", 
	ManaTextOverride = function(element, unit, min, max)
		if (not min) or (not max) or (min == 0) or (max == 0) or (min == max) then
			element:SetText("")
		else
			local perc = min/max
			if (perc < .25) then
				element:SetTextColor(Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3], .85)
			else 
				element:SetTextColor(Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5)
			end 
			element:SetFormattedText("%.0f", math_floor(min/max * 100))
		end 
	end,
	ManaTextParent = "Power", 
	ManaTextPlace = { "CENTER", 1, -32 },
	ManaValueColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .4 },
	ManaValueDrawLayer = { "OVERLAY", 1 },
	ManaValueFont = GetFont(18, true),
	ManaValueJustifyH = "CENTER", 
	ManaValueJustifyV = "MIDDLE", 
	ManaValuePlace = { "CENTER", 3, 0 },
	NoviceCastSize = { 385, 37 },
	NoviceCastTexture = GetMedia("hp_lowmid_bar"),
	NoviceHealthBackdropColor = { Colors.ui.wood[1], Colors.ui.wood[2], Colors.ui.wood[3] },
	NoviceHealthBackdropTexture = GetMedia("hp_low_case"),
	NoviceHealthSize = { 385, 37 },
	NoviceHealthSparkMap = {
		{ keyPercent =   0/512, topOffset = -24/64, bottomOffset = -39/64 }, 
		{ keyPercent =   9/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 460/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 478/512, topOffset =   0/64, bottomOffset =   0/64 }, 
		{ keyPercent = 483/512, topOffset =   0/64, bottomOffset =  -3/64 }, 
		{ keyPercent = 507/512, topOffset =   0/64, bottomOffset = -46/64 }, 
		{ keyPercent = 512/512, topOffset = -11/64, bottomOffset = -54/64 }  
	},
	NoviceHealthTexture = GetMedia("hp_lowmid_bar"),
	NoviceManaOrbColor = { Colors.ui.wood[1], Colors.ui.wood[2], Colors.ui.wood[3] },
	NoviceManaOrbTexture = GetMedia("orb_case_low"),
	NovicePowerForegroundTexture = GetMedia("pw_crystal_case_low"),
	NovicePowerForegroundColor = { Colors.ui.wood[1], Colors.ui.wood[2], Colors.ui.wood[3] },
	Place = { "BOTTOMLEFT", 167, 100 },
	PostUpdateTextures = PlayerFrame_TexturesPostUpdate,
	PowerOverrideColor = PlayerFrame_PowerOverrideColor, 
	PowerBackgroundColor = { 1, 1, 1, .95 },
	PowerBackgroundDrawLayer = { "BACKGROUND", -2 },
	PowerBackgroundPlace = { "CENTER", 0, 0 },
	PowerBackgroundSize = { 120/(206-50)*255, 140/(219-37)*255 },
	PowerBackgroundTexture = GetMedia("power_crystal_back"),
	PowerBarOrientation = "UP",
	PowerBarSmoothingFrequency = .45,
	PowerBarSmoothingMode = "bezier-fast-in-slow-out",
	PowerBarSparkMap = {
		top = {
			{ keyPercent =   0/256, offset =  -65/256 }, 
			{ keyPercent =  72/256, offset =    0/256 }, 
			{ keyPercent = 116/256, offset =  -16/256 }, 
			{ keyPercent = 128/256, offset =  -28/256 }, 
			{ keyPercent = 256/256, offset =  -84/256 }, 
		},
		bottom = {
			{ keyPercent =   0/256, offset =  -47/256 }, 
			{ keyPercent =  84/256, offset =    0/256 }, 
			{ keyPercent = 135/256, offset =  -24/256 }, 
			{ keyPercent = 142/256, offset =  -32/256 }, 
			{ keyPercent = 225/256, offset =  -79/256 }, 
			{ keyPercent = 256/256, offset = -168/256 }, 
		}
	},
	PowerBarTexCoord = { 50/255, 206/255, 37/255, 219/255 },
	PowerBarTexture = GetMedia("power_crystal_front"),
	PowerColorSuffix = "_CRYSTAL", 
	PowerForegroundPlace = { "BOTTOM", 7, -51 }, 
	PowerForegroundSize = { 198,98 }, 
	PowerForegroundTexture = GetMedia("pw_crystal_case"), 
	PowerForegroundDrawLayer = { "ARTWORK", 1 },
	PowerIgnoredResource = "MANA",
	PowerPlace = { "BOTTOMLEFT", -101, 38 },
	PowerSize = { 120, 140 },
	PowerType = "StatusBar", 
	PowerValueColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .4 },
	PowerValueDrawLayer = { "OVERLAY", 1 },
	PowerValueFont = GetFont(18, true),
	PowerValueJustifyH = "CENTER", 
	PowerValueJustifyV = "MIDDLE", 
	PowerValuePlace = { "CENTER", 0, -16 },
	SeasonedCastSize = { 385, 40 },
	SeasonedCastTexture = GetMedia("hp_cap_bar_highlight"),
	SeasonedHealthBackdropColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	SeasonedHealthBackdropTexture = GetMedia("hp_cap_case"),
	SeasonedHealthSize = { 385, 40 },
	SeasonedHealthSparkMap = {
		{ keyPercent =   0/512, topOffset = -24/64, bottomOffset = -39/64 }, 
		{ keyPercent =   9/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 460/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 478/512, topOffset =   0/64, bottomOffset =   0/64 }, 
		{ keyPercent = 483/512, topOffset =   0/64, bottomOffset =  -3/64 }, 
		{ keyPercent = 507/512, topOffset =   0/64, bottomOffset = -46/64 }, 
		{ keyPercent = 512/512, topOffset = -11/64, bottomOffset = -54/64 }  
	},
	SeasonedHealthTexture = GetMedia("hp_cap_bar"),
	SeasonedManaOrbColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	SeasonedManaOrbTexture = GetMedia("orb_case_hi"),
	SeasonedPowerForegroundColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	SeasonedPowerForegroundTexture = GetMedia("pw_crystal_case"),
	Size = { 439, 93 },
	WinterVeilManaColor = { 1, 1, 1 }, 
	WinterVeilManaDrawLayer = { "OVERLAY", 0 },
	WinterVeilManaPlace = { "CENTER", 0, 0 },
	WinterVeilManaSize = { 188, 188 },
	WinterVeilManaTexture = GetMedia("seasonal_winterveil_orb"), 
	WinterVeilPowerColor = { 1, 1, 1 }, 
	WinterVeilPowerDrawLayer = { "OVERLAY", 0 },
	WinterVeilPowerPlace = { "CENTER", -2, 24 },
	WinterVeilPowerTexture = GetMedia("seasonal_winterveil_crystal"), 
	WinterVeilPowerSize = { 120 / ((255-50*2)/255), 140 / ((255-37*2)/255) }
}

-- PlayerHUD (combo points and castbar)
Layouts.UnitFramePlayerHUD = {
	CastBarColor = { 70/255, 255/255, 131/255, .69 }, 
	CastBarOrientation = "RIGHT",
	CastTimeToHoldFailed = .5, 
	CastBarBackgroundColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	CastBarBackgroundDrawLayer = { "BACKGROUND", 1 },
	CastBarBackgroundPlace = { "CENTER", 1, -1 }, 
	CastBarBackgroundSize = { 193,93 },
	CastBarBackgroundTexture = GetMedia("cast_back"), 
	CastBarValueColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	CastBarValueDrawLayer = { "OVERLAY", 1 },
	CastBarValueFont = GetFont(14, true),
	CastBarValueJustifyH = "CENTER",
	CastBarValueJustifyV = "MIDDLE",
	CastBarValuePlace = { "CENTER", 0, 0 },
	CastBarNameColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	CastBarNameDrawLayer = { "OVERLAY", 1 },
	CastBarNameFont = GetFont(15, true),
	CastBarNameJustifyH = "CENTER",
	CastBarNameJustifyV = "MIDDLE",
	CastBarNamePlace = { "TOP", 0, -(12 + 14) },
	CastBarPlace = { "BOTTOM", "UICenter", "BOTTOM", 0, 250 }, -- CENTER, 0, -133
	CastBarSize = Constant.SmallBar,
	CastBarShieldColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	CastBarShieldDrawLayer = { "BACKGROUND", 1 }, 
	CastBarShieldPlace = { "CENTER", 1, -2 }, 
	CastBarShieldSize = { 193, 93 },
	CastBarShieldTexture = GetMedia("cast_back_spiked"), 
	CastBarSparkMap = {
		top = {
			{ keyPercent =   0/128, offset = -16/32 }, 
			{ keyPercent =  10/128, offset =   0/32 }, 
			{ keyPercent = 119/128, offset =   0/32 }, 
			{ keyPercent = 128/128, offset = -16/32 }
		},
		bottom = {
			{ keyPercent =   0/128, offset = -16/32 }, 
			{ keyPercent =  10/128, offset =   0/32 }, 
			{ keyPercent = 119/128, offset =   0/32 }, 
			{ keyPercent = 128/128, offset = -16/32 }
		}
	},
	CastBarSpellQueuePlace = { "BOTTOM", "UICenter", "BOTTOM", 0, 250 }, 
	CastBarSpellQueueSize = Constant.SmallBar,
	CastBarSpellQueueTexture = Constant.SmallBarTexture, 
	CastBarSpellQueueColor = { 1, 1, 1, .5 },
	CastBarSpellQueueOrientation = "LEFT",
	CastBarSpellQueueSparkMap = {
		top = {
			{ keyPercent =   0/128, offset = -16/32 }, 
			{ keyPercent =  10/128, offset =   0/32 }, 
			{ keyPercent = 119/128, offset =   0/32 }, 
			{ keyPercent = 128/128, offset = -16/32 }
		},
		bottom = {
			{ keyPercent =   0/128, offset = -16/32 }, 
			{ keyPercent =  10/128, offset =   0/32 }, 
			{ keyPercent = 119/128, offset =   0/32 }, 
			{ keyPercent = 128/128, offset = -16/32 }
		}
	},
	CastBarTexture = Constant.SmallBarTexture, 
	ClassPowerAlphaWhenEmpty = .5, 
	ClassPowerAlphaWhenOutOfCombat = 1,
	ClassPowerAlphaWhenOutOfCombatRunes = .5, 
	ClassPowerHideWhenNoTarget = true, 
	ClassPowerHideWhenUnattackable = true, 
	ClassPowerMaxComboPoints = 5, 
	ClassPowerPlace = { "CENTER", "UICenter", "CENTER", 0, 0 }, 
	ClassPowerPostCreatePoint = PlayerHUD_ClassPowerPostCreatePoint,
	ClassPowerPostUpdate = PlayerHUD_ClassPowerPostUpdate,
	ClassPowerReverseSides = false, 
	ClassPowerRuneSortOrder = "ASC",
	ClassPowerSize = { 2,2 }, 
	IgnoreMouseOver = true, 
	Place = { "BOTTOMLEFT", 75, 127 },
	Size = { 103, 103 }
}

-- Target
Layouts.UnitFrameTarget = { 
	Aura_PostCreateButton = UnitFrame_Aura_PostCreateButton,
	Aura_PostUpdateButton = UnitFrame_Aura_PostUpdateButton,
	AuraBorderBackdrop = { edgeFile = GetMedia("aura_border"), edgeSize = 16 },
	AuraBorderBackdropColor = { 0, 0, 0, 0 },
	AuraBorderBackdropBorderColor = { Colors.ui.stone[1] *.3, Colors.ui.stone[2] *.3, Colors.ui.stone[3] *.3 }, 
	AuraBorderFramePlace = { "CENTER", 0, 0 }, 
	AuraBorderFrameSize = { 40 + 14, 40 + 14 },
	AuraCountColor = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
	AuraCountFont = GetFont(14, true),
	AuraCountPlace = { "BOTTOMRIGHT", 9, -6 },
	AuraFramePlace = { "TOPRIGHT", -(27 + 10), -(27 + 40 + 20) },
	AuraFrameSize = { 40*7 + 6*(7 -1), 40 },
	AuraIconPlace = { "CENTER", 0, 0 },
	AuraIconSize = { 40 - 6, 40 - 6 },
	AuraIconTexCoord = { 5/64, 59/64, 5/64, 59/64 }, 
	AuraProperties = {
		auraHeight = nil, 
		auraSize = 40, 
		auraWidth = nil, 
		debuffsFirst = true, 
		disableMouse = false, 
		filter = nil, 
		filterBuffs = "HELPFUL", 
		filterDebuffs = "HARMFUL", 
		func = nil, 
		funcBuffs = GetAuraFilterFunc("target"), 
		funcDebuffs = GetAuraFilterFunc("target"), 
		growthX = "LEFT", 
		growthY = "DOWN", 
		maxBuffs = nil, 
		maxDebuffs = nil, 
		maxVisible = 14, 
		showDurations = true, 
		showLongDurations = true,
		showSpirals = false, 
		spacingH = 6, 
		spacingV = 6, 
		tooltipAnchor = nil,
		tooltipDefaultPosition = false, 
		tooltipOffsetX = -8,
		tooltipOffsetY = -16,
		tooltipPoint = "TOPRIGHT",
		tooltipRelPoint = "BOTTOMRIGHT"
	},
	AuraTimeFont = GetFont(14, true),
	AuraTimePlace = { "TOPLEFT", -6, 6 }, 
	BossCastPlace = { "TOPRIGHT", -27, -27 }, 
	BossCastSize = { 533, 40 },
	BossCastSparkMap = {
		top = {
			{ keyPercent =    0/1024, offset = -24/64 }, 
			{ keyPercent =   13/1024, offset =   0/64 }, 
			{ keyPercent = 1018/1024, offset =   0/64 }, 
			{ keyPercent = 1024/1024, offset = -10/64 }
		},
		bottom = {
			{ keyPercent =    0/1024, offset = -39/64 }, 
			{ keyPercent =   13/1024, offset = -16/64 }, 
			{ keyPercent =  949/1024, offset = -16/64 }, 
			{ keyPercent =  977/1024, offset =  -1/64 }, 
			{ keyPercent =  984/1024, offset =  -2/64 }, 
			{ keyPercent = 1024/1024, offset = -52/64 }
		}
	},
	BossCastTexture = GetMedia("hp_boss_bar"),
	BossHealthBackdropColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	BossHealthBackdropPlace = { "CENTER", -.5, 1 }, 
	BossHealthBackdropSize = { 694, 190 }, 
	BossHealthBackdropTexture = GetMedia("hp_boss_case"),
	BossHealthPercentVisible = true, 
	BossHealthPlace = { "TOPRIGHT", -27, -27 }, 
	BossHealthSize = { 533, 40 },
	BossHealthSparkMap = {
		top = {
			{ keyPercent =    0/1024, offset = -24/64 }, 
			{ keyPercent =   13/1024, offset =   0/64 }, 
			{ keyPercent = 1018/1024, offset =   0/64 }, 
			{ keyPercent = 1024/1024, offset = -10/64 }
		},
		bottom = {
			{ keyPercent =    0/1024, offset = -39/64 }, 
			{ keyPercent =   13/1024, offset = -16/64 }, 
			{ keyPercent =  949/1024, offset = -16/64 }, 
			{ keyPercent =  977/1024, offset =  -1/64 }, 
			{ keyPercent =  984/1024, offset =  -2/64 }, 
			{ keyPercent = 1024/1024, offset = -52/64 }
		}
	},
	BossHealthTexture = GetMedia("hp_boss_bar"),
	BossHealthValueVisible = true, 
	BossPortraitForegroundColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] }, 
	BossPortraitForegroundTexture = GetMedia("portrait_frame_hi"),
	BossPowerForegroundColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	BossPowerForegroundTexture = GetMedia("pw_crystal_case"),
	CastBarColor = { 1, 1, 1, .25 }, 
	CastBarNameColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	CastBarNameDrawLayer = { "OVERLAY", 1 }, 
	CastBarNameFont = GetFont(16, true),
	CastBarNameJustifyH = "RIGHT", 
	CastBarNameJustifyV = "MIDDLE",
	CastBarNamePlace = { "RIGHT", -27, 4 },
	CastBarNameSize = { 250, 40 }, 
	CastBarOrientation = "LEFT", 
	CastBarPlace = { "BOTTOMLEFT", 27, 27 },
	CastBarPostUpdate = TargetFrame_CastBarPostUpdate,
	CastBarSetFlippedHorizontally = true, 
	CastBarSmoothingMode = "bezier-fast-in-slow-out", 
	CastBarSmoothingFrequency = .15,
	CastBarSize = { 385, 40 },
	CastBarSparkMap = {
		{ keyPercent =   0/512, topOffset = -24/64, bottomOffset = -39/64 }, 
		{ keyPercent =   9/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 460/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 478/512, topOffset =   0/64, bottomOffset =   0/64 }, 
		{ keyPercent = 483/512, topOffset =   0/64, bottomOffset =  -3/64 }, 
		{ keyPercent = 507/512, topOffset =   0/64, bottomOffset = -46/64 }, 
		{ keyPercent = 512/512, topOffset = -11/64, bottomOffset = -54/64 }  
	},
	CastBarValueColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	CastBarValueDrawLayer = { "OVERLAY", 1 },
	CastBarValueFont = GetFont(18, true),
	CastBarValueJustifyH = "CENTER",
	CastBarValueJustifyV = "MIDDLE",
	CastBarValuePlace = { "LEFT", 27, 4 },
	ClassificationColor = { 1, 1, 1 },
	ClassificationIndicatorAllianceTexture = GetMedia("icon_badges_alliance"),
	ClassificationIndicatorBossTexture = GetMedia("icon_badges_boss"),
	ClassificationIndicatorEliteTexture = GetMedia("icon_classification_elite"),
	ClassificationIndicatorHordeTexture = GetMedia("icon_badges_horde"),
	ClassificationIndicatorRareTexture = GetMedia("icon_classification_rare"),
	ClassificationPlace = { "BOTTOMRIGHT", 72, -43 },
	ClassificationSize = { 84, 84 },
	CritterCastPlace = { "TOPRIGHT", -24, -24 },
	CritterCastSize = { 40, 36 },
	CritterCastSparkMap = {
		top = {
			{ keyPercent =  0/64, offset = -30/64 }, 
			{ keyPercent = 14/64, offset =  -1/64 }, 
			{ keyPercent = 49/64, offset =  -1/64 }, 
			{ keyPercent = 64/64, offset = -34/64 }
		},
		bottom = {
			{ keyPercent =  0/64, offset = -30/64 }, 
			{ keyPercent = 15/64, offset =   0/64 }, 
			{ keyPercent = 32/64, offset =  -1/64 }, 
			{ keyPercent = 50/64, offset =  -4/64 }, 
			{ keyPercent = 64/64, offset = -27/64 }
		}
	},
	CritterCastTexture = GetMedia("hp_critter_bar"),
	CritterHealthBackdropColor = { Colors.ui.wood[1], Colors.ui.wood[2], Colors.ui.wood[3] },
	CritterHealthBackdropPlace = { "CENTER", 0, 1 }, 
	CritterHealthBackdropSize = { 98,96 }, 
	CritterHealthBackdropTexture = GetMedia("hp_critter_case"),
	CritterHealthPercentVisible = false, 
	CritterHealthPlace = { "TOPRIGHT", -24, -24 }, 
	CritterHealthSize = { 40, 36 },
	CritterHealthSparkMap = {
		top = {
			{ keyPercent =  0/64, offset = -30/64 }, 
			{ keyPercent = 14/64, offset =  -1/64 }, 
			{ keyPercent = 49/64, offset =  -1/64 }, 
			{ keyPercent = 64/64, offset = -34/64 }
		},
		bottom = {
			{ keyPercent =  0/64, offset = -30/64 }, 
			{ keyPercent = 15/64, offset =   0/64 }, 
			{ keyPercent = 32/64, offset =  -1/64 }, 
			{ keyPercent = 50/64, offset =  -4/64 }, 
			{ keyPercent = 64/64, offset = -27/64 }
		}
	},
	CritterHealthTexture = GetMedia("hp_critter_bar"),
	CritterHealthValueVisible = false, 
	CritterPortraitForegroundColor = { Colors.ui.wood[1], Colors.ui.wood[2], Colors.ui.wood[3] }, 
	CritterPortraitForegroundTexture = GetMedia("portrait_frame_lo"),
	CritterPowerForegroundColor = { Colors.ui.wood[1], Colors.ui.wood[2], Colors.ui.wood[3] },
	CritterPowerForegroundTexture = GetMedia("pw_crystal_case_low"),
	HardenedCastPlace = { "TOPRIGHT", -27, -27 }, 
	HardenedCastSize = { 385, 37 },
	HardenedCastSparkMap = {
		{ keyPercent =   0/512, topOffset = -24/64, bottomOffset = -39/64 }, 
		{ keyPercent =   9/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 460/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 478/512, topOffset =   0/64, bottomOffset =   0/64 }, 
		{ keyPercent = 483/512, topOffset =   0/64, bottomOffset =  -3/64 }, 
		{ keyPercent = 507/512, topOffset =   0/64, bottomOffset = -46/64 }, 
		{ keyPercent = 512/512, topOffset = -11/64, bottomOffset = -54/64 }  
	},
	HardenedCastTexture = GetMedia("hp_lowmid_bar"),
	HardenedHealthBackdropColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	HardenedHealthBackdropPlace = { "CENTER", -2, -1 }, 
	HardenedHealthBackdropSize = { 716, 188 }, 
	HardenedHealthBackdropTexture = GetMedia("hp_mid_case"),
	HardenedHealthPercentVisible = true, 
	HardenedHealthPlace = { "TOPRIGHT", -27, -27 }, 
	HardenedHealthSize = { 385, 37 },
	HardenedHealthSparkMap = {
		{ keyPercent =   0/512, topOffset = -24/64, bottomOffset = -39/64 }, 
		{ keyPercent =   9/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 460/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 478/512, topOffset =   0/64, bottomOffset =   0/64 }, 
		{ keyPercent = 483/512, topOffset =   0/64, bottomOffset =  -3/64 }, 
		{ keyPercent = 507/512, topOffset =   0/64, bottomOffset = -46/64 }, 
		{ keyPercent = 512/512, topOffset = -11/64, bottomOffset = -54/64 }  
	},
	HardenedHealthTexture = GetMedia("hp_lowmid_bar"),
	HardenedHealthValueVisible = true, 
	HardenedLevel = 40,
	HardenedPortraitForegroundColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] }, 
	HardenedPortraitForegroundTexture = GetMedia("portrait_frame_hi"),
	HardenedPowerForegroundColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	HardenedPowerForegroundTexture = GetMedia("pw_crystal_case"),
	HealthBackdropDrawLayer = { "BACKGROUND", -1 },
	HealthBackdropPlace = { "CENTER", 1, -.5 },
	HealthBackdropSize = { 716, 188 },
	HealthBackdropTexCoord = { 1, 0, 0, 1 }, 
	HealthBarOrientation = "LEFT",
	HealthBarSetFlippedHorizontally = true, 
	HealthColorClass = true, -- color players by class 
	HealthColorDisconnected = true, -- color disconnected units
	HealthColorHealth = false, -- color anything else in the default health color
	HealthColorReaction = true, -- color NPCs by their reaction standing with us
	HealthColorTapped = true, -- color tap denied units 
	HealthFrequentUpdates = true, -- listen to frequent health events for more accurate updates
	HealthPercentColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	HealthPercentDrawLayer = { "OVERLAY", 1 },
	HealthPercentFont = GetFont(18, true),
	HealthPercentJustifyH = "LEFT",
	HealthPercentJustifyV = "MIDDLE",
	HealthPercentPlace = { "LEFT", 27, 4 },
	HealthPlace = { "TOPRIGHT", 27, 27 },
	HealthSmoothingFrequency = .2, -- speed of the smoothing method
	HealthSmoothingMode = "bezier-fast-in-slow-out", 
	HealthValueColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	HealthValueFont = GetFont(18, true),
	HealthValueDrawLayer = { "OVERLAY", 1 },
	HealthValueJustifyH = "RIGHT", 
	HealthValueJustifyV = "MIDDLE", 
	HealthValuePlace = { "RIGHT", -27, 4 },
	HitRectInsets = { 0, -80, -30, 0 }, 
	LevelAlpha = .7,
	LevelBadgeColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	LevelBadgeDrawLayer = { "BACKGROUND", 1 },
	LevelBadgeSize = { 86, 86 }, 
	LevelBadgeTexture = GetMedia("point_plate"),
	LevelColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3] },
	LevelDeadSkullColor = { 1, 1, 1, 1 }, 
	LevelDeadSkullDrawLayer = { "BORDER", 2 }, 
	LevelDeadSkullSize = { 64, 64 }, 
	LevelDeadSkullTexture = GetMedia("icon_skull_dead"),
	LevelDrawLayer = { "BORDER", 1 },
	LevelFont = GetFont(13, true),
	LevelHideCapped = true, 
	LevelHideFloored = true, 
	LevelJustifyH = "CENTER",
	LevelJustifyV = "MIDDLE", 
	LevelPlace = { "CENTER", 298, -15 }, 
	LevelSkullColor = { 1, 1, 1, 1 }, 
	LevelSkullDrawLayer = { "BORDER", 2 }, 
	LevelSkullSize = { 64, 64 }, 
	LevelSkullTexture = GetMedia("icon_skull"),
	LevelVisibilityFilter = TargetFrame_LevelVisibilityFilter,
	LoveTargetIndicatorPetByEnemyColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	LoveTargetIndicatorPetByEnemyPlace = { "TOPRIGHT", -10 + 50/2 + 4, 12 + 50/2 -4 },
	LoveTargetIndicatorPetByEnemySize = { 48,48 },
	LoveTargetIndicatorPetByEnemyTexture = GetMedia("icon-heart-blue"),
	LoveTargetIndicatorYouByEnemyColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	LoveTargetIndicatorYouByEnemyPlace = { "TOPRIGHT", -10 + 50/2 + 4, 12 + 50/2 -4 },
	LoveTargetIndicatorYouByEnemySize = { 48,48 },
	LoveTargetIndicatorYouByEnemyTexture = GetMedia("icon-heart-red"),
	LoveTargetIndicatorYouByFriendColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	LoveTargetIndicatorYouByFriendPlace = { "TOPRIGHT", -10 + 50/2 + 4, 12 + 50/2 -4 },
	LoveTargetIndicatorYouByFriendSize = { 48,48 },
	LoveTargetIndicatorYouByFriendTexture = GetMedia("icon-heart-green"),
	NameColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .75 },
	NameDrawLayer = { "OVERLAY", 1 }, 
	NameFont = GetFont(18, true),
	NameJustifyH = "RIGHT", 
	NameJustifyV = "TOP",
	NamePlace = { "TOPRIGHT", -40, 18 },
	NamePostUpdateBecauseOfToT = TargetFrame_NamePostUpdate,
	NameSize = { 250, 18 },
	NoviceCastPlace = { "TOPRIGHT", -27, -27 }, 
	NoviceCastSize = { 385, 37 },
	NoviceCastSparkMap = {
		{ keyPercent =   0/512, topOffset = -24/64, bottomOffset = -39/64 }, 
		{ keyPercent =   9/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 460/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 478/512, topOffset =   0/64, bottomOffset =   0/64 }, 
		{ keyPercent = 483/512, topOffset =   0/64, bottomOffset =  -3/64 }, 
		{ keyPercent = 507/512, topOffset =   0/64, bottomOffset = -46/64 }, 
		{ keyPercent = 512/512, topOffset = -11/64, bottomOffset = -54/64 }  
	},
	NoviceCastTexture = GetMedia("hp_lowmid_bar"),
	NoviceHealthBackdropColor = { Colors.ui.wood[1], Colors.ui.wood[2], Colors.ui.wood[3] },
	NoviceHealthBackdropPlace = { "CENTER", -1, -.5 }, 
	NoviceHealthBackdropSize = { 716, 188 }, 
	NoviceHealthBackdropTexture = GetMedia("hp_low_case"),
	NoviceHealthPercentVisible = true, 
	NoviceHealthPlace = { "TOPRIGHT", -27, -27 }, 
	NoviceHealthSize = { 385, 37 },
	NoviceHealthSparkMap = {
		{ keyPercent =   0/512, topOffset = -24/64, bottomOffset = -39/64 }, 
		{ keyPercent =   9/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 460/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 478/512, topOffset =   0/64, bottomOffset =   0/64 }, 
		{ keyPercent = 483/512, topOffset =   0/64, bottomOffset =  -3/64 }, 
		{ keyPercent = 507/512, topOffset =   0/64, bottomOffset = -46/64 }, 
		{ keyPercent = 512/512, topOffset = -11/64, bottomOffset = -54/64 }  
	},
	NoviceHealthTexture = GetMedia("hp_lowmid_bar"),
	NoviceHealthValueVisible = true, 
	NovicePortraitForegroundColor = { Colors.ui.wood[1], Colors.ui.wood[2], Colors.ui.wood[3] }, 
	NovicePortraitForegroundTexture = GetMedia("portrait_frame_lo"),
	NovicePowerForegroundColor = { Colors.ui.wood[1], Colors.ui.wood[2], Colors.ui.wood[3] },
	NovicePowerForegroundTexture = GetMedia("pw_crystal_case_low"),
	Place = { "TOPRIGHT", -153, -79 },
	PortraitAlpha = .85, 
	PortraitBackgroundColor = { .5, .5, .5 }, 
	PortraitBackgroundDrawLayer = { "BACKGROUND", 0 }, 
	PortraitBackgroundPlace = { "TOPRIGHT", 116, 55 },
	PortraitBackgroundSize = { 173, 173 },
	PortraitBackgroundTexture = GetMedia("party_portrait_back"), 
	PortraitDistanceScale = 1,
	PortraitForegroundDrawLayer = { "BACKGROUND", 0 },
	PortraitForegroundPlace = { "TOPRIGHT", 123, 61 },
	PortraitForegroundSize = { 187, 187 },
	PortraitPlace = { "TOPRIGHT", 73, 8 },
	PortraitPositionX = 0,
	PortraitPositionY = 0,
	PortraitPositionZ = 0,
	PortraitRotation = 0, 
	PortraitShowFallback2D = true, 
	PortraitShadeDrawLayer = { "BACKGROUND", -1 },
	PortraitShadePlace = { "TOPRIGHT", 83, 21 },
	PortraitShadeSize = { 107, 107 }, 
	PortraitShadeTexture = GetMedia("shade_circle"),
	PortraitSize = { 85, 85 }, 
	PostUpdateTextures = TargetFrame_TexturesPostUpdate,
	PowerBackgroundColor = { 1, 1, 1, .85 },
	PowerBackgroundDrawLayer = { "BACKGROUND", -2 },
	PowerBackgroundPlace = { "CENTER", 0, 0 },
	PowerBackgroundSize = { 68 +12, 68 +12 },
	PowerBackgroundTexCoord = { 0, 1, 0, 1 },
	PowerBackgroundTexture = GetMedia("power_crystal_small_back"),
	PowerBarOrientation = "UP",
	PowerBarSetFlippedHorizontally = false, 
	PowerBarSmoothingFrequency = .5,
	PowerBarSmoothingMode = "bezier-fast-in-slow-out",
	PowerBarSparkTexture = GetMedia("blank"),
	PowerBarTexCoord = { 0, 1, 0, 1 },
	PowerBarTexture = GetMedia("power_crystal_small_front"),
	PowerColorSuffix = "_CRYSTAL", 
	PowerHideWhenDead = true,  
	PowerHideWhenEmpty = true,
	PowerIgnoredResource = nil,
	PowerPlace ={ "CENTER", 439/2 + 79 +2, -6+ 93/2 -62 + 4 +6 }, 
	PowerSize = { 68 +12, 68 +12 },
	PowerShowAlternate = true, 
	PowerValueColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	PowerValueDrawLayer = { "OVERLAY", 1 },
	PowerValueFont = GetFont(14, true),
	PowerValueJustifyH = "CENTER", 
	PowerValueJustifyV = "MIDDLE", 
	PowerValuePlace = { "CENTER", 0, -5 },
	PowerValueOverride = TargetFrame_PowerValueOverride,
	PowerVisibilityFilter = TargetFrame_PowerVisibilityFilter,
	SeasonedCastPlace = { "TOPRIGHT", -27, -27 }, 
	SeasonedCastSize = { 385, 40 },
	SeasonedCastSparkMap = {
		{ keyPercent =   0/512, topOffset = -24/64, bottomOffset = -39/64 }, 
		{ keyPercent =   9/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 460/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 478/512, topOffset =   0/64, bottomOffset =   0/64 }, 
		{ keyPercent = 483/512, topOffset =   0/64, bottomOffset =  -3/64 }, 
		{ keyPercent = 507/512, topOffset =   0/64, bottomOffset = -46/64 }, 
		{ keyPercent = 512/512, topOffset = -11/64, bottomOffset = -54/64 }  
	},
	SeasonedCastTexture = GetMedia("hp_cap_bar"),
	SeasonedHealthBackdropColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	SeasonedHealthBackdropPlace = { "CENTER", -2, 0 }, 
	SeasonedHealthBackdropSize = { 716, 188 },
	SeasonedHealthBackdropTexture = GetMedia("hp_cap_case"),
	SeasonedHealthPercentVisible = true, 
	SeasonedHealthPlace = { "TOPRIGHT", -27, -27 }, 
	SeasonedHealthSize = { 385, 40 },
	SeasonedHealthSparkMap = {
		{ keyPercent =   0/512, topOffset = -24/64, bottomOffset = -39/64 }, 
		{ keyPercent =   9/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 460/512, topOffset =   0/64, bottomOffset = -16/64 }, 
		{ keyPercent = 478/512, topOffset =   0/64, bottomOffset =   0/64 }, 
		{ keyPercent = 483/512, topOffset =   0/64, bottomOffset =  -3/64 }, 
		{ keyPercent = 507/512, topOffset =   0/64, bottomOffset = -46/64 }, 
		{ keyPercent = 512/512, topOffset = -11/64, bottomOffset = -54/64 }  
	},
	SeasonedHealthTexture = GetMedia("hp_cap_bar"),
	SeasonedHealthValueVisible = true, 
	SeasonedPortraitForegroundColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] }, 
	SeasonedPortraitForegroundTexture = GetMedia("portrait_frame_hi"),
	SeasonedPowerForegroundColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	SeasonedPowerForegroundTexture = GetMedia("pw_crystal_case"),
	Size = { 439, 93 },
	TargetIndicatorPetByEnemyColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	TargetIndicatorPetByEnemyPlace = { "TOPRIGHT", -10 + 96/2, 12 + 48/2 },
	TargetIndicatorPetByEnemySize = { 96, 48 },
	TargetIndicatorPetByEnemyTexture = GetMedia("icon_target_blue"),
	TargetIndicatorYouByEnemyColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	TargetIndicatorYouByEnemyPlace = { "TOPRIGHT", -10 + 96/2, 12 + 48/2 },
	TargetIndicatorYouByEnemySize = { 96, 48 },
	TargetIndicatorYouByEnemyTexture = GetMedia("icon_target_red"),
	TargetIndicatorYouByFriendColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] },
	TargetIndicatorYouByFriendPlace = { "TOPRIGHT", -10 + 96/2, 12 + 48/2 },
	TargetIndicatorYouByFriendSize = { 96, 48 },
	TargetIndicatorYouByFriendTexture = GetMedia("icon_target_green")
}

------------------------------------------------
-- Template Unit Frame Layouts
------------------------------------------------
-- Boss 
Layouts.UnitFrameBoss = setmetatable({
	BuffFilterFunc = GetAuraFilterFunc("boss"), 
	DebuffFilterFunc = GetAuraFilterFunc("boss"), 
	GrowthX = 0, -- Horizontal growth per new unit
	GrowthY = -97, -- Vertical growth per new unit
	NameColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .75 },
	NameDrawLayer = { "OVERLAY", 1 },
	NameFont = GetFont(14, true),
	NameJustifyH = "CENTER",
	NameJustifyV = "TOP",
	NamePlace = { "BOTTOMRIGHT", -(Constant.SmallFrame[1] - Constant.SmallBar[1])/2, Constant.SmallFrame[2] - Constant.SmallBar[2] + 16 }, 
	HealthColorClass = false, -- color players by class 
	HealthColorDisconnected = false, -- color disconnected units
	HealthColorHealth = true, -- color anything else in the default health color
	HealthColorPetAsPlayer = false, -- color your pet as you 
	HealthColorReaction = true, -- color NPCs by their reaction standing with us
	HealthColorTapped = false, -- color tap denied units 
	Place = { "TOPRIGHT", "UICenter", "RIGHT", -64, 261 } -- Position of the initial frame
}, { __index = Template_SmallFrameReversed_Auras })

-- 2-5 player groups
Layouts.UnitFrameParty = setmetatable({
	AlternateGroupAnchor = "BOTTOMLEFT", 
	AlternateGrowthX = 140, -- Horizontal growth per new unit
	AlternateGrowthY = 0, -- Vertical growth per new unit
	AlternatePlace = { "BOTTOMLEFT", "UICenter", "BOTTOMLEFT", 56, 360 + 10 }, -- Position of the healermode frame
	Aura_PostCreateButton = UnitFrame_Aura_PostCreateButton,
	Aura_PostUpdateButton = UnitFrame_Aura_PostUpdateButton,
	
	Place = { "TOPLEFT", "UICenter", "TOPLEFT", 50, -42 }, -- Position of the initial frame
	GroupAnchor = "TOPLEFT", 
	GrowthX = 130, -- Horizontal growth per new unit
	GrowthY = 0, -- Vertical growth per new unit
	
	HealthColorTapped = false, -- color tap denied units 
	HealthColorDisconnected = true, -- color disconnected units
	HealthColorClass = true, -- color players by class
	HealthColorPetAsPlayer = true, -- color your pet as you 
	HealthColorReaction = true, -- color NPCs by their reaction standing with us
	HealthColorHealth = true, -- color anything else in the default health color
	HealthValuePlace = { "CENTER", 0, 0 },
	HealthValueDrawLayer = { "OVERLAY", 1 },
	HealthValueJustifyH = "CENTER", 
	HealthValueJustifyV = "MIDDLE", 
	HealthValueFont = GetFont(13, true),
	HealthValueColor = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
	HealthShowPercent = true, 

	PortraitPlace = { "BOTTOM", 0, 22 },
	PortraitSize = { 70, 73 }, 
	PortraitAlpha = .85, 
	PortraitDistanceScale = 1,
	PortraitPositionX = 0,
	PortraitPositionY = 0,
	PortraitPositionZ = 0,
	PortraitRotation = 0, -- in degrees
	PortraitShowFallback2D = true, -- display 2D portraits when unit is out of range of 3D models
	PortraitBackgroundPlace = { "BOTTOM", 0, -6 }, 
	PortraitBackgroundSize = { 130, 130 },
	PortraitBackgroundTexture = GetMedia("party_portrait_back"), 
	PortraitBackgroundDrawLayer = { "BACKGROUND", 0 }, 
	PortraitBackgroundColor = { .5, .5, .5 }, 
	PortraitShadePlace = { "BOTTOM", 0, 16 },
	PortraitShadeSize = { 86, 86 }, 
	PortraitShadeTexture = GetMedia("shade_circle"),
	PortraitShadeDrawLayer = { "BACKGROUND", -1 },
	PortraitForegroundPlace = { "BOTTOM", 0, -38 },
	PortraitForegroundSize = { 194, 194 },
	PortraitForegroundTexture = GetMedia("party_portrait_border"), 
	PortraitForegroundDrawLayer = { "BACKGROUND", 0 },
	PortraitForegroundColor = { Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3] }, 
		
	AuraProperties = {
		growthX = "RIGHT", 
		growthY = "DOWN", 
		spacingH = 4, 
		spacingV = 4, 
		auraSize = 30, auraWidth = nil, auraHeight = nil, 
		maxVisible = 6, maxBuffs = nil, maxDebuffs = nil, 
		filter = nil, filterBuffs = "PLAYER HELPFUL", filterDebuffs = "PLAYER HARMFUL", 
		func = nil, funcBuffs = GetAuraFilterFunc("party"), funcDebuffs = GetAuraFilterFunc("party"), 
		debuffsFirst = false, 
		disableMouse = false, 
		showSpirals = false, 
		showDurations = true, 
		showLongDurations = true,
		tooltipDefaultPosition = false, 
		tooltipPoint = "TOPRIGHT",
		tooltipAnchor = nil,
		tooltipRelPoint = "BOTTOMRIGHT",
		tooltipOffsetX = -8,
		tooltipOffsetY = -16
	},
	AuraFrameSize = { 30*3 + 2*5, 30*2 + 5  }, 
	AuraFramePlace = { "BOTTOM", 0, -(30*2 + 5 + 16) },
	AuraIconPlace = { "CENTER", 0, 0 },
	AuraIconSize = { 30 - 6, 30 - 6 },
	AuraIconTexCoord = { 5/64, 59/64, 5/64, 59/64 }, -- aura icon tex coords
	AuraCountPlace = { "BOTTOMRIGHT", 9, -6 },
	AuraCountFont = GetFont(12, true),
	AuraCountColor = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
	AuraTimePlace = { "TOPLEFT", -6, 6 },
	AuraTimeFont = GetFont(11, true),
	AuraBorderFramePlace = { "CENTER", 0, 0 }, 
	AuraBorderFrameSize = { 30 + 10, 30 + 10 },
	AuraBorderBackdrop = { edgeFile = GetMedia("aura_border"), edgeSize = 12 },
	AuraBorderBackdropColor = { 0, 0, 0, 0 },
	AuraBorderBackdropBorderColor = { Colors.ui.stone[1] *.3, Colors.ui.stone[2] *.3, Colors.ui.stone[3] *.3 },
	Size = { 130, 130 }, 

	-- Prio #1
	GroupAuraSize = { 36, 36 },
	GroupAuraPlace = { "BOTTOM", 0, Constant.TinyBar[2]/2 - 36/2 -1 }, 
	GroupAuraButtonIconPlace = { "CENTER", 0, 0 },
	GroupAuraButtonIconSize = { 36 - 6, 36 - 6 },
	GroupAuraButtonIconTexCoord = { 5/64, 59/64, 5/64, 59/64 }, -- aura icon tex coords
	GroupAuraButtonCountPlace = { "BOTTOMRIGHT", 9, -6 },
	GroupAuraButtonCountFont = GetFont(12, true),
	GroupAuraButtonCountColor = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
	GroupAuraButtonTimePlace = { "CENTER", 0, 0 },
	GroupAuraButtonTimeFont = GetFont(11, true),
	GroupAuraButtonTimeColor = { 250/255, 250/255, 250/255, .85 },
	GroupAuraButtonBorderFramePlace = { "CENTER", 0, 0 }, 
	GroupAuraButtonBorderFrameSize = { 36 + 16, 36 + 16 },
	GroupAuraButtonBorderBackdrop = { edgeFile = GetMedia("aura_border"), edgeSize = 16 },
	GroupAuraButtonBorderBackdropColor = { 0, 0, 0, 0 },
	GroupAuraButtonBorderBackdropBorderColor = { Colors.ui.stone[1] *.3, Colors.ui.stone[2] *.3, Colors.ui.stone[3] *.3 },
	GroupAuraButtonDisableMouse = false, 
	GroupAuraTooltipDefaultPosition = nil, 
	GroupAuraPostUpdate = function(element, unit)
		local self = element._owner 

		local rz = self.ResurrectIndicator
		local rc = self.ReadyCheck
		local us = self.UnitStatus
		local hv = self.Health.Value

		if element:IsShown() then 
			-- Hide all lower priority elements
			rc:Hide()
			rz:Hide()
			us:Hide()
			hv:Hide()

			-- Colorize the border
			if (element.filter == "HARMFUL") then 
				local color = element.debuffType and spellTypeColor[element.debuffType]
				if color then 
					element.Border:SetBackdropBorderColor(color[1], color[2], color[3])
				else
					element.Border:SetBackdropBorderColor(Colors.ui.stone[1] *.3, Colors.ui.stone[2] *.3, Colors.ui.stone[3] *.3)
				end
			else
				element.Border:SetBackdropBorderColor(Colors.ui.stone[1] *.3, Colors.ui.stone[2] *.3, Colors.ui.stone[3] *.3)
			end

		else 
			-- Display lower priority elements as needed 
			if rc.status then 
				rc:Show()
				rz:Hide()
				us:Hide()
				hv:Hide()
			elseif rz.status then 
				rc:Hide()
				rz:Show()
				us:Hide()
				hv:Hide()
			elseif us.status then 
				rc:Hide()
				rz:Hide()
				us:Show()
				hv:Hide()
			else
				hv:Show()
			end 
		end 
	end, 

	-- Prio #2
	ReadyCheckPlace = { "CENTER", 0, -7 }, 
	ReadyCheckSize = { 32, 32 }, 
	ReadyCheckDrawLayer = { "OVERLAY", 7 },
	ReadyCheckPostUpdate = function(element, unit, status) 
		local self = element._owner

		local rd = self.GroupAura
		local rz = self.ResurrectIndicator
		local us = self.UnitStatus
		local hv = self.Health.Value

		if element:IsShown() then 
			hv:Hide()

			-- Hide if a higher priority element is visible
			if rd:IsShown() then 
				return element:Hide()
			end 
			-- Hide all lower priority elements
			rz:Hide()
			us:Hide()
		else 
			-- Show lower priority elements if no higher is visible
			if (not rd:IsShown()) then 
				if (rz.status) then 
					rz:Show()
					us:Hide()
					hv:Hide()
				elseif (us.status) then 
					rz:Hide()
					us:Show()
					hv:Hide()
				else 
					hv:Show()
				end 
			else 
				hv:Show()
			end 
		end 
	end,
	
	-- Prio #3
	ResurrectIndicatorPlace = { "CENTER", 0, -7 }, 
	ResurrectIndicatorSize = { 32, 32 }, 
	ResurrectIndicatorDrawLayer = { "OVERLAY", 1 },
	ResurrectIndicatorPostUpdate = function(element, unit, incomingResurrect) 
		local self = element._owner

		local rc = self.ReadyCheck
		local rd = self.GroupAura
		local us = self.UnitStatus
		local hv = self.Health.Value

		if element:IsShown() then 
			hv:Hide()

			-- Hide if a higher priority element is visible
			if (rd:IsShown() or rc.status) then 
				return element:Hide()
			end 
			-- Hide lower priority element
			us:Hide()
		else
			-- Show lower priority elements if no higher is visible
			if (not rd:IsShown()) and (not rc.status) then 
				if (us.status) then 
					us:Show()
					hv:Hide()
				else
					hv:Show()
				end 
			end
		end 
	end,

	-- Prio #4
	UnitStatusPlace = { "CENTER", 0, -(7 + 100/2) },
	UnitStatusDrawLayer = { "ARTWORK", 2 },
	UnitStatusJustifyH = "CENTER",
	UnitStatusJustifyV = "MIDDLE",
	UnitStatusFont = GetFont(12, true),
	UnitStatusColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .75 },
	UseUnitStatusMessageOOM = L["oom"],
	UnitStatusHideAFK = true, 
	UnitStatusHideOffline = true, 
	UnitStatusHideDead = true, 
	UnitStatusPostUpdate = function(element, unit) 
		local self = element._owner

		local rc = self.ReadyCheck
		local rd = self.GroupAura
		local rz = self.ResurrectIndicator
		local hv = self.Health.Value

		if element:IsShown() then 
			-- Hide if a higher priority element is visible
			if (rd:IsShown() or rc.status or rz.status) then 
				element:Hide()
			end 
			hv:Hide()
		else
			hv:Show()
		end 
	end,
	
}, { __index = Template_TinyFrame })

-- Player Pet
Layouts.UnitFramePet = setmetatable({
	HealthColorClass = false, -- color players by class 
	HealthColorDisconnected = false, -- color disconnected units
	HealthColorHealth = true, -- color anything else in the default health color
	HealthColorPetAsPlayer = false, -- color your pet as you 
	HealthColorReaction = false, -- color NPCs by their reaction standing with us
	HealthColorTapped = false, -- color tap denied units 
	HealthFrequentUpdates = true, 
	Place = { "LEFT", "UICenter", "BOTTOMLEFT", 362, 125 }
}, { __index = Template_SmallFrame })

-- 6-40 player groups
Layouts.UnitFrameRaid = setmetatable({

	TargetHighlightSize = { 140 * .94, 90 *.94 },
	Size = Constant.RaidFrame, 
	Place = { "TOPLEFT", "UICenter", "TOPLEFT", 64, -42 }, -- Position of the initial frame
	AlternatePlace = { "BOTTOMLEFT", "UICenter", "BOTTOMLEFT", 64, 360 - 10 }, -- Position of the initial frame

	GroupSizeNormal = 5,
	GrowthXNormal = 0, -- Horizontal growth per new unit within a group
	GrowthYNormal = -38 - 4, -- Vertical growth per new unit within a group
	GrowthYNormalHealerMode = -(-38 - 4), -- Vertical growth per new unit within a group
	GroupGrowthXNormal = 110, 
	GroupGrowthYNormal = -(38 + 8)*5 - 10,
	GroupGrowthYNormalHealerMode = -(-(38 + 8)*5 - 10),
	GroupColsNormal = 5, 
	GroupRowsNormal = 1, 
	GroupAnchorNormal = "TOPLEFT", 
	GroupAnchorNormalHealerMode = "BOTTOMLEFT", 
	GroupSizeEpic = 8,
	GrowthXEpic = 0, 
	GrowthYEpic = -38 - 4,
	GrowthYEpicHealerMode = -(-38 - 4),
	GroupGrowthXEpic = 110, 
	GroupGrowthYEpic = -(38 + 8)*8 - 10,
	GroupGrowthYEpicHealerMode = -(-(38 + 8)*8 - 10),
	GroupColsEpic = 5, 
	GroupRowsEpic = 1, 
	GroupAnchorEpic = "TOPLEFT", 
	GroupAnchorEpicHealerMode = "BOTTOMLEFT", 

	HealthSize = Constant.RaidBar, 
	HealthBackdropSize = { 140 *.94, 90 *.94 },
	HealthColorTapped = false, -- color tap denied units 
	HealthColorDisconnected = true, -- color disconnected units
	HealthColorClass = true, -- color players by class
	HealthColorPetAsPlayer = true, -- color your pet as you 
	HealthColorReaction = true, -- color NPCs by their reaction standing with us
	HealthColorHealth = true, -- color anything else in the default health color

	NamePlace = { "TOP", 0, 1 - 2 }, 
	NameDrawLayer = { "ARTWORK", 1 },
	NameJustifyH = "CENTER",
	NameJustifyV = "TOP",
	NameFont = GetFont(11, true),
	NameColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .75 },
	NameMaxChars = 8, 
	NameUseDots = false, 

	RaidRolePoint = "RIGHT", RaidRoleAnchor = "Name", RaidRolePlace = { "LEFT", -1, 1 }, 
	RaidRoleSize = { 16, 16 }, 
	RaidRoleDrawLayer = { "ARTWORK", 3 },
	RaidRoleRaidTargetTexture = GetMedia("raid_target_icons_small"),
	
	-- Prio #1
	GroupAuraSize = { 24, 24 },
	GroupAuraPlace = { "BOTTOM", 0, Constant.TinyBar[2]/2 - 24/2 -(1 + 2) }, 
	GroupAuraButtonIconPlace = { "CENTER", 0, 0 },
	GroupAuraButtonIconSize = { 24 - 6, 24 - 6 },
	GroupAuraButtonIconTexCoord = { 5/64, 59/64, 5/64, 59/64 }, -- aura icon tex coords
	GroupAuraButtonCountPlace = { "BOTTOMRIGHT", 9, -6 },
	GroupAuraButtonCountFont = GetFont(12, true),
	GroupAuraButtonCountColor = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
	GroupAuraButtonTimePlace = { "CENTER", 0, 0 },
	GroupAuraButtonTimeFont = GetFont(11, true),
	GroupAuraButtonTimeColor = { 250/255, 250/255, 250/255, .85 },
	GroupAuraButtonBorderFramePlace = { "CENTER", 0, 0 }, 
	GroupAuraButtonBorderFrameSize = { 24 + 12, 24 + 12 },
	GroupAuraButtonBorderBackdrop = { edgeFile = GetMedia("aura_border"), edgeSize = 12 },
	GroupAuraButtonBorderBackdropColor = { 0, 0, 0, 0 },
	GroupAuraButtonBorderBackdropBorderColor = { Colors.ui.stone[1] *.3, Colors.ui.stone[2] *.3, Colors.ui.stone[3] *.3 },
	GroupAuraButtonDisableMouse = false, 
	GroupAuraTooltipDefaultPosition = nil, 
	GroupAuraPostUpdate = function(element, unit)
		local self = element._owner 

		local rz = self.ResurrectIndicator
		local rc = self.ReadyCheck
		local us = self.UnitStatus

		if element:IsShown() then 
			-- Hide all lower priority elements
			rc:Hide()
			rz:Hide()
			us:Hide()

			-- Colorize the border
			if (element.filter == "HARMFUL") then 
				local color = element.debuffType and spellTypeColor[element.debuffType]
				if color then 
					element.Border:SetBackdropBorderColor(color[1], color[2], color[3])
				else
					element.Border:SetBackdropBorderColor(Colors.ui.stone[1] *.3, Colors.ui.stone[2] *.3, Colors.ui.stone[3] *.3)
				end
			else
				element.Border:SetBackdropBorderColor(Colors.ui.stone[1] *.3, Colors.ui.stone[2] *.3, Colors.ui.stone[3] *.3)
			end
	
		else 
			-- Display lower priority elements as needed 
			if rc.status then 
				rc:Show()
				rz:Hide()
				us:Hide()
			elseif rz.status then 
				rc:Hide()
				rz:Show()
				us:Hide()
			elseif us.status then 
				rc:Hide()
				rz:Hide()
				us:Show()
			end 
		end 
	end, 

	-- Prio #2
	ReadyCheckPlace = { "CENTER", 0, -7 }, 
	ReadyCheckSize = { 32, 32 }, 
	ReadyCheckDrawLayer = { "OVERLAY", 7 },
	ReadyCheckPostUpdate = function(element, unit, status) 
		local self = element._owner

		local rd = self.GroupAura
		local rz = self.ResurrectIndicator
		local us = self.UnitStatus

		if element:IsShown() then 
			-- Hide if a higher priority element is visible
			if rd:IsShown() then 
				return element:Hide()
			end 
			-- Hide all lower priority elements
			rz:Hide()
			us:Hide()
		else 
			-- Show lower priority elements if no higher is visible
			if (not rd:IsShown()) then 
				if (rz.status) then 
					rz:Show()
					us:Hide()
				elseif (us.status) then 
					rz:Hide()
					us:Show()
				end 
			end 
		end 
	end,

	-- Prio #3
	ResurrectIndicatorPlace = { "CENTER", 0, -7 }, 
	ResurrectIndicatorSize = { 32, 32 }, 
	ResurrectIndicatorDrawLayer = { "OVERLAY", 1 },
	ResurrectIndicatorPostUpdate = function(element, unit, incomingResurrect) 
		local self = element._owner

		local rc = self.ReadyCheck
		local rd = self.GroupAura
		local us = self.UnitStatus

		if element:IsShown() then 
			-- Hide if a higher priority element is visible
			if (rd:IsShown() or rc.status) then 
				return element:Hide()
			end 
			-- Hide lower priority element
			us:Hide()
		else
			-- Show lower priority elements if no higher is visible
			if (not rd:IsShown()) and (not rc.status) then 
				if (us.status) then 
					us:Show()
				end 
			end
		end 
	end,

	-- Prio #4
	UnitStatusPlace = { "CENTER", 0, -7 },
	UnitStatusDrawLayer = { "ARTWORK", 2 },
	UnitStatusJustifyH = "CENTER",
	UnitStatusJustifyV = "MIDDLE",
	UnitStatusFont = GetFont(12, true),
	UnitStatusColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .75 },
	UseUnitStatusMessageOOM = L["oom"],
	UnitStatusPostUpdate = function(element, unit) 
		local self = element._owner
		local rc = self.ReadyCheck
		local rd = self.GroupAura
		local rz = self.ResurrectIndicator
		if element:IsShown() then 
			-- Hide if a higher priority element is visible
			if (rd:IsShown() or rc.status or rz.status) then 
				element:Hide()
			end 
		end 
	end,

}, { __index = Template_TinyFrame })

-- Target of Target
Layouts.UnitFrameToT = setmetatable({
	HealthColorClass = true, -- color players by class 
	HealthColorDisconnected = true, -- color disconnected units
	HealthColorHealth = false, -- color anything else in the default health color
	HealthColorPetAsPlayer = true, -- color your pet as you 
	HealthColorReaction = true, -- color NPCs by their reaction standing with us
	HealthColorTapped = true, -- color tap denied units 
	HealthFrequentUpdates = true, 
	HideWhenTargetIsCritter = true, -- hide the frame when unit is a critter
	HideWhenUnitIsPlayer = true, -- hide the frame when the unit is the player
	HideWhenUnitIsTarget = true, -- hide the frame when the unit matches our target
	NameColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .75 },
	NameDrawLayer = { "OVERLAY", 1 },
	NameFont = GetFont(14, true),
	NameJustifyH = "RIGHT",
	NameJustifyV = "TOP",
	NamePlace = { "BOTTOMRIGHT", -(Constant.SmallFrame[1] - Constant.SmallBar[1])/2, Constant.SmallFrame[2] - Constant.SmallBar[2] + 16 - 4 }, 
	Place = { "RIGHT", "UICenter", "TOPRIGHT", -492, -96 + 6 }
}, { __index = Template_SmallFrameReversed })

------------------------------------------------
-- Private Addon API
------------------------------------------------
-- Initialize or retrieve the saved settings
Private.GetConfig = function(name, profile)
	local db = Wheel("LibModule"):GetModule(ADDON):GetConfig(name, profile or "global", nil, true)
	return db or Wheel("LibModule"):GetModule(ADDON):NewConfig(name, Private.GetDefaults(name), profile or "global")
end 

-- Retrieve default settings
Private.GetDefaults = function(name) 
	return Defaults[name] 
end 

-- Retrieve layout
Private.GetLayout = function(moduleName) return Layouts[moduleName] end 
