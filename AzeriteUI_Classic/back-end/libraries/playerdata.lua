local LibPlayerData = Wheel:Set("LibPlayerData", 17)
if (not LibPlayerData) then
	return
end

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibCast requires LibClientBuild to be loaded.")

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
local FindActiveAzeriteItem = C_AzeriteItem and C_AzeriteItem.FindActiveAzeriteItem
local GetAccountExpansionLevel = GetAccountExpansionLevel
local GetExpansionLevel = GetExpansionLevel
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local GetWatchedFactionInfo = GetWatchedFactionInfo
local IsAzeriteItemLocationBankBag = AzeriteUtil and AzeriteUtil.IsAzeriteItemLocationBankBag
local IsXPUserDisabled = IsXPUserDisabled
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local UnitLevel = UnitLevel

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

-- Library registries
---------------------------------------------------------------------	
LibPlayerData.embeds = LibPlayerData.embeds or {}
LibPlayerData.frame = LibPlayerData.frame or CreateFrame("Frame")

-- Local constants & tables
---------------------------------------------------------------------	
-- Constant to track current player role
local CURRENT_ROLE

-- Player class and GUID constants
local _,playerClass = UnitClass("player")
local playerGUID = UnitGUID("player")

-- List of damage-only classes
local classIsDamage = {}
if (IsClassic) then
	classIsDamage.HUNTER = true
	classIsDamage.MAGE = true
	classIsDamage.ROGUE = true
	classIsDamage.WARLOCK = true
elseif (IsRetail) then
	classIsDamage.DEMONHUNTER = true
	classIsDamage.HUNTER = true
	classIsDamage.MAGE = true
	classIsDamage.ROGUE = true
	classIsDamage.WARLOCK = true
end

-- List of classes that can tank
local classCanTank = {}
if (IsClassic) then
	classCanTank.DRUID = true
	classCanTank.PALADIN = true
	classCanTank.WARRIOR = true
elseif (IsRetail) then
	classCanTank.DEATHKNIGHT = true
	classCanTank.DRUID = true
	classCanTank.MONK = true
	classCanTank.PALADIN = true
	classCanTank.WARRIOR = true
end


-- Setup our frame for tracking role events
-- *NOT updated for Classic yet!
if (classIsDamage[playerClass]) then
	CURRENT_ROLE = "DAMAGER"
	LibPlayerData.frame:SetScript("OnEvent", nil)
	LibPlayerData.frame:UnregisterAllEvents()
else
	if (IsClassic) then
		CURRENT_ROLE = classCanTank[playerClass] and "TANK" or "DAMAGER"
	elseif (IsRetail) then
		LibPlayerData.frame:SetScript("OnEvent", function(self, event, ...) 
			if (event == "PLAYER_LOGIN") then
				self:UnregisterEvent(event)
				self:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
			end
			-- Role name is 7th stat, wowpedia has it wrong. 
			local _, _, _, _, _, _, role = GetSpecializationInfo(GetSpecialization() or 0)
			CURRENT_ROLE = role or "DAMAGER"
		end)
		if IsLoggedIn() then 
			LibPlayerData.frame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
			LibPlayerData.frame:GetScript("OnEvent")(LibPlayerData.frame)
		else 
			LibPlayerData.frame:RegisterEvent("PLAYER_LOGIN")
		end 
	end
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

-- Level Functions 
---------------------------------------------------------------------	
if (IsClassic) then
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

	-- Returns whether the player is  tracking a reputation
	LibPlayerData.PlayerHasRep = function()
		return GetWatchedFactionInfo() and true or false 
	end

elseif (IsRetail) then

	-- Returns the maximum level the account has access to 
	LibPlayerData.GetEffectivePlayerMaxLevel = function()
		return MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()]
	end

	-- Returns the maximum level in the current expansion 
	LibPlayerData.GetEffectiveExpansionMaxLevel = function()
		return MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()]
	end

	-- Is the provided level at the account's maximum level?
	LibPlayerData.IsUnitLevelAtEffectiveMaxLevel = function(level)
		return (level >= LibPlayerData.GetEffectivePlayerMaxLevel())
	end

	-- Is the provided level at the expansions's maximum level?
	LibPlayerData.IsUnitLevelAtEffectiveExpansionMaxLevel = function(level)
		return (level >= LibPlayerData.GetEffectiveExpansionMaxLevel())
	end 

	-- Is the player at the account's maximum level?
	LibPlayerData.IsPlayerAtEffectiveMaxLevel = function()
		return LibPlayerData.IsUnitLevelAtEffectiveMaxLevel(UnitLevel("player"))
	end

	-- Is the player at the expansions's maximum level?
	LibPlayerData.IsPlayerAtEffectiveExpansionMaxLevel = function()
		return LibPlayerData.IsUnitLevelAtEffectiveExpansionMaxLevel(UnitLevel("player"))
	end

	-- Return whether the player currently can gain XP
	LibPlayerData.PlayerHasXP = function(useExpansionMax)
		if IsXPUserDisabled() then 
			return false 
		elseif useExpansionMax then 
			return (not LibPlayerData.IsPlayerAtEffectiveExpansionMaxLevel())
		else
			return (not LibPlayerData.IsPlayerAtEffectiveMaxLevel())
		end 
	end

	LibPlayerData.PlayerHasAP = function()
		local azeriteItemLocation = FindActiveAzeriteItem()
		if (azeriteItemLocation) and (not IsAzeriteItemLocationBankBag(azeriteItemLocation)) then
			return azeriteItemLocation
		end
	end

	-- Returns whether the player is  tracking a reputation
	LibPlayerData.PlayerHasRep = function()
		local name, reaction, min, max, current, factionID = GetWatchedFactionInfo()
		if name then 
			local numFactions = GetNumFactions()
			for i = 1, numFactions do
				local factionName, description, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(i)
				local friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(factionID)
				if (factionName == name) then
					if standingID then 
						return true
					else 
						return false
					end 
				end
			end
		end 
	end

end

-- Role Functions
---------------------------------------------------------------------	
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
if (IsRetail) then
	embedMethods.PlayerHasAP = true
end

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
