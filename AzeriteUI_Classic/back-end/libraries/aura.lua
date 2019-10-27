local LibAura = Wheel:Set("LibAura", 17)
if (not LibAura) then	
	return
end

local LibMessage = Wheel("LibMessage")
assert(LibMessage, "LibAura requires LibMessage to be loaded.")

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibAura requires LibEvent to be loaded.")

local LibFrame = Wheel("LibFrame")
assert(LibFrame, "LibAura requires LibFrame to be loaded.")

local LibPlayerData = Wheel("LibPlayerData")
assert(LibPlayerData, "LibAura requires LibPlayerData to be loaded.")

LibMessage:Embed(LibAura)
LibEvent:Embed(LibAura)
LibFrame:Embed(LibAura)
LibPlayerData:Embed(LibAura)

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
local string_gsub = string.gsub
local string_join = string.join
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local tonumber = tonumber
local type = type

-- WoW API
local CombatLogGetCurrentEventInfo = _G.CombatLogGetCurrentEventInfo
local GetComboPoints = _G.GetComboPoints
local GetSpellInfo = _G.GetSpellInfo
local GetTime = _G.GetTime
local IsPlayerSpell = _G.IsPlayerSpell
local UnitAura = _G.UnitAura
local UnitClass = _G.UnitClass
local UnitGUID = _G.UnitGUID
local UnitIsUnit = _G.UnitIsUnit

-- WoW Constants
local BUFF_MAX_DISPLAY = _G.BUFF_MAX_DISPLAY
local DEBUFF_MAX_DISPLAY = _G.DEBUFF_MAX_DISPLAY 

-- Library registries
LibAura.embeds = LibAura.embeds or {}
LibAura.infoFlags = LibAura.infoFlags or {} -- static library info flags about the auras
LibAura.auraFlags = LibAura.auraFlags or {} -- static library aura flag cache
LibAura.userFlags = LibAura.userFlags or {} -- static user/module flag cache
LibAura.auraCache = LibAura.auraCache or {} -- dynamic unit aura cache
LibAura.auraCacheByGUID = LibAura.auraCacheByGUID or {} -- dynamic aura info from the combat log
LibAura.auraWatches = LibAura.auraWatches or {} -- dynamic list of tracked units

-- Frame tracking events and updates
LibAura.frame = LibAura.frame or LibAura:CreateFrame("Frame") 

-- Shortcuts
local InfoFlags = LibAura.infoFlags -- static library info flags about the auras
local AuraFlags = LibAura.auraFlags -- static library aura flag cache
local UserFlags = LibAura.userFlags --- static user/module flag cache
local AuraCache = LibAura.auraCache -- dynamic unit aura cache
local AuraCacheByGUID = LibAura.auraCacheByGUID -- dynamic aura info from the combat log
local UnitHasAuraWatch = LibAura.auraWatches -- dynamic list of tracked units

-- WoW Constants
local COMBATLOG_OBJECT_TYPE_PLAYER = _G.COMBATLOG_OBJECT_TYPE_PLAYER
local COMBATLOG_OBJECT_REACTION_FRIENDLY = _G.COMBATLOG_OBJECT_REACTION_FRIENDLY

-- Library Constants
local DRResetTime = 18.4
local DRMultipliers = { .5, .25, 0 }
local playerGUID = UnitGUID("player")
local _, playerClass = UnitClass("player")
local sunderArmorName = GetSpellInfo(11597)

-- Utility Functions
--------------------------------------------------------------------------
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

-- Utility function to parse and order a filter, 
-- to make sure we avoid duplicate caches. 
local parseFilter = function(filter)
	
	-- speed it up for default situations
	if ((not filter) or (filter == "")) then 
		return "HELPFUL"
	end

	-- parse the string, ignore separator types and order
	local harmful = string_match(filter, "HARMFUL")
	local helpful = string_match(filter, "HELPFUL")
	local player = string_match(filter, "PLAYER") -- auras that were applied by the player
	local raid = string_match(filter, "RAID") -- auras that can be applied (if HELPFUL) or dispelled (if HARMFUL) by the player
	local cancelable = string_match(filter, "CANCELABLE") -- buffs that can be removed (such as by right-clicking or using the /cancelaura command)
	local not_cancelable = string_match(filter, "NOT_CANCELABLE") -- buffs that cannot be removed

	-- return a nil value for invalid filters. 
	-- *this might cause an error, but that is the intention.
	if (harmful and helpful) or (cancelable and not_cancelable) then 
		return 
	end

	-- always include these, as we're always using UnitAura() to retrieve buffs/debuffs.
	local parsedFilter
	if (harmful) then 
		parsedFilter = "HARMFUL"
	else 
		parsedFilter = "HELPFUL" -- default when no help/harm is mentioned
	end 

	-- return a parsed filter with arguments separated by spaces, and in our preferred order
	return parsedFilter .. (player and " PLAYER" or "") 
						.. (raid and " RAID" or "") 
						.. (cancelable and " CANCELABLE" or "") 
						.. (not_cancelable and " NOT_CANCELABLE" or "") 
end 

local comboCache, comboCacheOld = 0,0
local GetComboPointsCached = function()
	if (comboCache) then 
		return (comboCacheOld > comboCache) and comboCacheOld or comboCache
	else 
		return GetComboPoints("player", "target") 
	end
end

-- Aura tracking frame and event handling
--------------------------------------------------------------------------
local Frame = LibAura.frame
local Frame_MT = { __index = Frame }

-- Methods we don't wish to expose to the modules
local IsEventRegistered = Frame_MT.__index.IsEventRegistered
local RegisterEvent = Frame_MT.__index.RegisterEvent
local RegisterUnitEvent = Frame_MT.__index.RegisterUnitEvent
local UnregisterEvent = Frame_MT.__index.UnregisterEvent
local UnregisterAllEvents = Frame_MT.__index.UnregisterAllEvents

Frame.OnEvent = function(self, event, unit, ...)
	if (event == "PLAYER_TARGET_CHANGED") then 
		return Frame:OnEvent("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")

	elseif (event == "UNIT_POWER_UPDATE") then 
		local powerType = ... 
		if (powerType == "COMBO_POINTS") then 
			comboCacheOld = comboCache
			comboCache = GetComboPoints(unit, "target")
		end 

	elseif (event == "UNIT_SPELLCAST_SUCCEEDED") then 
		local castID, spellID = ...

	elseif (event == "UNIT_AURA") then 
		-- don't bother caching up anything we haven't got a registered aurawatch or cache for
		if (not UnitHasAuraWatch[unit]) then 
			return 
		end 

		-- retrieve the unit's aura cache, bail out if none has been queried before
		local cache = AuraCache[unit]
		if (not cache) then 
			return 
		end 

		-- refresh all the registered filters
		for filter in pairs(cache) do 
			LibAura:CacheUnitAurasByFilter(unit, filter)
		end 

		-- Send a message to anybody listening
		LibAura:SendMessage("GP_UNIT_AURA", unit)

	elseif (event == "COMBAT_LOG_EVENT_UNFILTERED") then 
		return Frame:OnEvent("CLEU", CombatLogGetCurrentEventInfo())

	elseif (event == "CLEU") then 

		local timestamp, eventType, hideCaster, 
			sourceGUID, sourceName, sourceFlags, sourceRaidFlags, 
			destGUID, destName, destFlags, destRaidFlags,
			spellID, arg2, arg3, arg4, arg5 = ...

		-- We're only interested in who the aura is applied to.
		local cacheByGUID
		local cacheGUID = destGUID or sourceGUID
		if (cacheGUID) then 
			if (not AuraCacheByGUID[cacheGUID]) then 
				AuraCacheByGUID[cacheGUID] = {}
			end
			cacheByGUID = AuraCacheByGUID[cacheGUID]
			for i in pairs(cacheByGUID) do 
				cacheByGUID[i] = nil
			end
		end 

		if (cacheByGUID) then 
			cacheByGUID.timestamp = timestamp
			cacheByGUID.eventType = eventType
			cacheByGUID.sourceFlags = sourceFlags
			cacheByGUID.sourceRaidFlags = sourceRaidFlags
			cacheByGUID.destFlags = destFlags
			cacheByGUID.destRaidFlags = destRaidFlags
			cacheByGUID.isCastByPlayer = sourceGUID == playerGUID
			cacheByGUID.unitCaster = sourceName
		end

		if (spellName == sunderArmorName) then
			if (eventType == "SPELL_CAST_SUCCESS") then
				eventType = "SPELL_AURA_REFRESH"
				auraType = "DEBUFF"
			end
		end
	
		if ((auraType == "BUFF") or (auraType == "DEBUFF")) then
		end

		if (eventType == "SPELL_INTERRUPT") then
		end

		if (eventType == "UNIT_DIED") then
			-- clear cache
		end

	end 
end

LibAura.CacheUnitBuffsByFilter = function(self, unit, filter)
	return self:CacheUnitAurasByFilter(unit, "HELPFUL" .. (filter or ""))
end 

LibAura.CacheUnitDebuffsByFilter = function(self, unit, filter)
	return self:CacheUnitAurasByFilter(unit, "HARMFUL" .. (filter or ""))
end 

local localUnits = { player = true, pet = true }
for i = 1,4 do 
	localUnits["party"..i] = true 
	localUnits["party"..i.."pet"] = true 
end 
for i = 2,40 do 
	localUnits["raid"..i] = true 
	localUnits["raid"..i.."pet"] = true 
end 

LibAura.CacheUnitAurasByFilter = function(self, unit, filter)
	-- Parse the provided or create a default filter
	local filter = parseFilter(filter)
	if (not filter) then 
		return -- don't cache invalid filters
	end

	-- Enable the aura watch for this unit and filter if it hasn't been already
	-- This also creates the relevant tables for us. 
	if (not UnitHasAuraWatch[unit]) or (not AuraCache[unit][filter]) then 
		LibAura:RegisterAuraWatch(unit, filter)
	end 

	-- Retrieve the aura cache for this unit and filter
	local cache = AuraCache[unit][filter]

	-- Figure out if this is a unit we can get more info about
	local queryUnit
	if (UnitInParty(unit) or UnitInRaid(unit)) then 
		for localUnit in pairs(localUnits) do 
			if ((unit ~= localUnit) and (UnitIsUnit(unit, localUnit))) then 
				queryUnit = localUnit
			end
		end
	end

	local unitGUID = UnitGUID(queryUnit or unit)
	local auraCacheByGUID = AuraCacheByGUID[unitGUID]

	local counter, limit = 0, string_match(filter, "HARMFUL") and DEBUFF_MAX_DISPLAY or BUFF_MAX_DISPLAY
	for i = 1,limit do 

		-- Retrieve buff information
		local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = UnitAura(queryUnit or unit, i, filter)

		-- No name means no more buffs matching the filter
		if (not name) then
			break
		end

		-- Cache up the values for the aura index.
		-- *Only ever replace the whole table on its initial creation, 
		-- always reuse the existing ones at all other times. 
		-- This can fire A LOT in battlegrounds, so this is needed for performance and memory. 
		if (cache[i]) then 
			cache[i][1], 
			cache[i][2], 
			cache[i][3], 
			cache[i][4], 
			cache[i][5], 
			cache[i][6], 
			cache[i][7], 
			cache[i][8], 
			cache[i][9], 
			cache[i][10], 
			cache[i][11], 
			cache[i][12], 
			cache[i][13], 
			cache[i][14], 
			cache[i][15], 
			cache[i][16], 
			cache[i][17], 
			cache[i][18] = name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3
		else 
			cache[i] = { name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 }
		end 

		-- Anything retrieved from the combat log?
		if (auraCacheByGUID and auraCacheByGUID[spellId]) then 

		end

		counter = counter + 1
	end 

	-- Clear out old, if any
	local numAuras = #cache
	if (numAuras > counter) then 
		for i = counter+1,numAuras do 
			for j = 1,#cache[i] do 
				cache[i][j] = nil
			end 
		end
	end
	
	-- return cache and aura count for this filter and unit
	return cache, counter
end

-- retrieve a cached filtered aura list for the given unit
LibAura.GetUnitAuraCacheByFilter = function(self, unit, filter)
	return AuraCache[unit] and AuraCache[unit][filter] or LibAura:CacheUnitAurasByFilter(unit, filter)
end

LibAura.GetUnitBuffCacheByFilter = function(self, unit, filter)
	local realFilter = "HELPFUL" .. (filter or "")
	return AuraCache[unit] and AuraCache[unit][realFilter] or LibAura:CacheUnitAurasByFilter(unit, realFilter)
end

LibAura.GetUnitDebuffCacheByFilter = function(self, unit, filter)
	local realFilter = "HARMFUL" .. (filter or "")
	return AuraCache[unit] and AuraCache[unit][realFilter] or LibAura:CacheUnitAurasByFilter(unit, realFilter)
end

LibAura.GetUnitAura = function(self, unit, auraID, filter)
	local cache = self:GetUnitAuraCacheByFilter(unit, filter)
	local aura = cache and cache[auraID]
	if aura then 
		return aura[1], aura[2], aura[3], aura[4], aura[5], aura[6], aura[7], aura[8], aura[9], aura[10], aura[11], aura[12], aura[13], aura[14], aura[15], aura[16], aura[17], aura[18]
	end 
end

LibAura.GetUnitBuff = function(self, unit, auraID, filter)
	local cache = self:GetUnitBuffCacheByFilter(unit, filter)
	local aura = cache and cache[auraID]
	if aura then 
		return aura[1], aura[2], aura[3], aura[4], aura[5], aura[6], aura[7], aura[8], aura[9], aura[10], aura[11], aura[12], aura[13], aura[14], aura[15], aura[16], aura[17], aura[18]
	end 
end

LibAura.GetUnitDebuff = function(self, unit, auraID, filter)
	local cache = self:GetUnitDebuffCacheByFilter(unit, filter)
	local aura = cache and cache[auraID]
	if aura then 
		return aura[1], aura[2], aura[3], aura[4], aura[5], aura[6], aura[7], aura[8], aura[9], aura[10], aura[11], aura[12], aura[13], aura[14], aura[15], aura[16], aura[17], aura[18]
	end 
end

LibAura.RegisterAuraWatch = function(self, unit, filter)
	check(unit, 1, "string")

	-- set the tracking flag for this unit
	UnitHasAuraWatch[unit] = true

	-- create the relevant tables
	-- this is needed for the event handler to respond 
	-- to blizz events and cache up the relevant auras.
	if (not AuraCache[unit]) then 
		AuraCache[unit] = {}
	end 
	if (not AuraCache[unit][filter]) then 
		AuraCache[unit][filter] = {}
	end 

	-- register the main events with our event frame, if they haven't been already
	if (not IsEventRegistered(Frame, "UNIT_AURA")) then
		RegisterEvent(Frame, "UNIT_AURA")
	end
	if (not LibAura.isTracking) then 
		RegisterEvent(Frame, "UNIT_SPELLCAST_SUCCEEDED")
		RegisterEvent(Frame, "COMBAT_LOG_EVENT_UNFILTERED")
		if (playerClass == "ROGUE") then
			RegisterEvent(Frame, "PLAYER_TARGET_CHANGED")
			RegisterUnitEvent(Frame, "UNIT_POWER_UPDATE", "player")
		end
		LibAura.isTracking = true
	end 
end

LibAura.UnregisterAuraWatch = function(self, unit, filter)
	check(unit, 1, "string")

	-- clear the tracking flag for this unit
	UnitHasAuraWatch[unit] = false

	-- check if anything is still tracked
	for unit,tracked in pairs(Units) do 
		if (tracked) then 
			return 
		end 
	end 

	-- if we made it this far, we're not tracking anything
	if (LibAura.isTracking) then 
		UnregisterEvent(Frame, "UNIT_AURA")
		UnregisterEvent(Frame, "UNIT_SPELLCAST_SUCCEEDED")
		UnregisterEvent(Frame, "COMBAT_LOG_EVENT_UNFILTERED")
		if (playerClass == "ROGUE") then
			UnregisterEvent(Frame, "PLAYER_TARGET_CHANGED")
			UnregisterEvent(Frame, "UNIT_POWER_UPDATE")
		end
		LibAura.isTracking = nil
	end 
end

--------------------------------------------------------------------------
-- InfoFlag queries
--------------------------------------------------------------------------
-- Not a fan of this in the slightest, 
-- but for purposes of speed we need to hand this table out to the modules. 
-- and in case of library updates we need this table to be the same,
LibAura.GetAllAuraInfoFlags = function(self)
	return Auras
end

-- Return the hashed info flag table, 
-- to allow easy usage of keywords in the modules.
-- We will have make sure the keywords remain consistent.  
LibAura.GetAllAuraInfoBitFilters = function(self)
	return InfoFlags
end

-- Check if the provided info flags are set for the aura
LibAura.HasAuraInfoFlags = function(self, spellID, flags)
	-- Not verifying input types as we don't want the extra function calls on 
	-- something that might be called multiple times each second. 
	return AuraFlags[spellID] and (bit_band(AuraFlags[spellID], flags) ~= 0)
end

-- Retrieve the current info flags for the aura, or nil if none are set
LibAura.GetAuraInfoFlags = function(self, spellID)
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
LibAura.AddAuraUserFlags = function(self, spellID, flags)
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
LibAura.GetAuraUserFlags = function(self, spellID)
	-- Not verifying input types as we don't want the extra function calls on 
	-- something that might be called multiple times each second. 
	if (not UserFlags[self]) or (not UserFlags[self][spellID]) then 
		return 
	end 
	return UserFlags[self][spellID]
end

-- Return the full user flag table for the module
LibAura.GetAllAuraUserFlags = function(self)
	return UserFlags[self]
end

-- Check if the provided user flags are set for the aura
LibAura.HasAuraUserFlags = function(self, spellID, flags)
	-- Not verifying input types as we don't want the extra function calls on 
	-- something that might be called multiple times each second. 
	if (not UserFlags[self]) or (not UserFlags[self][spellID]) then 
		return 
	end 
	return (bit_band(UserFlags[self][spellID], flags) ~= 0)
end

-- Remove a set of user flags, or all if no removalFlags are provided.
LibAura.RemoveAuraUserFlags = function(self, spellID, removalFlags)
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
	CacheUnitAurasByFilter = true,
	CacheUnitBuffsByFilter = true,
	CacheUnitDebuffsByFilter = true,
	GetUnitAura = true,
	GetUnitBuff = true,
	GetUnitDebuff = true,
	GetUnitAuraCacheByFilter = true,
	GetUnitBuffCacheByFilter = true, 
	GetUnitDebuffCacheByFilter = true, 
	RegisterAuraWatch = true,
	UnregisterAuraWatch = true,
	GetAllAuraInfoFlags = true, 
	GetAllAuraUserFlags = true, 
	GetAllAuraInfoBitFilters = true, 
	GetAuraInfoFlags = true, 
	HasAuraInfoFlags = true, 
	AddAuraUserFlags = true,
	GetAuraUserFlags = true,
	HasAuraUserFlags = true, 
	RemoveAuraUserFlags = true,
	GetSpellRank = true, 
	GetSpellInfo = true
}

LibAura.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibAura.embeds) do
	LibAura:Embed(target)
end

-- Important. Doh. 
Frame:UnregisterAllEvents()
Frame:SetScript("OnEvent", Frame.OnEvent)

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
