local LibAuraData = Wheel:Set("LibAuraData", -1)
if (not LibAuraData) then	
	return
end

-- Lua API
local _G = _G
local assert = assert
local bit_band = bit.band
local bit_bor = bit.bor
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

-- Library registries
---------------------------------------------------------------------	
LibAuraData.embeds = LibAuraData.embeds or {}
LibAuraData.infoFlags = LibAuraData.infoFlags or {} -- static library info flags about the auras
LibAuraData.auraFlags = LibAuraData.auraFlags or {} -- static library aura flag cache
LibAuraData.userFlags = LibAuraData.userFlags or {} -- static user/module flag cache
LibAuraData.auraDuration = LibAuraData.auraDuration or {} -- static library aura duration cache

-- Quality of Life
---------------------------------------------------------------------	
local InfoFlags = LibAuraData.infoFlags
local AuraFlags = LibAuraData.auraFlags
local UserFlags = LibAuraData.userFlags
local AuraDuration = LibAuraData.auraDuration

-- Local constants & tables
---------------------------------------------------------------------	

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

--------------------------------------------------------------------------
-- InfoFlag queries
--------------------------------------------------------------------------
-- Not a fan of this in the slightest, 
-- but for purposes of speed we need to hand this table out to the modules. 
-- and in case of library updates we need this table to be the same,
LibAuraData.GetAllAuraInfoFlags = function(self)
	return Auras
end

-- Return the hashed info flag table, 
-- to allow easy usage of keywords in the modules.
-- We will have make sure the keywords remain consistent.  
LibAuraData.GetAllAuraInfoBitFilters = function(self)
	return InfoFlags
end

-- Check if the provided info flags are set for the aura
LibAuraData.HasAuraInfoFlags = function(self, spellID, flags)
	-- Not verifying input types as we don't want the extra function calls on 
	-- something that might be called multiple times each second. 
	return AuraFlags[spellID] and (bit_band(AuraFlags[spellID], flags) ~= 0)
end

-- Retrieve the current info flags for the aura, or nil if none are set
LibAuraData.GetAuraInfoFlags = function(self, spellID)
	-- Not verifying input types as we don't want the extra function calls on 
	-- something that might be called multiple times each second. 
	return AuraFlags[spellID]
end

--------------------------------------------------------------------------
-- UserFlags
-- The flags set here are registered per module, 
-- and are to be used for the front-end's own purposes, 
-- whether that be display preference, blacklists, whitelists, etc. 
-- Nothing here is global, and all is separate from the InfoFlags.
--------------------------------------------------------------------------
-- Adds a custom aura flag
LibAuraData.AddAuraUserFlags = function(self, spellID, flags)
	check(spellID, 1, "number")
	check(flags, 2, "number")
	if (not UserFlags[self]) then 
		UserFlags[self] = {}
	end 
	if (not UserFlags[self][spellID]) then 
		UserFlags[self][spellID] = flags
		return 
	end 
	UserFlags[self][spellID] = bit_bor(UserFlags[self][spellID], flags)
end 

-- Retrieve the current set flags for the aura, or nil if none are set
LibAuraData.GetAuraUserFlags = function(self, spellID)
	-- Not verifying input types as we don't want the extra function calls on 
	-- something that might be called multiple times each second. 
	if (not UserFlags[self]) or (not UserFlags[self][spellID]) then 
		return 
	end 
	return UserFlags[self][spellID]
end

-- Return the full user flag table for the module
LibAuraData.GetAllAuraUserFlags = function(self)
	return UserFlags[self]
end

-- Check if the provided user flags are set for the aura
LibAuraData.HasAuraUserFlags = function(self, spellID, flags)
	-- Not verifying input types as we don't want the extra function calls on 
	-- something that might be called multiple times each second. 
	if (not UserFlags[self]) or (not UserFlags[self][spellID]) then 
		return 
	end 
	return (bit_band(UserFlags[self][spellID], flags) ~= 0)
end

-- Remove a set of user flags, or all if no removalFlags are provided.
LibAuraData.RemoveAuraUserFlags = function(self, spellID, removalFlags)
	check(spellID, 1, "number")
	check(removalFlags, 2, "number", "nil")
	if (not UserFlags[self]) or (not UserFlags[self][spellID]) then 
		return 
	end 
	local userFlags = UserFlags[self][spellID]
	if removalFlags  then 
		local changed
		for i = 1,64 do -- bit.bits ? 
			local bit = (i-1)^2 -- create a mask 
			local userFlagsHasBit = bit_band(userFlags, bit) -- see if the user filter has the bit set
			local removalFlagsHasBit = bit_band(removalFlags, bit) -- see if the removal flags has the bit set
			if (userFlagsHasBit and removalFlagsHasBit) then 
				userFlags = userFlags - bit -- just simply deduct the masked bit value if it was set
				changed = true 
			end 
		end 
		if (changed) then 
			UserFlags[self][spellID] = userFlags
		end 
	else 
		UserFlags[self][spellID] = nil
	end 
end 

local embedMethods = {
	GetAllAuraInfoFlags = true, 
	GetAllAuraUserFlags = true, 
	GetAllAuraInfoBitFilters = true, 
	GetAuraInfoFlags = true, 
	HasAuraInfoFlags = true, 
	AddAuraUserFlags = true,
	GetAuraUserFlags = true,
	HasAuraUserFlags = true, 
	RemoveAuraUserFlags = true
}

LibAuraData.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	LibAuraData.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibAuraData.embeds) do
	LibAuraData:Embed(target)
end

-- Databases
---------------------------------------------------------------------	
--------------------------------------------------------------------------
-- InfoFlags
-- The flags in this DB should only describe factual properties 
-- of the auras like type of spell, what class it belongs to, etc. 
--------------------------------------------------------------------------

local PlayerSpell 		= 2^0
local RacialSpell 		= 2^1

-- 2nd return value from UnitClass(unit)
local DRUID 			= 2^2
local HUNTER 			= 2^3
local MAGE 				= 2^4
local PALADIN 			= 2^5
local PRIEST 			= 2^6
local ROGUE 			= 2^7
local SHAMAN 			= 2^8
local WARLOCK 			= 2^9
local WARRIOR 			= 2^10

local CrowdControl 		= 2^11
local Incapacitate 		= 2^12
local Root 				= 2^13
local Snare 			= 2^14
local Silence 			= 2^15
local Stun 				= 2^16
local Taunt 			= 2^17
local Immune			= 2^18
local ImmuneSpell 		= 2^19
local ImmunePhysical 	= 2^20
local Disarm 			= 2^21

local Food 				= 2^22
local Flask 			= 2^23

InfoFlags.IsPlayerSpell = PlayerSpell
InfoFlags.IsRacialSpell = RacialSpell

InfoFlags.DRUID = DRUID
InfoFlags.HUNTER = HUNTER
InfoFlags.MAGE = MAGE
InfoFlags.PALADIN = PALADIN
InfoFlags.PRIEST = PRIEST
InfoFlags.ROGUE = ROGUE
InfoFlags.SHAMAN = SHAMAN
InfoFlags.WARLOCK = WARLOCK
InfoFlags.WARRIOR = WARRIOR

InfoFlags.IsCrowdControl = CrowdControl
InfoFlags.IsIncapacitate = Incapacitate
InfoFlags.IsRoot = Root
InfoFlags.IsSnare = Snare
InfoFlags.IsSilence = Silence
InfoFlags.IsStun = Stun
InfoFlags.IsImmune = Immune
InfoFlags.IsImmuneSpell = ImmuneSpell
InfoFlags.IsImmunePhysical = ImmunePhysical
InfoFlags.IsDisarm = Disarm
InfoFlags.IsFood = Food
InfoFlags.IsFlask = Flask

-- For convenience farther down the list here
local IsDruid = PlayerSpell + DRUID
local IsHunter = PlayerSpell + HUNTER
local IsMage = PlayerSpell + MAGE
local IsPaladin = PlayerSpell + PALADIN
local IsPriest = PlayerSpell + PRIEST
local IsRogue = PlayerSpell + ROGUE
local IsShaman = PlayerSpell + SHAMAN
local IsWarlock = PlayerSpell + WARLOCK
local IsWarrior = PlayerSpell + WARRIOR

local IsIncapacitate = CrowdControl + Incapacitate
local IsRoot = CrowdControl + Root
local IsSnare = CrowdControl + Snare
local IsSilence = CrowdControl + Silence
local IsStun = CrowdControl + Stun
local IsTaunt = Taunt

-- Add flags to or create the cache entry
-- This is to avoid duplicate entries removing flags
local AddFlags = function(spellID, flags)
	if (not AuraFlags[spellID]) then 
		AuraFlags[spellID] = flags
		return 
	end 
	AuraFlags[spellID] = bit_bor(AuraFlags[spellID], flags)
end

-- Druid (Balance)
------------------------------------------------------------------------
AddFlags(22812, IsDruid) 					-- Barkskin
AddFlags(  339, IsDruid + IsRoot) 			-- Entangling Roots (Rank 1)
AddFlags( 1062, IsDruid + IsRoot) 			-- Entangling Roots (Rank 2)
AddFlags( 5195, IsDruid + IsRoot) 			-- Entangling Roots (Rank 3)
AddFlags( 5196, IsDruid + IsRoot) 			-- Entangling Roots (Rank 4)
AddFlags( 9852, IsDruid + IsRoot) 			-- Entangling Roots (Rank 5)
AddFlags( 9853, IsDruid + IsRoot) 			-- Entangling Roots (Rank 6)
AddFlags(  770, IsDruid) 					-- Faerie Fire (Rank 1)
AddFlags( 2637, IsDruid + IsStun) 			-- Hibernate (Rank 1)
AddFlags(18657, IsDruid + IsStun) 			-- Hibernate (Rank 2)
AddFlags(18658, IsDruid + IsStun) 			-- Hibernate (Rank 3)
AddFlags(16689, IsDruid + IsRoot) 			-- Nature's Grasp (Rank 1)
AddFlags(16689, IsDruid + IsRoot) 			-- Nature's Grasp (Rank 2)
AddFlags(16689, IsDruid + IsRoot) 			-- Nature's Grasp (Rank 3)
AddFlags(16689, IsDruid + IsRoot) 			-- Nature's Grasp (Rank 4)
AddFlags(16689, IsDruid + IsRoot) 			-- Nature's Grasp (Rank 5)
AddFlags(16689, IsDruid + IsRoot) 			-- Nature's Grasp (Rank 6)
AddFlags(16870, IsDruid) 					-- Omen of Clarity (Proc)

-- Druid (Feral)
-- https://classic.wowhead.com/druid-abilities/feral-combat
------------------------------------------------------------------------
AddFlags( 1066, IsDruid) 					-- Aquatic Form
AddFlags( 8983, IsDruid + IsStun) 			-- Bash
AddFlags( 5487, IsDruid) 					-- Bear Form
AddFlags(  768, IsDruid) 					-- Cat Form
AddFlags( 5209, IsDruid + IsTaunt) 			-- Challenging Roar (Taunt)
AddFlags( 9821, IsDruid) 					-- Dash
AddFlags( 9634, IsDruid) 					-- Dire Bear Form
AddFlags( 5229, IsDruid) 					-- Enrage
AddFlags(16857, IsDruid) 					-- Faerie Fire (Feral)
AddFlags(22896, IsDruid) 					-- Frenzied Regeneration
AddFlags( 6795, IsDruid + IsTaunt) 			-- Growl (Taunt)
AddFlags(24932, IsDruid) 					-- Leader of the Pack
AddFlags( 9007, IsDruid + IsStun) 			-- Pounce Bleed (Rank 1)
AddFlags( 9824, IsDruid + IsStun) 			-- Pounce Bleed (Rank 2)
AddFlags( 9826, IsDruid + IsStun) 			-- Pounce Bleed (Rank 3)
AddFlags( 5215, IsDruid) 					-- Prowl (Rank 1)
AddFlags( 6783, IsDruid) 					-- Prowl (Rank 2)
AddFlags( 9913, IsDruid) 					-- Prowl (Rank 3)
AddFlags( 9904, IsDruid) 					-- Rake
AddFlags( 9894, IsDruid) 					-- Rip
AddFlags( 9845, IsDruid) 					-- Tiger's Fury
AddFlags(  783, IsDruid) 					-- Travel Form

-- Druid (Restoration)
------------------------------------------------------------------------
AddFlags( 2893, IsDruid) 					-- Abolish Poison
AddFlags(29166, IsDruid) 					-- Innervate
AddFlags( 8936, IsDruid) 					-- Regrowth (Rank 1)
AddFlags( 8938, IsDruid) 					-- Regrowth (Rank 2)
AddFlags( 8939, IsDruid) 					-- Regrowth (Rank 3)
AddFlags( 8940, IsDruid) 					-- Regrowth (Rank 4)
AddFlags( 8941, IsDruid) 					-- Regrowth (Rank 5)
AddFlags( 9750, IsDruid) 					-- Regrowth (Rank 6)
AddFlags( 9856, IsDruid) 					-- Regrowth (Rank 7)
AddFlags( 9857, IsDruid) 					-- Regrowth (Rank 8)
AddFlags( 9858, IsDruid) 					-- Regrowth (Rank 9)
AddFlags(  774, IsDruid) 					-- Rejuvenation (Rank 1)
AddFlags( 1058, IsDruid) 					-- Rejuvenation (Rank 2)
AddFlags( 1430, IsDruid) 					-- Rejuvenation (Rank 3)
AddFlags( 2090, IsDruid) 					-- Rejuvenation (Rank 4)
AddFlags( 2091, IsDruid) 					-- Rejuvenation (Rank 5)
AddFlags( 3627, IsDruid) 					-- Rejuvenation (Rank 6)
AddFlags( 8910, IsDruid) 					-- Rejuvenation (Rank 7)
AddFlags( 9839, IsDruid) 					-- Rejuvenation (Rank 8)
AddFlags( 9840, IsDruid) 					-- Rejuvenation (Rank 9)
AddFlags( 9841, IsDruid) 					-- Rejuvenation (Rank 10)
AddFlags(  740, IsDruid) 					-- Tranquility (Rank 1)
AddFlags( 8918, IsDruid) 					-- Tranquility (Rank 2)
AddFlags( 9862, IsDruid) 					-- Tranquility (Rank 3)
AddFlags( 9863, IsDruid) 					-- Tranquility (Rank 4)

-- Warrior (Arms)
------------------------------------------------------------------------
AddFlags( 7922, IsWarrior + IsStun) 		-- Charge Stun (Rank 1)
AddFlags(  772, IsWarrior) 					-- Rend (Rank 1)
AddFlags( 6343, IsWarrior) 					-- Thunder Clap (Rank 1)

-- Warrior (Fury)
------------------------------------------------------------------------
AddFlags( 6673, IsWarrior) 					-- Battle Shout (Rank 1)
