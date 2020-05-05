local LibSecureButton = Wheel:Set("LibSecureButton", 88)
if (not LibSecureButton) then
	return
end

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibSecureButton requires LibEvent to be loaded.")

local LibMessage = Wheel("LibMessage")
assert(LibMessage, "LibSecureButton requires LibMessage to be loaded.")

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibSecureButton requires LibClientBuild to be loaded.")

local LibFrame = Wheel("LibFrame")
assert(LibFrame, "LibSecureButton requires LibFrame to be loaded.")

local LibSound = Wheel("LibSound")
assert(LibSound, "LibSecureButton requires LibSound to be loaded.")

local LibTooltip = Wheel("LibTooltip")
assert(LibTooltip, "LibSecureButton requires LibTooltip to be loaded.")

local LibSpellData = Wheel("LibSpellData", true)
if (LibClientBuild:IsClassic()) then
	assert(LibSpellData, "LibSecureButton requires LibSpellData to be loaded.")
end

local LibSpellHighlight = Wheel("LibSpellHighlight")
assert(LibSpellHighlight, "LibSecureButton requires LibSpellHighlight to be loaded.")

-- Embed functionality into this
LibEvent:Embed(LibSecureButton)
LibMessage:Embed(LibSecureButton)
LibFrame:Embed(LibSecureButton)
LibSound:Embed(LibSecureButton)
LibTooltip:Embed(LibSecureButton)
LibSpellHighlight:Embed(LibSecureButton)

if (LibClientBuild:IsClassic()) then
	LibSpellData:Embed(LibSecureButton)
end

-- Lua API
local _G = _G
local assert = assert
local debugstack = debugstack
local error = error
local ipairs = ipairs
local pairs = pairs
local select = select
local setmetatable = setmetatable
local string_format = string.format
local string_join = string.join
local string_match = string.match
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local tonumber = tonumber
local tostring = tostring
local type = type

-- WoW API
local CursorHasItem = CursorHasItem
local CursorHasSpell = CursorHasSpell
local FlyoutHasSpell = FlyoutHasSpell
local GetActionCharges = GetActionCharges
local GetActionCooldown = GetActionCooldown
local GetActionInfo = GetActionInfo
local GetActionLossOfControlCooldown = GetActionLossOfControlCooldown
local GetActionCount = GetActionCount
local GetActionTexture = GetActionTexture
local GetBindingKey = GetBindingKey 
local GetCursorInfo = GetCursorInfo
local GetMacroSpell = GetMacroSpell
local GetOverrideBarIndex = GetOverrideBarIndex
local GetPetActionInfo = GetPetActionInfo
local GetSpellInfo = GetSpellInfo
local GetSpellSubtext = GetSpellSubtext
local GetTempShapeshiftBarIndex = GetTempShapeshiftBarIndex
local GetTime = GetTime
local GetVehicleBarIndex = GetVehicleBarIndex
local HasAction = HasAction
local IsActionInRange = IsActionInRange
local IsAutoCastPetAction = C_ActionBar.IsAutoCastPetAction
local IsConsumableAction = IsConsumableAction
local IsEnabledAutoCastPetAction = C_ActionBar.IsEnabledAutoCastPetAction
local IsStackableAction = IsStackableAction
local IsUsableAction = IsUsableAction
local SetClampedTextureRotation = SetClampedTextureRotation
local UnitClass = UnitClass

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

-- Doing it this way to make the transition to library later on easier
LibSecureButton.embeds = LibSecureButton.embeds or {} 
LibSecureButton.buttons = LibSecureButton.buttons or {} 
LibSecureButton.allbuttons = LibSecureButton.allbuttons or {} 
LibSecureButton.callbacks = LibSecureButton.callbacks or {} 
LibSecureButton.numButtons = LibSecureButton.numButtons or 0 -- total number of spawned buttons 

-- Frame to securely hide items
if (not LibSecureButton.frame) then
	local frame = CreateFrame("Frame", nil, UIParent, "SecureHandlerAttributeTemplate")
	frame:Hide()
	frame:SetPoint("TOPLEFT", 0, 0)
	frame:SetPoint("BOTTOMRIGHT", 0, 0)
	frame.children = {}
	RegisterAttributeDriver(frame, "state-visibility", "hide")

	-- Attach it to our library
	LibSecureButton.frame = frame
end

-- Shortcuts
local AllButtons = LibSecureButton.allbuttons
local Buttons = LibSecureButton.buttons
local Callbacks = LibSecureButton.callbacks
local UIHider = LibSecureButton.frame

-- Blizzard Textures
local EDGE_LOC_TEXTURE = [[Interface\Cooldown\edge-LoC]]
local EDGE_NORMAL_TEXTURE = [[Interface\Cooldown\edge]]
local BLING_TEXTURE = [[Interface\Cooldown\star4]]

-- Generic format strings for our button names
local BUTTON_NAME_TEMPLATE_SIMPLE = "%sActionButton"
local BUTTON_NAME_TEMPLATE_FULL = "%sActionButton%.0f"
local PETBUTTON_NAME_TEMPLATE_SIMPLE = "%sPetActionButton"
local PETBUTTON_NAME_TEMPLATE_FULL = "%sPetActionButton%.0f"

-- Constants
local NUM_ACTIONBAR_BUTTONS = NUM_ACTIONBAR_BUTTONS
local NUM_PET_ACTION_SLOTS = NUM_PET_ACTION_SLOTS
local NUM_STANCE_SLOTS = NUM_STANCE_SLOTS

-- Time constants
local DAY, HOUR, MINUTE = 86400, 3600, 60

local SECURE = {
	Page_OnAttributeChanged = string_format([=[ 
		if (name == "state-page") then 
			local page; 

			if (value == "11") then 
				page = 12; 
			end

			local driverResult; 
			if page then 
				driverResult = value;
				value = page; 
			end 

			self:SetAttribute("state", value);

			local button = self:GetFrameRef("Button"); 
			local buttonPage = button:GetAttribute("actionpage"); 
			local id = button:GetID(); 
			local actionpage = tonumber(value); 
			local slot = actionpage and (actionpage > 1) and ((actionpage - 1)*%d + id) or id; 

			button:SetAttribute("actionpage", actionpage or 0); 
			button:SetAttribute("action", slot); 
			button:CallMethod("UpdateAction"); 

			-- Debugging the weird results
			-- *only showing bar 1, button 1
			if self:GetID() == 1 and id == 1 then
				if driverResult then 
					local page = tonumber(driverResult); 
					if page then 
						self:CallMethod("AddDebugMessage", "ActionButton driver attempted to change page to: " ..driverResult.. " - Page changed by environment to: " .. value); 
					else 
						self:CallMethod("AddDebugMessage", "ActionButton driver reported the state: " ..driverResult.. " - Page changed by environment to: " .. value); 
					end
				elseif value then 
					self:CallMethod("AddDebugMessage", "ActionButton driver changed page to: " ..value); 
				end
			end
		end 
	]=])

}

-- Utility Functions
----------------------------------------------------
-- Syntax check 
local check = function(value, num, ...)
	assert(type(num) == "number", ("Bad argument #%.0f to '%s': %s expected, got %s"):format(2, "Check", "number", type(num)))
	for i = 1,select("#", ...) do
		if type(value) == select(i, ...) then 
			return 
		end
	end
	local types = string_join(", ", ...)
	local name = string_match(debugstack(2, 2, 0), ": in function [`<](.-)['>]")
	error(("Bad argument #%.0f to '%s': %s expected, got %s"):format(num, name, types, type(value)), 3)
end

local nameHelper = function(self, id, buttonType)
	local name
	if id then
		if (buttonType == "pet") then 
			name = string_format(PETBUTTON_NAME_TEMPLATE_FULL, self:GetOwner():GetName(), id)
		else 
			name = string_format(BUTTON_NAME_TEMPLATE_FULL, self:GetOwner():GetName(), id)
		end
	else 
		if (buttonType == "pet") then 
			name = string_format(PETBUTTON_NAME_TEMPLATE_SIMPLE, self:GetOwner():GetName())
		else
			name = string_format(BUTTON_NAME_TEMPLATE_SIMPLE, self:GetOwner():GetName())
		end
	end 
	return name
end

local sortByID = function(a,b)
	if (a) and (b) then 
		if (a.id) and (b.id) then 
			return (a.id < b.id)
		else
			return a.id and true or false 
		end 
	else 
		return a and true or false
	end 
end 

-- Aimed to be compact and displayed on buttons
local formatCooldownTime = function(time)
	if time > DAY then -- more than a day
		time = time + DAY/2
		return "%.0f%s", time/DAY - time/DAY%1, "d"
	elseif time > HOUR then -- more than an hour
		time = time + HOUR/2
		return "%.0f%s", time/HOUR - time/HOUR%1, "h"
	elseif time > MINUTE then -- more than a minute
		time = time + MINUTE/2
		return "%.0f%s", time/MINUTE - time/MINUTE%1, "m"
	elseif time > 10 then -- more than 10 seconds
		return "%.0f", time - time%1
	elseif time >= 1 then -- more than 5 seconds
		return "|cffff8800%.0f|r", time - time%1
	elseif time > 0 then
		return "|cffff0000%.0f|r", time*10 - time*10%1
	else
		return ""
	end	
end

-- Updates
----------------------------------------------------
local OnUpdate = function(self, elapsed)

	self.flashTime = (self.flashTime or 0) - elapsed
	self.rangeTimer = (self.rangeTimer or -1) - elapsed
	self.cooldownTimer = (self.cooldownTimer or 0) - elapsed

	-- Cooldown count
	if (self.cooldownTimer <= 0) then 
		local Cooldown = self.Cooldown 
		local CooldownCount = self.CooldownCount
		if Cooldown.active then 

			local start, duration
			if (Cooldown.currentCooldownType == COOLDOWN_TYPE_NORMAL) then 
				local action = self.buttonAction
				start, duration = GetActionCooldown(action)

			elseif (Cooldown.currentCooldownType == COOLDOWN_TYPE_LOSS_OF_CONTROL) then
				local action = self.buttonAction
				start, duration = GetActionLossOfControlCooldown(action)

			end 

			if CooldownCount then 
				if ((start > 0) and (duration > 1.5)) then
					CooldownCount:SetFormattedText(formatCooldownTime(duration - GetTime() + start))
					if (not CooldownCount:IsShown()) then 
						CooldownCount:Show()
					end
				else 
					if (CooldownCount:IsShown()) then 
						CooldownCount:SetText("")
						CooldownCount:Hide()
					end
				end  
			end 
		else
			if (CooldownCount and CooldownCount:IsShown()) then 
				CooldownCount:SetText("")
				CooldownCount:Hide()
			end
		end 

		self.cooldownTimer = .1
	end 

	-- Range
	if (self.rangeTimer <= 0) then
		local inRange = self:IsInRange()
		local oldRange = self.outOfRange
		self.outOfRange = (inRange == false)
		if oldRange ~= self.outOfRange then
			self:UpdateUsable()
		end
		self.rangeTimer = TOOLTIP_UPDATE_TIME
	end 

	-- Flashing
	if (self.flashTime <= 0) then
		if (self.flashing == 1) then
			if self.Flash:IsShown() then
				self.Flash:Hide()
			else
				self.Flash:Show()
			end
		end
		self.flashTime = self.flashTime + ATTACK_BUTTON_FLASH_TIME
	end 

end 

local UpdateActionButton = function(self, event, ...)
	local arg1, arg2 = ...

	if (event == "PLAYER_ENTERING_WORLD") then 
		self:Update()
		self:UpdateAutoCastMacro()

	elseif (event == "PLAYER_REGEN_ENABLED") then 
		if self.queuedForMacroUpdate then 
			self:UpdateAutoCastMacro()
			self:UnregisterEvent("PLAYER_REGEN_ENABLED", UpdateActionButton)
			self.queuedForMacroUpdate = nil
		end 

	elseif (event == "UPDATE_SHAPESHIFT_FORM") or (event == "UPDATE_VEHICLE_ACTIONBAR") then
		self:Update()

	elseif (event == "PLAYER_ENTER_COMBAT") or (event == "PLAYER_LEAVE_COMBAT") then
		self:UpdateFlash()

	elseif (event == "ACTIONBAR_SLOT_CHANGED") then
		if ((arg1 == 0) or (arg1 == self.buttonAction)) then
			self:HideOverlayGlow()
			self:Update()
			self:UpdateAutoCastMacro()
		end

	elseif (event == "ACTIONBAR_UPDATE_COOLDOWN") then
		self:UpdateCooldown()
	
	elseif (event == "ACTIONBAR_UPDATE_USABLE") then
		self:UpdateUsable()

	elseif (event == "ACTIONBAR_UPDATE_STATE") or
		   ((event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and (arg1 == "player")) or
		   ((event == "COMPANION_UPDATE") and (arg1 == "MOUNT")) then

		self:UpdateFlash()
		--self:UpdateCheckedState()

	elseif (event == "CURSOR_UPDATE") 
		or (event == "ACTIONBAR_SHOWGRID") or (event == "ACTIONBAR_HIDEGRID") then 
			self:UpdateGrid()

	elseif (event == "LOSS_OF_CONTROL_ADDED") then
		self:UpdateCooldown()

	elseif (event == "LOSS_OF_CONTROL_UPDATE") then
		self:UpdateCooldown()

	elseif (event == "PLAYER_MOUNT_DISPLAY_CHANGED") then 
		self:UpdateUsable()

	elseif (event == "GP_SPELL_ACTIVATION_OVERLAY_GLOW_SHOW") then
		local spellID = self:GetSpellID()
		if (spellID and (spellID == arg1)) then
			local overlayType = LibSecureButton:GetSpellOverlayType(spellID)
			if (overlayType) then
				self:ShowOverlayGlow(overlayType)
			end
		else
			local actionType, id = GetActionInfo(self.buttonAction)
			if (actionType == "flyout") and FlyoutHasSpell(id, arg1) then
				local overlayType = LibSecureButton:GetSpellOverlayType(spellID)
				if (overlayType) then
					self:ShowOverlayGlow(overlayType)
				end
			end
		end

	elseif (event == "GP_SPELL_ACTIVATION_OVERLAY_GLOW_HIDE") then
		local spellID = self:GetSpellID()
		if (spellID and (spellID == arg1)) then
			self:HideOverlayGlow()
		else
			local actionType, id = GetActionInfo(self.buttonAction)
			if (actionType == "flyout") and (FlyoutHasSpell(id, arg1)) then
				self:HideOverlayGlow()
			end
		end

	elseif (event == "SPELL_UPDATE_CHARGES") then
		self:UpdateCount()

	elseif (event == "SPELLS_CHANGED") or (event == "UPDATE_MACROS") then 
		-- Needed for macros. 
		self:Update() 
	elseif (event == "SPELL_UPDATE_ICON") then
		self:Update() -- really? how often is this called?

	elseif (event == "TRADE_SKILL_SHOW") or (event == "TRADE_SKILL_CLOSE") or (event == "ARCHAEOLOGY_CLOSED") then
		self:UpdateFlash()
		--self:UpdateCheckedState()

	elseif (event == "UPDATE_BINDINGS") then
		self:UpdateBinding()

	elseif (event == "UPDATE_SUMMONPETS_ACTION") then 
		local actionType, id = GetActionInfo(self.buttonAction)
		if (actionType == "summonpet") then
			local texture = GetActionTexture(self.buttonAction)
			if (texture) then
				self.Icon:SetTexture(texture)
			end
		end

	end
end

local UpdatePetButton = function(self, event, ...)
	local arg1 = ...
	
	if (event == "PLAYER_ENTERING_WORLD") then
		self:Update()
	elseif (event == "PET_BAR_UPDATE") then
		self:Update()
	elseif (event == "UNIT_PET" and arg1 == "player") then
		self:Update()
	elseif (((event == "UNIT_FLAGS") or (event == "UNIT_AURA")) and (arg1 == "pet")) then
		self:Update()
	elseif (event == "PLAYER_CONTROL_LOST") or (event == "PLAYER_CONTROL_GAINED") then
		self:Update()
	elseif (event == "PLAYER_FARSIGHT_FOCUS_CHANGED") then
		self:Update()
	elseif (event == "PET_BAR_UPDATE_COOLDOWN") then
		self:UpdateCooldown()
	elseif (event == "PET_BAR_SHOWGRID") then
		--self:ShowGrid()
	elseif (event == "PET_BAR_HIDEGRID") then
		--self:HideGrid()
	elseif (event == "UPDATE_BINDINGS") then
		self:UpdateBinding()
	end
end

local UpdateStanceButton = function(self, event, ...)
	local arg1 = ...

	if (event == "PLAYER_ENTERING_WORLD") then
		self:Update()

	elseif (event == "PLAYER_REGEN_ENABLED") then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", UpdateStanceButton)
		self:UpdateMaxButtons()

	elseif (event == "UPDATE_SHAPESHIFT_FORMS") then
		if (InCombatLockdown()) then 
			self:RegisterEvent("PLAYER_REGEN_ENABLED", UpdateStanceButton)
		else
			self:UpdateMaxButtons()
		end

	elseif (event == "UPDATE_SHAPESHIFT_COOLDOWN") then
		self:UpdateCooldown()

	elseif (event == "UPDATE_SHAPESHIFT_USABLE") then
		self:UpdateUsable()

	elseif (event == "UPDATE_SHAPESHIFT_FORM") then
	elseif (event == "ACTIONBAR_PAGE_CHANGED") then
	end
end

local UpdateTooltip = function(self)
	local tooltip = self:GetTooltip()
	tooltip:Hide()
	tooltip:SetDefaultAnchor(self)
	tooltip:SetMinimumWidth(280)
	tooltip:SetAction(self.buttonAction)
end 

local UpdatePetTooltip = function(self)
	local tooltip = self:GetTooltip()
	tooltip:Hide()
	tooltip:SetDefaultAnchor(self)
	tooltip:SetMinimumWidth(20)
	tooltip:SetPetAction(self.id)
end 

local OnCooldownDone = function(cooldown)
	cooldown.active = nil
	cooldown:SetScript("OnCooldownDone", nil)
	cooldown:GetParent():UpdateCooldown()
end

local SetCooldown = function(cooldown, start, duration, enable, forceShowDrawEdge, modRate)
	if (enable and (enable ~= 0) and (start > 0) and (duration > 0)) then
		cooldown:SetDrawEdge(forceShowDrawEdge)
		cooldown:SetCooldown(start, duration, modRate)
		cooldown.active = true
	else
		cooldown.active = nil
		cooldown:Clear()
	end
end

-- ActionButton Template
----------------------------------------------------
local ActionButton = LibSecureButton:CreateFrame("CheckButton")
local ActionButton_MT = { __index = ActionButton }

-- Grab some original methods for our own event handlers
local IsEventRegistered = ActionButton_MT.__index.IsEventRegistered
local RegisterEvent = ActionButton_MT.__index.RegisterEvent
local RegisterUnitEvent = ActionButton_MT.__index.RegisterUnitEvent
local UnregisterEvent = ActionButton_MT.__index.UnregisterEvent
local UnregisterAllEvents = ActionButton_MT.__index.UnregisterAllEvents

-- ActionButton Event Handling
----------------------------------------------------
ActionButton.RegisterEvent = function(self, event, func)
	if (not Callbacks[self]) then
		Callbacks[self] = {}
	end
	if (not Callbacks[self][event]) then
		Callbacks[self][event] = {}
	end

	local events = Callbacks[self][event]
	if (#events > 0) then
		for i = #events, 1, -1 do
			if (events[i] == func) then
				return
			end
		end
	end

	table_insert(events, func)

	if (not IsEventRegistered(self, event)) then
		RegisterEvent(self, event)
	end
end

ActionButton.UnregisterEvent = function(self, event, func)
	if not Callbacks[self] or not Callbacks[self][event] then
		return
	end
	local events = Callbacks[self][event]
	if #events > 0 then
		for i = #events, 1, -1 do
			if events[i] == func then
				table_remove(events, i)
				if #events == 0 then
					UnregisterEvent(self, event) 
				end
			end
		end
	end
end

ActionButton.UnregisterAllEvents = function(self)
	if not Callbacks[self] then 
		return
	end
	for event, funcs in pairs(Callbacks[self]) do
		for i = #funcs, 1, -1 do
			table_remove(funcs, i)
		end
	end
	UnregisterAllEvents(self)
end

ActionButton.RegisterMessage = function(self, event, func)
	if (not Callbacks[self]) then
		Callbacks[self] = {}
	end
	if (not Callbacks[self][event]) then
		Callbacks[self][event] = {}
	end

	local events = Callbacks[self][event]
	if (#events > 0) then
		for i = #events, 1, -1 do
			if (events[i] == func) then
				return
			end
		end
	end

	table_insert(events, func)

	if (not LibSecureButton.IsMessageRegistered(self, event, func)) then
		LibSecureButton.RegisterMessage(self, event, func)
	end
end

-- ActionButton Updates
----------------------------------------------------
ActionButton.Update = function(self)
	if HasAction(self.buttonAction) then 
		self.hasAction = true
		self.Icon:SetTexture(GetActionTexture(self.buttonAction))
		self:SetAlpha(1)
	else
		self.hasAction = false
		self.Icon:SetTexture(nil) 
	end 

	self:UpdateBinding()
	self:UpdateCount()
	self:UpdateCooldown()
	self:UpdateFlash()
	self:UpdateUsable()
	self:UpdateGrid()
	self:UpdateAutoCast()
	self:UpdateFlyout()
	self:UpdateSpellHighlight()

	if self.PostUpdate then 
		self:PostUpdate()
	end 
end

-- Called when the button action (and thus the texture) has changed
ActionButton.UpdateAction = function(self)
	self.buttonAction = self:GetAction()
	local texture = GetActionTexture(self.buttonAction)
	if texture then 
		self.Icon:SetTexture(texture)
	else
		self.Icon:SetTexture(nil) 
	end 
	self:Update()
end 

ActionButton.UpdateAutoCast = function(self)
	if (HasAction(self.buttonAction) and IsAutoCastPetAction(self.buttonAction)) then 
		if IsEnabledAutoCastPetAction(self.buttonAction) then 
			if (not self.SpellAutoCast.Ants.Anim:IsPlaying()) then
				self.SpellAutoCast.Ants.Anim:Play()
				self.SpellAutoCast.Glow.Anim:Play()
			end
			self.SpellAutoCast:SetAlpha(1)
		else 
			if (self.SpellAutoCast.Ants.Anim:IsPlaying()) then
				self.SpellAutoCast.Ants.Anim:Pause()
				self.SpellAutoCast.Glow.Anim:Pause()
			end
			self.SpellAutoCast:SetAlpha(.5)
		end 
		self.SpellAutoCast:Show()
	else 
		self.SpellAutoCast:Hide()
	end 
end

ActionButton.UpdateAutoCastMacro = function(self)
	if InCombatLockdown() then 
		self.queuedForMacroUpdate = true
		self:RegisterEvent("PLAYER_REGEN_ENABLED", UpdateActionButton)
		return 
	end
	local name = IsAutoCastPetAction(self.buttonAction) and GetSpellInfo(self:GetSpellID())
	if name then 
		self:SetAttribute("macrotext", "/petautocasttoggle "..name)
	else 
		self:SetAttribute("macrotext", nil)
	end 
end

-- Called when the keybinds are loaded or changed
ActionButton.UpdateBinding = function(self) 
	local Keybind = self.Keybind
	if Keybind then 
		Keybind:SetText(self.bindingAction and GetBindingKey(self.bindingAction) or GetBindingKey("CLICK "..self:GetName()..":LeftButton"))
	end 
end 

ActionButton.UpdateCheckedState = function(self)
	-- Suppress the checked state if the button is currently flashing
	local action = self.buttonAction
	if self.Flash then 
		if IsCurrentAction(action) and not((IsAttackAction(action) and IsCurrentAction(action)) or IsAutoRepeatAction(action)) then
			self:SetChecked(true)
		else
			self:SetChecked(false)
		end
	else 
		if (IsCurrentAction(action) or IsAutoRepeatAction(action)) then
			self:SetChecked(true)
		else
			self:SetChecked(false)
		end
	end 
end

ActionButton.UpdateCooldown = function(self)
	local Cooldown = self.Cooldown
	if Cooldown then
		local locStart, locDuration = GetActionLossOfControlCooldown(self.buttonAction)
		local start, duration, enable, modRate = GetActionCooldown(self.buttonAction)
		local charges, maxCharges, chargeStart, chargeDuration, chargeModRate = GetActionCharges(self.buttonAction)
		local hasChargeCooldown

		if ((locStart + locDuration) > (start + duration)) then

			if Cooldown.currentCooldownType ~= COOLDOWN_TYPE_LOSS_OF_CONTROL then
				Cooldown:SetEdgeTexture(EDGE_LOC_TEXTURE)
				Cooldown:SetSwipeColor(0.17, 0, 0)
				Cooldown:SetHideCountdownNumbers(true)
				Cooldown.currentCooldownType = COOLDOWN_TYPE_LOSS_OF_CONTROL
			end
			SetCooldown(Cooldown, locStart, locDuration, true, true, modRate)

		else

			if (Cooldown.currentCooldownType ~= COOLDOWN_TYPE_NORMAL) then
				Cooldown:SetEdgeTexture(EDGE_NORMAL_TEXTURE)
				Cooldown:SetSwipeColor(0, 0, 0)
				Cooldown:SetHideCountdownNumbers(true)
				Cooldown.currentCooldownType = COOLDOWN_TYPE_NORMAL
			end

			if (locStart > 0) then
				Cooldown:SetScript("OnCooldownDone", OnCooldownDone)
			end

			local ChargeCooldown = self.ChargeCooldown
			if ChargeCooldown then 
				if (charges and maxCharges and (charges > 0) and (charges < maxCharges)) and not((not chargeStart) or (chargeStart == 0)) then

					-- Set the spellcharge cooldown
					--cooldown:SetDrawBling(cooldown:GetEffectiveAlpha() > 0.5)
					SetCooldown(ChargeCooldown, chargeStart, chargeDuration, true, true, chargeModRate)
					hasChargeCooldown = true 
				else
					ChargeCooldown.active = nil
					ChargeCooldown:Hide()
				end
			end 

			if (hasChargeCooldown) then 
				SetCooldown(ChargeCooldown, 0, 0, false)
			else 
				SetCooldown(Cooldown, start, duration, enable, false, modRate)
			end 
		end

		if hasChargeCooldown then 
			if self.PostUpdateChargeCooldown then 
				return self:PostUpdateChargeCooldown(self.ChargeCooldown)
			end 
		else 
			if self.PostUpdateCooldown then 
				return self:PostUpdateCooldown(self.Cooldown)
			end 
		end 
	end 
end

ActionButton.UpdateCount = function(self) 
	local Count = self.Count
	if Count then 
		local count
		local action = self.buttonAction
		local actionType, actionID = GetActionInfo(action)
		if (actionType == "spell") or (actionType == "macro") then
			if (actionType == "macro") then
				actionID = GetMacroSpell(actionID)
				if (not actionID) then
					-- Only show this count on actions that
					-- have more than a single charge,
					-- or we'll have shapeshifts, trinkets
					-- and all sorts of stuff showing "1".
					local numActions = GetActionCount(action)
					if (numActions > 1) then
						count = numActions
					end
				end
			end
			if (IsClassic) then
				local reagentID = LibSecureButton:GetReagentBySpellID(actionID)
				if reagentID then
					count = GetItemCount(reagentID)
				end
			end
		else
			if (IsItemAction(action) and (IsConsumableAction(action) or IsStackableAction(action))) then
				count = GetActionCount(action)
			else
				local charges, maxCharges, chargeStart, chargeDuration, chargeModRate = GetActionCharges(action)
				if (charges and maxCharges and (maxCharges > 1) and (charges > 0)) then
					count = charges
				end
			end
		end
		if count and (count > (self.maxDisplayCount or 9999)) then
			count = "*"
		end
		Count:SetText(count or "")
		if self.PostUpdateCount then 
			return self:PostUpdateCount(count)
		end 
	end 
end 

-- Updates the red flashing on attack skills 
ActionButton.UpdateFlash = function(self)
	local Flash = self.Flash
	if Flash then 
		local action = self.buttonAction
		if HasAction(action) then 
			if (IsAttackAction(action) and IsCurrentAction(action)) or IsAutoRepeatAction(action) then
				self.flashing = 1
				self.flashTime = 0
			else
				self.flashing = 0
				self.Flash:Hide()
			end
		end 
	end 
	self:UpdateCheckedState()
end 

ActionButton.UpdateFlyout = function(self)

	if self.FlyoutBorder then 
		self.FlyoutBorder:Hide()
	end 

	if self.FlyoutBorderShadow then 
		self.FlyoutBorderShadow:Hide()
	end 

	if self.FlyoutArrow then 

		local buttonAction = self:GetAction()
		if HasAction(buttonAction) then

			local actionType = GetActionInfo(buttonAction)
			if (actionType == "flyout") then

				self.FlyoutArrow:Show()
				self.FlyoutArrow:ClearAllPoints()

				local direction = self:GetAttribute("flyoutDirection")
				if (direction == "LEFT") then
					self.FlyoutArrow:SetPoint("LEFT", 0, 0)
					SetClampedTextureRotation(self.FlyoutArrow, 270)

				elseif (direction == "RIGHT") then
					self.FlyoutArrow:SetPoint("RIGHT", 0, 0)
					SetClampedTextureRotation(self.FlyoutArrow, 90)

				elseif (direction == "DOWN") then
					self.FlyoutArrow:SetPoint("BOTTOM", 0, 0)
					SetClampedTextureRotation(self.FlyoutArrow, 180)

				else
					self.FlyoutArrow:SetPoint("TOP", 1, 0)
					SetClampedTextureRotation(self.FlyoutArrow, 0)
				end

				return
			end
		end
		self.FlyoutArrow:Hide()	
	end 
end

ActionButton.UpdateGrid = function(self)
	if (self:IsShown()) then 
		if (self:HasContent()) then
			self:SetAlpha(1)
		elseif (CursorHasSpell() or CursorHasItem()) then
			self:SetAlpha(1)
		else 
			local cursor = GetCursorInfo()
			if (cursor == "spell") or (cursor == "macro") or (cursor == "mount") or (cursor == "item") or (cursor == "battlepet") then 
				self:SetAlpha(1)
			else
				if (self.showGrid) then 
					self:SetAlpha(self.overrideAlphaWhenEmpty or 1)
				else 
					self:SetAlpha(0)
				end 
			end 
		end
	else
		self:SetAlpha(0)
	end
end

-- Strict true/false check for button content
ActionButton.HasContent = function(self)
	if (HasAction(self.buttonAction) and (self:GetSpellID() ~= 0)) then
		return true
	else 
		return false
	end
end

-- Called when the usable state of the button changes
ActionButton.UpdateUsable = function(self) 
	if UnitIsDeadOrGhost("player") then 
		self.Icon:SetDesaturated(true)
		self.Icon:SetVertexColor(.3, .3, .3)

	elseif self.outOfRange then
		self.Icon:SetDesaturated(true)
		self.Icon:SetVertexColor(1, .15, .15)

	else
		local isUsable, notEnoughMana = IsUsableAction(self.buttonAction)
		if isUsable then
			self.Icon:SetDesaturated(false)
			self.Icon:SetVertexColor(1, 1, 1)

		elseif notEnoughMana then
			self.Icon:SetDesaturated(true)
			self.Icon:SetVertexColor(.25, .25, 1)

		else
			self.Icon:SetDesaturated(true)
			self.Icon:SetVertexColor(.3, .3, .3)
		end
	end
end

ActionButton.ShowOverlayGlow = function(self, overlayType)
	if self.SpellHighlight then 
		local r, g, b, a
		if (overlayType == "CLEARCAST") then
			r, g, b, a = 125/255, 225/255, 255/255, .75
		elseif (overlayType == "REACTIVE") then
			r, g, b, a = 255/255, 225/255, 125/255, .75
		elseif (overlayType == "FINISHER") then
			r, g, b, a = 255/255, 50/255, 75/255, .75
		else
			-- Not sure why finishers sometimes change into this yet.
			r, g, b, a = 255/255, 225/255, 125/255, .75
		end
		self.SpellHighlight.Texture:SetVertexColor(r, g, b, .75)
		self.SpellHighlight:Show()
	end
end

ActionButton.HideOverlayGlow = function(self)
	if self.SpellHighlight then 
		self.SpellHighlight:Hide()
	end
end

ActionButton.UpdateSpellHighlight = function(self)
	if self.SpellHighlight then 
		local spellId = self:GetSpellID()
		if (spellId) then
			local overlayType = LibSecureButton:GetSpellOverlayType(spellId)
			if (overlayType) then
				self:ShowOverlayGlow(overlayType)
			else
				self:HideOverlayGlow()
			end
		end
	end 
end

-- Getters
----------------------------------------------------
ActionButton.GetSpellRank = function(self)
	local spellID = self:GetSpellID()
	if (spellID) then 
		local name, _, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(spellID)
		local rankMsg = GetSpellSubtext(spellID)
		if rankMsg then 
			local rank = string_match(rankMsg, "(%d+)")
			if rank then 
				return tonumber(rank)
			end 
		end 
	end 
end

ActionButton.GetAction = function(self)
	local actionpage = tonumber(self:GetAttribute("actionpage"))
	local id = self:GetID()
	return actionpage and (actionpage > 1) and ((actionpage - 1) * NUM_ACTIONBAR_BUTTONS + id) or id
end

ActionButton.GetActionTexture = function(self) 
	return GetActionTexture(self.buttonAction)
end

ActionButton.GetBindingText = function(self)
	return self.bindingAction and GetBindingKey(self.bindingAction) or GetBindingKey("CLICK "..self:GetName()..":LeftButton")
end 

ActionButton.GetCooldown = function(self) 
	return GetActionCooldown(self.buttonAction) 
end

ActionButton.GetLossOfControlCooldown = function(self) 
	return GetActionLossOfControlCooldown(self.buttonAction) 
end

ActionButton.GetPageID = function(self)
	return self._pager:GetID()
end 

ActionButton.GetPager = function(self)
	return self._pager
end 

ActionButton.GetSpellID = function(self)
	local actionType, id, subType = GetActionInfo(self.buttonAction)
	if (actionType == "spell") then
		return id
	elseif (actionType == "macro") then
		return (GetMacroSpell(id))
	end
end

ActionButton.GetTooltip = function(self)
	return LibSecureButton:GetActionButtonTooltip()
end

-- Isers
----------------------------------------------------
ActionButton.IsFlyoutShown = function(self)
	local buttonAction = self:GetAction()
	if HasAction(buttonAction) then
		return (GetActionInfo(buttonAction) == "flyout") and (SpellFlyout and SpellFlyout:IsShown() and SpellFlyout:GetParent() == self)
	end 
end

ActionButton.IsInRange = function(self)
	local unit = self:GetAttribute("unit")
	if (unit == "player") then
		unit = nil
	end

	local val = IsActionInRange(self.buttonAction, unit)
	if (val == 1) then 
		val = true 
	elseif (val == 0) then 
		val = false 
	end

	return val
end

-- Script Handlers
----------------------------------------------------
ActionButton.OnEnable = function(self)
	self:RegisterEvent("ACTIONBAR_SLOT_CHANGED", UpdateActionButton)
	self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", UpdateActionButton)
	self:RegisterEvent("ACTIONBAR_UPDATE_STATE", UpdateActionButton)
	self:RegisterEvent("ACTIONBAR_UPDATE_USABLE", UpdateActionButton)
	self:RegisterEvent("ACTIONBAR_HIDEGRID", UpdateActionButton)
	self:RegisterEvent("ACTIONBAR_SHOWGRID", UpdateActionButton)
	self:RegisterEvent("CURSOR_UPDATE", UpdateActionButton)
	self:RegisterEvent("LOSS_OF_CONTROL_ADDED", UpdateActionButton)
	self:RegisterEvent("LOSS_OF_CONTROL_UPDATE", UpdateActionButton)
	--self:RegisterEvent("PET_BAR_HIDEGRID", UpdateActionButton)
	--self:RegisterEvent("PET_BAR_SHOWGRID", UpdateActionButton)
	--self:RegisterEvent("PET_BAR_UPDATE", UpdateActionButton)
	self:RegisterEvent("PLAYER_ENTER_COMBAT", UpdateActionButton)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", UpdateActionButton)
	self:RegisterEvent("PLAYER_LEAVE_COMBAT", UpdateActionButton)
	self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", UpdateActionButton)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", UpdateActionButton)
	self:RegisterEvent("SPELL_UPDATE_CHARGES", UpdateActionButton)
	self:RegisterEvent("SPELL_UPDATE_ICON", UpdateActionButton)
	self:RegisterEvent("SPELLS_CHANGED", UpdateActionButton)
	self:RegisterEvent("TRADE_SKILL_CLOSE", UpdateActionButton)
	self:RegisterEvent("TRADE_SKILL_SHOW", UpdateActionButton)
	self:RegisterEvent("UPDATE_BINDINGS", UpdateActionButton)
	self:RegisterEvent("UPDATE_MACROS", UpdateActionButton)
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", UpdateActionButton)

	if (IsRetail) then
		self:RegisterEvent("ARCHAEOLOGY_CLOSED", Update)
		self:RegisterEvent("COMPANION_UPDATE", Update)
		--self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", Update)
		--self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", Update)
		self:RegisterEvent("UNIT_ENTERED_VEHICLE", Update)
		self:RegisterEvent("UNIT_EXITED_VEHICLE", Update)
		self:RegisterEvent("UPDATE_SUMMONPETS_ACTION", Update)
		self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR", Update)
	end

	self:RegisterMessage("GP_SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", UpdateActionButton)
	self:RegisterMessage("GP_SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", UpdateActionButton)
end

ActionButton.OnDisable = function(self)
	self:UnregisterEvent("ACTIONBAR_SLOT_CHANGED", UpdateActionButton)
	self:UnregisterEvent("ACTIONBAR_UPDATE_COOLDOWN", UpdateActionButton)
	self:UnregisterEvent("ACTIONBAR_UPDATE_STATE", UpdateActionButton)
	self:UnregisterEvent("ACTIONBAR_UPDATE_USABLE", UpdateActionButton)
	self:UnregisterEvent("ACTIONBAR_HIDEGRID", UpdateActionButton)
	self:UnregisterEvent("ACTIONBAR_SHOWGRID", UpdateActionButton)
	self:UnregisterEvent("CURSOR_UPDATE", UpdateActionButton)
	self:UnregisterEvent("LOSS_OF_CONTROL_ADDED", UpdateActionButton)
	self:UnregisterEvent("LOSS_OF_CONTROL_UPDATE", UpdateActionButton)
	--self:UnregisterEvent("PET_BAR_HIDEGRID", UpdateActionButton)
	--self:UnregisterEvent("PET_BAR_SHOWGRID", UpdateActionButton)
	--self:UnregisterEvent("PET_BAR_UPDATE", UpdateActionButton)
	self:UnregisterEvent("PLAYER_ENTER_COMBAT", UpdateActionButton)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", UpdateActionButton)
	self:UnregisterEvent("PLAYER_LEAVE_COMBAT", UpdateActionButton)
	self:UnregisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", UpdateActionButton)
	self:UnregisterEvent("PLAYER_TARGET_CHANGED", UpdateActionButton)
	self:UnregisterEvent("SPELL_UPDATE_CHARGES", UpdateActionButton)
	self:UnregisterEvent("SPELL_UPDATE_ICON", UpdateActionButton)
	self:UnregisterEvent("TRADE_SKILL_CLOSE", UpdateActionButton)
	self:UnregisterEvent("TRADE_SKILL_SHOW", UpdateActionButton)
	self:UnregisterEvent("UPDATE_BINDINGS", UpdateActionButton)
	self:UnregisterEvent("UPDATE_MACROS", UpdateActionButton)
	self:UnregisterEvent("UPDATE_SHAPESHIFT_FORM", UpdateActionButton)
end

ActionButton.OnEvent = function(self, event, ...)
	if (self:IsVisible() and Callbacks[self] and Callbacks[self][event]) then 
		local events = Callbacks[self][event]
		for i = 1, #events do
			events[i](self, event, ...)
		end
	end 
end

ActionButton.OnEnter = function(self) 
	self.isMouseOver = true

	-- Don't fire off tooltip updates if the button has no content
	if (not HasAction(self.buttonAction)) or (self:GetSpellID() == 0) then 
		self.UpdateTooltip = nil
		self:GetTooltip():Hide()
	else
		self.UpdateTooltip = UpdateTooltip
		self:UpdateTooltip()
	end 

	if self.PostEnter then 
		self:PostEnter()
	end 
end

ActionButton.OnLeave = function(self) 
	self.isMouseOver = nil
	self.UpdateTooltip = nil

	local tooltip = self:GetTooltip()
	tooltip:Hide()

	if self.PostLeave then 
		self:PostLeave()
	end 
end

ActionButton.PreClick = function(self) 
	self:SetChecked(false)
end

ActionButton.PostClick = function(self) 
end

-- PetButton Template
-- *Note that generic methods will be
--  borrowed from the ActionButton template.
----------------------------------------------------
local PetButton = LibSecureButton:CreateFrame("CheckButton")
local PetButton_MT = { __index = PetButton }

-- PetButton Event Handling
----------------------------------------------------
PetButton.RegisterEvent = ActionButton.RegisterEvent
PetButton.UnregisterEvent = ActionButton.UnregisterEvent
PetButton.UnregisterAllEvents = ActionButton.UnregisterAllEvents
PetButton.RegisterMessage = ActionButton.RegisterMessage

-- PetButton Updates
----------------------------------------------------
PetButton.Update = function(self)
	local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID = GetPetActionInfo(self.id)

	if (name) then 
		self.hasAction = true
		self.Icon:SetTexture((not isToken) and texture or _G[texture])
		self:SetAlpha(1)
	else
		self.hasAction = false
		self.Icon:SetTexture(nil) 
	end 
	if isActive then
		self:SetChecked(true)

		if IsPetAttackAction(self.id) then
			-- start flash
		end
	else
		self:SetChecked(false)

		if IsPetAttackAction(self.id) then
			-- stop flash
		end
	end

	self:UpdateBinding()
	--self:UpdateCount()
	self:UpdateCooldown()
	--self:UpdateFlash()
	--self:UpdateUsable()
	--self:UpdateGrid()
	self:UpdateAutoCast()

	if (self.PostUpdate) then 
		self:PostUpdate()
	end 

end

PetButton.UpdateAutoCast = function(self)
	local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID = GetPetActionInfo(self.id)

	if (name and autoCastAllowed) then 
		if (autoCastEnabled) then 
			if (not self.SpellAutoCast.Ants.Anim:IsPlaying()) then
				self.SpellAutoCast.Ants.Anim:Play()
				self.SpellAutoCast.Glow.Anim:Play()
			end
			self.SpellAutoCast:SetAlpha(1)
		else 
			if (self.SpellAutoCast.Ants.Anim:IsPlaying()) then
				self.SpellAutoCast.Ants.Anim:Pause()
				self.SpellAutoCast.Glow.Anim:Pause()
			end
			self.SpellAutoCast:SetAlpha(.5)
		end 
		self.SpellAutoCast:Show()
	else 
		self.SpellAutoCast:Hide()
	end 
end

PetButton.UpdateCooldown = function(self)
	local Cooldown = self.Cooldown
	if Cooldown then
		local start, duration, enable = GetPetActionCooldown(self.id)
		SetCooldown(Cooldown, start, duration, enable, false, 1)

		if (self.PostUpdateCooldown) then 
			return self:PostUpdateCooldown(self.Cooldown)
		end 
	end
end

PetButton.UpdateBinding = ActionButton.UpdateBinding

-- Getters
----------------------------------------------------
PetButton.GetPager = function(self)
	return self._pager
end 

PetButton.GetSpellID = function(self)
	local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID = GetPetActionInfo(self.id)
	return spellID
end

PetButton.GetBindingText = ActionButton.GetBindingText
PetButton.GetTooltip = ActionButton.GetTooltip

-- PetButton Script Handlers
----------------------------------------------------
PetButton.OnEnable = function(self)
	self:RegisterEvent("PLAYER_CONTROL_LOST", UpdatePetButton)
	self:RegisterEvent("PLAYER_CONTROL_GAINED", UpdatePetButton)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", UpdatePetButton)
	self:RegisterEvent("PLAYER_FARSIGHT_FOCUS_CHANGED", UpdatePetButton)
	self:RegisterEvent("UNIT_PET", UpdatePetButton)
	self:RegisterEvent("UNIT_FLAGS", UpdatePetButton)
	self:RegisterEvent("UNIT_AURA", UpdatePetButton)
	self:RegisterEvent("UPDATE_BINDINGS", UpdatePetButton)
	self:RegisterEvent("PET_BAR_UPDATE", UpdatePetButton)
	self:RegisterEvent("PET_BAR_UPDATE_COOLDOWN", UpdatePetButton)
	self:RegisterEvent("PET_BAR_SHOWGRID", UpdatePetButton)
	self:RegisterEvent("PET_BAR_HIDEGRID", UpdatePetButton)
end

PetButton.OnDisable = function(self)
	self:UnregisterEvent("PLAYER_CONTROL_LOST", UpdatePetButton)
	self:UnregisterEvent("PLAYER_CONTROL_GAINED", UpdatePetButton)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", UpdatePetButton)
	self:UnregisterEvent("PLAYER_FARSIGHT_FOCUS_CHANGED", UpdatePetButton)
	self:UnregisterEvent("UNIT_PET", UpdatePetButton)
	self:UnregisterEvent("UNIT_FLAGS", UpdatePetButton)
	self:UnregisterEvent("UNIT_AURA", UpdatePetButton)
	self:UnregisterEvent("UPDATE_BINDINGS", UpdatePetButton)
	self:UnregisterEvent("PET_BAR_UPDATE", UpdatePetButton)
	self:UnregisterEvent("PET_BAR_UPDATE_COOLDOWN", UpdatePetButton)
	self:UnregisterEvent("PET_BAR_SHOWGRID", UpdatePetButton)
	self:UnregisterEvent("PET_BAR_HIDEGRID", UpdatePetButton)
end

PetButton.OnEnter = function(self) 
	self.isMouseOver = true

	-- Don't fire off tooltip updates if the button has no content
	if (not GetPetActionInfo(self.id)) then 
		self.UpdateTooltip = nil
		self:GetTooltip():Hide()
	else
		self.UpdateTooltip = UpdatePetTooltip
		self:UpdateTooltip()
	end 

	if self.PostEnter then 
		self:PostEnter()
	end 
end

PetButton.OnLeave = function(self) 
	self.isMouseOver = nil
	self.UpdateTooltip = nil

	local tooltip = self:GetTooltip()
	tooltip:Hide()

	if self.PostLeave then 
		self:PostLeave()
	end 
end

PetButton.OnDragStart = function(self)
	self:SetChecked(false)
end

PetButton.OnReceiveDrag = function(self)
	self:SetChecked(false)
end

PetButton.PreClick = function(self) 
	self:SetChecked(false)
end

PetButton.OnEvent = ActionButton.OnEvent

-- StanceButton Template
-- *Note that generic methods will be
--  borrowed from the ActionButton template.
----------------------------------------------------
local StanceButton = LibSecureButton:CreateFrame("CheckButton")
local StanceButton_MT = { __index = StanceButton }

-- StanceButton Event Handling
----------------------------------------------------
StanceButton.RegisterEvent = ActionButton.RegisterEvent
StanceButton.UnregisterEvent = ActionButton.UnregisterEvent
StanceButton.UnregisterAllEvents = ActionButton.UnregisterAllEvents
StanceButton.RegisterMessage = ActionButton.RegisterMessage

-- StanceButton Updates
----------------------------------------------------
StanceButton.Update = function(self)

end

StanceButton.UpdateCooldown = function(self)
end

StanceButton.UpdateMaxButtons = function(self)
end

StanceButton.UpdateUsable = function(self)
end

-- StanceButton Script Handlers
----------------------------------------------------
StanceButton.OnEnable = function(self)
	self:RegisterEvent("ACTIONBAR_PAGE_CHANGED", UpdateStanceButton)
	self:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN", UpdateStanceButton)
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", UpdateStanceButton)
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", UpdateStanceButton)
	self:RegisterEvent("UPDATE_SHAPESHIFT_USABLE", UpdateStanceButton)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", UpdateStanceButton)
end

-- Library API
----------------------------------------------------
LibSecureButton.CreateButtonLayers = function(self, button)

	local icon = button:CreateTexture()
	icon:SetDrawLayer("BACKGROUND", 2)
	icon:SetAllPoints()
	button.Icon = icon

	local slot = button:CreateTexture()
	slot:SetDrawLayer("BACKGROUND", 1)
	slot:SetAllPoints()
	button.Slot = slot

	local flash = button:CreateTexture()
	flash:SetDrawLayer("ARTWORK", 2)
	flash:SetAllPoints(icon)
	flash:SetColorTexture(1, 0, 0, .25)
	flash:Hide()
	button.Flash = flash

	local pushed = button:CreateTexture(nil, "OVERLAY")
	pushed:SetDrawLayer("ARTWORK", 1)
	pushed:SetColorTexture(1, 1, 1, .15)
	pushed:SetAllPoints(icon)
	button.Pushed = pushed

	-- We're letting blizzard handle this one,
	-- in order to catch both mouse clicks and keybind clicks.
	button:SetPushedTexture(pushed)
	button:GetPushedTexture():SetBlendMode("ADD")
	button:GetPushedTexture():SetDrawLayer("ARTWORK") -- must be updated after pushed texture has been set
end

LibSecureButton.CreateButtonOverlay = function(self, button)
	local overlay = button:CreateFrame("Frame", nil, button)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(button:GetFrameLevel() + 15)
	button.Overlay = overlay
end 

LibSecureButton.CreateButtonKeybind = function(self, button)
	local keybind = (button.Overlay or button):CreateFontString()
	keybind:SetDrawLayer("OVERLAY", 2)
	keybind:SetPoint("TOPRIGHT", -2, -1)
	keybind:SetFontObject(Game12Font_o1)
	keybind:SetJustifyH("CENTER")
	keybind:SetJustifyV("BOTTOM")
	keybind:SetShadowOffset(0, 0)
	keybind:SetShadowColor(0, 0, 0, 0)
	keybind:SetTextColor(230/255, 230/255, 230/255, .75)
	button.Keybind = keybind
end 

LibSecureButton.CreateButtonCount = function(self, button)
	local count = (button.Overlay or button):CreateFontString()
	count:SetDrawLayer("OVERLAY", 1)
	count:SetPoint("BOTTOMRIGHT", -2, 1)
	count:SetFontObject(Game12Font_o1)
	count:SetJustifyH("CENTER")
	count:SetJustifyV("BOTTOM")
	count:SetShadowOffset(0, 0)
	count:SetShadowColor(0, 0, 0, 0)
	count:SetTextColor(250/255, 250/255, 250/255, .85)
	button.Count = count
end 

LibSecureButton.CreateButtonAutoCast = function(self, button)
	local autoCast = button:CreateFrame("Frame")
	autoCast:Hide()
	autoCast:SetFrameLevel(button:GetFrameLevel() + 10)

	local ants = autoCast:CreateTexture()
	ants:SetDrawLayer("ARTWORK", 1)
	ants:SetAllPoints()
	ants:SetVertexColor(255/255, 225/255, 125/255, 1)
	
	local animGroup = ants:CreateAnimationGroup()    
	animGroup:SetLooping("REPEAT")

	local anim = animGroup:CreateAnimation("Rotation")
	anim:SetDegrees(-360)
	anim:SetDuration(30)
	ants.Anim = animGroup

	local glow = autoCast:CreateTexture()
	glow:SetDrawLayer("ARTWORK", 0)
	glow:SetAllPoints()
	glow:SetVertexColor(255/255, 225/255, 125/255, .25)

	local animGroup2 = glow:CreateAnimationGroup()
	animGroup2:SetLooping("REPEAT")

	for i = 1,10 do
		local anim2 = animGroup2:CreateAnimation("Rotation")
		anim2:SetOrder(i*2 - 1)
		anim2:SetDegrees(-18)
		anim2:SetDuration(1.5)

		local anim3 = animGroup2:CreateAnimation("Rotation")
		anim3:SetOrder(i*2)
		anim3:SetDegrees(-18)
		anim3:SetDuration(1.5)

		local alpha = animGroup2:CreateAnimation("Alpha")
		alpha:SetOrder(i*2 - 1)
		alpha:SetDuration(1.5)
		alpha:SetFromAlpha(.25)
		alpha:SetToAlpha(.75)

		local alpha2 = animGroup2:CreateAnimation("Alpha")
		alpha2:SetOrder(i*2)
		alpha2:SetDuration(1.5)
		alpha2:SetFromAlpha(.75)
		alpha2:SetToAlpha(.25)
	end 

	glow.Anim = animGroup2

	button.SpellAutoCast = autoCast
	button.SpellAutoCast.Ants = ants
	button.SpellAutoCast.Glow = glow
end

LibSecureButton.CreateButtonCooldowns = function(self, button)
	local cooldown = button:CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown:Hide()
	cooldown:SetAllPoints()
	cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
	cooldown:SetReverse(false)
	cooldown:SetSwipeColor(0, 0, 0, .75)
	cooldown:SetBlingTexture(BLING_TEXTURE, .3, .6, 1, .75) 
	cooldown:SetEdgeTexture(EDGE_NORMAL_TEXTURE)
	cooldown:SetDrawSwipe(true)
	cooldown:SetDrawBling(true)
	cooldown:SetDrawEdge(false)
	cooldown:SetHideCountdownNumbers(true) 
	button.Cooldown = cooldown

	local cooldownCount = (button.Overlay or button):CreateFontString()
	cooldownCount:SetDrawLayer("ARTWORK", 1)
	cooldownCount:SetPoint("CENTER", 1, 0)
	cooldownCount:SetFontObject(Game12Font_o1)
	cooldownCount:SetJustifyH("CENTER")
	cooldownCount:SetJustifyV("MIDDLE")
	cooldownCount:SetShadowOffset(0, 0)
	cooldownCount:SetShadowColor(0, 0, 0, 0)
	cooldownCount:SetTextColor(250/255, 250/255, 250/255, .85)
	button.CooldownCount = cooldownCount

	local chargeCooldown = button:CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	chargeCooldown:Hide()
	chargeCooldown:SetAllPoints()
	chargeCooldown:SetFrameLevel(button:GetFrameLevel() + 2)
	chargeCooldown:SetReverse(false)
	chargeCooldown:SetSwipeColor(0, 0, 0, .75)
	chargeCooldown:SetBlingTexture(BLING_TEXTURE, .3, .6, 1, .75) 
	chargeCooldown:SetEdgeTexture(EDGE_NORMAL_TEXTURE)
	chargeCooldown:SetDrawEdge(true)
	chargeCooldown:SetDrawSwipe(true)
	chargeCooldown:SetDrawBling(false)
	chargeCooldown:SetHideCountdownNumbers(true) 
	button.ChargeCooldown = chargeCooldown
end

LibSecureButton.CreateFlyoutArrow = function(self, button)
	local flyoutArrow = (button.Overlay or button):CreateTexture()
	flyoutArrow:Hide()
	flyoutArrow:SetSize(23,11)
	flyoutArrow:SetDrawLayer("OVERLAY", 1)
	flyoutArrow:SetTexture([[Interface\Buttons\ActionBarFlyoutButton]])
	flyoutArrow:SetTexCoord(.625, .984375, .7421875, .828125)
	flyoutArrow:SetPoint("TOP", 0, 2)
	button.FlyoutArrow = flyoutArrow

	-- blizzard code bugs out without these
	button.FlyoutBorder = button:CreateTexture()
	button.FlyoutBorderShadow = button:CreateTexture()
end 

LibSecureButton.CreateButtonSpellHighlight = function(self, button)
	local spellHighlight = button:CreateFrame("Frame")
	spellHighlight:Hide()
	spellHighlight:SetFrameLevel(button:GetFrameLevel() + 10)
	button.SpellHighlight = spellHighlight

	local texture = spellHighlight:CreateTexture()
	texture:SetDrawLayer("ARTWORK", 2)
	texture:SetAllPoints()
	texture:SetVertexColor(255/255, 225/255, 125/255, 1)
	button.SpellHighlight.Texture = texture
end

-- Prepare a Blizzard Pet Button for our usage
LibSecureButton.PrepareButton = function(self, button)
	local name = button:GetName()

	button:UnregisterAllEvents()
	button:SetScript("OnEvent", nil)
	button:SetScript("OnDragStart",nil)
	button:SetScript("OnReceiveDrag",nil)
	button:SetScript("OnUpdate",nil)
	button:SetNormalTexture("")
	button.SpellHighlightAnim:Stop()
	for _,element in pairs({
		_G[name.."AutoCastable"],
		_G[name.."Cooldown"],
		_G[name.."Flash"],
		_G[name.."HotKey"],
		_G[name.."Icon"],
		_G[name.."Shine"],
		button.SpellHighlightTexture,
		button:GetNormalTexture(),
		button:GetPushedTexture(),
		button:GetHighlightTexture()
	}) do
		element:SetParent(UIHider)
	end


	return button
end

-- Public API
----------------------------------------------------
LibSecureButton.SpawnActionButton = function(self, buttonType, parent, buttonTemplate, ...)
	check(parent, 1, "string", "table")
	check(buttonType, 2, "string")
	check(buttonTemplate, 3, "table", "nil")

	-- Doing it this way to only include the global arguments
	-- available in all button types as function arguments.
	-- *What the hell am I talking about here?
	local barID, buttonID = ...

	-- Store the button
	if (not Buttons[self]) then 
		Buttons[self] = {}
	end 

	-- Increase the button count
	LibSecureButton.numButtons = LibSecureButton.numButtons + 1

	-- Count the total number of buttons
	-- belonging to the addon that spawned it.
	local count = 0 
	for button in pairs(Buttons[self]) do 
		count = count + 1
	end 

	-- Make up an unique name
	local name = nameHelper(self, count + 1, buttonType)

	-- Create an additional visibility layer to handle manual toggling
	local visibility = self:CreateFrame("Frame", nil, parent, "SecureHandlerAttributeTemplate")
	visibility:Hide() -- driver will show it later on
	visibility:SetAttribute("_onattributechanged", [=[
		if (name == "state-vis") then
			if (value == "show") then 
				self:Show(); 
			elseif (value == "hide") then 
				self:Hide(); 
			end 
		end
	]=])

	local button
	if (buttonType == "pet") then 
		-- Add a page driver layer, basically a fake bar for the current button
		local page = visibility:CreateFrame("Frame", nil, "SecureHandlerAttributeTemplate")
		page.AddDebugMessage = self.AddDebugMessageFormatted

		button = setmetatable(LibSecureButton:PrepareButton(page:CreateFrame("CheckButton", name, "PetActionButtonTemplate")), PetButton_MT)
		button:SetFrameStrata("LOW")

		-- Link the button to the visibility layer
		visibility:SetFrameRef("Button", button)

		-- Create button layers
		LibSecureButton:CreateButtonLayers(button)
		LibSecureButton:CreateButtonOverlay(button)
		LibSecureButton:CreateButtonCooldowns(button)
		LibSecureButton:CreateButtonCount(button)
		LibSecureButton:CreateButtonKeybind(button)
		LibSecureButton:CreateButtonAutoCast(button)

		button:RegisterForDrag("LeftButton", "RightButton")
		button:RegisterForClicks("AnyUp")

		button:SetID(buttonID)
		button:SetAttribute("type", "pet")
		--button:SetAttribute("unit", "pettarget")
		button:SetAttribute("action", buttonID)
		button:SetAttribute("buttonLock", true)
		button.id = buttonID
		button._owner = visibility
		button._pager = page

		button:SetScript("OnEnter", PetButton.OnEnter)
		button:SetScript("OnLeave", PetButton.OnLeave)
		button:SetScript("OnDragStart", PetButton.OnDragStart)
		button:SetScript("OnReceiveDrag", PetButton.OnReceiveDrag)

		-- This allows drag functionality, but stops the casting, 
		-- thus allowing us to drag spells even with cast on down, wohoo! 
		-- Doesn't currently appear to be a way to make this work without the modifier, though, 
		-- since the override bindings we use work by sending mouse events to the listeners, 
		-- meaning there's no way to separate keys and mouse buttons. 
		button:SetAttribute("alt-ctrl-shift-type*", "stop")
		
		page:SetFrameRef("Visibility", visibility)
		page:SetFrameRef("Button", button)
		visibility:SetFrameRef("Page", page)

		button:SetAttribute("OnDragStart", [[
			local id = self:GetID(); 
			local buttonLock = self:GetAttribute("buttonLock"); 
			if ((not buttonLock) or (IsShiftKeyDown() and IsAltKeyDown() and IsControlKeyDown())) then
				return "petaction", id
			end
		]])
		
		-- When a spell is dragged from a button
		-- *This never fires when cast on down is enabled. ARGH! 
		page:WrapScript(button, "OnDragStart", [[
			return self:RunAttribute("OnDragStart")
		]])

		-- Bartender says: 
		-- Wrap twice, because the post-script is not run when the pre-script causes a pickup (doh)
		-- we also need some phony message, or it won't work =/
		page:WrapScript(button, "OnDragStart", [[
			return "message", "update"
		]])

		-- When a spell is dropped onto a button
		page:WrapScript(button, "OnReceiveDrag", [[
			local kind, value, subtype, extra = ...
			if ((not kind) or (not value)) then 
				return false 
			end
			local button = self:GetFrameRef("Button"); 
			local buttonLock = button:GetAttribute("buttonLock"); 
			local id = button:GetID(); 
			if ((not buttonLock) or (IsShiftKeyDown() and IsAltKeyDown() and IsControlKeyDown())) then
				return "petaction", id
			end 
		]])
		page:WrapScript(button, "OnReceiveDrag", [[
			return "message", "update"
		]])

		local visibilityDriver = "[@pet,exists]show;hide"

		-- enable the visibility driver
		RegisterAttributeDriver(visibility, "state-vis", visibilityDriver)

		-- not run by a page driver
		page:SetAttribute("state-page", "0") 
		button:SetAttribute("state", "0")
		

	elseif (buttonType == "stance") then
		button = setmetatable(visibility:CreateFrame("CheckButton", name, "StanceButtonTemplate"), StanceButton_MT)
		button:SetFrameStrata("LOW")


		button:SetScript("OnEnter", StanceButton.OnEnter)
		button:SetScript("OnLeave", StanceButton.OnLeave)
		button:SetScript("OnDragStart", StanceButton.OnDragStart)
		button:SetScript("OnReceiveDrag", StanceButton.OnReceiveDrag)

	else 
		-- Add a page driver layer, basically a fake bar for the current button
		local page = visibility:CreateFrame("Frame", nil, "SecureHandlerAttributeTemplate")
		page.id = barID
		page.AddDebugMessage = self.AddDebugMessageFormatted
		page:SetID(barID) 
		page:SetAttribute("_onattributechanged", SECURE.Page_OnAttributeChanged)

		button = setmetatable(page:CreateFrame("CheckButton", name, "SecureActionButtonTemplate"), ActionButton_MT)
		button:SetFrameStrata("LOW")

		-- Create button layers
		LibSecureButton:CreateButtonLayers(button)
		LibSecureButton:CreateButtonOverlay(button)
		LibSecureButton:CreateButtonCooldowns(button)
		LibSecureButton:CreateButtonCount(button)
		LibSecureButton:CreateButtonKeybind(button)
		LibSecureButton:CreateButtonAutoCast(button)
		LibSecureButton:CreateButtonSpellHighlight(button)
		LibSecureButton:CreateFlyoutArrow(button)

		button:RegisterForDrag("LeftButton", "RightButton")
		button:RegisterForClicks("AnyUp")

		-- This allows drag functionality, but stops the casting, 
		-- thus allowing us to drag spells even with cast on down, wohoo! 
		-- Doesn't currently appear to be a way to make this work without the modifier, though, 
		-- since the override bindings we use work by sending mouse events to the listeners, 
		-- meaning there's no way to separate keys and mouse buttons. 
		button:SetAttribute("alt-ctrl-shift-type*", "stop")

		button:SetID(buttonID)
		button:SetAttribute("type", "action")
		button:SetAttribute("flyoutDirection", "UP")
		button:SetAttribute("checkselfcast", true)
		button:SetAttribute("checkfocuscast", true)
		button:SetAttribute("useparent-unit", true)
		button:SetAttribute("useparent-actionpage", true)
		button:SetAttribute("buttonLock", true)
		button.id = buttonID
		button.action = 0

		button._owner = visibility
		button._pager = page

		button:SetScript("OnEnter", ActionButton.OnEnter)
		button:SetScript("OnLeave", ActionButton.OnLeave)
		button:SetScript("PreClick", ActionButton.PreClick)
		button:SetScript("PostClick", ActionButton.PostClick)
		button:SetScript("OnUpdate", OnUpdate)

		-- A little magic to allow us to toggle autocasting of pet abilities
		page:WrapScript(button, "PreClick", [[
			if (button ~= "RightButton") then 
				if (self:GetAttribute("type2")) then 
					self:SetAttribute("type2", nil); 
				end 
				return 
			end
			local actionpage = self:GetAttribute("actionpage"); 
			if (not actionpage) then
				if (self:GetAttribute("type2")) then 
					self:SetAttribute("type2", nil); 
				end 
				return
			end
			local id = self:GetID(); 
			local action = (actionpage > 1) and ((actionpage - 1)*12 + id) or id; 
			local actionType, id, subType = GetActionInfo(action);
			if (subType == "pet") and (id ~= 0) then 
				self:SetAttribute("type2", "macro"); 
			else 
				if (self:GetAttribute("type2")) then 
					self:SetAttribute("type2", nil); 
				end 
			end 
		]]) 

		page:SetFrameRef("Visibility", visibility)
		page:SetFrameRef("Button", button)
		visibility:SetFrameRef("Page", page)

		button:SetAttribute("OnDragStart", [[
			local actionpage = self:GetAttribute("actionpage"); 
			if (not actionpage) then
				return
			end
			local id = self:GetID(); 
			local buttonLock = self:GetAttribute("buttonLock"); 
			local action = (actionpage > 1) and ((actionpage - 1)*12 + id) or id; 
			if action and ( (not buttonLock) or (IsShiftKeyDown() and IsAltKeyDown() and IsControlKeyDown()) ) then
				return "action", action
			end
		]])

		-- When a spell is dragged from a button
		-- *This never fires when cast on down is enabled. ARGH! 
		page:WrapScript(button, "OnDragStart", [[
			return self:RunAttribute("OnDragStart")
		]])
		-- Bartender says: 
		-- Wrap twice, because the post-script is not run when the pre-script causes a pickup (doh)
		-- we also need some phony message, or it won't work =/
		page:WrapScript(button, "OnDragStart", [[
			return "message", "update"
		]])

		-- When a spell is dropped onto a button
		page:WrapScript(button, "OnReceiveDrag", [[
			local kind, value, subtype, extra = ...
			if ((not kind) or (not value)) then 
				return false 
			end
			local button = self:GetFrameRef("Button"); 
			local buttonLock = button and button:GetAttribute("buttonLock"); 
			local actionpage = self:GetAttribute("actionpage"); 
			local id = self:GetID(); 
			local action = actionpage and (actionpage > 1) and ((actionpage - 1)*12 + id) or id; 
			if action and ((not buttonLock) or (IsShiftKeyDown() and IsAltKeyDown() and IsControlKeyDown())) then
				return "action", action
			end 
		]])
		page:WrapScript(button, "OnReceiveDrag", [[
			return "message", "update"
		]])

		local driver, visibilityDriver
		if (IsClassic) then
			if (barID == 1) then 
				driver = "[form,noform] 0; [bar:2]2; [bar:3]3; [bar:4]4; [bar:5]5; [bar:6]6"

				local _, playerClass = UnitClass("player")
				if (playerClass == "DRUID") then
					driver = driver .. "; [bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10"

				elseif (playerClass == "PRIEST") then
					driver = driver .. "; [bonusbar:1] 7"

				elseif (playerClass == "ROGUE") then
					driver = driver .. "; [bonusbar:1] 7"

				elseif (playerClass == "WARRIOR") then
					driver = driver .. "; [bonusbar:1] 7; [bonusbar:2] 8" 
				end
				driver = driver .. "; 1"
				visibilityDriver = "[@player,exists]show;hide"
			else 
				driver = tostring(barID)
				visibilityDriver = "[@player,noexists]hide;show"
			end 

		elseif (IsRetail) then
			if (barID == 1) then 
				-- Moving vehicles farther back in the queue, as some overridebars like the ones 
				-- found in the new 8.1.5 world quest "Cycle of Life" returns positive for both vehicleui and overridebar. 
				driver = ("[overridebar]%.0f; [possessbar]%.0f; [shapeshift]%.0f; [vehicleui]%.0f; [form,noform] 0; [bar:2]2; [bar:3]3; [bar:4]4; [bar:5]5; [bar:6]6"):format(GetOverrideBarIndex(), GetVehicleBarIndex(), GetTempShapeshiftBarIndex(), GetVehicleBarIndex())
		
				local _, playerClass = UnitClass("player")
				if (playerClass == "DRUID") then
					driver = driver .. "; [bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10"
		
				elseif (playerClass == "MONK") then
					driver = driver .. "; [bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9"
		
				elseif (playerClass == "PRIEST") then
					driver = driver .. "; [bonusbar:1] 7"
		
				elseif (playerClass == "ROGUE") then
					driver = driver .. "; [bonusbar:1] 7"
		
				elseif (playerClass == "WARRIOR") then
					driver = driver .. "; [bonusbar:1] 7; [bonusbar:2] 8" 
				end
				--driver = driver .. "; [form] 1; 1"
				driver = driver .. "; 1"

				visibilityDriver = "[@player,exists][overridebar][possessbar][shapeshift][vehicleui]show;hide"
			else 
				driver = tostring(barID)
				visibilityDriver = "[overridebar][possessbar][shapeshift][vehicleui][@player,noexists]hide;show"
			end 
		end

		-- enable the visibility driver
		RegisterAttributeDriver(visibility, "state-vis", visibilityDriver)
		
		-- reset the page before applying a new page driver
		page:SetAttribute("state-page", "0") 

		-- just in case we're not run by a header, default to state 0
		button:SetAttribute("state", "0")

		-- enable the page driver
		RegisterAttributeDriver(page, "state-page", driver) 

		-- initial action update
		button:UpdateAction()

	end

	Buttons[self][button] = buttonType
	AllButtons[button] = buttonType

	-- Add any methods from the optional template.
	-- *we're now allowing modules to overwrite methods.
	if buttonTemplate then
		for methodName, func in pairs(buttonTemplate) do
			if (type(func) == "function") then
				button[methodName] = func
			end
		end
	end
	
	-- Call the post create method if it exists, 
	-- and pass along any remaining arguments.
	-- This is a good place to add styling.
	if button.PostCreate then
		button:PostCreate(...)
	end

	-- Our own event handler
	button:SetScript("OnEvent", button.OnEvent)

	-- Update all elements when shown
	button:HookScript("OnShow", button.Update)
	
	-- Enable the newly created button
	-- This is where events are registered and set up
	button:OnEnable()

	-- Run a full initial update
	button:Update()

	return button
end

-- Returns an iterator for all buttons registered to the module
-- Buttons are returned as the first return value, and ordered by their IDs.
LibSecureButton.GetAllActionButtonsOrdered = function(self)
	local buttons = Buttons[self]
	if (not buttons) then 
		return function() return nil end
	end 

	local sorted = {}
	for button,type in pairs(buttons) do 
		sorted[#sorted + 1] = button
	end 
	table_sort(sorted, sortByID)

	local counter = 0
	return function() 
		counter = counter + 1
		return sorted[counter]
	end 
end 

-- Returns an iterator for all buttons of the given type registered to the module.
-- Buttons are returned as the first return value, and ordered by their IDs.
LibSecureButton.GetAllActionButtonsByType = function(self, buttonType)
	local buttons = Buttons[self]
	if (not buttons) then 
		return function() return nil end
	end 

	local sorted = {}
	for button,type in pairs(buttons) do 
		if (type == buttonType) then 
			sorted[#sorted + 1] = button
		end 
	end 
	table_sort(sorted, sortByID)

	local counter = 0
	return function() 
		counter = counter + 1
		return sorted[counter]
	end 
end 

LibSecureButton.GetActionButtonTooltip = function(self)
	return LibSecureButton:GetTooltip("GP_ActionButtonTooltip") or LibSecureButton:CreateTooltip("GP_ActionButtonTooltip")
end

-- Modules should call this at UPDATE_BINDINGS and the first PLAYER_ENTERING_WORLD
LibSecureButton.UpdateActionButtonBindings = function(self)
	-- "SHAPESHIFTBUTTON%.0f" -- stance bar
	for button in self:GetAllActionButtonsByType("action") do 

		local pager = button:GetPager()

		-- clear current overridebindings
		ClearOverrideBindings(pager) 

		-- retrieve page and button id
		local buttonID = button:GetID()
		local barID = button:GetPageID()

		-- figure out the binding action
		local bindingAction
		if (barID == 1) then 
			bindingAction = ("ACTIONBUTTON%.0f"):format(buttonID)
		elseif (barID == BOTTOMLEFT_ACTIONBAR_PAGE) then 
			bindingAction = ("MULTIACTIONBAR1BUTTON%.0f"):format(buttonID)

		elseif (barID == BOTTOMRIGHT_ACTIONBAR_PAGE) then 
			bindingAction = ("MULTIACTIONBAR2BUTTON%.0f"):format(buttonID)

		elseif (barID == RIGHT_ACTIONBAR_PAGE) then 
			bindingAction = ("MULTIACTIONBAR3BUTTON%.0f"):format(buttonID)

		elseif (barID == LEFT_ACTIONBAR_PAGE) then 
			bindingAction = ("MULTIACTIONBAR4BUTTON%.0f"):format(buttonID)
		end 

		-- store the binding action name on the button
		button.bindingAction = bindingAction

		-- iterate through the registered keys for the action
		for keyNumber = 1, select("#", GetBindingKey(bindingAction)) do 

			-- get a key for the action
			local key = select(keyNumber, GetBindingKey(bindingAction)) 
			if (key and (key ~= "")) then
				-- this is why we need named buttons
				SetOverrideBindingClick(pager, false, key, button:GetName(), "CLICK: LeftButton") -- assign the key to our own button
			end	
		end
	end

	for button in self:GetAllActionButtonsByType("pet") do

		local pager = button:GetPager()

		-- clear current overridebindings
		ClearOverrideBindings(pager) 

		-- retrieve button id
		local buttonID = button:GetID()

		-- figure out the binding action
		local bindingAction = ("BONUSACTIONBUTTON%.0f"):format(buttonID)

		-- store the binding action name on the button
		button.bindingAction = bindingAction

		-- iterate through the registered keys for the action
		for keyNumber = 1, select("#", GetBindingKey(bindingAction)) do 

			-- get a key for the action
			local key = select(keyNumber, GetBindingKey(bindingAction))
			if (key and (key ~= "")) then
				-- We need both right- and left click functionality on pet buttons
				SetOverrideBindingClick(pager, false, key, button:GetName()) -- assign the key to our own button
			end	
		end
		
	end
end 

-- This will cause multiple updates when library is updated. Hmm....
hooksecurefunc("ActionButton_UpdateFlyout", function(self, ...)
	if AllButtons[self] then
		self:UpdateFlyout()
	end
end)

-- Module embedding
local embedMethods = {
	SpawnActionButton = true,
	GetActionButtonTooltip = true, 
	GetAllActionButtonsOrdered = true,
	GetAllActionButtonsByType = true,
	UpdateActionButtonBindings = true
}

LibSecureButton.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibSecureButton.embeds) do
	LibSecureButton:Embed(target)
end
