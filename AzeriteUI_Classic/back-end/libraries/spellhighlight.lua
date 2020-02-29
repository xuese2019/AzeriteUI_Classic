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
local type = type

-- WoW API
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
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

-- Doing it this way to make the transition to library later on easier
LibSpellHighlight.embeds = LibSpellHighlight.embeds or {} 
LibSpellHighlight.activeHighlights = LibSpellHighlight.activeHighlights or {}
LibSpellHighlight.highlightSpellsByAuraID = LibSpellHighlight.highlightSpellsByAuraID or {} 
LibSpellHighlight.highlightTypeByAuraID = LibSpellHighlight.highlightTypeByAuraID or {} 
LibSpellHighlight.reactiveSpells = LibSpellHighlight.reactiveSpells or {}

-- Shortcuts
local ActiveHighlights = LibSpellHighlight.activeHighlights
local HighlightSpellsByAuraID = LibSpellHighlight.highlightSpellsByAuraID
local HighlightTypeByAuraID = LibSpellHighlight.highlightTypeByAuraID
local ReactiveSpells = LibSpellHighlight.reactiveSpells

-- Constants
local gameLocale = GetLocale()
local _,playerClass = UnitClass("player")
local playerGUID = UnitGUID("player")

local AFFILIATION_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE

-- Localized spell- and creature type names
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
LibSpellHighlight.IsSpellOverlayed = function(self, spellID)
	for auraID in pairs(ActiveHighlights) do
		local highlightsByAuraID = HighlightSpellsByAuraID[auraID]
		if (highlightsByAuraID) and (highlightsByAuraID[spellID]) then
			return true
		end
	end
end

LibSpellHighlight.GetSpellOverlayType = function(self, spellID)
	for auraID in pairs(ActiveHighlights) do
		local highlightsByAuraID = HighlightSpellsByAuraID[auraID]
		if (highlightsByAuraID) and (highlightsByAuraID[spellID]) then
			return HighlightTypeByAuraID[auraID]
		end
	end
end

-- Library Updates
----------------------------------------------------
do
	local currentHighlights = {} -- only used as a cache for this method
	LibSpellHighlight.UpdateHighlightsByAura = function(self)
		for auraID in pairs(currentHighlights) do
			currentHighlights[auraID] = nil
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

				-- Add it to current highlights.
				currentHighlights[auraID] = true

				-- Add to active and send an actication message if needed.
				-- Only do this once per discovery.
				for auraID,highlightsByAuraID in pairs(HighlightSpellsByAuraID) do
					if (not ActiveHighlights[auraID]) then
						ActiveHighlights[auraID] = true
						for spellID in pairs(highlightsByAuraID) do
							self:SendMessage("GP_SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", spellID, HighlightTypeByAuraID[auraID])
						end
					end
				end
			end
			
		end

		-- Disable active highlights that no longer match the current ones.
		for auraID in pairs(ActiveHighlights) do
			if (not currentHighlights[auraID]) then
				ActiveHighlights[auraID] = nil
				for spellID in pairs(HighlightSpellsByAuraID[auraID]) do
					self:SendMessage("GP_SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", spellID, HighlightTypeByAuraID[auraID])
				end
			end
		end
		
	end
end

LibSpellHighlight.UpdateEvents = function(self)
	if (playerClass == "PALADIN") then
		if (self:GetHighestRankForReactiveSpell(L.Spell_Exorcism)) then

		end
	end
end

LibSpellHighlight.OnEvent = function(self, event, unit, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		self:UpdateHighlightsByAura()

	elseif (event == "GP_UNIT_AURA") then
		if (unit == "player") then
			self:UpdateHighlightsByAura()
		end
	end
end

LibSpellHighlight:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
LibSpellHighlight:RegisterMessage("GP_UNIT_AURA", "OnEvent")

if (playerClass == "HUNTER")
or (playerClass == "PALADIN")
or (playerClass == "ROGUE")
or (playerClass == "WARLOCK")
or (playerClass == "WARRIOR") then
	LibSpellHighlight:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateEvents")
	LibSpellHighlight:RegisterEvent("SPELLS_CHANGED", "UpdateEvents")
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

end

if (playerClass == "HUNTER") then
	ReactiveSpells[L.Spell_Counterattack] = { 19306, 20909, 20910 }
	ReactiveSpells[L.Spell_MongooseBite] = { 1495, 14269, 14270, 14271 }
end 

if (playerClass == "PALADIN") then
	ReactiveSpells[L.Spell_Exorcism] = { 879, 5614, 5615, 10312, 10313, 10314 }
	ReactiveSpells[L.Spell_HammerOfWrath] = { 24239, 24274, 24275 }
end 

if (playerClass == "ROGUE") then
	ReactiveSpells[L.Spell_Riposte] = { 14251 }
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

end 

if (playerClass == "WARRIOR") then
	ReactiveSpells[L.Spell_Execute] = { 5308, 20658, 20660, 20661, 20662 }
	ReactiveSpells[L.Spell_Overpower] = { 7384, 7887, 11584, 11585 }
	ReactiveSpells[L.Spell_Revenge] = { 6572, 6574, 7379, 11600, 11601, 25288 }
end

LibSpellHighlight.GetHighestRankForReactiveSpell = function(spellName)
	local reactiveSpells = ReactiveSpells[spellName]
	if (reactiveSpells) then
		for i = #reactiveSpells,1,-1 do
			local spellID = reactiveSpells[i]
			if (IsPlayerSpell(spellID)) then
				return spellID 
			end
		end
	end
end
