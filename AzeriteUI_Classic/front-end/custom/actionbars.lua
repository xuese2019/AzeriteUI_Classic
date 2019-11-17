local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

-- Note that there's still a lot of hardcoded things in this file, 
-- and it will eventually be changed to be fully Layout driven. 
local L = Wheel("LibLocale"):GetLocale(ADDON)
local Module = Core:NewModule("ActionBarMain", "LibEvent", "LibMessage", "LibDB", "LibFrame", "LibSound", "LibTooltip", "LibSecureButton", "LibWidgetContainer", "LibPlayerData")

-- Lua API
local _G = _G
local ipairs = ipairs
local math_floor = math.floor
local pairs = pairs
local table_remove = table.remove
local tonumber = tonumber
local tostring = tostring

-- WoW API
local FindActiveAzeriteItem = _G.C_AzeriteItem and _G.C_AzeriteItem.FindActiveAzeriteItem
local GetAzeriteItemXPInfo = _G.C_AzeriteItem and _G.C_AzeriteItem.GetAzeriteItemXPInfo
local GetPowerLevel = _G.C_AzeriteItem and _G.C_AzeriteItem.GetPowerLevel
local InCombatLockdown = _G.InCombatLockdown
local IsMounted = _G.IsMounted
local UnitLevel = _G.UnitLevel
local UnitOnTaxi = _G.UnitOnTaxi
local UnitRace = _G.UnitRace

-- Private API
local Colors = Private.Colors
local GetConfig = Private.GetConfig
local GetLayout = Private.GetLayout

-- Blizzard textures for generic styling
local BLANK_TEXTURE = [[Interface\ChatFrame\ChatFrameBackground]]

-- Various string formatting for our tooltips and bars
local shortXPString = "%s%%"
local longXPString = "%s / %s"
local fullXPString = "%s / %s (%s)"
local restedString = " (%s%% %s)"
local shortLevelString = "%s %.0f"

-- Cache of buttons and ranks
local Cache = {}

-- Is ConsolePort loaded?
local CONSOLEPORT = Module:IsAddOnEnabled("ConsolePort")

-- Secure Code Snippets
local secureSnippets = {
	-- TODO: 
	-- Make this a formatstring, and fill in layout options from the Layout cache to make these universal. 
	arrangeButtons = [=[

		local UICenter = self:GetFrameRef("UICenter"); 
		local extraButtonsCount = tonumber(self:GetAttribute("extraButtonsCount")) or 0;
	
		local buttonSize, buttonSpacing, iconSize = 64, 8, 44; 
		local row2mod = -2/5; -- horizontal offset for upper row 

		for id, button in ipairs(Buttons) do 
			local buttonID = button:GetID(); 
			local barID = Pagers[id]:GetID(); 

			button:ClearAllPoints(); 

			if (barID == 1) then 
				if (buttonID > 10) then
					button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + ((buttonID-2-1 + row2mod) * (buttonSize + buttonSpacing)), 42 + buttonSize + buttonSpacing)
				else
					button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + ((buttonID-1) * (buttonSize + buttonSpacing)), 42 )
				end 

			elseif (barID == self:GetAttribute("BOTTOMLEFT_ACTIONBAR_PAGE")) then 

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

	attributeChanged = [=[
		-- 'name' appears to be turned to lowercase by the restricted environment(?), 
		-- but we're doing it manually anyway, just to avoid problems. 
		if name then 
			name = string.lower(name); 
		end 

		if (name == "change-extrabuttonsvisibility") then 
			self:SetAttribute("extraButtonsVisibility", value); 
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
		elseif (name == "change-buttonlock") then 
			self:SetAttribute("buttonLock", value and true or false); 

			-- change all button attributes
			for id, button in ipairs(Buttons) do 
				button:SetAttribute("buttonLock", value);
			end
		end 

	]=]
}

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

local IN_COMBAT

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
		return tostring(math_floor(value))
	end	
end

local L_KEY = {
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

		key = key:gsub("ALT%-", L_KEY["Alt"])
		key = key:gsub("CTRL%-", L_KEY["Ctrl"])
		key = key:gsub("SHIFT%-", L_KEY["Shift"])
		key = key:gsub("NUMPAD", L_KEY["NumPad"])

		key = key:gsub("PLUS", "%+")
		key = key:gsub("MINUS", "%-")
		key = key:gsub("MULTIPLY", "%*")
		key = key:gsub("DIVIDE", "%/")

		key = key:gsub("BACKSPACE", L_KEY["Backspace"])

		for i = 1,31 do
			key = key:gsub("BUTTON" .. i, L_KEY["Button" .. i])
		end

		key = key:gsub("CAPSLOCK", L_KEY["Capslock"])
		key = key:gsub("CLEAR", L_KEY["Clear"])
		key = key:gsub("DELETE", L_KEY["Delete"])
		key = key:gsub("END", L_KEY["End"])
		key = key:gsub("HOME", L_KEY["Home"])
		key = key:gsub("INSERT", L_KEY["Insert"])
		key = key:gsub("MOUSEWHEELDOWN", L_KEY["Mouse Wheel Down"])
		key = key:gsub("MOUSEWHEELUP", L_KEY["Mouse Wheel Up"])
		key = key:gsub("NUMLOCK", L_KEY["Num Lock"])
		key = key:gsub("PAGEDOWN", L_KEY["Page Down"])
		key = key:gsub("PAGEUP", L_KEY["Page Up"])
		key = key:gsub("SCROLLLOCK", L_KEY["Scroll Lock"])
		key = key:gsub("SPACEBAR", L_KEY["Spacebar"])
		key = key:gsub("TAB", L_KEY["Tab"])

		key = key:gsub("DOWNARROW", L_KEY["Down Arrow"])
		key = key:gsub("LEFTARROW", L_KEY["Left Arrow"])
		key = key:gsub("RIGHTARROW", L_KEY["Right Arrow"])
		key = key:gsub("UPARROW", L_KEY["Up Arrow"])

		return key
	end
end

-- ActionButton Template
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

-- Module API
----------------------------------------------------
-- Just a proxy for the secure method. Only call out of combat. 
Module.ArrangeButtons = function(self)
	local Proxy = self:GetSecureUpdater()
	if Proxy then
		Proxy:Execute(Proxy:GetAttribute("arrangeButtons"))
	end
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

Module.SpawnButtons = function(self)
	local db = self.db
	local proxy = self:GetSecureUpdater()

	local buttons, hover = {}, {} 
	local FORCED = false -- Private test mode to show all

	for id = 1,NUM_ACTIONBAR_BUTTONS do 
		local id2 = id + NUM_ACTIONBAR_BUTTONS
		
		-- Store all buttons
		buttons[id] = self:SpawnActionButton("action", self.frame, ActionButton, 1, id)
		buttons[id2] = self:SpawnActionButton("action", self.frame, ActionButton, _G.BOTTOMLEFT_ACTIONBAR_PAGE, id)

		-- Store the buttons that have hover options
		hover[buttons[id]] = id > 7 
		hover[buttons[id2]] = true
	
		-- Link the buttons and their pagers 
		proxy:SetFrameRef("Button"..id, buttons[id])
		proxy:SetFrameRef("Button"..id2, buttons[id2])
		proxy:SetFrameRef("Pager"..id, buttons[id]:GetPager())
		proxy:SetFrameRef("Pager"..id2, buttons[id2]:GetPager())
	end 

	for id,button in ipairs(buttons) do 
		-- Apply saved buttonLock setting
		button:SetAttribute("buttonLock", db.buttonLock)

		-- Reference all buttons in our menu callback frame
		proxy:Execute(([=[
			table.insert(Buttons, self:GetFrameRef("Button"..%.0f)); 
			table.insert(Pagers, self:GetFrameRef("Pager"..%.0f)); 
		]=]):format(id, id))

		-- Hide buttons beyond our current maximum visible
		if (hover[button] and (id > db.extraButtonsCount + 7)) then 
			button:GetPager():Hide()
		end 
	end 

	self.buttons = buttons
	self.hover = hover

	local fadeOutTime = 1/5 -- has to be fast, or layers will blend weirdly
	local hoverFrame = self:CreateFrame("Frame")
	hoverFrame.timeLeft = 0
	hoverFrame.elapsed = 0
	hoverFrame:SetScript("OnUpdate", function(self, elapsed) 
		self.elapsed = self.elapsed + elapsed
		self.timeLeft = self.timeLeft - elapsed

		if (self.timeLeft <= 0) then
			if FORCED or self.FORCED or self.always or (self.incombat and IN_COMBAT) or self.forced or self.flyout or self:IsMouseOver(0,0,0,0) then
				if (not self.isMouseOver) then 
					self.isMouseOver = true
					self.alpha = 1
					for id = 8,24 do 
						buttons[id]:GetPager():SetAlpha(self.alpha)
					end 
				end 
			else 
				if self.isMouseOver then 
					self.isMouseOver = nil
					if (not self.fadeOutTime) then 
						self.fadeOutTime = fadeOutTime
					end 
				end 
				if self.fadeOutTime then 
					self.fadeOutTime = self.fadeOutTime - self.elapsed
					if (self.fadeOutTime > 0) then 
						self.alpha = self.fadeOutTime / fadeOutTime
					else 
						self.alpha = 0
						self.fadeOutTime = nil
					end 
					for id = 8,24 do 
						buttons[id]:GetPager():SetAlpha(self.alpha)
					end 
				end 
			end 
			self.elapsed = 0
			self.timeLeft = .05
		end 
	end) 
	hoverFrame:SetScript("OnEvent", function(self, event, ...) 
		if (event == "ACTIONBAR_SHOWGRID") then 
			self.forced = true
		elseif (event == "ACTIONBAR_HIDEGRID") then
			self.forced = nil
		end 
	end)
	hoverFrame:RegisterEvent("ACTIONBAR_HIDEGRID")
	hoverFrame:RegisterEvent("ACTIONBAR_SHOWGRID")
	hoverFrame.isMouseOver = true -- Set this to initiate the first fade-out
	self.hoverFrame = hoverFrame

	hooksecurefunc("ActionButton_UpdateFlyout", function(self) 
		if hover[self] then 
			hoverFrame.flyout = self:IsFlyoutShown()
		end
	end)
end 

Module.GetButtons = function(self)
	return pairs(self.buttons)
end

Module.SetForcedVisibility = function(self, force)
	if (not self.hoverFrame) then 
		return 
	end 
	if (force) then 
		self.hoverFrame.FORCED = true
	else 
		self.hoverFrame.FORCED = nil
	end 
end

Module.GetSecureUpdater = function(self)
	return self.proxyUpdater
end

Module.UpdateFading = function(self)
	local db = self.db
	local combat = db.extraButtonsVisibility == "combat"
	local always = db.extraButtonsVisibility == "always"

	self.hoverFrame.incombat = combat
	self.hoverFrame.always = always
end 

Module.UpdateFadeAnchors = function(self)
	local db = self.db

	self.frame:ClearAllPoints()
	self.hoverFrame:ClearAllPoints() 

	-- Parse buttons for hoverbutton IDs
	local first, last, left, right, top, bottom, mLeft, mRight, mTop, mBottom
	for id,button in ipairs(self.buttons) do 
		-- If we pass number of visible hoverbuttons, just bail out
		if (id > db.extraButtonsCount + 7) then 
			break 
		end 

		local bLeft = button:GetLeft()
		local bRight = button:GetRight()
		local bTop = button:GetTop()
		local bBottom = button:GetBottom()
		
		if self.hover[button] then 
			-- Only counting the first encountered as the first
			if (not first) then 
				first = id 
			end 

			-- Counting every button as the last, until we actually reach it 
			last = id 

			-- Figure out hoverframe anchor buttons
			left = left and (self.buttons[left]:GetLeft() < bLeft) and left or id
			right = right and (self.buttons[right]:GetRight() > bRight) and right or id
			top = top and (self.buttons[top]:GetTop() > bTop) and top or id
			bottom = bottom and (self.buttons[bottom]:GetBottom() < bBottom) and bottom or id
		end 

		-- Figure out main frame anchor buttons, 
		-- as we need this for the explorer mode fade anchors!
		mLeft = mLeft and (self.buttons[mLeft]:GetLeft() < bLeft) and mLeft or id
		mRight = mRight and (self.buttons[mRight]:GetRight() > bRight) and mRight or id
		mTop = mTop and (self.buttons[mTop]:GetTop() > bTop) and mTop or id
		mBottom = mBottom and (self.buttons[mBottom]:GetBottom() < bBottom) and mBottom or id
	end 

	-- Setup main frame anchors for explorer mode! 
	self.frame:SetPoint("TOP", self.buttons[mTop], "TOP", 0, 0)
	self.frame:SetPoint("BOTTOM", self.buttons[mBottom], "BOTTOM", 0, 0)
	self.frame:SetPoint("LEFT", self.buttons[mLeft], "LEFT", 0, 0)
	self.frame:SetPoint("RIGHT", self.buttons[mRight], "RIGHT", 0, 0)

	-- If we have hoverbuttons, setup the anchors
	if (left and right and top and bottom) then 
		self.hoverFrame:SetPoint("TOP", self.buttons[top], "TOP", 0, 0)
		self.hoverFrame:SetPoint("BOTTOM", self.buttons[bottom], "BOTTOM", 0, 0)
		self.hoverFrame:SetPoint("LEFT", self.buttons[left], "LEFT", 0, 0)
		self.hoverFrame:SetPoint("RIGHT", self.buttons[right], "RIGHT", 0, 0)
	end

end

Module.UpdateButtonCount = function(self)
	-- Announce the updated button count to the world
	self:SendMessage("GP_UPDATE_ACTIONBUTTON_COUNT")
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
	if (CONSOLEPORT) then 
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
	self:UpdateCastOnDown()
	self:UpdateTooltipSettings()
end 

Module.OnEvent = function(self, event, ...)
	if (event == "UPDATE_BINDINGS") then 
		self:UpdateBindings()
	elseif (event == "PLAYER_ENTERING_WORLD") then 
		self:UpdateBindings()
	elseif (event == "PLAYER_REGEN_DISABLED") then
		IN_COMBAT = true 
	elseif (event == "PLAYER_REGEN_ENABLED") then 
		IN_COMBAT = false
	end 
end 

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

Module.OnInit = function(self)
	self.db = self:ParseSavedSettings()
	self.layout = GetLayout(self:GetName())
	self.frame = self:CreateFrame("Frame", nil, "UICenter")

	local proxy = self:CreateFrame("Frame", nil, parent, "SecureHandlerAttributeTemplate")
	proxy.UpdateCastOnDown = function(proxy) self:UpdateCastOnDown() end
	proxy.UpdateFading = function(proxy) self:UpdateFading() end
	proxy.UpdateFadeAnchors = function(proxy) self:UpdateFadeAnchors() end
	proxy.UpdateButtonCount = function(proxy) self:UpdateButtonCount() end
	for key,value in pairs(self.db) do 
		proxy:SetAttribute(key,value)
	end 
	proxy:Execute([=[ Buttons = table.new(); Pagers = table.new(); ]=])
	proxy:SetFrameRef("UICenter", self:GetFrame("UICenter"))
	proxy:SetAttribute("BOTTOMLEFT_ACTIONBAR_PAGE", _G.BOTTOMLEFT_ACTIONBAR_PAGE);
	proxy:SetAttribute("arrangeButtons", secureSnippets.arrangeButtons)
	proxy:SetAttribute("_onattributechanged", secureSnippets.attributeChanged)
	self.proxyUpdater = proxy

	-- Spawn the buttons
	self:SpawnButtons()

	-- Spawn the Exit button
	self:SpawnExitButton()

	-- Arrange buttons 
	self:ArrangeButtons()

	-- Update saved settings
	self:UpdateBindings()
	self:UpdateSettings()
end 

Module.OnEnable = function(self)
	self:RegisterEvent("UPDATE_BINDINGS", "OnEvent")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
end
