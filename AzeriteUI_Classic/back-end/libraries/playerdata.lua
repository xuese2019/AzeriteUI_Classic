local LibPlayerData = CogWheel:Set("LibPlayerData", 9)
if (not LibPlayerData) then	
	return
end

-- Lua API
local _G = _G
local assert = assert
local date = date
local debugstack = debugstack
local error = error
local pairs = pairs
local select = select
local string_join = string.join
local string_match = string.match
local tonumber = tonumber
local type = type

-- WoW API
local GetAccountExpansionLevel = _G.GetAccountExpansionLevel
local GetExpansionLevel = _G.GetExpansionLevel
local GetSpecialization = _G.GetSpecialization
local GetSpecializationInfo = _G.GetSpecializationInfo
local GetWatchedFactionInfo = _G.GetWatchedFactionInfo
local IsXPUserDisabled = _G.IsXPUserDisabled
local UnitClass = _G.UnitClass
local UnitLevel = _G.UnitLevel

-- Library registries
---------------------------------------------------------------------	
LibPlayerData.embeds = LibPlayerData.embeds or {}
LibPlayerData.frame = LibPlayerData.frame or CreateFrame("Frame")
LibPlayerData.unitCache = LibPlayerData.unitCache or {}

-- Local constants & tables
---------------------------------------------------------------------	
-- Constant to track current player role
local CURRENT_ROLE

-- Specific per class buffs we wish to see
local _,playerClass = UnitClass("player")

-- List of damage-only classes
local classIsDamage = { 
	HUNTER = true, 
	MAGE = true, 
	ROGUE = true, 
	WARLOCK = true 
}

-- List of classes that can tank
local classCanTank = { 
	DRUID = true, 
	PALADIN = true, 
	WARRIOR = true 
}

-- Setup our frame for tracking role events
-- *NOT updated for Classic yet!
if classIsDamage[playerClass] then
	CURRENT_ROLE = "DAMAGER"
	LibPlayerData.frame:SetScript("OnEvent", nil)
	LibPlayerData.frame:UnregisterAllEvents()
else
	CURRENT_ROLE = classCanTank[playerClass] and "TANK" or "DAMAGER"
end 

-- Units blacklisted from health caching
local UnitBlackList = {}

-- Utility Functions
---------------------------------------------------------------------	
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

-- Unit Health Cache
---------------------------------------------------------------------	
LibPlayerData.UnitHealth = function(self)
end

LibPlayerData.UnitHealthMax = function(self)
end

-- Level Functions 
---------------------------------------------------------------------	
-- Most of these are identical, and a clean-up is needed. 
-- They are remnants from the transition from the retail API. 

-- Returns the maximum level the account has access to 
LibPlayerData.GetEffectivePlayerMaxLevel = function() return 60 end

-- Returns the maximum level in the current expansion 
LibPlayerData.GetEffectiveExpansionMaxLevel = function() return 60 end

-- Is the provided level at the account's maximum level?
LibPlayerData.IsUnitLevelAtEffectiveMaxLevel = function() return 60 end

-- Is the provided level at the expansions's maximum level?
LibPlayerData.IsUnitLevelAtEffectiveExpansionMaxLevel = function() return 60 end

-- Is the player at the account's maximum level?
LibPlayerData.IsPlayerAtEffectiveMaxLevel = function() return 60 end

-- Is the player at the expansions's maximum level?
LibPlayerData.IsPlayerAtEffectiveExpansionMaxLevel = function() return 60 end

-- Return whether the player currently can gain XP
LibPlayerData.PlayerHasXP = function() return (UnitLevel("player") < 60) end


-- Role Functions
---------------------------------------------------------------------	
-- Returns whether the player is  tracking a reputation
LibPlayerData.PlayerHasRep = function()
	return GetWatchedFactionInfo() and true or false 
end

LibPlayerData.PlayerCanTank = function()
	return classCanTank[playerClass]
end

LibPlayerData.PlayerIsDamageOnly = function()
	return classIsDamage[playerClass]
end

LibPlayerData.GetPlayerRole = function()
	return CURRENT_ROLE
end

local embedMethods = {
	GetPlayerRole = true, 
	GetEffectivePlayerMaxLevel = true, 
	GetEffectiveExpansionMaxLevel = true, 
	IsPlayerAtEffectiveMaxLevel = true, 
	IsPlayerAtEffectiveExpansionMaxLevel = true, 
	IsUnitLevelAtEffectiveMaxLevel = true, 
	IsUnitLevelAtEffectiveExpansionMaxLevel = true, 
	PlayerHasXP = true, 
	PlayerHasRep = true, 
	PlayerCanTank = true, 
	PlayerIsDamageOnly = true,
	UnitHealth = true, 
	UnitHealthMax = true
}

LibPlayerData.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	LibPlayerData.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibPlayerData.embeds) do
	LibPlayerData:Embed(target)
end

-- Units blacklisted from the health cache
---------------------------------------------------------------------	
UnitBlackList[ 5924] = true -- Disease Cleansing Totem
UnitBlackList[ 2630] = true -- Earthbind Totem
UnitBlackList[ 5879] = true -- Fire Nova Totem
UnitBlackList[ 6110] = true -- Fire Nova Totem II
UnitBlackList[ 6111] = true -- Fire Nova Totem III
UnitBlackList[ 7844] = true -- Fire Nova Totem IV
UnitBlackList[ 7845] = true -- Fire Nova Totem V
UnitBlackList[ 5927] = true -- Fire Resistance Totem
UnitBlackList[ 7424] = true -- Fire Resistance Totem II
UnitBlackList[ 7425] = true -- Fire Resistance Totem III
UnitBlackList[ 5950] = true -- Flametongue Totem
UnitBlackList[ 6012] = true -- Flametongue Totem II
UnitBlackList[ 7423] = true -- Flametongue Totem III
UnitBlackList[10557] = true -- Flametongue Totem IV
UnitBlackList[ 5926] = true -- Frost Resistance Totem
UnitBlackList[ 7412] = true -- Frost Resistance Totem II
UnitBlackList[ 7413] = true -- Frost Resistance Totem III
UnitBlackList[ 7486] = true -- Grace of Air Totem
UnitBlackList[ 7487] = true -- Grace of Air Totem II
UnitBlackList[15463] = true -- Grace of Air Totem III
UnitBlackList[ 5925] = true -- Grounding Totem
UnitBlackList[ 3527] = true -- Healing Stream Totem
UnitBlackList[ 3906] = true -- Healing Stream Totem II
UnitBlackList[ 3907] = true -- Healing Stream Totem III
UnitBlackList[ 3908] = true -- Healing Stream Totem IV
UnitBlackList[ 3909] = true -- Healing Stream Totem V
UnitBlackList[ 5929] = true -- Magma Totem
UnitBlackList[ 7464] = true -- Magma Totem II
UnitBlackList[ 7465] = true -- Magma Totem III
UnitBlackList[ 7466] = true -- Magma Totem IV
UnitBlackList[ 3573] = true -- Mana Spring Totem
UnitBlackList[ 7414] = true -- Mana Spring Totem II
UnitBlackList[ 7415] = true -- Mana Spring Totem III
UnitBlackList[ 7416] = true -- Mana Spring Totem IV
UnitBlackList[11100] = true -- Mana Tide Totem II
UnitBlackList[11101] = true -- Mana Tide Totem III
UnitBlackList[ 7467] = true -- Nature Resistance Totem
UnitBlackList[ 7468] = true -- Nature Resistance Totem II
UnitBlackList[ 7469] = true -- Nature Resistance Totem III
UnitBlackList[ 5923] = true -- Poison Cleansing Totem
UnitBlackList[ 2523] = true -- Searing Totem
UnitBlackList[ 3902] = true -- Searing Totem II
UnitBlackList[ 3903] = true -- Searing Totem III
UnitBlackList[ 3904] = true -- Searing Totem IV
UnitBlackList[ 7400] = true -- Searing Totem V
UnitBlackList[ 7402] = true -- Searing Totem VI
UnitBlackList[ 3968] = true -- Sentry Totem
UnitBlackList[ 3579] = true -- Stoneclaw Totem
UnitBlackList[ 3911] = true -- Stoneclaw Totem II
UnitBlackList[ 3912] = true -- Stoneclaw Totem III
UnitBlackList[ 3913] = true -- Stoneclaw Totem IV
UnitBlackList[ 7398] = true -- Stoneclaw Totem V
UnitBlackList[ 7399] = true -- Stoneclaw Totem VI
UnitBlackList[ 5873] = true -- Stoneskin Totem
UnitBlackList[ 5919] = true -- Stoneskin Totem II
UnitBlackList[ 5920] = true -- Stoneskin Totem III
UnitBlackList[ 7366] = true -- Stoneskin Totem IV
UnitBlackList[ 7367] = true -- Stoneskin Totem V
UnitBlackList[ 7368] = true -- Stoneskin Totem VI
UnitBlackList[ 5874] = true -- Strength of Earth Totem
UnitBlackList[ 5921] = true -- Strength of Earth Totem II
UnitBlackList[ 5922] = true -- Strength of Earth Totem III
UnitBlackList[ 7403] = true -- Strength of Earth Totem IV
UnitBlackList[15464] = true -- Strength of Earth Totem V
UnitBlackList[15803] = true -- Tranquil Air Totem
UnitBlackList[ 5913] = true -- Tremor Totem
UnitBlackList[ 6112] = true -- Windfury Totem
UnitBlackList[ 7483] = true -- Windfury Totem II
UnitBlackList[ 7484] = true -- Windfury Totem III
UnitBlackList[ 9687] = true -- Windwall Totem
UnitBlackList[ 9688] = true -- Windwall Totem II
UnitBlackList[ 9689] = true -- Windwall Totem III
