local LibSpellHighlight = Wheel:Set("LibSpellHighlight", -1)
if (not LibSpellHighlight) then
	return
end

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibSpellHighlight requires LibEvent to be loaded.")

local LibMessage = Wheel("LibMessage")
assert(LibMessage, "LibSpellHighlight requires LibMessage to be loaded.")

local LibAura = Wheel("LibAura")
assert(LibAura, "LibSpellHighlight requires LibAura to be loaded.")

-- Embed functionality into this
LibEvent:Embed(LibSpellHighlight)
LibMessage:Embed(LibSpellHighlight)
LibAura:Embed(LibSpellHighlight)

-- Lua API
local _G = _G
local assert = assert
local bit_band = bit.band
local debugstack = debugstack
local error = error
local select = select
local string_join = string.join
local string_match = string.match
local table_wipe = table.wipe
local type = type

-- WoW API
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local GetComboPoints = GetComboPoints
local GetSpellInfo = GetSpellInfo
local IsPlayerSpell = IsPlayerSpell
local IsUsableSpell = IsUsableSpell
local UnitClass = UnitClass
local UnitCreatureType = UnitCreatureType
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsFriend = UnitIsFriend
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType

-- Doing it this way to make the transition to library later on easier
LibSpellHighlight.embeds = LibSpellHighlight.embeds or {} 
LibSpellHighlight.activeHighlights = LibSpellHighlight.activeHighlights or {} -- current active highlights spellIDs and their highlight type
LibSpellHighlight.activeHighlightsByAuraID = LibSpellHighlight.activeHighlightsByAuraID or {}
LibSpellHighlight.highlightSpellsByAuraID = LibSpellHighlight.highlightSpellsByAuraID or {} -- reactive auras and actionbar highlight spells
LibSpellHighlight.highlightTypeByAuraID = LibSpellHighlight.highlightTypeByAuraID or {} -- character auraID to actionbar highlight type
LibSpellHighlight.highlightTypeBySpellID = LibSpellHighlight.highlightTypeBySpellID or {}
LibSpellHighlight.reactiveSpellsBySpellID = LibSpellHighlight.reactiveSpellsBySpellID or {}
LibSpellHighlight.comboFinishersBySpellID = LibSpellHighlight.comboFinishersBySpellID or {}
LibSpellHighlight.spellIDToAuraID = LibSpellHighlight.spellIDToAuraID or {} -- table to convert spellID to triggering auraID
LibSpellHighlight.runningTimers = LibSpellHighlight.runningTimers or {} -- currently running timers

-- Frame tracking timers
LibSpellHighlight.frame = LibSpellHighlight.frame or CreateFrame("Frame") 

-- Shortcuts
local Frame = LibSpellHighlight.frame
local Timers = LibSpellHighlight.runningTimers
local ActiveHighlights = LibSpellHighlight.activeHighlights
local ActiveHighlightsByAuraID = LibSpellHighlight.activeHighlightsByAuraID
local HighlightSpellsByAuraID = LibSpellHighlight.highlightSpellsByAuraID
local HighlightTypeByAuraID = LibSpellHighlight.highlightTypeByAuraID
local HighlightTypeBySpellID = LibSpellHighlight.highlightTypeBySpellID
local ReactiveSpellsBySpellID = LibSpellHighlight.reactiveSpellsBySpellID
local ComboFinishersBySpellID = LibSpellHighlight.comboFinishersBySpellID
local SpellIDToAuraID = LibSpellHighlight.spellIDToAuraID

-- Reset caches in case of library upgrade
table_wipe(ComboFinishersBySpellID)
table_wipe(HighlightSpellsByAuraID)
table_wipe(HighlightTypeByAuraID)
table_wipe(HighlightTypeBySpellID)
table_wipe(ReactiveSpellsBySpellID)

-- Kill off any existing events in case of a library upgrade
LibSpellHighlight:UnregisterAllEvents()
LibSpellHighlight:UnregisterAllMessages()

-- Player Constants
local _,playerClass = UnitClass("player")
local playerGUID = UnitGUID("player")

-- Sourced from BlizzardInterfaceResources/Resources/EnumerationTables.lua
local SPELL_POWER_COMBO_POINTS = Enum.PowerType.ComboPoints
local SPELL_POWER_ENERGY = Enum.PowerType.Energy

-- Sourced from FrameXML/TargetFrame.lua
local MAX_COMBO_POINTS = MAX_COMBO_POINTS

-- Sourced from FrameXML/BuffFrame.lua
local BUFF_MAX_DISPLAY = BUFF_MAX_DISPLAY

-- Sourced from FrameXML/Constants.lua
local COMBATLOG_OBJECT_AFFILIATION_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE

-- Localized spell- and creature type names
-- https://wow.gamepedia.com/API_UnitCreatureType
local gameLocale = GetLocale()
local L = {
	Creature_Demon = ({
		enUS = "Demon",
		deDE = "Dämon",
		esES = "Demonio",
		esMX = "Demonio",
		frFR = "Démon",
		itIT = "Demone",
		ptBR = "Demônio",
		ruRU = "Демон",
		koKR = "악마",
		zhCN = "恶魔",
		zhTW = "惡魔"
	})[gameLocale],

	Creature_Undead = ({
		enUS = "Undead",
		deDE = "Untoter",
		esES = "No-muerto",
		esMX = "No-muerto",
		frFR = "Mort-vivant",
		itIT = "Non Morto",
		ptBR = "Renegado",
		ruRU = "Нежить",
		koKR = "언데드",
		zhCN = "亡灵",
		zhTW = "不死族"
	})[gameLocale],

	Spell_Counterattack = GetSpellInfo(19306),
	Spell_Execute = GetSpellInfo(20662),
	Spell_Exorcism = GetSpellInfo(879),
	Spell_HammerOfWrath = GetSpellInfo(24239),
	Spell_MongooseBite = GetSpellInfo(1495),
	Spell_Nightfall = GetSpellInfo(18094),
	Spell_Overpower = GetSpellInfo(7384),
	Spell_Revenge = GetSpellInfo(6572),
	Spell_Riposte = GetSpellInfo(14251),
	Spell_ShadowBolt = GetSpellInfo(686)
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

-- Public API
----------------------------------------------------
-- Strict boolean return values
LibSpellHighlight.IsSpellOverlayed = function(self, spellID)
	-- Check for active spellIDs
	if (ActiveHighlights[spellID]) then
		return true
	else
		-- Check if an aura connected to the spellID is active
		local auraID = SpellIDToAuraID[spellID]
		if (auraID) and (ActiveHighlightsByAuraID[auraID]) then
			return true
		end
	end
	return false
end

-- Can be used in the same manner as the above,
-- but this one returns the overlay type or nil instead of strictly booleans.
LibSpellHighlight.GetSpellOverlayType = function(self, spellID)
	-- Check for active spellIDs
	if (ActiveHighlights[spellID]) then
		local highlightType = HighlightTypeBySpellID[spellID]
		if (highlightType) then
			return highlightType
		end
	else
		-- Check if an aura connected to the spellID is active
		local auraID = SpellIDToAuraID[spellID]
		if (auraID) and (ActiveHighlightsByAuraID[auraID]) then
			return HighlightTypeByAuraID[auraID]
		end
	end
end

-- Library Timers
----------------------------------------------------
-- Constant to track if updates are running
local TimerRunning 

-- Reset the frame, in case this is a library update
Frame:SetScript("OnUpdate", nil)
Frame.timers = Timers

local OnUpdate = function(self, elapsed)
	local numTimers = 0
	for spellID, timeLeft in pairs(self.timers) do
		if (timeLeft - elapsed > 0) then
			self.timers[spellID] = timeLeft - elapsed
			numTimers = numTimers + 1
		else
			self.timers[spellID] = nil
			LibSpellHighlight:DeactivateHighlight(spellID)
		end
	end
	if (numTimers == 0) then
		TimerRunning = nil
		self:SetScript("OnUpdate", nil)
	end
end

LibSpellHighlight.ActivateHighlight = function(self, spellID, duration)
	Timers[spellID] = duration

	self:SendMessage("GP_SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", spellID, HighlightTypeBySpellID[spellID])

	if (not TimerRunning) then
		TimerRunning = true
		Frame:SetScript("OnUpdate", OnUpdate)
	end
end

LibSpellHighlight.DeactivateHighlight = function(self, spellID)
	Timers[spellID] = nil
	self:SendMessage("GP_SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", spellID, HighlightTypeBySpellID[spellID])
end

-- Retrieve the spellID of the highest available rank of a spell.
LibSpellHighlight.GetHighestRankForReactiveSpell = function(self, spellName)
	local reactiveSpellsBySpellID = ReactiveSpellsBySpellID[spellName]
	if (reactiveSpellsBySpellID) then
		for i = #reactiveSpellsBySpellID,1,-1 do
			local spellID = reactiveSpellsBySpellID[i]
			if (IsPlayerSpell(spellID)) then
				return spellID 
			end
		end
	end
end

-- Library Updates
----------------------------------------------------
local currentTriggerAuras = {}
local comboPointsAreMaxed

-- Druid, Warlock
LibSpellHighlight.UpdateAuras = function(self, event, ...)
	local unit = ...
	if (event == "GP_UNIT_AURA") and (unit ~= "player") then
		return
	end

	-- This is a local temporary list of highlights,
	-- which we need to reset on every iteration.
	for auraID in pairs(currentTriggerAuras) do
		currentTriggerAuras[auraID] = nil
	end

	-- Iterate for current highlights
	for i = 1, BUFF_MAX_DISPLAY do 

		-- Retrieve buff information
		local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, auraID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = self:GetUnitBuff("player", i, "HELPFUL PLAYER")

		-- No name means no more buffs matching the filter
		if (not name) then
			break
		end

		local highlightsByAuraID = HighlightSpellsByAuraID[auraID]
		if (highlightsByAuraID) then

			-- Add it to this iteration's highlights.
			currentTriggerAuras[auraID] = true

			if (not ActiveHighlightsByAuraID[auraID]) then
				ActiveHighlightsByAuraID[auraID] = true

				for spellID in pairs(highlightsByAuraID) do -- iterate spell list
					self:ActivateHighlight(spellID)
				end
			end
		end
		
	end

	-- Disable active highlights that no longer match the current iteration.
	for auraID in pairs(ActiveHighlightsByAuraID) do -- iterate the previous aura iteration
		if (not currentTriggerAuras[auraID]) then -- compare to the current iteration

			-- Clear out this entry
			ActiveHighlightsByAuraID[auraID] = nil

			local highlightsByAuraID = HighlightSpellsByAuraID[auraID] -- get spell list
			if (highlightsByAuraID) then
				for spellID in pairs(highlightsByAuraID) do -- iterate spell list
					self:DeactivateHighlight(spellID)
				end
			end
		end
	end
end

-- Druid, Rogue
LibSpellHighlight.UpdateComboPoints = function(self, event, ...)
	local min = UnitPower("player", SPELL_POWER_COMBO_POINTS)
	local max = UnitPowerMax("player", SPELL_POWER_COMBO_POINTS)
	if (min == max) then
		if (not comboPointsAreMaxed) then
			comboPointsAreMaxed = true
			for spellID in pairs(ComboFinishersBySpellID) do
				if (not ActiveHighlights[spellID]) then
					ActiveHighlights[spellID] = true
					self:ActivateHighlight(spellID)
				end
			end
		end
	else
		if (comboPointsAreMaxed) then
			comboPointsAreMaxed = nil
			for spellID in pairs(ComboFinishersBySpellID) do
				if (ActiveHighlights[spellID]) then
					ActiveHighlights[spellID] = nil
					self:DeactivateHighlight(spellID)
				end
			end
		end
	end
end

-- Hunter
LibSpellHighlight.UpdateCounterAttack = function(self, event, ...)
	local timestamp, eventType, hideCaster,
	sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
	destGUID, destName, destFlags, destRaidFlags,
	swingMissType, spellName, _, spellMissType, swingBlocked = CombatLogGetCurrentEventInfo()

	local isSrcPlayer = bit_band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) == COMBATLOG_OBJECT_AFFILIATION_MINE
	local isDstPlayer = destGUID == UnitGUID("player")

	if (isDstPlayer) then
		if (eventType == "SWING_MISSED") or (eventType == "SPELL_MISSED") then
			local missedType
			if (eventType == "SWING_MISSED") then
				missedType = swingMissType
			elseif (eventType == "SPELL_MISSED") then
				missedType = spellMissType
			end
			if (missedType == "PARRY") then
				local spellID = self:GetHighestRankForReactiveSpell(L.Spell_Counterattack)
				if (spellID) then
					ActiveHighlights[spellID] = true
					self:ActivateHighlight(spellID, 5)
				end
			end
		end
	end
	
	if (isSrcPlayer) and (eventType == "SPELL_CAST_SUCCESS") and (spellName == L.Spell_Counterattack) then
		local spellID = self:GetHighestRankForReactiveSpell(L.Spell_Counterattack)
		if (spellID) then
			ActiveHighlights[spellID] = nil
			self:DeactivateHighlight(spellID)
		end
	end
end

-- Warrior
LibSpellHighlight.UpdateExecute = function(self, event, ...)
	local spellID = self:GetHighestRankForReactiveSpell(L.Spell_Execute)
	if (spellID) then
		local enable
		if (UnitExists("target")) and (not UnitIsFriend("player", "target")) then
			local min = UnitHealth("target")
			local max = UnitHealthMax("target")
			if (min > 0) and (max > 0) and ((min/max < .2) or IsUsableSpell(spellID)) then
				enable = true
			end
		end
		if (enable) then
			ActiveHighlights[spellID] = true
			self:ActivateHighlight(spellID, 10)
		else
			ActiveHighlights[spellID] = nil
			self:DeactivateHighlight(spellID)
		end
	end
end

-- Paladin
LibSpellHighlight.UpdateExorcism = function(self, event, ...)
	-- 5 sec duration
end

-- Paladin
LibSpellHighlight.UpdateHammerOfWrath = function(self, event, ...)
	local spellID = self:GetHighestRankForReactiveSpell(L.Spell_HammerOfWrath)
	if (spellID) then
		local enable
		if (UnitExists("target")) and (not UnitIsFriend("player", "target")) then
			local min = UnitHealth("target")
			local max = UnitHealthMax("target")
			if (min > 0) and (max > 0) and (min/max < .2) then
				enable = true
			end
		end
		if (enable) then
			ActiveHighlights[spellID] = true
			self:ActivateHighlight(spellID, 10)
		else
			ActiveHighlights[spellID] = nil
			self:DeactivateHighlight(spellID)
		end
	end
end

-- Hunter
LibSpellHighlight.UpdateMongooseBite = function(self, event, ...)
	local timestamp, eventType, hideCaster,
	sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
	destGUID, destName, destFlags, destRaidFlags,
	swingMissType, spellName, _, spellMissType, swingBlocked = CombatLogGetCurrentEventInfo()

	local isSrcPlayer = bit_band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) == COMBATLOG_OBJECT_AFFILIATION_MINE
	local isDstPlayer = destGUID == UnitGUID("player")

	if (isDstPlayer) then
		if (eventType == "SWING_MISSED") or (eventType == "SPELL_MISSED") then
			local missedType
			if (eventType == "SWING_MISSED") then
				missedType = swingMissType
			elseif (eventType == "SPELL_MISSED") then
				missedType = spellMissType
			end
			if (missedType == "DODGE") then
				local spellID = self:GetHighestRankForReactiveSpell(L.Spell_MongooseBite)
				if (spellID) then
					ActiveHighlights[spellID] = true
					self:ActivateHighlight(spellID, 5)
				end
			end
		end
	end
	
	if (isSrcPlayer) and (eventType == "SPELL_CAST_SUCCESS") and (spellName == L.Spell_MongooseBite) then
		local spellID = self:GetHighestRankForReactiveSpell(L.Spell_MongooseBite)
		if (spellID) then
			ActiveHighlights[spellID] = nil
			self:DeactivateHighlight(spellID)
		end
	end
end

-- Warrior
LibSpellHighlight.UpdateOverpower = function(self, event, ...)
	local timestamp, eventType, hideCaster,
	sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
	destGUID, destName, destFlags, destRaidFlags,
	swingMissType, spellName, _, spellMissType = CombatLogGetCurrentEventInfo()

	local isSrcPlayer = bit_band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) == COMBATLOG_OBJECT_AFFILIATION_MINE

	if (isSrcPlayer) then
		if (eventType == "SWING_MISSED") or (eventType == "SPELL_MISSED") then
			local missedType
			if (eventType == "SWING_MISSED") then
				missedType = swingMissType
			elseif (eventType == "SPELL_MISSED") then
				missedType = spellMissType
			end
			if (missedType == "DODGE") then
				local spellID = self:GetHighestRankForReactiveSpell(L.Spell_Overpower)
				if (spellID) then
					ActiveHighlights[spellID] = true
					self:ActivateHighlight(spellID, 5)
				end
			end
		elseif (eventType == "SPELL_CAST_SUCCESS") then
			if (spellName == L.Spell_Overpower) then
				local spellID = self:GetHighestRankForReactiveSpell(L.Spell_Overpower)
				if (spellID) then
					ActiveHighlights[spellID] = nil
					self:DeactivateHighlight(spellID)
				end
			end
		end
	end
end

-- Warrior
LibSpellHighlight.UpdateRevenge = function(self, event, ...)
	local timestamp, eventType, hideCaster,
	sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
	destGUID, destName, destFlags, destRaidFlags,
	swingMissType, spellName, _, spellMissType, swingBlocked = CombatLogGetCurrentEventInfo()

	local isSrcPlayer = bit_band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) == COMBATLOG_OBJECT_AFFILIATION_MINE
	local isDstPlayer = destGUID == UnitGUID("player")

	if (isDstPlayer) then
		if (eventType == "SWING_MISSED") or (eventType == "SPELL_MISSED") then
			local missedType
			if (eventType == "SWING_MISSED") then
				missedType = swingMissType
			elseif (eventType == "SPELL_MISSED") then
				missedType = spellMissType
			end
			if (missedType == "BLOCK") or (missedType == "DODGE") or (missedType == "PARRY") then
				local spellID = self:GetHighestRankForReactiveSpell(L.Spell_Revenge)
				if (spellID) then
					ActiveHighlights[spellID] = true
					self:ActivateHighlight(spellID, 5)
				end
			end
		elseif (eventType == "SWING_DAMAGE") and (swingBlocked) then
			local spellID = self:GetHighestRankForReactiveSpell(L.Spell_Revenge)
			if (spellID) then
				ActiveHighlights[spellID] = true
				self:ActivateHighlight(spellID, 5)
			end
		end
	end

	if (isSrcPlayer) and (eventType == "SPELL_CAST_SUCCESS") and (spellName == L.Spell_Revenge) then
		local spellID = self:GetHighestRankForReactiveSpell(L.Spell_Revenge)
		if (spellID) then
			ActiveHighlights[spellID] = nil
			self:DeactivateHighlight(spellID)
		end
	end
end

-- Rogue
LibSpellHighlight.UpdateRiposte = function(self, event, ...)
	local timestamp, eventType, hideCaster,
	sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
	destGUID, destName, destFlags, destRaidFlags,
	swingMissType, spellName, _, spellMissType, swingBlocked = CombatLogGetCurrentEventInfo()

	local isSrcPlayer = bit_band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) == COMBATLOG_OBJECT_AFFILIATION_MINE
	local isDstPlayer = destGUID == UnitGUID("player")

	if (isDstPlayer) and ((eventType == "SWING_MISSED") or (eventType == "SPELL_MISSED")) then
		local missedType
		if (eventType == "SWING_MISSED") then
			missedType = swingMissType
		elseif (eventType == "SPELL_MISSED") then
			missedType = spellMissType
		end
		if (missedType == "PARRY") then
			local spellID = self:GetHighestRankForReactiveSpell(L.Spell_Riposte)
			if (spellID) then
				ActiveHighlights[spellID] = true
				self:ActivateHighlight(spellID, 5)
			end
		end
	end

	if (isSrcPlayer) and (eventType == "SPELL_CAST_SUCCESS") and (spellName == L.Spell_Riposte) then
		local spellID = self:GetHighestRankForReactiveSpell(L.Spell_Riposte)
		if (spellID) then
			ActiveHighlights[spellID] = nil
			self:DeactivateHighlight(spellID)
		end
	end
end

-- An extra step mainly for convenience here.
LibSpellHighlight.RegisterCombatLogEvent = function(self, spellName, methodName)
	if (self:GetHighestRankForReactiveSpell(spellName)) then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", methodName)
	end
end

LibSpellHighlight.UpdateEvents = function(self, event, ...)
	self:UnregisterAllEvents()
	self:UnregisterAllMessages()

	-- Allow it to run on the first occurence
	-- of this event after any sort of UI reset.
	-- Not needed after teleports or instance zoning.
	if (event == "PLAYER_ENTERING_WORLD") then
		local isLogin, isReload = ...
		if not(isLogin or isReload) then
			return
		end
	end

	if (playerClass == "DRUID") then
		-- Track clear casting aura for expensive spell highlight.
		self:RegisterMessage("GP_UNIT_AURA", "UpdateAuras")

		-- Track combo points for finisher highlight.
		self:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateComboPoints")
		self:RegisterUnitEvent("UNIT_MAXPOWER", "UpdateComboPoints", "player")
		self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "UpdateComboPoints", "player")

		-- Initial update of highlights.
		self:UpdateAuras()
		self:UpdateComboPoints()
	
	elseif (playerClass == "HUNTER") then
		-- Register combat log parsing if abilities exist.
		self:RegisterCombatLogEvent(L.Spell_Counterattack, "UpdateCounterAttack")
		self:RegisterCombatLogEvent(L.Spell_MongooseBite, "UpdateMongooseBite")
	
	elseif (playerClass == "ROGUE") then
		-- Track combo points for finisher highlight.
		self:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateComboPoints")
		self:RegisterUnitEvent("UNIT_MAXPOWER", "UpdateComboPoints", "player")
		self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "UpdateComboPoints", "player")

		-- Register combat log parsing if abilities exist.
		self:RegisterCombatLogEvent(L.Spell_Riposte, "UpdateRiposte")

		-- Initial update of highlights.
		self:UpdateComboPoints()

	elseif (playerClass == "PALADIN") then
		if (self:GetHighestRankForReactiveSpell(L.Spell_HammerOfWrath)) then
			-- Track target health for activations.
			self:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", "UpdateHammerOfWrath", "target")
			self:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateHammerOfWrath")

			-- Initial update of highlights.
			self:UpdateHammerOfWrath()
		end

		-- Register combat log parsing if abilities exist.
		self:RegisterCombatLogEvent(L.Spell_Exorcism, "UpdateExorcism")

	elseif (playerClass == "WARLOCK") then
		if (self:GetHighestRankForReactiveSpell(L.Spell_Nightfall)) then
			-- Track Shadow Trance for Shadow Bolt highlighting.
			self:RegisterMessage("GP_UNIT_AURA", "UpdateAuras")

			-- Initial update of highlights.
			self:UpdateAuras()
		end

	elseif (playerClass == "WARRIOR") then
		if (self:GetHighestRankForReactiveSpell(L.Spell_Execute)) then
			-- Track target health for activations.
			self:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", "UpdateExecute", "target")
			self:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateExecute")

			-- Initial update of highlights.
			self:UpdateExecute()
		end

		-- Register combat log parsing if abilities exist.
		self:RegisterCombatLogEvent(L.Spell_Overpower, "UpdateOverpower")
		self:RegisterCombatLogEvent(L.Spell_Revenge, "UpdateRevenge")
	end
end

-- Upgrade existing embeds, if any
for target in pairs(LibSpellHighlight.embeds) do
	LibSpellHighlight:Embed(target)
end

if (playerClass == "DRUID") then

	-- Omen of Clarity (Proc)
	HighlightTypeByAuraID[16870] = "CLEARCAST"
	HighlightSpellsByAuraID[16870] = {
		[6807] = true, -- Maul (Rank 1)
		[6808] = true, -- Maul (Rank 2)
		[6809] = true, -- Maul (Rank 3)
		[8972] = true, -- Maul (Rank 4)
		[9745] = true, -- Maul (Rank 5)
		[9880] = true, -- Maul (Rank 6)
		[9881] = true, -- Maul (Rank 7)
		[6785] = true, -- Ravage (Rank 1)
		[6787] = true, -- Ravage (Rank 2)
		[9866] = true, -- Ravage (Rank 3)
		[9867] = true, -- Ravage (Rank 4)
		[8936] = true, -- Regrowth (Rank 1)
		[8938] = true, -- Regrowth (Rank 2)
		[8939] = true, -- Regrowth (Rank 3)
		[8940] = true, -- Regrowth (Rank 4)
		[8941] = true, -- Regrowth (Rank 5)
		[9750] = true, -- Regrowth (Rank 6)
		[9856] = true, -- Regrowth (Rank 7)
		[9857] = true, -- Regrowth (Rank 8)
		[9858] = true, -- Regrowth (Rank 9)
		[5221] = true, -- Shred (Rank 1)
		[6800] = true, -- Shred (Rank 2)
		[8992] = true, -- Shred (Rank 3)
		[9829] = true, -- Shred (Rank 4)
		[9830] = true  -- Shred (Rank 5)
	}

	ComboFinishersBySpellID[22568] = true -- Ferocious Bite (Rank 1)
	ComboFinishersBySpellID[22827] = true -- Ferocious Bite (Rank 2)
	ComboFinishersBySpellID[22828] = true -- Ferocious Bite (Rank 3)
	ComboFinishersBySpellID[22829] = true -- Ferocious Bite (Rank 4)
	ComboFinishersBySpellID[31018] = true -- Ferocious Bite (Rank 5) (The Beast - Content Phase 6)
	ComboFinishersBySpellID[ 1079] = true -- Rip (Rank 1)
	ComboFinishersBySpellID[ 9492] = true -- Rip (Rank 2)
	ComboFinishersBySpellID[ 9493] = true -- Rip (Rank 3)
	ComboFinishersBySpellID[ 9752] = true -- Rip (Rank 4)
	ComboFinishersBySpellID[ 9894] = true -- Rip (Rank 5)
	ComboFinishersBySpellID[ 9896] = true -- Rip (Rank 6)

end

if (playerClass == "HUNTER") then
	ReactiveSpellsBySpellID[L.Spell_Counterattack] = { 19306, 20909, 20910 }
	ReactiveSpellsBySpellID[L.Spell_MongooseBite] = { 1495, 14269, 14270, 14271 }
end 

if (playerClass == "PALADIN") then
	ReactiveSpellsBySpellID[L.Spell_Exorcism] = { 879, 5614, 5615, 10312, 10313, 10314 }
	ReactiveSpellsBySpellID[L.Spell_HammerOfWrath] = { 24239, 24274, 24275 }
end 

if (playerClass == "ROGUE") then
	ReactiveSpellsBySpellID[L.Spell_Riposte] = { 14251 }

	ComboFinishersBySpellID[ 8647] = true -- Expose Armor (Rank 1)
	ComboFinishersBySpellID[ 8649] = true -- Expose Armor (Rank 2)
	ComboFinishersBySpellID[ 8650] = true -- Expose Armor (Rank 3)
	ComboFinishersBySpellID[11197] = true -- Expose Armor (Rank 4)
	ComboFinishersBySpellID[11198] = true -- Expose Armor (Rank 5)
	ComboFinishersBySpellID[ 2098] = true -- Eviscerate (Rank 1)
	ComboFinishersBySpellID[ 6760] = true -- Eviscerate (Rank 2)
	ComboFinishersBySpellID[ 6761] = true -- Eviscerate (Rank 3)
	ComboFinishersBySpellID[ 6762] = true -- Eviscerate (Rank 4)
	ComboFinishersBySpellID[ 8623] = true -- Eviscerate (Rank 5)
	ComboFinishersBySpellID[ 8624] = true -- Eviscerate (Rank 6)
	ComboFinishersBySpellID[11299] = true -- Eviscerate (Rank 7)
	ComboFinishersBySpellID[11300] = true -- Eviscerate (Rank 8)
	ComboFinishersBySpellID[31016] = true -- Eviscerate (Rank 9) (Blackhand Assasin - Content Phase 6)
	ComboFinishersBySpellID[ 1943] = true -- Rupture (Rank 1)
	ComboFinishersBySpellID[ 8639] = true -- Rupture (Rank 2)
	ComboFinishersBySpellID[ 8640] = true -- Rupture (Rank 3)
	ComboFinishersBySpellID[11273] = true -- Rupture (Rank 4)
	ComboFinishersBySpellID[11274] = true -- Rupture (Rank 5)
	ComboFinishersBySpellID[11275] = true -- Rupture (Rank 6)
	ComboFinishersBySpellID[ 5171] = true -- Slice and Dive (Rank 1)
	ComboFinishersBySpellID[ 6774] = true -- Slice and Dive (Rank 2)

end 

if (playerClass == "WARLOCK") then

	HighlightTypeByAuraID[17941] = "REACTIVE"
	HighlightSpellsByAuraID[17941] = { -- Shadow Trance
		[  686] = true, -- Shadow Bolt (Rank 1)
		[  695] = true, -- Shadow Bolt (Rank 2)
		[  705] = true, -- Shadow Bolt (Rank 3)
		[ 1088] = true, -- Shadow Bolt (Rank 4)
		[ 1106] = true, -- Shadow Bolt (Rank 5)
		[ 7641] = true, -- Shadow Bolt (Rank 6)
		[11659] = true, -- Shadow Bolt (Rank 7)
		[11660] = true, -- Shadow Bolt (Rank 8)
		[11661] = true, -- Shadow Bolt (Rank 9)
		[25307] = true, -- Shadow Bolt (Rank 10)
	}
	ReactiveSpellsBySpellID[L.Spell_Nightfall] = { 18094, 18095 }
end 

if (playerClass == "WARRIOR") then
	ReactiveSpellsBySpellID[L.Spell_Execute] = { 5308, 20658, 20660, 20661, 20662 }
	ReactiveSpellsBySpellID[L.Spell_Overpower] = { 7384, 7887, 11584, 11585 }
	--ReactiveSpellsBySpellID[L.Spell_Overpower] = { 284 } -- Heroic Strike (Rank 2)
	ReactiveSpellsBySpellID[L.Spell_Revenge] = { 6572, 6574, 7379, 11600, 11601, 25288 }
end

-- Cache all spellIDs that have a triggering auraID,
-- and store their overlay types.
for auraID,spells in pairs(HighlightSpellsByAuraID) do
	for spellID in pairs(spells) do
		SpellIDToAuraID[spellID] = auraID
		HighlightTypeBySpellID[spellID] = HighlightTypeByAuraID[auraID]
	end
end

-- Store overlay type of reative spells
for spellName, spells in pairs(ReactiveSpellsBySpellID) do
	for _,spellID in ipairs(spells) do
		HighlightTypeBySpellID[spellID] = "REACTIVE"
	end
end

-- Store overlay type of combo point finishers
for spellID in pairs(ComboFinishersBySpellID) do
	HighlightTypeBySpellID[spellID] = "FINISHER"
end

-- Module embedding
local embedMethods = {
	IsSpellOverlayed = true,
	GetSpellOverlayType = true
}

LibSpellHighlight.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Register initialization events
if (playerClass == "DRUID") then

	LibSpellHighlight:RegisterEvent("SPELLS_CHANGED", "UpdateEvents")
	LibSpellHighlight:RegisterEvent("UNIT_DISPLAYPOWER", "UpdateEvents")
	LibSpellHighlight:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateEvents")

elseif (playerClass == "HUNTER")
	or (playerClass == "PALADIN")
	or (playerClass == "ROGUE")
	or (playerClass == "WARLOCK")
	or (playerClass == "WARRIOR") then

	LibSpellHighlight:RegisterEvent("SPELLS_CHANGED", "UpdateEvents")
	LibSpellHighlight:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateEvents")
end
