local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

-- Note that there's still a lot of hardcoded things in this file, 
-- and it will eventually be changed to be fully Layout driven. 
local L = Wheel("LibLocale"):GetLocale(ADDON)
local Module = Core:NewModule("ActionBarMain", "LibEvent", "LibMessage", "LibDB", "LibFrame", "LibSound", "LibTooltip", "LibSecureButton", "LibWidgetContainer", "LibPlayerData", "LibClientBuild")

-- Lua API
local _G = _G
local ipairs = ipairs
local math_floor = math.floor
local pairs = pairs
local table_remove = table.remove
local tonumber = tonumber
local tostring = tostring

-- WoW API
local FindActiveAzeriteItem = C_AzeriteItem and C_AzeriteItem.FindActiveAzeriteItem
local GetAzeriteItemXPInfo = C_AzeriteItem and C_AzeriteItem.GetAzeriteItemXPInfo
local GetPowerLevel = C_AzeriteItem and C_AzeriteItem.GetPowerLevel
local HasOverrideActionBar = HasOverrideActionBar
local HasTempShapeshiftActionBar = HasTempShapeshiftActionBar
local HasVehicleActionBar = HasVehicleActionBar
local InCombatLockdown = InCombatLockdown
local IsMounted = IsMounted
local UnitLevel = UnitLevel
local UnitOnTaxi = UnitOnTaxi
local UnitRace = UnitRace

-- Private API
local Colors = Private.Colors
local GetConfig = Private.GetConfig
local GetLayout = Private.GetLayout
local GetMedia = Private.GetMedia

-- Constants for client version
local IsClassic = Module:IsClassic()
local IsRetail = Module:IsRetail()

-- Blizzard textures for generic styling
local BLANK_TEXTURE = [[Interface\ChatFrame\ChatFrameBackground]]

-- Various string formatting for our tooltips and bars
local shortXPString = "%s%%"
local longXPString = "%s / %s"
local fullXPString = "%s / %s (%s)"
local restedString = " (%s%% %s)"
local shortLevelString = "%s %.0f"

-- Cache of buttons
local Cache = {} -- cache buttons to separate different ranks of same spell
local Buttons = {} -- all action buttons
local PetButtons = {} -- all pet buttons
local HoverButtons = {} -- all action buttons that can fade out

-- Hover frames
local ActionBarHoverFrame, PetBarHoverFrame
local FadeOutHZ, FadeOutDuration = 1/20, 1/5

-- Is ConsolePort enabled in the addon listing?
local IsConsolePortEnabled = Module:IsAddOnEnabled("ConsolePort")

-- Track combat status
local IN_COMBAT

-- Secure Code Snippets
local secureSnippets = {
	-- TODO: 
	-- Make this a formatstring, and fill in layout options from the Layout cache to make these universal. 
	arrangeButtons = [=[

		local UICenter = self:GetFrameRef("UICenter"); 
		local extraButtonsCount = tonumber(self:GetAttribute("extraButtonsCount")) or 0;
		local buttonSize, buttonSpacing, iconSize = 64, 8, 44;
		local row2mod = -2/5; -- horizontal offset for upper row

		for id,button in ipairs(Buttons) do 
			local buttonID = button:GetID(); 
			local barID = Pagers[id]:GetID(); 

			-- Primary Bar
			if (barID == 1) then 
				button:ClearAllPoints(); 

				if (buttonID > 10) then
					button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + ((buttonID-2-1 + row2mod) * (buttonSize + buttonSpacing)), 42 + buttonSize + buttonSpacing)
				else
					button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + ((buttonID-1) * (buttonSize + buttonSpacing)), 42)
				end 

			-- Secondary Bar
			elseif (barID == self:GetAttribute("BOTTOMLEFT_ACTIONBAR_PAGE")) then 
				button:ClearAllPoints(); 

				-- 3x2 complimentary buttons
				if (extraButtonsCount <= 11) then 
					if (buttonID < 4) then 
						button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + (((buttonID+10)-1) * (buttonSize + buttonSpacing)), 42 )
					else
						button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + (((buttonID-3+10)-1 +row2mod) * (buttonSize + buttonSpacing)), 42 + buttonSize + buttonSpacing)
					end

				-- 6x2 complimentary buttons
				else 
					if (buttonID < 7) then 
						button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + (((buttonID+10)-1) * (buttonSize + buttonSpacing)), 42 )
					else
						button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + (((buttonID-6+10)-1 +row2mod) * (buttonSize + buttonSpacing)), 42 + buttonSize + buttonSpacing)
					end
				end 
			end
		end 

		-- lua callback to update the hover frame anchors to the current layout
		self:CallMethod("UpdateFadeAnchors"); 
	
	]=],

	arrangeSideButtons = [=[
		local UICenter = self:GetFrameRef("UICenter"); 
		local sideBar1Enabled = self:GetAttribute("sideBar1Enabled");
		local sideBar2Enabled = self:GetAttribute("sideBar2Enabled");
		local sideBar3Enabled = self:GetAttribute("sideBar3Enabled");
		local sideBarCount = (sideBar1Enabled and 1 or 0) + (sideBar2Enabled and 1 or 0) + (sideBar3Enabled and 1 or 0);
		local buttonSize, buttonSpacing, iconSize = 64, 8, 44;

		for id,button in ipairs(Buttons) do 
			local buttonID = button:GetID(); 
			local barID = Pagers[id]:GetID(); 

			-- First Side Bar
			if (barID == self:GetAttribute("RIGHT_ACTIONBAR_PAGE")) then

				if (sideBar1Enabled) then
					button:ClearAllPoints(); 

					-- 12x1
					if (sideBarCount > 1) then
						-- This is always the first when it's enabled

					-- 6x2
					else

					end
				end

			-- Second Side Bar
			elseif (barID == self:GetAttribute("LEFT_ACTIONBAR_PAGE")) then

				if (sideBar2Enabled) then
					button:ClearAllPoints(); 

					if (sideBarCount > 1) then

						-- 12x1, 2nd
						if (sideBar1Enabled) then

						-- 12x1, 1st
						else

						end

					-- 6x2, 1st
					else

					end
				end

			-- Third Side Bar
			elseif (barID == self:GetAttribute("BOTTOMRIGHT_ACTIONBAR_PAGE")) then

				if (sideBar3Enabled) then
					button:ClearAllPoints(); 

					-- 12x1, 3rd
					if (sideBarCount > 2) then

					-- 12x1, 2nd
					elseif (sideBarCount > 1) then

					-- 6x2, 1st
					else

					end
				end
			end 
		end
	]=],

	arrangePetButtons = [=[
		local UICenter = self:GetFrameRef("UICenter");
		local buttonSize, buttonSpacing = 64*3/4, 2;
		local startX, startY = -(buttonSize*10 + buttonSpacing*9)/2, 200;

		for id,button in ipairs(PetButtons) do
			button:ClearAllPoints();
			button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOM", startX + ((id-1) * (buttonSize + buttonSpacing)), startY);
		end

		-- lua callback to update the explorer mode anchors to the current layout
		self:CallMethod("UpdateExplorerModeAnchors"); 

	]=],

	attributeChanged = [=[
		-- 'name' appears to be turned to lowercase by the restricted environment(?), 
		-- but we're doing it manually anyway, just to avoid problems. 
		if name then 
			name = string.lower(name); 
		end 

		if (name == "change-extrabuttonsvisibility") then 
			self:SetAttribute("extraButtonsVisibility", value); 
			self:CallMethod("UpdateFading"); 
		
		elseif (name == "change-petbarvisibility") then 
				self:SetAttribute("petBarVisibility", value); 
				self:CallMethod("UpdateFading"); 
	
		elseif (name == "change-extrabuttonscount") then 
			local extraButtonsCount = tonumber(value) or 0; 
			local visible = extraButtonsCount + 7; 
	
			-- Update button visibility counts
			for i = 8,24 do 
				local pager = Pagers[i]; 
				if (i > visible) then 
					if pager:IsShown() then 
						pager:Hide(); 
					end 
				else 
					if (not pager:IsShown()) then 
						pager:Show(); 
					end 
				end 
			end 

			self:SetAttribute("extraButtonsCount", extraButtonsCount); 
			self:RunAttribute("arrangeButtons"); 

			-- tell lua about it
			self:CallMethod("UpdateButtonCount"); 

		elseif (name == "change-castondown") then 
			self:SetAttribute("castOnDown", value and true or false); 
			self:CallMethod("UpdateCastOnDown"); 

		elseif (name == "change-petbarenabled") then 
			self:SetAttribute("petBarEnabled", value and true or false); 

			for i = 1,10 do
				local pager = PetPagers[i]; 
				if value then 
					if (not pager:IsShown()) then 
						pager:Show(); 
					end 
				else 
					if pager:IsShown() then 
						pager:Hide(); 
					end 
				end 
			end

			-- lua callback to update the explorer mode anchors to the current layout
			self:CallMethod("UpdateExplorerModeAnchors"); 
			
		elseif (name == "change-buttonlock") then 
			self:SetAttribute("buttonLock", value and true or false); 

			-- change all button attributes
			for id, button in ipairs(Buttons) do 
				button:SetAttribute("buttonLock", value);
			end

			-- change all pet button attributes
			for id, button in ipairs(PetButtons) do 
				button:SetAttribute("buttonLock", value);
			end
		end 

	]=]
}

-- Keybind abbrevations. Do not localize these.
local ShortKey = {
	-- Keybinds (visible on the actionbuttons)
	["Alt"] = "A",
	["Left Alt"] = "LA",
	["Right Alt"] = "RA",
	["Ctrl"] = "C",
	["Left Ctrl"] = "LC",
	["Right Ctrl"] = "RC",
	["Shift"] = "S",
	["Left Shift"] = "LS",
	["Right Shift"] = "RS",
	["NumPad"] = "N", 
	["Backspace"] = "BS",
	["Button1"] = "B1",
	["Button2"] = "B2",
	["Button3"] = "B3",
	["Button4"] = "B4",
	["Button5"] = "B5",
	["Button6"] = "B6",
	["Button7"] = "B7",
	["Button8"] = "B8",
	["Button9"] = "B9",
	["Button10"] = "B10",
	["Button11"] = "B11",
	["Button12"] = "B12",
	["Button13"] = "B13",
	["Button14"] = "B14",
	["Button15"] = "B15",
	["Button16"] = "B16",
	["Button17"] = "B17",
	["Button18"] = "B18",
	["Button19"] = "B19",
	["Button20"] = "B20",
	["Button21"] = "B21",
	["Button22"] = "B22",
	["Button23"] = "B23",
	["Button24"] = "B24",
	["Button25"] = "B25",
	["Button26"] = "B26",
	["Button27"] = "B27",
	["Button28"] = "B28",
	["Button29"] = "B29",
	["Button30"] = "B30",
	["Button31"] = "B31",
	["Capslock"] = "Cp",
	["Clear"] = "Cl",
	["Delete"] = "Del",
	["End"] = "End",
	["Enter"] = "Ent",
	["Return"] = "Ret",
	["Home"] = "Hm",
	["Insert"] = "Ins",
	["Help"] = "Hlp",
	["Mouse Wheel Down"] = "WD",
	["Mouse Wheel Up"] = "WU",
	["Num Lock"] = "NL",
	["Page Down"] = "PD",
	["Page Up"] = "PU",
	["Print Screen"] = "Prt",
	["Scroll Lock"] = "SL",
	["Spacebar"] = "Sp",
	["Tab"] = "Tb",
	["Down Arrow"] = "Dn",
	["Left Arrow"] = "Lf",
	["Right Arrow"] = "Rt",
	["Up Arrow"] = "Up"
}

-- Hotkey abbreviations for better readability
local getBindingKeyText = function(key)
	if key then
		key = key:upper()
		key = key:gsub(" ", "")

		key = key:gsub("ALT%-", ShortKey["Alt"])
		key = key:gsub("CTRL%-", ShortKey["Ctrl"])
		key = key:gsub("SHIFT%-", ShortKey["Shift"])
		key = key:gsub("NUMPAD", ShortKey["NumPad"])

		key = key:gsub("PLUS", "%+")
		key = key:gsub("MINUS", "%-")
		key = key:gsub("MULTIPLY", "%*")
		key = key:gsub("DIVIDE", "%/")

		key = key:gsub("BACKSPACE", ShortKey["Backspace"])

		for i = 1,31 do
			key = key:gsub("BUTTON" .. i, ShortKey["Button" .. i])
		end

		key = key:gsub("CAPSLOCK", ShortKey["Capslock"])
		key = key:gsub("CLEAR", ShortKey["Clear"])
		key = key:gsub("DELETE", ShortKey["Delete"])
		key = key:gsub("END", ShortKey["End"])
		key = key:gsub("HOME", ShortKey["Home"])
		key = key:gsub("INSERT", ShortKey["Insert"])
		key = key:gsub("MOUSEWHEELDOWN", ShortKey["Mouse Wheel Down"])
		key = key:gsub("MOUSEWHEELUP", ShortKey["Mouse Wheel Up"])
		key = key:gsub("NUMLOCK", ShortKey["Num Lock"])
		key = key:gsub("PAGEDOWN", ShortKey["Page Down"])
		key = key:gsub("PAGEUP", ShortKey["Page Up"])
		key = key:gsub("SCROLLLOCK", ShortKey["Scroll Lock"])
		key = key:gsub("SPACEBAR", ShortKey["Spacebar"])
		key = key:gsub("TAB", ShortKey["Tab"])

		key = key:gsub("DOWNARROW", ShortKey["Down Arrow"])
		key = key:gsub("LEFTARROW", ShortKey["Left Arrow"])
		key = key:gsub("RIGHTARROW", ShortKey["Right Arrow"])
		key = key:gsub("UPARROW", ShortKey["Up Arrow"])

		return key
	end
end

-- Old removed settings we need to purge from old databases
local deprecated = {
	buttonsPrimary = 1, 
	buttonsComplimentary = 1, 
	editMode = true, 
	enableComplimentary = false, 
	enableStance = false, 
	enablePet = false, 
	showBinds = true, 
	showCooldown = true, 
	showCooldownCount = true,
	showNames = false,
	visibilityPrimary = 1,
	visibilityComplimentary = 1,
	visibilityStance = 1, 
	visibilityPet = 1
}

-- ActionButton Template (Custom Methods)
----------------------------------------------------
local ActionButton = {}

ActionButton.GetBindingTextAbbreviated = function(self)
	return getBindingKeyText(self:GetBindingText())
end

ActionButton.UpdateBinding = function(self)
	local Keybind = self.Keybind
	if Keybind then 
		Keybind:SetText(self:GetBindingTextAbbreviated() or "")
	end 
end

ActionButton.UpdateMouseOver = function(self)
	if (self.isMouseOver) then 
		if (self.Darken) then 
			self.Darken:SetAlpha(self.Darken.highlight)
		end 
		if (self.Border) then 
			self.Border:SetVertexColor(Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], 1)
		end 
		if (self.Glow) then 
			self.Glow:Show()
		end 
	else 
		if self.Darken then 
			self.Darken:SetAlpha(self.Darken.normal)
		end 
		if self.Border then 
			self.Border:SetVertexColor(Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3], 1)
		end 
		if self.Glow then 
			self.Glow:Hide()
		end 
	end 
end 

ActionButton.PostEnter = function(self)
	self:UpdateMouseOver()
end 

ActionButton.PostLeave = function(self)
	self:UpdateMouseOver()
end 

ActionButton.SetRankVisibility = function(self, visible)
	if (not IsClassic) then
		return
	end
	local cache = Cache[self]

	-- Show rank on self
	if (visible) then 

		-- Create rank text if needed
		if (not self.Rank) then 
			local count = self.Count
			local rank = self:CreateFontString()
			rank:SetParent(count:GetParent())
			--rank:SetFontObject(count:GetFontObject()) -- nah, this one changes based on count!
			rank:SetFontObject(Private.GetFont(14,true)) -- use the smaller font
			rank:SetDrawLayer(count:GetDrawLayer())
			rank:SetTextColor(Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3])
			rank:SetPoint(count:GetPoint())
			self.Rank = rank
		end
		self.Rank:SetText(cache.spellRank)

	-- Hide rank on self, if it exists. 
	elseif (not visible) and (self.Rank) then 
		self.Rank:SetText("")
	end 
end

ActionButton.PostUpdate = function(self)
	self:UpdateMouseOver()

	-- The following is only for classic
	if (not IsClassic) then
		return
	end

	local cache = Cache[self]
	if (not cache) then 
		Cache[self] = {}
		cache = Cache[self]
	end

	-- Retrieve the previous info, if any.
	local oldCount = cache.spellCount -- counter of the amount of multiples
	local oldName = cache.spellName -- used as identifier for multiples
	local oldRank = cache.spellRank -- rank of this instance of the multiple

	-- Update cached info 
	cache.spellRank = self:GetSpellRank()
	cache.spellName = GetSpellInfo(self:GetSpellID())

	-- Button spell changed?
	if (cache.spellName ~= oldName) then 

		-- We had a spell before, and there were more of it.
		-- We need to find the old ones, update their counts,
		-- and hide them if there's only a single one left. 
		if (oldRank and (oldCount > 1)) then 
			local newCount = oldCount - 1
			for button,otherCache in pairs(Cache) do 
				-- Ignore self, as we no longer have the same counter. 
				if (button ~= self) and (otherCache.spellName == oldName) then 
					otherCache.spellCount = newCount
					button:SetRankVisibility((newCount > 1))
				end
			end
		end 
	end 

	-- Counter for number of duplicates of the current spell
	local howMany = 0
	if (cache.spellRank) then 
		for button,otherCache in pairs(Cache) do 
			if (otherCache.spellName == cache.spellName) then 
				howMany = howMany + 1
			end 
		end
	end 

	-- Update stored counter
	cache.spellCount = howMany

	-- Update all rank texts and counters
	for button,otherCache in pairs(Cache) do 
		if (otherCache.spellName == cache.spellName) then 
			otherCache.spellCount = howMany
			button:SetRankVisibility((howMany > 1))
		end 
	end
end 

ActionButton.PostCreate = function(self, ...)
	local layout = Module.layout

	self:SetSize(unpack(layout.ButtonSize))
	self:SetHitRectInsets(unpack(layout.ButtonHitRects))

	-- Assign our own global custom colors
	self.colors = Colors

	-- Restyle the blizz layers
	-----------------------------------------------------
	self.Icon:SetSize(unpack(layout.IconSize))
	self.Icon:ClearAllPoints()
	self.Icon:SetPoint(unpack(layout.IconPlace))

	-- If SetTexture hasn't been called, the mask and probably texcoords won't stick. 
	-- This started happening in build 8.1.0.29600 (March 5th, 2019), or at least that's when I noticed.
	-- Does not appear to be related to whether GetTexture() has a return value or not. 
	self.Icon:SetTexture("") 
	self.Icon:SetMask(layout.MaskTexture)

	self.Pushed:SetDrawLayer(unpack(layout.PushedDrawLayer))
	self.Pushed:SetSize(unpack(layout.PushedSize))
	self.Pushed:ClearAllPoints()
	self.Pushed:SetPoint(unpack(layout.PushedPlace))
	self.Pushed:SetMask(layout.MaskTexture)
	self.Pushed:SetColorTexture(unpack(layout.PushedColor))
	self:SetPushedTexture(self.Pushed)
	self:GetPushedTexture():SetBlendMode(layout.PushedBlendMode)
		
	-- We need to put it back in its correct drawlayer, 
	-- or Blizzard will set it to ARTWORK which can lead 
	-- to it randomly being drawn behind the icon texture. 
	self:GetPushedTexture():SetDrawLayer(unpack(layout.PushedDrawLayer)) 

	-- Add a simpler checked texture
	if self.SetCheckedTexture then
		self.Checked = self.Checked or self:CreateTexture()
		self.Checked:SetDrawLayer(unpack(layout.CheckedDrawLayer))
		self.Checked:SetSize(unpack(layout.CheckedSize))
		self.Checked:ClearAllPoints()
		self.Checked:SetPoint(unpack(layout.CheckedPlace))
		self.Checked:SetMask(layout.MaskTexture)
		self.Checked:SetColorTexture(unpack(layout.CheckedColor))
		self:SetCheckedTexture(self.Checked)
		self:GetCheckedTexture():SetBlendMode(layout.CheckedBlendMode)
	end
	
	self.Flash:SetDrawLayer(unpack(layout.FlashDrawLayer))
	self.Flash:SetSize(unpack(layout.FlashSize))
	self.Flash:ClearAllPoints()
	self.Flash:SetPoint(unpack(layout.FlashPlace))
	self.Flash:SetTexture(layout.FlashTexture)
	self.Flash:SetVertexColor(unpack(layout.FlashColor))
	self.Flash:SetMask(layout.MaskTexture)

	self.Cooldown:SetSize(unpack(layout.CooldownSize))
	self.Cooldown:ClearAllPoints()
	self.Cooldown:SetPoint(unpack(layout.CooldownPlace))
	self.Cooldown:SetSwipeTexture(layout.CooldownSwipeTexture)
	self.Cooldown:SetSwipeColor(unpack(layout.CooldownSwipeColor))
	self.Cooldown:SetDrawSwipe(layout.ShowCooldownSwipe)
	self.Cooldown:SetBlingTexture(layout.CooldownBlingTexture, unpack(layout.CooldownBlingColor)) 
	self.Cooldown:SetDrawBling(layout.ShowCooldownBling)

	self.ChargeCooldown:SetSize(unpack(layout.ChargeCooldownSize))
	self.ChargeCooldown:ClearAllPoints()
	self.ChargeCooldown:SetPoint(unpack(layout.ChargeCooldownPlace))
	self.ChargeCooldown:SetSwipeTexture(layout.ChargeCooldownSwipeTexture, unpack(layout.ChargeCooldownSwipeColor))
	self.ChargeCooldown:SetSwipeColor(unpack(layout.ChargeCooldownSwipeColor))
	self.ChargeCooldown:SetBlingTexture(layout.ChargeCooldownBlingTexture, unpack(layout.ChargeCooldownBlingColor)) 
	self.ChargeCooldown:SetDrawSwipe(layout.ShowChargeCooldownSwipe)
	self.ChargeCooldown:SetDrawBling(layout.ShowChargeCooldownBling)

	self.CooldownCount:ClearAllPoints()
	self.CooldownCount:SetPoint(unpack(layout.CooldownCountPlace))
	self.CooldownCount:SetFontObject(layout.CooldownCountFont)
	self.CooldownCount:SetJustifyH(layout.CooldownCountJustifyH)
	self.CooldownCount:SetJustifyV(layout.CooldownCountJustifyV)
	self.CooldownCount:SetShadowOffset(unpack(layout.CooldownCountShadowOffset))
	self.CooldownCount:SetShadowColor(unpack(layout.CooldownCountShadowColor))
	self.CooldownCount:SetTextColor(unpack(layout.CooldownCountColor))

	self.Count:ClearAllPoints()
	self.Count:SetPoint(unpack(layout.CountPlace))
	self.Count:SetFontObject(layout.CountFont)
	self.Count:SetJustifyH(layout.CountJustifyH)
	self.Count:SetJustifyV(layout.CountJustifyV)
	self.Count:SetShadowOffset(unpack(layout.CountShadowOffset))
	self.Count:SetShadowColor(unpack(layout.CountShadowColor))
	self.Count:SetTextColor(unpack(layout.CountColor))

	self.maxDisplayCount = layout.CountMaxDisplayed
	self.PostUpdateCount = layout.CountPostUpdate

	self.Keybind:ClearAllPoints()
	self.Keybind:SetPoint(unpack(layout.KeybindPlace))
	self.Keybind:SetFontObject(layout.KeybindFont)
	self.Keybind:SetJustifyH(layout.KeybindJustifyH)
	self.Keybind:SetJustifyV(layout.KeybindJustifyV)
	self.Keybind:SetShadowOffset(unpack(layout.KeybindShadowOffset))
	self.Keybind:SetShadowColor(unpack(layout.KeybindShadowColor))
	self.Keybind:SetTextColor(unpack(layout.KeybindColor))

	self.SpellHighlight:ClearAllPoints()
	self.SpellHighlight:SetPoint(unpack(layout.SpellHighlightPlace))
	self.SpellHighlight:SetSize(unpack(layout.SpellHighlightSize))
	self.SpellHighlight.Texture:SetTexture(layout.SpellHighlightTexture)
	self.SpellHighlight.Texture:SetVertexColor(unpack(layout.SpellHighlightColor))

	self.SpellAutoCast:ClearAllPoints()
	self.SpellAutoCast:SetPoint(unpack(layout.SpellAutoCastPlace))
	self.SpellAutoCast:SetSize(unpack(layout.SpellAutoCastSize))
	self.SpellAutoCast.Ants:SetTexture(layout.SpellAutoCastAntsTexture)
	self.SpellAutoCast.Ants:SetVertexColor(unpack(layout.SpellAutoCastAntsColor))	
	self.SpellAutoCast.Glow:SetTexture(layout.SpellAutoCastGlowTexture)
	self.SpellAutoCast.Glow:SetVertexColor(unpack(layout.SpellAutoCastGlowColor))	

	self.Backdrop = self:CreateTexture()
	self.Backdrop:SetSize(unpack(layout.BackdropSize))
	self.Backdrop:SetPoint(unpack(layout.BackdropPlace))
	self.Backdrop:SetDrawLayer(unpack(layout.BackdropDrawLayer))
	self.Backdrop:SetTexture(layout.BackdropTexture)
	self.Backdrop:SetVertexColor(unpack(layout.BackdropColor))

	self.Darken = self:CreateTexture()
	self.Darken:SetDrawLayer("BACKGROUND", 3)
	self.Darken:SetSize(unpack(layout.IconSize))
	self.Darken:SetAllPoints(self.Icon)
	self.Darken:SetMask(layout.MaskTexture)
	self.Darken:SetTexture(BLANK_TEXTURE)
	self.Darken:SetVertexColor(0, 0, 0)
	self.Darken.highlight = 0
	self.Darken.normal = .15

	self.BorderFrame = self:CreateFrame("Frame")
	self.BorderFrame:SetFrameLevel(self:GetFrameLevel() + 5)
	self.BorderFrame:SetAllPoints(self)

	self.Border = self.BorderFrame:CreateTexture()
	self.Border:SetPoint(unpack(layout.BorderPlace))
	self.Border:SetDrawLayer(unpack(layout.BorderDrawLayer))
	self.Border:SetSize(unpack(layout.BorderSize))
	self.Border:SetTexture(layout.BorderTexture)
	self.Border:SetVertexColor(unpack(layout.BorderColor))

	self.Glow = self.Overlay:CreateTexture()
	self.Glow:SetDrawLayer(unpack(layout.GlowDrawLayer))
	self.Glow:SetSize(unpack(layout.GlowSize))
	self.Glow:SetPoint(unpack(layout.GlowPlace))
	self.Glow:SetTexture(layout.GlowTexture)
	self.Glow:SetVertexColor(unpack(layout.GlowColor))
	self.Glow:SetBlendMode(layout.GlowBlendMode)
	self.Glow:Hide()
end 

ActionButton.PostUpdateCooldown = function(self, cooldown)
	local layout = Module.layout
	cooldown:SetSwipeColor(unpack(layout.CooldownSwipeColor))
end 

ActionButton.PostUpdateChargeCooldown = function(self, cooldown)
	local layout = Module.layout
	cooldown:SetSwipeColor(unpack(layout.ChargeCooldownSwipeColor))
end

-- PetButton Template (Custom Methods)
----------------------------------------------------
local PetButton = {}

PetButton.PostCreate = function(self, ...)
	local layout = Module.layout

	self:SetSize(unpack(layout.PetButtonSize))
	self:SetHitRectInsets(unpack(layout.PetButtonHitRects))

	-- Assign our own global custom colors
	self.colors = Colors

	-- Restyle the blizz layers
	-----------------------------------------------------
	self.Icon:SetSize(unpack(layout.PetIconSize))
	self.Icon:ClearAllPoints()
	self.Icon:SetPoint(unpack(layout.PetIconPlace))

	-- If SetTexture hasn't been called, the mask and probably texcoords won't stick. 
	-- This started happening in build 8.1.0.29600 (March 5th, 2019), or at least that's when I noticed.
	-- Does not appear to be related to whether GetTexture() has a return value or not. 
	self.Icon:SetTexture("") 
	self.Icon:SetMask(layout.PetMaskTexture)

	self.Pushed:SetDrawLayer(unpack(layout.PetPushedDrawLayer))
	self.Pushed:SetSize(unpack(layout.PetPushedSize))
	self.Pushed:ClearAllPoints()
	self.Pushed:SetPoint(unpack(layout.PetPushedPlace))
	self.Pushed:SetMask(layout.PetMaskTexture)
	self.Pushed:SetColorTexture(unpack(layout.PetPushedColor))
	self:SetPushedTexture(self.Pushed)
	self:GetPushedTexture():SetBlendMode(layout.PetPushedBlendMode)
		
	-- We need to put it back in its correct drawlayer, 
	-- or Blizzard will set it to ARTWORK which can lead 
	-- to it randomly being drawn behind the icon texture. 
	self:GetPushedTexture():SetDrawLayer(unpack(layout.PetPushedDrawLayer)) 

	self.Checked = self:CreateTexture()
	self.Checked:SetDrawLayer(unpack(layout.PetCheckedDrawLayer))
	self.Checked:SetSize(unpack(layout.PetCheckedSize))
	self.Checked:ClearAllPoints()
	self.Checked:SetPoint(unpack(layout.PetCheckedPlace))
	self.Checked:SetTexture(layout.PetMaskTexture)
	self.Checked:SetVertexColor(unpack(layout.PetCheckedColor))
	self.Checked:SetBlendMode(layout.PetCheckedBlendMode)
	self:SetCheckedTexture(self.Checked)
	self:GetCheckedTexture():SetBlendMode(layout.PetCheckedBlendMode)

	self.Flash:SetDrawLayer(unpack(layout.PetFlashDrawLayer))
	self.Flash:SetSize(unpack(layout.PetFlashSize))
	self.Flash:ClearAllPoints()
	self.Flash:SetPoint(unpack(layout.PetFlashPlace))
	self.Flash:SetTexture(layout.PetFlashTexture)
	self.Flash:SetVertexColor(unpack(layout.PetFlashColor))
	self.Flash:SetMask(layout.PetMaskTexture)

	self.Cooldown:SetSize(unpack(layout.PetCooldownSize))
	self.Cooldown:ClearAllPoints()
	self.Cooldown:SetPoint(unpack(layout.PetCooldownPlace))
	self.Cooldown:SetSwipeTexture(layout.PetCooldownSwipeTexture)
	self.Cooldown:SetSwipeColor(unpack(layout.PetCooldownSwipeColor))
	self.Cooldown:SetDrawSwipe(layout.PetShowCooldownSwipe)
	self.Cooldown:SetBlingTexture(layout.PetCooldownBlingTexture, unpack(layout.PetCooldownBlingColor)) 
	self.Cooldown:SetDrawBling(layout.PetShowCooldownBling)

	self.ChargeCooldown:SetSize(unpack(layout.PetChargeCooldownSize))
	self.ChargeCooldown:ClearAllPoints()
	self.ChargeCooldown:SetPoint(unpack(layout.PetChargeCooldownPlace))
	self.ChargeCooldown:SetSwipeTexture(layout.PetChargeCooldownSwipeTexture, unpack(layout.PetChargeCooldownSwipeColor))
	self.ChargeCooldown:SetSwipeColor(unpack(layout.PetChargeCooldownSwipeColor))
	self.ChargeCooldown:SetBlingTexture(layout.PetChargeCooldownBlingTexture, unpack(layout.PetChargeCooldownBlingColor)) 
	self.ChargeCooldown:SetDrawSwipe(layout.PetShowChargeCooldownSwipe)
	self.ChargeCooldown:SetDrawBling(layout.PetShowChargeCooldownBling)

	self.CooldownCount:ClearAllPoints()
	self.CooldownCount:SetPoint(unpack(layout.PetCooldownCountPlace))
	self.CooldownCount:SetFontObject(layout.PetCooldownCountFont)
	self.CooldownCount:SetJustifyH(layout.PetCooldownCountJustifyH)
	self.CooldownCount:SetJustifyV(layout.PetCooldownCountJustifyV)
	self.CooldownCount:SetShadowOffset(unpack(layout.PetCooldownCountShadowOffset))
	self.CooldownCount:SetShadowColor(unpack(layout.PetCooldownCountShadowColor))
	self.CooldownCount:SetTextColor(unpack(layout.PetCooldownCountColor))

	self.Count:ClearAllPoints()
	self.Count:SetPoint(unpack(layout.PetCountPlace))
	self.Count:SetFontObject(layout.PetCountFont)
	self.Count:SetJustifyH(layout.PetCountJustifyH)
	self.Count:SetJustifyV(layout.PetCountJustifyV)
	self.Count:SetShadowOffset(unpack(layout.PetCountShadowOffset))
	self.Count:SetShadowColor(unpack(layout.PetCountShadowColor))
	self.Count:SetTextColor(unpack(layout.PetCountColor))

	self.Keybind:ClearAllPoints()
	self.Keybind:SetPoint(unpack(layout.PetKeybindPlace))
	self.Keybind:SetFontObject(layout.PetKeybindFont)
	self.Keybind:SetJustifyH(layout.PetKeybindJustifyH)
	self.Keybind:SetJustifyV(layout.PetKeybindJustifyV)
	self.Keybind:SetShadowOffset(unpack(layout.PetKeybindShadowOffset))
	self.Keybind:SetShadowColor(unpack(layout.PetKeybindShadowColor))
	self.Keybind:SetTextColor(unpack(layout.PetKeybindColor))

	self.SpellAutoCast:ClearAllPoints()
	self.SpellAutoCast:SetPoint(unpack(layout.PetSpellAutoCastPlace))
	self.SpellAutoCast:SetSize(unpack(layout.PetSpellAutoCastSize))
	self.SpellAutoCast.Ants:SetTexture(layout.PetSpellAutoCastAntsTexture)
	self.SpellAutoCast.Ants:SetVertexColor(unpack(layout.PetSpellAutoCastAntsColor))	
	self.SpellAutoCast.Glow:SetTexture(layout.PetSpellAutoCastGlowTexture)
	self.SpellAutoCast.Glow:SetVertexColor(unpack(layout.PetSpellAutoCastGlowColor))	

	self.Backdrop = self:CreateTexture()
	self.Backdrop:SetSize(unpack(layout.PetBackdropSize))
	self.Backdrop:SetPoint(unpack(layout.PetBackdropPlace))
	self.Backdrop:SetDrawLayer(unpack(layout.PetBackdropDrawLayer))
	self.Backdrop:SetTexture(layout.PetBackdropTexture)
	self.Backdrop:SetVertexColor(unpack(layout.PetBackdropColor))

	self.Darken = self:CreateTexture()
	self.Darken:SetDrawLayer("BACKGROUND", 3)
	self.Darken:SetSize(unpack(layout.PetIconSize))
	self.Darken:SetAllPoints(self.Icon)
	self.Darken:SetMask(layout.PetMaskTexture)
	self.Darken:SetTexture(BLANK_TEXTURE)
	self.Darken:SetVertexColor(0, 0, 0)
	self.Darken.highlight = 0
	self.Darken.normal = .15

	self.BorderFrame = self:CreateFrame("Frame")
	self.BorderFrame:SetFrameLevel(self:GetFrameLevel() + 5)
	self.BorderFrame:SetAllPoints(self)

	self.Border = self.BorderFrame:CreateTexture()
	self.Border:SetPoint(unpack(layout.PetBorderPlace))
	self.Border:SetDrawLayer(unpack(layout.PetBorderDrawLayer))
	self.Border:SetSize(unpack(layout.PetBorderSize))
	self.Border:SetTexture(layout.PetBorderTexture)
	self.Border:SetVertexColor(unpack(layout.PetBorderColor))

	self.Glow = self.Overlay:CreateTexture()
	self.Glow:SetDrawLayer(unpack(layout.PetGlowDrawLayer))
	self.Glow:SetSize(unpack(layout.PetGlowSize))
	self.Glow:SetPoint(unpack(layout.PetGlowPlace))
	self.Glow:SetTexture(layout.PetGlowTexture)
	self.Glow:SetVertexColor(unpack(layout.PetGlowColor))
	self.Glow:SetBlendMode(layout.PetGlowBlendMode)
	self.Glow:Hide()
end 

PetButton.PostUpdate = function(self)
	self:UpdateMouseOver()
end

PetButton.GetBindingTextAbbreviated = ActionButton.GetBindingTextAbbreviated
PetButton.UpdateBinding = ActionButton.UpdateBinding
PetButton.UpdateMouseOver = ActionButton.UpdateMouseOver
PetButton.PostEnter = ActionButton.PostEnter
PetButton.PostLeave = ActionButton.PostLeave

-- Bar Creation
----------------------------------------------------
Module.SpawnActionBars = function(self)
	local db = self.db
	local proxy = self:GetSecureUpdater()

	-- Private test mode to show all
	local FORCED = false 

	local buttonID = 0 -- current buttonID when spawning
	local numPrimary = 7 -- Number of primary buttons always visible
	local firstHiddenID = db.extraButtonsCount + numPrimary -- first buttonID to be hidden
	
	-- Primary Action Bar
	for id = 1,NUM_ACTIONBAR_BUTTONS do 
		buttonID = buttonID + 1
		Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButton, 1, id)
		HoverButtons[Buttons[buttonID]] = buttonID > numPrimary
	end 

	-- Secondary Action Bar (Bottom Left)
	for id = 1,NUM_ACTIONBAR_BUTTONS do 
		buttonID = buttonID + 1
		Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButton, BOTTOMLEFT_ACTIONBAR_PAGE, id)
		HoverButtons[Buttons[buttonID]] = true
	end 

	-- First Side Bar (Bottom Right)
	for id = 1,NUM_ACTIONBAR_BUTTONS do 
		buttonID = buttonID + 1
		Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButton, BOTTOMRIGHT_ACTIONBAR_PAGE, id)
	end

	-- Second Side bar (Right)
	for id = 1,NUM_ACTIONBAR_BUTTONS do 
		buttonID = buttonID + 1
		Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButton, RIGHT_ACTIONBAR_PAGE, id)
	end

	-- Third Side Bar (Left)
	for id = 1,NUM_ACTIONBAR_BUTTONS do 
		buttonID = buttonID + 1
		Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButton, LEFT_ACTIONBAR_PAGE, id)
	end

	-- Apply common settings to the action buttons.
	for buttonID,button in ipairs(Buttons) do 
	
		-- Apply saved buttonLock setting
		button:SetAttribute("buttonLock", db.buttonLock)

		-- Link the buttons and their pagers 
		proxy:SetFrameRef("Button"..buttonID, Buttons[buttonID])
		proxy:SetFrameRef("Pager"..buttonID, Buttons[buttonID]:GetPager())

		-- Reference all buttons in our menu callback frame
		proxy:Execute(([=[
			table.insert(Buttons, self:GetFrameRef("Button"..%.0f)); 
			table.insert(Pagers, self:GetFrameRef("Pager"..%.0f)); 
		]=]):format(buttonID, buttonID))

		-- Hide buttons beyond our current maximum visible
		if (HoverButtons[button] and (buttonID > firstHiddenID)) then 
			button:GetPager():Hide()
		end 
	end 
end

Module.SpawnPetBar = function(self)
	local db = self.db
	local proxy = self:GetSecureUpdater()
	
	-- Spawn the Pet Bar
	for id = 1,NUM_PET_ACTION_SLOTS do
		PetButtons[id] = self:SpawnActionButton("pet", self.frame, PetButton, nil, id)
	end

	-- Apply common stuff to the pet buttons
	for id,button in pairs(PetButtons) do
		-- Apply saved buttonLock setting
		button:SetAttribute("buttonLock", db.buttonLock)

		-- Link the buttons and their pagers 
		proxy:SetFrameRef("PetButton"..id, PetButtons[id])
		proxy:SetFrameRef("PetPager"..id, PetButtons[id]:GetPager())

		if (not db.petBarEnabled) then
			PetButtons[id]:GetPager():Hide()
		end
		
		-- Reference all buttons in our menu callback frame
		proxy:Execute(([=[
			table.insert(PetButtons, self:GetFrameRef("PetButton"..%.0f)); 
			table.insert(PetPagers, self:GetFrameRef("PetPager"..%.0f)); 
		]=]):format(id, id))
		
	end
end

Module.SpawnStanceBar = function(self)
end

Module.SpawnExitButton = function(self)
	local layout = self.layout

	local button = self:CreateFrame("Button", nil, "UICenter", "SecureActionButtonTemplate")
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(100)
	button:Place(unpack(layout.ExitButtonPlace))
	button:SetSize(unpack(layout.ExitButtonSize))
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", "/dismount [mounted]")

	-- Put our texture on the button
	button.texture = button:CreateTexture()
	button.texture:SetSize(unpack(layout.ExitButtonTextureSize))
	button.texture:SetPoint(unpack(layout.ExitButtonTexturePlace))
	button.texture:SetTexture(layout.ExitButtonTexturePath)

	button:SetScript("OnEnter", function(button)
		local tooltip = self:GetActionButtonTooltip()
		tooltip:Hide()
		tooltip:SetDefaultAnchor(button)

		if UnitOnTaxi("player") then 
			tooltip:AddLine(TAXI_CANCEL)
			tooltip:AddLine(TAXI_CANCEL_DESCRIPTION, Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
		elseif IsMounted() then 
			tooltip:AddLine(BINDING_NAME_DISMOUNT)
			tooltip:AddLine(L["%s to dismount."]:format(L["<Left-Click>"]), Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
		else 
			tooltip:AddLine(LEAVE_VEHICLE)
			tooltip:AddLine(L["%s to leave the vehicle."]:format(L["<Left-Click>"]), Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
		end 

		tooltip:Show()
	end)

	button:SetScript("OnLeave", function(button) 
		local tooltip = self:GetActionButtonTooltip()
		tooltip:Hide()
	end)

	-- Gotta do this the unsecure way, no macros exist for this yet. 
	button:HookScript("OnClick", function(self, button) 
		if (UnitOnTaxi("player") and (not InCombatLockdown())) then
			TaxiRequestEarlyLanding()
		end
	end)

	-- Register a visibility driver
	RegisterAttributeDriver(button, "state-visibility", "[mounted]show;hide")

	self.VehicleExitButton = button
end

-- Getters
----------------------------------------------------
Module.GetButtons = function(self)
	return pairs(Buttons)
end

Module.GetExplorerModeFrameAnchors = function(self)
	return self:GetOverlayFrame(), self:GetOverlayFramePet()
end

Module.GetFadeFrame = function(self)
	if (not ActionBarHoverFrame) then 
		ActionBarHoverFrame = self:CreateFrame("Frame")
		ActionBarHoverFrame.timeLeft = 0
		ActionBarHoverFrame.elapsed = 0
		ActionBarHoverFrame:SetScript("OnUpdate", function(self, elapsed) 
			self.elapsed = self.elapsed + elapsed
			self.timeLeft = self.timeLeft - elapsed
	
			if (self.timeLeft <= 0) then
				if FORCED or self.FORCED or self.always or (self.incombat and IN_COMBAT) or self.forced or self.flyout or self:IsMouseOver(0,0,0,0) then
					if (not self.isMouseOver) then 
						self.isMouseOver = true
						self.alpha = 1
						for id = 8,24 do 
							Buttons[id]:GetPager():SetAlpha(self.alpha)
						end 
					end 
				else 
					if (self.isMouseOver) then 
						self.isMouseOver = nil
						if (not self.fadeOutTime) then 
							self.fadeOutTime = FadeOutDuration
						end 
					end 
					if (self.fadeOutTime) then 
						self.fadeOutTime = self.fadeOutTime - self.elapsed
						if (self.fadeOutTime > 0) then 
							self.alpha = self.fadeOutTime / FadeOutDuration
						else 
							self.alpha = 0
							self.fadeOutTime = nil
						end 
						for id = 8,24 do 
							Buttons[id]:GetPager():SetAlpha(self.alpha)
						end 
					end 
				end 
				self.elapsed = 0
				self.timeLeft = FadeOutHZ
			end 
		end) 

		ActionBarHoverFrame:SetScript("OnEvent", function(self, event, ...) 
			if (event == "ACTIONBAR_SHOWGRID") then 
				self.forced = true
			elseif (event == "ACTIONBAR_HIDEGRID") or (event == "buttonLock") then
				self.forced = nil
			end 
		end)

		hooksecurefunc("ActionButton_UpdateFlyout", function(self) 
			if (HoverButtons[self]) then 
				ActionBarHoverFrame.flyout = self:IsFlyoutShown()
			end
		end)

		ActionBarHoverFrame:RegisterEvent("ACTIONBAR_HIDEGRID")
		ActionBarHoverFrame:RegisterEvent("ACTIONBAR_SHOWGRID")
		ActionBarHoverFrame.isMouseOver = true -- Set this to initiate the first fade-out
	end
	return ActionBarHoverFrame
end

Module.GetFadeFramePet = function(self)
	if (not PetBarHoverFrame) then
		PetBarHoverFrame = self:CreateFrame("Frame")
		PetBarHoverFrame.timeLeft = 0
		PetBarHoverFrame.elapsed = 0
		PetBarHoverFrame:SetScript("OnUpdate", function(self, elapsed) 
			self.elapsed = self.elapsed + elapsed
			self.timeLeft = self.timeLeft - elapsed
	
			if (self.timeLeft <= 0) then
				if FORCED or self.FORCED or self.always or (self.incombat and IN_COMBAT) or self.forced or self.flyout or self:IsMouseOver(0,0,0,0) then
					if (not self.isMouseOver) then 
						self.isMouseOver = true
						self.alpha = 1
						for id in pairs(PetButtons) do
							PetButtons[id]:GetPager():SetAlpha(self.alpha)
						end 
					end
				else 
					if (self.isMouseOver) then 
						self.isMouseOver = nil
						if (not self.fadeOutTime) then 
							self.fadeOutTime = FadeOutDuration
						end 
					end 
					if (self.fadeOutTime) then 
						self.fadeOutTime = self.fadeOutTime - self.elapsed
						if (self.fadeOutTime > 0) then 
							self.alpha = self.fadeOutTime / FadeOutDuration
						else 
							self.alpha = 0
							self.fadeOutTime = nil
						end 
						for id in pairs(PetButtons) do
							PetButtons[id]:GetPager():SetAlpha(self.alpha)
						end 
					end 
				end 
				self.elapsed = 0
				self.timeLeft = FadeOutHZ
			end 
		end) 

		PetBarHoverFrame:SetScript("OnEvent", function(self, event, ...) 
			if (event == "PET_BAR_SHOWGRID") then 
				self.forced = true
			elseif (event == "PET_BAR_HIDEGRID") or (event == "buttonLock") then
				self.forced = nil
			end 
		end)


		PetBarHoverFrame:RegisterEvent("PET_BAR_SHOWGRID")
		PetBarHoverFrame:RegisterEvent("PET_BAR_HIDEGRID")
		PetBarHoverFrame.isMouseOver = true -- Set this to initiate the first fade-out
	end
	return PetBarHoverFrame
end

Module.GetOverlayFrame = function(self)
	return self.frame
end

Module.GetOverlayFramePet = function(self)
	return self.frameOverlayPet
end

Module.GetPetButtons = function(self)
	return pairs(PetButtons)
end

Module.GetSecureUpdater = function(self)
	if (not self.proxyUpdater) then
		-- Secure frame used by the menu system to interact with our secure buttons.
		local proxy = self:CreateFrame("Frame", nil, parent, "SecureHandlerAttributeTemplate")

		-- Add some module methods to the proxy.
		for _,method in pairs({
			"UpdateCastOnDown",
			"UpdateFading",
			"UpdateFadeAnchors",
			"UpdateExplorerModeAnchors",
			"UpdateButtonCount"
		}) do
			proxy[method] = function() self[method](self) end
		end
	
		-- Copy all saved settings to our secure proxy frame.
		for key,value in pairs(self.db) do 
			proxy:SetAttribute(key,value)
		end 
	
		-- Create tables to hold the buttons
		-- within the restricted environment.
		proxy:Execute([=[ 
			Buttons = table.new();
			Pagers = table.new();
			PetButtons = table.new();
			PetPagers = table.new();
			StanceButtons = table.new();
		]=])
	
		-- Apply references and attributes used for updates.
		proxy:SetFrameRef("UICenter", self:GetFrame("UICenter"))
		proxy:SetAttribute("BOTTOMLEFT_ACTIONBAR_PAGE", BOTTOMLEFT_ACTIONBAR_PAGE)
		proxy:SetAttribute("BOTTOMRIGHT_ACTIONBAR_PAGE", BOTTOMRIGHT_ACTIONBAR_PAGE)
		proxy:SetAttribute("RIGHT_ACTIONBAR_PAGE", RIGHT_ACTIONBAR_PAGE)
		proxy:SetAttribute("LEFT_ACTIONBAR_PAGE", LEFT_ACTIONBAR_PAGE)
		proxy:SetAttribute("arrangeButtons", secureSnippets.arrangeButtons)
		proxy:SetAttribute("arrangePetButtons", secureSnippets.arrangePetButtons)
		proxy:SetAttribute("_onattributechanged", secureSnippets.attributeChanged)
	
		-- Reference it for later use
		self.proxyUpdater = proxy
	end
	return self.proxyUpdater
end

-- Setters
----------------------------------------------------
Module.SetForcedVisibility = function(self, force)
	local actionBarHoverFrame = self:GetFadeFrame()
	actionBarHoverFrame.FORCED = force and true
end

-- Updates
----------------------------------------------------
Module.UpdateFading = function(self)
	local db = self.db

	-- Set action bar hover settings
	local actionBarHoverFrame = self:GetFadeFrame()
	actionBarHoverFrame.incombat = db.extraButtonsVisibility == "combat"
	actionBarHoverFrame.always = db.extraButtonsVisibility == "always"

	-- We're hardcoding these until options can be added
	local petBarHoverFrame = self:GetFadeFramePet()
	petBarHoverFrame.incombat = db.petBarVisibility == "combat"
	petBarHoverFrame.always = db.petBarVisibility == "always"
end 

Module.UpdateExplorerModeAnchors = function(self)
	local db = self.db
	local frame = self:GetOverlayFramePet()
	if (self.db.petBarEnabled) then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", PetButtons[1], "TOPLEFT")
		frame:SetPoint("BOTTOMRIGHT", PetButtons[10], "BOTTOMRIGHT")
	else
		frame:ClearAllPoints()
		frame:SetAllPoints(self:GetFrame())
	end
end

Module.UpdateFadeAnchors = function(self)
	local db = self.db

	-- Parse buttons for hoverbutton IDs
	local first, last, left, right, top, bottom, mLeft, mRight, mTop, mBottom
	for id,button in ipairs(Buttons) do 
		-- If we pass number of visible hoverbuttons, just bail out
		if (id > db.extraButtonsCount + 7) then 
			break 
		end 

		local bLeft = button:GetLeft()
		local bRight = button:GetRight()
		local bTop = button:GetTop()
		local bBottom = button:GetBottom()
		
		if HoverButtons[button] then 
			-- Only counting the first encountered as the first
			if (not first) then 
				first = id 
			end 

			-- Counting every button as the last, until we actually reach it 
			last = id 

			-- Figure out hoverframe anchor buttons
			left = left and (Buttons[left]:GetLeft() < bLeft) and left or id
			right = right and (Buttons[right]:GetRight() > bRight) and right or id
			top = top and (Buttons[top]:GetTop() > bTop) and top or id
			bottom = bottom and (Buttons[bottom]:GetBottom() < bBottom) and bottom or id
		end 

		-- Figure out main frame anchor buttons, 
		-- as we need this for the explorer mode fade anchors!
		mLeft = mLeft and (Buttons[mLeft]:GetLeft() < bLeft) and mLeft or id
		mRight = mRight and (Buttons[mRight]:GetRight() > bRight) and mRight or id
		mTop = mTop and (Buttons[mTop]:GetTop() > bTop) and mTop or id
		mBottom = mBottom and (Buttons[mBottom]:GetBottom() < bBottom) and mBottom or id
	end 

	-- Setup main frame anchors for explorer mode! 
	self.frame:ClearAllPoints()
	self.frame:SetPoint("TOP", Buttons[mTop], "TOP", 0, 0)
	self.frame:SetPoint("BOTTOM", Buttons[mBottom], "BOTTOM", 0, 0)
	self.frame:SetPoint("LEFT", Buttons[mLeft], "LEFT", 0, 0)
	self.frame:SetPoint("RIGHT", Buttons[mRight], "RIGHT", 0, 0)

	-- If we have hoverbuttons, setup the anchors
	if (left and right and top and bottom) then 
		local actionBarHoverFrame = self:GetFadeFrame()
		actionBarHoverFrame:ClearAllPoints()
		actionBarHoverFrame:SetPoint("TOP", Buttons[top], "TOP", 0, 0)
		actionBarHoverFrame:SetPoint("BOTTOM", Buttons[bottom], "BOTTOM", 0, 0)
		actionBarHoverFrame:SetPoint("LEFT", Buttons[left], "LEFT", 0, 0)
		actionBarHoverFrame:SetPoint("RIGHT", Buttons[right], "RIGHT", 0, 0)
	end

	local petBarHoverFrame = self:GetFadeFramePet()
	if (self.db.petBarEnabled) then
		petBarHoverFrame:ClearAllPoints()
		petBarHoverFrame:SetPoint("TOPLEFT", PetButtons[1], "TOPLEFT")
		petBarHoverFrame:SetPoint("BOTTOMRIGHT", PetButtons[10], "BOTTOMRIGHT")
	else
		petBarHoverFrame:ClearAllPoints()
		petBarHoverFrame:SetAllPoints(self:GetFrame())
	end

	self:UpdateButtonGrids()
end

Module.UpdateButtonCount = function(self)
	-- Update our smart button grids
	self:UpdateButtonGrids()

	-- Announce the updated button count to the world
	self:SendMessage("GP_UPDATE_ACTIONBUTTON_COUNT")
end

Module.UpdateButtonGrids = function(self)
	local db = self.db 
	local numButtons = db.extraButtonsCount + 7
	local button, buttonHasContent, forceGrid

	if (IsRetail) then
		if (HasOverrideActionBar() or HasTempShapeshiftActionBar() or HasVehicleActionBar()) then
			for buttonID = numButtons,1,-1 do
				button = Buttons[buttonID]
				button.showGrid = nil
				button.overrideAlphaWhenEmpty = nil
				button:UpdateGrid()
			end
			return
		end
	end
	
	for buttonID = numButtons,1,-1 do
		button = Buttons[buttonID]
		buttonHasContent = button:HasContent()

		if (forceGrid) then
			button.showGrid = true
			button.overrideAlphaWhenEmpty = .95
		else
			-- Check if the button has content,
			-- and if so start forcing the grids.
			if (buttonHasContent) then
				forceGrid = true
			else
				button.showGrid = nil
				button.overrideAlphaWhenEmpty = nil
			end
		end
		button:UpdateGrid()
	end
end

-- Just a proxy for the secure arrangement method.
-- Only ever call this out of combat, as it does not check for it.
Module.UpdateButtonLayout = function(self)
	local proxy = self:GetSecureUpdater()
	if (proxy) then
		proxy:Execute(proxy:GetAttribute("arrangeButtons"))
		proxy:Execute(proxy:GetAttribute("arrangePetButtons"))
	end
end

Module.UpdateCastOnDown = function(self)
	if InCombatLockdown() then 
		return self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateSettings")
	end
	if (event == "PLAYER_REGEN_ENABLED") then 
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "UpdateSettings")
	end 
	local db = self.db
	for button in self:GetAllActionButtonsOrdered() do
		button:RegisterForClicks(db.castOnDown and "AnyDown" or "AnyUp")
		button:Update()
	end 
end 

Module.UpdateConsolePortBindings = function(self)
	local CP = _G.ConsolePort
	if (not CP) then 
		return 
	end 
end

Module.UpdateBindings = function(self)
	if (IsConsolePortEnabled) then 
		self:UpdateConsolePortBindings()
	else
		self:UpdateActionButtonBindings()
	end
end

Module.UpdateTooltipSettings = function(self)
	local layout = self.layout
	local tooltip = self:GetActionButtonTooltip()
	tooltip.colorNameAsSpellWithUse = layout.TooltipColorNameAsSpellWithUse
	tooltip.hideItemLevelWithUse = layout.TooltipHideItemLevelWithUse
	tooltip.hideStatsWithUseEffect = layout.TooltipHideStatsWithUse
	tooltip.hideBindsWithUseEffect = layout.TooltipHideBindsWithUse
	tooltip.hideUniqueWithUseEffect = layout.TooltipHideUniqueWithUse
	tooltip.hideEquipTypeWithUseEffect = layout.TooltipHideEquipTypeWithUse
end 

Module.UpdateSettings = function(self, event, ...)
	local db = self.db
	self:UpdateFading()
	self:UpdateFadeAnchors()
	self:UpdateExplorerModeAnchors()
	self:UpdateCastOnDown()
	self:UpdateTooltipSettings()
end 

-- Initialization
----------------------------------------------------
Module.ParseSavedSettings = function(self)
	local db = GetConfig(self:GetName())

	-- Convert old options to new, if present 
	local extraButtons
	if (db.enableComplimentary) then 
		if (db.buttonsComplimentary == 1) then 
			extraButtons = 11
		elseif (db.buttonsComplimentary == 2) then 
			extraButtons = 17
		end 
	elseif (db.buttonsPrimary) then 
		if (db.buttonsPrimary == 1) then
			extraButtons = 0 
		elseif (db.buttonsPrimary == 2) then 
			extraButtons = 3 
		elseif (db.buttonsPrimary == 3) then 
			extraButtons = 5 
		end 
	end 
	
	-- If extra buttons existed we also need to figure out their visibility
	if extraButtons then 
		-- Store the old number of buttons in our new button setting 
		db.extraButtonsCount = extraButtons

		-- Use complimentary bar visibility settings if it was enabled, 
		-- use primary bar visibility settings if it wasn't. No more split options. 
		local extraVisibility
		if (extraButtons > 5) then 
			if (db.visibilityComplimentary == 1) then -- hover 
				extraVisibility = "hover"
			elseif (db.visibilityComplimentary == 2) then -- hover + combat 
				extraVisibility = "combat"
			elseif (db.visibilityComplimentary == 3) then -- always 
				extraVisibility = "always"
			end 
		else 
			if (db.visibilityPrimary == 1) then -- hover 
				extraVisibility = "hover"
			elseif (db.visibilityPrimary == 2) then -- hover + combat 
				extraVisibility = "combat"
			elseif (db.visibilityPrimary == 3) then -- always 
				extraVisibility = "always"
			end 
		end 
		if extraVisibility then 
			db.extraButtonsVisibility = extraVisibility
		end 
	end  

	-- Remove old deprecated options 
	for option in pairs(db) do 
		if (deprecated[option] ~= nil) then 
			db[option] = nil
		end 
	end 

	return db
end

Module.OnEvent = function(self, event, ...)
	if (event == "UPDATE_BINDINGS") then 
		self:UpdateBindings()
	elseif (event == "PLAYER_ENTERING_WORLD") then
		IN_COMBAT = false
		self:UpdateBindings()
	elseif (event == "PLAYER_REGEN_DISABLED") then
		IN_COMBAT = true 
	elseif (event == "PLAYER_REGEN_ENABLED") then
		IN_COMBAT = false
	elseif (event == "ACTIONBAR_SLOT_CHANGED") then
		self:UpdateButtonGrids()
	else
		self:UpdateButtonGrids()
	end 
end 

Module.OnInit = function(self)
	self.db = self:ParseSavedSettings()
	self.layout = GetLayout(self:GetName())

	-- Create master frame
	self.frame = self:CreateFrame("Frame", nil, "UICenter")

	-- Create additional overlay frames
	self.frameOverlayPet = self:CreateFrame("Frame", nil, "UICenter")

	-- Spawn the bars
	self:SpawnActionBars()
	self:SpawnPetBar()
	self:SpawnStanceBar()
	self:SpawnExitButton()

	-- Arrange buttons
	self:UpdateButtonLayout()

	-- Update saved settings
	self:UpdateBindings()
	self:UpdateSettings()
end 

Module.OnEnable = function(self)
	self:RegisterEvent("UPDATE_BINDINGS", "OnEvent")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
	self:RegisterEvent("ACTIONBAR_SLOT_CHANGED", "OnEvent")

	if (IsRetail) then
		self:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR", "OnEvent")
		self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR", "OnEvent")
	end
end
