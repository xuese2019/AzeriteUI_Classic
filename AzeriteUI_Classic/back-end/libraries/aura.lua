local LibAura = Wheel:Set("LibAura", 27)
if (not LibAura) then
	return
end

-- Add in support for LibClassicDurations.
local LCD = LibStub and LibStub("LibClassicDurations", true)
if (LCD) then
	local ADDON, Private = ...
	LCD:RegisterFrame(Private)
end

local LibMessage = Wheel("LibMessage")
assert(LibMessage, "LibAura requires LibMessage to be loaded.")

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibAura requires LibEvent to be loaded.")

local LibFrame = Wheel("LibFrame")
assert(LibFrame, "LibAura requires LibFrame to be loaded.")

local LibAuraData = Wheel("LibAuraData")
assert(LibAuraData, "LibAura requires LibAuraData to be loaded.")

LibMessage:Embed(LibAura)
LibEvent:Embed(LibAura)
LibFrame:Embed(LibAura)
LibAuraData:Embed(LibAura)

-- Lua API
local _G = _G
local assert = assert
local bit_band = bit.band
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
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local GetComboPoints = GetComboPoints
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local IsPlayerSpell = IsPlayerSpell
local UnitAura = UnitAura
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local UnitIsFeignDeath = UnitIsFeignDeath
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local UnitIsUnit = UnitIsUnit

-- Library registries
LibAura.embeds = LibAura.embeds or {}
LibAura.auraCache = LibAura.auraCache or {} -- dynamic unit aura cache
LibAura.auraCacheByGUID = LibAura.auraCacheByGUID or {} -- dynamic aura info from the combat log
LibAura.auraWatches = LibAura.auraWatches or {} -- dynamic list of tracked units

-- Frame tracking events and updates
LibAura.frame = LibAura.frame or LibAura:CreateFrame("Frame") 

-- Shortcuts
local AuraCache = LibAura.auraCache -- dynamic unit aura cache
local AuraCacheByGUID = LibAura.auraCacheByGUID -- dynamic aura info from the combat log
local UnitHasAuraWatch = LibAura.auraWatches -- dynamic list of tracked units

-- Sourced from FrameXML/BuffFrame.lua
local BUFF_MAX_DISPLAY = BUFF_MAX_DISPLAY
local DEBUFF_MAX_DISPLAY = DEBUFF_MAX_DISPLAY 

-- Sourced from FrameXML/Constants.lua
local COMBATLOG_OBJECT_TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
local COMBATLOG_OBJECT_REACTION_FRIENDLY = COMBATLOG_OBJECT_REACTION_FRIENDLY

-- Library Constants
local DRResetTime = 18.4
local DRMultipliers = { .5, .25, 0 }
local playerGUID = UnitGUID("player")
local _, playerClass = UnitClass("player")
local sunderArmorName = GetSpellInfo(11597)

local localUnits = { player = true, pet = true }
for i = 1,4 do 
	localUnits["party"..i] = true 
	localUnits["party"..i.."pet"] = true 
end 
for i = 2,40 do 
	localUnits["raid"..i] = true 
	localUnits["raid"..i.."pet"] = true 
end 

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
	-- This fires before the aura events
	if (event == "COMBAT_LOG_EVENT_UNFILTERED") then 
		return LibAura:CombatLogHandler(CombatLogGetCurrentEventInfo()) 
	
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
	end
end

LibAura.CombatLogHandler = function(self, ...)
	local timestamp, eventType, hideCaster,
	sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
	destGUID, destName, destFlags, destRaidFlags,
	spellID, spellName, spellSchool, auraType = ...

	local unitGUID = destGUID or sourceGUID
	if (not unitGUID) or (not spellName) then 
		return -- this ever happens?
	end 

	if (spellName == sunderArmorName) then
		if (eventType == "SPELL_CAST_SUCCESS") then
			eventType = "SPELL_AURA_REFRESH"
			auraType = "DEBUFF"
		end
	end

	if (auraType == "BUFF") or (auraType == "DEBUFF") then
		if (eventType == "SPELL_AURA_REFRESH" or eventType == "SPELL_AURA_APPLIED") then
			if (not AuraCacheByGUID[unitGUID]) then 
				AuraCacheByGUID[unitGUID] = {}
			end
			local unitCache = AuraCacheByGUID[unitGUID]
			if (not unitCache[spellName]) then
				unitCache[spellName] = {}
			end
			local spellCache = unitCache[spellName]
			if (not spellCache[sourceGUID]) then
				spellCache[sourceGUID] = {}
			end
			spellCache.timestamp = timestamp
			spellCache.eventType = eventType
			spellCache.sourceFlags = sourceFlags
			spellCache.sourceRaidFlags = sourceRaidFlags
			spellCache.destFlags = destFlags
			spellCache.destRaidFlags = destRaidFlags
			spellCache.isCastByPlayer = sourceGUID == playerGUID
			spellCache.unitCaster = sourceName
	
		elseif (eventType == "SPELL_AURA_REMOVED") then
			local unitCache = AuraCacheByGUID[unitGUID]
			if (unitCache) then
				local spellCache = unitCache[spellName]
				if (spellCache) then
					for i in pairs(spellCache) do 
						spellCache[i] = nil
					end
				end
			end
		end
	end
end

LibAura.CacheUnitBuffsByFilter = function(self, unit, filter)
	if (filter) then 
		return self:CacheUnitAurasByFilter(unit, "HELPFUL " .. filter)
	else 
		return self:CacheUnitAurasByFilter(unit, "HELPFUL")
	end
end 

LibAura.CacheUnitDebuffsByFilter = function(self, unit, filter)
	if (filter) then 
		return self:CacheUnitAurasByFilter(unit, "HARMFUL " .. filter)
	else 
		return self:CacheUnitAurasByFilter(unit, "HARMFUL")
	end
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

	local hasBuffs, hasDebuffs
	local hasPoison, hasCurse, hasDisease, hasMagic

	local counter, limit = 0, string_match(filter, "HARMFUL") and DEBUFF_MAX_DISPLAY or BUFF_MAX_DISPLAY
	for i = 1,limit do 

		-- Retrieve buff information
		local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = UnitAura(queryUnit or unit, i, filter)

		-- No name means no more buffs matching the filter
		if (not name) then
			break
		end

		-- Add aura duration info
		if (LCD) then 
			local durationNew, expirationTimeNew = LCD:GetAuraDurationByUnit(unit, spellId, caster)
			if ((not duration) or (duration == 0)) and (durationNew) then
				duration = durationNew
				expirationTime = expirationTimeNew
			end
		end

		-- Add combat log parsed info
		local spellCache = auraCacheByGUID and auraCacheByGUID[name]
		if (spellCache) then
			unitCaster = spellCache.unitCaster
			isCastByPlayer = spellCache.isCastByPlayer
		else
			unitCaster = unit
			isCastByPlayer = unit == "player"
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
		if (playerClass == "ROGUE") or (playerClass == "DRUID") then
			UnregisterEvent(Frame, "PLAYER_TARGET_CHANGED")
			UnregisterEvent(Frame, "UNIT_POWER_UPDATE")
		end
		LibAura.isTracking = nil
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
	UnregisterAuraWatch = true
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

