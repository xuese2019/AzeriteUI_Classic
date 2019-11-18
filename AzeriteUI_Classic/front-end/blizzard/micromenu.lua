local ADDON,Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end
local Module = Core:NewModule("BlizzardMicroMenu", "LibEvent", "LibDB", "LibTooltip", "LibFrame")

-- Lua API
local _G = _G
local ipairs = ipairs
local math_floor = math.floor
local pairs = pairs
local string_format = string.format

-- WoW API
local GetAvailableBandwidth = _G.GetAvailableBandwidth
local GetBindingKey = _G.GetBindingKey
local GetBindingText = _G.GetBindingText
local GetCVarBool = _G.GetCVarBool
local GetDownloadedPercentage = _G.GetDownloadedPercentage
local GetFramerate = _G.GetFramerate
local GetMovieDownloadProgress = _G.GetMovieDownloadProgress
local GetNetStats = _G.GetNetStats

-- Private API
local Colors = Private.Colors
local GetLayout = Private.GetLayout

local BLANK_TEXTURE = [[Interface\ChatFrame\ChatFrameBackground]]
local buttonWidth, buttonHeight, buttonSpacing, sizeMod = 300,50,10, .75

local L = Wheel("LibLocale"):GetLocale(ADDON)
local Layout = GetLayout(Module:GetName())

local getBindingKeyForAction = function(action, useNotBound, useParentheses)
	local key = GetBindingKey(action)
	if key then
		key = GetBindingText(key)
	elseif useNotBound then
		key = NOT_BOUND
	end

	if key and useParentheses then
		return ("(%s)"):format(key)
	end

	return key
end

local formatBindingKeyIntoText = function(text, action, bindingAvailableFormat, keyStringFormat, useNotBound, useParentheses)
	local bindingKey = getBindingKeyForAction(action, useNotBound, useParentheses)

	if bindingKey then
		bindingAvailableFormat = bindingAvailableFormat or "%s %s"
		keyStringFormat = keyStringFormat or "%s"
		local keyString = keyStringFormat:format(bindingKey)
		return bindingAvailableFormat:format(text, keyString)
	end

	return text
end

local getMicroButtonTooltipText = function(text, action)
	return formatBindingKeyIntoText(text, action, "%s %s", NORMAL_FONT_COLOR_CODE.."(%s)"..FONT_COLOR_CODE_CLOSE)
end

local microButtons = {
	"CharacterMicroButton",
	"SpellbookMicroButton",
	"TalentMicroButton",
	"QuestLogMicroButton",
	"SocialsMicroButton",
	"WorldMapMicroButton",
	"MainMenuMicroButton",
	"HelpMicroButton"
}

local microButtonTexts = {
	CharacterMicroButton = CHARACTER_BUTTON,
	SpellbookMicroButton = SPELLBOOK_ABILITIES_BUTTON,
	TalentMicroButton = TALENTS_BUTTON, -- check order
	QuestLogMicroButton = QUESTLOG_BUTTON,
	SocialsMicroButton = SOCIALS,
	WorldMapMicroButton = WORLD_MAP, 
	MainMenuMicroButton = MAINMENU_BUTTON, 
	HelpMicroButton = HELP_BUTTON
}

local microButtonScripts = {

	CharacterMicroButton_OnEnter = function(self)
		self.tooltipText = getMicroButtonTooltipText(CHARACTER_BUTTON, "TOGGLECHARACTER0")
		local titleColor, normalColor = Layout.MenuButtonTitleColor, Layout.MenuButtonNormalColor
		local tooltip = Module:GetOptionsMenuTooltip()
		tooltip:Hide()
		tooltip:SetDefaultAnchor(self)
		tooltip:AddLine(self.tooltipText, titleColor[1], titleColor[2], titleColor[3], true)
		tooltip:AddLine(self.newbieText or NEWBIE_TOOLTIP_CHARACTER, normalColor[1], normalColor[2], normalColor[3], true)
		tooltip:Show()
	end,
	
	SpellbookMicroButton_OnEnter = function(self)
		self.tooltipText = getMicroButtonTooltipText(SPELLBOOK_ABILITIES_BUTTON, "TOGGLESPELLBOOK")
		local titleColor, normalColor = Layout.MenuButtonTitleColor, Layout.MenuButtonNormalColor
		local tooltip = Module:GetOptionsMenuTooltip()
		tooltip:Hide()
		tooltip:SetDefaultAnchor(self)
		tooltip:AddLine(self.tooltipText, titleColor[1], titleColor[2], titleColor[3], true)
		tooltip:AddLine(self.newbieText or NEWBIE_TOOLTIP_SPELLBOOK, normalColor[1], normalColor[2], normalColor[3], true)
		tooltip:Show()
	end,
	
	MainMenuMicroButton_OnEnter = function(self)
		local titleColor, normalColor = Layout.MenuButtonTitleColor, Layout.MenuButtonNormalColor
		local tooltip = Module:GetOptionsMenuTooltip()
		tooltip:Hide()
		tooltip:SetDefaultAnchor(self)
		tooltip:AddLine(self.tooltipText, titleColor[1], titleColor[2], titleColor[3], true)
		tooltip:AddLine(self.newbieText, normalColor[1], normalColor[2], normalColor[3], true)
		tooltip:Show()
	end,

	MicroButton_OnEnter = function(self)
		if (self:IsEnabled() or self.minLevel or self.disabledTooltip or self.factionGroup) then
	
			local titleColor, normalColor = Layout.MenuButtonTitleColor, Layout.MenuButtonNormalColor
			local tooltip = Module:GetOptionsMenuTooltip()
			tooltip:Hide()
			tooltip:SetDefaultAnchor(self)

			if self.tooltipText then
				tooltip:AddLine(self.tooltipText, titleColor[1], titleColor[2], titleColor[3], true)
				tooltip:AddLine(self.newbieText, normalColor[1], normalColor[2], normalColor[3], true)
			else
				tooltip:AddLine(self.newbieText, titleColor[1], titleColor[2], titleColor[3], true)
			end
	
			if (not self:IsEnabled()) then
				if (self.factionGroup == "Neutral") then
					tooltip:AddLine(FEATURE_NOT_AVAILBLE_PANDAREN, Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3], true)
	
				elseif ( self.minLevel ) then
					tooltip:AddLine(string_format(FEATURE_BECOMES_AVAILABLE_AT_LEVEL, self.minLevel), Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3], true)
	
				elseif ( self.disabledTooltip ) then
					tooltip:AddLine(self.disabledTooltip, Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3], true)
				end
			end

			tooltip:Show()
		end
	end, 

	MicroButton_OnLeave = function(button)
		local tooltip = Module:GetOptionsMenuTooltip()
		tooltip:Hide() 
	end
}

local ConfigWindow_OnShow = function(self) 
	local tooltip = Module:GetOptionsMenuTooltip()
	local button = Module:GetToggleButton()
	if (tooltip:IsShown() and (tooltip:GetOwner() == button)) then 
		tooltip:Hide()
	end 
end

local ConfigWindow_OnHide = function(self) 
	local tooltip = Module:GetOptionsMenuTooltip()
	local button = Module:GetToggleButton()
	if (button:IsMouseOver(0,0,0,0) and ((not tooltip:IsShown()) or (tooltip:GetOwner() ~= button))) then 
		button:GetScript("OnEnter")(button)
	end 
end

-- Same tooltip as used by the options menu module. 
Module.GetOptionsMenuTooltip = function(self)
	return self:GetTooltip(ADDON.."_OptionsMenuTooltip") or self:CreateTooltip(ADDON.."_OptionsMenuTooltip")
end

-- Avoid direct usage of 'self' here since this 
-- is used as a callback from global methods too! 
Module.UpdateMicroButtons = function()
	if InCombatLockdown() then 
		Module:AddDebugMessageFormatted("Attempted to adjust MicroMenu in combat, queueing up the action for combat end.")
		return Module:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	end 

	local buttons = Module:GetConfigButtons()
	local window = Module:GetConfigWindow()

	local strata = window:GetFrameStrata()
	local level = window:GetFrameLevel()
	local numVisible = 0
	for id,microButton in ipairs(buttons) do
		if (microButton and microButton:IsShown()) then
			microButton:SetParent(window) 
			microButton:SetFrameStrata(strata)
			microButton:SetFrameLevel(level + 1)
			microButton:SetSize(buttonWidth*sizeMod, buttonHeight*sizeMod)
			microButton:ClearAllPoints()
			microButton:SetPoint("BOTTOM", window, "BOTTOM", 0, buttonSpacing + buttonHeight*sizeMod*numVisible + buttonSpacing*numVisible)
			numVisible = numVisible + 1
		end
	end	

	-- Resize window to fit the buttons
	window:SetSize(buttonWidth*sizeMod + buttonSpacing*2, buttonHeight*sizeMod*numVisible + buttonSpacing*(numVisible+1))
end

Module.UpdatePerformanceBar = function(self)
	if MainMenuBarPerformanceBar then 
		MainMenuBarPerformanceBar:SetTexture(nil)
		MainMenuBarPerformanceBar:SetVertexColor(0,0,0,0)
		MainMenuBarPerformanceBar:Hide()
	end 
end

Module.GetConfigWindow = function(self)
	if (not self.ConfigWindow) then 

		local configWindow = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
		configWindow:Hide()
		configWindow:SetFrameStrata("DIALOG")
		configWindow:SetFrameLevel(1000)
		configWindow:Place(unpack(GetLayout(ADDON).MenuPlace))
		configWindow:EnableMouse(true)
		configWindow:SetScript("OnShow", ConfigWindow_OnShow)
		configWindow:SetScript("OnHide", ConfigWindow_OnHide)

		if Layout.MenuWindow_CreateBorder then 
			Layout.MenuWindow_CreateBorder(configWindow)
		end
		
		self.ConfigWindow = configWindow
	end 
	return self.ConfigWindow
end

Module.GetToggleButton = function(self)
	return Core:GetModule("OptionsMenu"):GetToggleButton()
end

Module.GetConfigButtons = function(self)
	if (not self.ConfigButtons) then 
		self.ConfigButtons = {}
	end 
	return self.ConfigButtons
end

Module.GetAutoHideReferences = function(self)
	if (not self.AutoHideReferences) then 
		self.AutoHideReferences = {}
	end 
	return self.AutoHideReferences
end

Module.AddOptionsToMenuButton = function(self)
	if (not self.addedToMenuButton) then 
		self.addedToMenuButton = true

		local ToggleButton = self:GetToggleButton()
		ToggleButton:SetFrameRef("MicroMenu", self:GetConfigWindow())
		ToggleButton:SetAttribute("middleclick", [[
			local window = self:GetFrameRef("MicroMenu");
			if window:IsShown() then
				window:Hide();
			else
				local window2 = self:GetFrameRef("OptionsMenu"); 
				if (window2 and window2:IsShown()) then 
					window2:Hide(); 
				end 
				window:Show();
				window:RegisterAutoHide(.75);
				window:AddToAutoHide(self);
				local autohideCounter = 1
				local autohideFrame = window:GetFrameRef("autohide"..autohideCounter);
				while autohideFrame do 
					window:AddToAutoHide(autohideFrame);
					autohideCounter = autohideCounter + 1;
					autohideFrame = window:GetFrameRef("autohide"..autohideCounter);
				end 
			end
		]])
		for reference,frame in pairs(self:GetAutoHideReferences()) do 
			self:GetConfigWindow():SetFrameRef(reference,frame)
		end 
		ToggleButton.middleButtonTooltip = "|TInterface\\TutorialFrame\\UI-TUTORIAL-FRAME:20:15:0:0:512:512:1:76:118:218|t " .. L["Game Panels"]
	end 
end 

Module.AddOptionsToMenuWindow = function(self)
	if (not self.addedToMenuWindow) then 
		self.addedToMenuWindow = true

		-- Frame to hide items with
		local UIHider = CreateFrame("Frame")
		UIHider:Hide()

		local buttons = self:GetConfigButtons()
		local window = self:GetConfigWindow()
		local hiders = self:GetAutoHideReferences()

		for id,buttonName in ipairs(microButtons) do 

			local microButton = _G[buttonName]
			if microButton then 

				buttons[#buttons + 1] = microButton

				local normal = microButton:GetNormalTexture()
				if normal then
					microButton:SetNormalTexture("")
					normal:SetAlpha(0)
					normal:SetSize(.0001, .0001)
				end
			
				local pushed = microButton:GetPushedTexture()
				if pushed then
					microButton:SetPushedTexture("")
					pushed:SetTexture(nil)
					pushed:SetAlpha(0)
					pushed:SetSize(.0001, .0001)
				end
			
				local highlight = microButton:GetNormalTexture()
				if highlight then
					microButton:SetHighlightTexture("")
					highlight:SetAlpha(0)
					highlight:SetSize(.0001, .0001)
				end
				
				local disabled = microButton:GetDisabledTexture()
				if disabled then
					microButton:SetNormalTexture("")
					disabled:SetAlpha(0)
					disabled:SetSize(.0001, .0001)
				end
				
				local flash = _G[buttonName.."Flash"]
				if flash then
					flash:SetTexture(nil)
					flash:SetAlpha(0)
					flash:SetSize(.0001, .0001)
				end
		
				microButton:SetScript("OnUpdate", nil)
				microButton:SetScript("OnEnter", microButtonScripts[buttonName.."_OnEnter"] or microButtonScripts.MicroButton_OnEnter)
				microButton:SetScript("OnLeave", microButtonScripts.MicroButton_OnLeave)
				microButton:SetSize(Layout.MenuButtonSize[1]*Layout.MenuButtonSizeMod, Layout.MenuButtonSize[2]*Layout.MenuButtonSizeMod) 
				microButton:SetHitRectInsets(0, 0, 0, 0)

				if Layout.MenuButton_PostCreate then 
					Layout.MenuButton_PostCreate(microButton, microButtonTexts[buttonName])
				end

				if Layout.MenuButton_PostUpdate then 
					local PostUpdate = Layout.MenuButton_PostUpdate
					microButton:HookScript("OnEnter", PostUpdate)
					microButton:HookScript("OnLeave", PostUpdate)
					microButton:HookScript("OnMouseDown", function(self) self.isDown = true; return PostUpdate(self) end)
					microButton:HookScript("OnMouseUp", function(self) self.isDown = false; return PostUpdate(self) end)
					microButton:HookScript("OnShow", function(self) self.isDown = false; return PostUpdate(self) end)
					microButton:HookScript("OnHide", function(self) self.isDown = false; return PostUpdate(self) end)
					PostUpdate(microButton)
				else
					microButton:HookScript("OnMouseDown", function(self) self.isDown = true end)
					microButton:HookScript("OnMouseUp", function(self) self.isDown = false end)
					microButton:HookScript("OnShow", function(self) self.isDown = false end)
					microButton:HookScript("OnHide", function(self) self.isDown = false end)
				end 

				-- Add a frame the secure autohider can track,
				-- and anchor it to the micro button
				local autohideParent = CreateFrame("Frame", nil, window, "SecureHandlerAttributeTemplate")
				autohideParent:SetPoint("TOPLEFT", microButton, "TOPLEFT", -6, 6)
				autohideParent:SetPoint("BOTTOMRIGHT", microButton, "BOTTOMRIGHT", 6, -6)

				-- Add the frame to the list of secure autohiders
				hiders["autohide"..id] = autohideParent
			end 

		end 

		for id,object in ipairs({ 
				MicroButtonPortrait, 
				GuildMicroButtonTabard, 
				PVPMicroButtonTexture, 
				MainMenuBarPerformanceBar, 
				MainMenuBarDownload }) 
			do
			if object then 
				if (object.SetTexture) then 
					object:SetTexture(nil)
					object:SetVertexColor(0,0,0,0)
				end 
				object:SetParent(UIHider)
			end  
		end 
		for id,method in ipairs({ 
				"MoveMicroButtons", 
				"UpdateMicroButtons", 
				"UpdateMicroButtonsParent" }) 
			do 
			if _G[method] then 
				hooksecurefunc(method, Module.UpdateMicroButtons)
			end 
		end 

		self:UpdateMicroButtons()
	end 
end

Module.OnEvent = function(self, event, ...)
	if (event == "PLAYER_REGEN_ENABLED") then 
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		self:UpdateMicroButtons()
	end 
end

Module.HandleBartenderMicroBar = function(self)
	self:AddDebugMessageFormatted("[Bartender4 - MicroMenu] bar loaded, handling incompatible elements.")
	local MicroMenuMod = Bartender4:GetModule("MicroMenu")
	if MicroMenuMod.bar then 
		MicroMenuMod.bar.UpdateButtonLayout = function() end
		self:AddDebugMessageFormatted("[Bartender4 - MicroMenu] handling, updating MicroButtons.")
		self:UpdateMicroButtons()
	end
end

Module.HandleBartender = function(self)
	self:AddDebugMessageFormatted("[Bartender4] loaded, handling incompatible elements.")
	local Bartender4 = Bartender4
	local MicroMenuMod = Bartender4:GetModule("MicroMenu", true)
	if MicroMenuMod then 
		self:AddDebugMessageFormatted("[MicroMenu] module detected.")
		MicroMenuMod.MicroMenuBarShow = function() end
		MicroMenuMod.BlizzardBarShow = function() end
		MicroMenuMod.UpdateButtonLayout = function() end
		if MicroMenuMod.bar then 
			self:AddDebugMessageFormatted("[Bartender4 - MicroMenu] bar detected.")
			self:HandleBartenderMicroBar()
		else
			self:AddDebugMessageFormatted("[Bartender4 - MicroMenu] bar not yet created, adding handle action to queue.")
			hooksecurefunc(MicroMenuMod, "OnEnable", function() 
				self:HandleBartenderMicroBar()
			end)
		end 
	end

end

Module.ListenForBartender = function(self, event, addon)
	if (addon == "Bartender4") then 
		self:HandleBartender()
		self:UnregisterEvent("ADDON_LOADED", "ListenForBartender")
	end
end

Module.OnInit = function(self)
	if self:IsAddOnEnabled("Bartender4") then 
		self:AddDebugMessageFormatted("[Bartender4] detected.")
		if IsAddOnLoaded("Bartender4") then 
			self:HandleBartender()
		else 
			self:AddDebugMessageFormatted("[Bartender4] not yet loaded, adding handle action to queue.")
			self:RegisterEvent("ADDON_LOADED", "ListenForBartender")
		end 
	end
	self:AddOptionsToMenuWindow()
end 

Module.OnEnable = function(self)
	self:AddOptionsToMenuButton()
	self:UpdatePerformanceBar()
end 
