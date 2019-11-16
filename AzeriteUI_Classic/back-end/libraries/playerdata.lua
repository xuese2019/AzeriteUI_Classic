local LibPlayerData = Wheel:Set("LibPlayerData", 13)
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
local string_byte = string.byte
local string_find = string.find
local string_join = string.join
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local type = type

-- WoW API
local GetWatchedFactionInfo = GetWatchedFactionInfo
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local UnitLevel = UnitLevel

-- Library registries
---------------------------------------------------------------------	
LibPlayerData.embeds = LibPlayerData.embeds or {}
LibPlayerData.frame = LibPlayerData.frame or CreateFrame("Frame")
LibPlayerData.unitCache = LibPlayerData.unitCache or {}
LibPlayerData.unitCacheBlacklist = LibPlayerData.unitCacheBlacklist or {}

-- Quality of Life
---------------------------------------------------------------------	
local UnitCache = LibPlayerData.unitCache
local UnitBlacklist = LibPlayerData.unitCacheBlacklist

-- Local constants & tables
---------------------------------------------------------------------	
-- Constant to track current player role
local CURRENT_ROLE

-- Player class and GUID constants
local _,playerClass = UnitClass("player")
local playerGUID = UnitGUID("player")

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
if (classIsDamage[playerClass]) then
	CURRENT_ROLE = "DAMAGER"
	LibPlayerData.frame:SetScript("OnEvent", nil)
	LibPlayerData.frame:UnregisterAllEvents()
else
	CURRENT_ROLE = classCanTank[playerClass] and "TANK" or "DAMAGER"
end 

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
-- Just a proxy for RealMobHealth right now. Shortest path. 
LibPlayerData.UnitHealth = function(self, unit)
	if (RealMobHealth and RealMobHealth.GetUnitHealth) then 
		local healthCur, healthMax, curIsGuess, maxIsGuess = RealMobHealth.GetUnitHealth(unit)
		if (curIsGuess ~= nil) then -- nil means just percentage fallbacks are available
			return healthCur or 0
		end
	end
end

LibPlayerData.UnitHealthMax = function(self, unit)
	if (RealMobHealth and RealMobHealth.GetUnitHealth) then 
		local healthCur, healthMax, curIsGuess, maxIsGuess = RealMobHealth.GetUnitHealth(unit)
		if (maxIsGuess ~= nil) then -- nil means just percentage fallbacks are available
			return healthMax or 0
		end
	end
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
	GetEffectiveExpansionMaxLevel = true, 
	GetEffectivePlayerMaxLevel = true, 
	GetPlayerRole = true, 
	IsPlayerAtEffectiveExpansionMaxLevel = true, 
	IsPlayerAtEffectiveMaxLevel = true, 
	IsUnitLevelAtEffectiveExpansionMaxLevel = true, 
	IsUnitLevelAtEffectiveMaxLevel = true, 
	PlayerCanTank = true, 
	PlayerHasRep = true, 
	PlayerHasXP = true, 
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
do
	UnitBlacklist[ 5924] = true -- Disease Cleansing Totem
	UnitBlacklist[ 2630] = true -- Earthbind Totem
	UnitBlacklist[ 5879] = true -- Fire Nova Totem
	UnitBlacklist[ 6110] = true -- Fire Nova Totem II
	UnitBlacklist[ 6111] = true -- Fire Nova Totem III
	UnitBlacklist[ 7844] = true -- Fire Nova Totem IV
	UnitBlacklist[ 7845] = true -- Fire Nova Totem V
	UnitBlacklist[ 5927] = true -- Fire Resistance Totem
	UnitBlacklist[ 7424] = true -- Fire Resistance Totem II
	UnitBlacklist[ 7425] = true -- Fire Resistance Totem III
	UnitBlacklist[ 5950] = true -- Flametongue Totem
	UnitBlacklist[ 6012] = true -- Flametongue Totem II
	UnitBlacklist[ 7423] = true -- Flametongue Totem III
	UnitBlacklist[10557] = true -- Flametongue Totem IV
	UnitBlacklist[ 5926] = true -- Frost Resistance Totem
	UnitBlacklist[ 7412] = true -- Frost Resistance Totem II
	UnitBlacklist[ 7413] = true -- Frost Resistance Totem III
	UnitBlacklist[ 7486] = true -- Grace of Air Totem
	UnitBlacklist[ 7487] = true -- Grace of Air Totem II
	UnitBlacklist[15463] = true -- Grace of Air Totem III
	UnitBlacklist[ 5925] = true -- Grounding Totem
	UnitBlacklist[ 3527] = true -- Healing Stream Totem
	UnitBlacklist[ 3906] = true -- Healing Stream Totem II
	UnitBlacklist[ 3907] = true -- Healing Stream Totem III
	UnitBlacklist[ 3908] = true -- Healing Stream Totem IV
	UnitBlacklist[ 3909] = true -- Healing Stream Totem V
	UnitBlacklist[ 5929] = true -- Magma Totem
	UnitBlacklist[ 7464] = true -- Magma Totem II
	UnitBlacklist[ 7465] = true -- Magma Totem III
	UnitBlacklist[ 7466] = true -- Magma Totem IV
	UnitBlacklist[ 3573] = true -- Mana Spring Totem
	UnitBlacklist[ 7414] = true -- Mana Spring Totem II
	UnitBlacklist[ 7415] = true -- Mana Spring Totem III
	UnitBlacklist[ 7416] = true -- Mana Spring Totem IV
	UnitBlacklist[11100] = true -- Mana Tide Totem II
	UnitBlacklist[11101] = true -- Mana Tide Totem III
	UnitBlacklist[ 7467] = true -- Nature Resistance Totem
	UnitBlacklist[ 7468] = true -- Nature Resistance Totem II
	UnitBlacklist[ 7469] = true -- Nature Resistance Totem III
	UnitBlacklist[ 5923] = true -- Poison Cleansing Totem
	UnitBlacklist[ 2523] = true -- Searing Totem
	UnitBlacklist[ 3902] = true -- Searing Totem II
	UnitBlacklist[ 3903] = true -- Searing Totem III
	UnitBlacklist[ 3904] = true -- Searing Totem IV
	UnitBlacklist[ 7400] = true -- Searing Totem V
	UnitBlacklist[ 7402] = true -- Searing Totem VI
	UnitBlacklist[ 3968] = true -- Sentry Totem
	UnitBlacklist[ 3579] = true -- Stoneclaw Totem
	UnitBlacklist[ 3911] = true -- Stoneclaw Totem II
	UnitBlacklist[ 3912] = true -- Stoneclaw Totem III
	UnitBlacklist[ 3913] = true -- Stoneclaw Totem IV
	UnitBlacklist[ 7398] = true -- Stoneclaw Totem V
	UnitBlacklist[ 7399] = true -- Stoneclaw Totem VI
	UnitBlacklist[ 5873] = true -- Stoneskin Totem
	UnitBlacklist[ 5919] = true -- Stoneskin Totem II
	UnitBlacklist[ 5920] = true -- Stoneskin Totem III
	UnitBlacklist[ 7366] = true -- Stoneskin Totem IV
	UnitBlacklist[ 7367] = true -- Stoneskin Totem V
	UnitBlacklist[ 7368] = true -- Stoneskin Totem VI
	UnitBlacklist[ 5874] = true -- Strength of Earth Totem
	UnitBlacklist[ 5921] = true -- Strength of Earth Totem II
	UnitBlacklist[ 5922] = true -- Strength of Earth Totem III
	UnitBlacklist[ 7403] = true -- Strength of Earth Totem IV
	UnitBlacklist[15464] = true -- Strength of Earth Totem V
	UnitBlacklist[15803] = true -- Tranquil Air Totem
	UnitBlacklist[ 5913] = true -- Tremor Totem
	UnitBlacklist[ 6112] = true -- Windfury Totem
	UnitBlacklist[ 7483] = true -- Windfury Totem II
	UnitBlacklist[ 7484] = true -- Windfury Totem III
	UnitBlacklist[ 9687] = true -- Windwall Totem
	UnitBlacklist[ 9688] = true -- Windwall Totem II
	UnitBlacklist[ 9689] = true -- Windwall Totem III
end
