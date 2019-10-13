local LibAura = CogWheel:Set("LibAura", 16)
if (not LibAura) then	
	return
end

local LibMessage = CogWheel("LibMessage")
assert(LibMessage, "LibAura requires LibMessage to be loaded.")

local LibEvent = CogWheel("LibEvent")
assert(LibEvent, "LibAura requires LibEvent to be loaded.")

local LibFrame = CogWheel("LibFrame")
assert(LibFrame, "LibAura requires LibFrame to be loaded.")

LibMessage:Embed(LibAura)
LibEvent:Embed(LibAura)
LibFrame:Embed(LibAura)

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
		LibAura:SendMessage("CG_UNIT_AURA", unit)

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

local spellRanks = table_concat(
{
	".........1......1...................................1.............1....1...1.1..........1....2....111...........11.1.1.1.1......",
	"....1..1..1...2.3......................1...1......1.........................2......................2.................1..........",
	"...........................23......................1......1........12.....12......1........1................1....1..............",
	"..................1....1............1.............................1.1..1........1.1........111.1212211111211123111..23.2.1.2...2",
	".21.11227.....1.2.211111122111122.3321...2..213221613321212.31211.......1111112212.1232313.111.111122112112313.3131121341.11..2.",
	".13.2.311151122241113233.............214....111.1....122..21.111312.31..211..111221121121123122321.1.....11.......1..1....1211..",
	"31.1.1.1.21212.11111111122221.23..................111...............33.222.211.1.13214.322.622.122.3.4.2.1.3.115.6...2...5.1.2.1",
	"..33332233.133.3444431.1.144.2.1.22.2441.451..5544442155..41.562.4.3.11.233111311.311.44435223344.2222232.2554411111122.1..2211.",
	"244.3.35121.1.1..55.1...3.111...222..2211...33...333..1..1..3224422.133.413.1...35122.2.215.1..13...21...1...1.1.....1...123411.",
	"2.....21..1234.1....221.1...234.1...112211.1.3.3.......21.3.21..2.3.2.2.2..2............1.1231231231341231234123111...12..232312",
	"1212..12..111..124145.12312312312311.123...2323...1.1.....12..12.........4564545..444.123....123....2321.4..121.12....1....2.45.",
	".....123...1231.1..1233231121.1....11..11....1234.123.11..1....12341234.11..1....112..1...1.........11..1..1...........1......1.",
	".......12...1..1..........21..11..11345....123................1.....1234545.......................1....1....2..3................",
	"......23..123....................1...1....1......111..................2121...1....1234512345234512345123451234512..12..1234.1234",
	"..................1..........123.512321..2..1.2..........1..1..1212......3.....123135112.......1234.....12......12.1..1.45......",
	"....................1.1.1...1..........1.....1...........11.....1.................11.1.1.22.11.22..............................3",
	"31123122312113..113422....11.............4545..111................1111112.112..........123.1123.................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"..........................23..2.....23.........1..............5512354..........12345....................1.......................",
	"......................111.1.2341234..........213451234512..12.............1.1.....1.....1.11........................1123452345..",
	"...1....1123452345.........................................................11.5444545......11.2..2....4.4...1.52...2.......1....",
	".12...123451......1.2.....12......1..1.1...343455121..1..11..1........4541...23..1.........1.1.1.1.11.34................3.3.4411",
	"111112..............1.......115671112311........................871.................22...11234123411.211............234623123123",
	"123.14234123111241232312311..........12...........................1414.....................................................1....",
	".........121231212............1...................................34............................................................",
	".........................11........1...........................................1122........1212.........234.....................",
	".........66....666............1.............................................................4........111........................",
	"............6611.....1....................661...............................3434.8455....11......2.1.4.1.112412212342341234..1..",
	"2..1......51.1145111111.13261.661244.225.........................................................1..........................1...",
	"................................................................................................................................",
	"....................................................................................................................1...........",
	"..........123.4124323456782345678.........................................12345678123456781234567812345678.12345.67812345678.123",
	"4567812345678.........12345678123456781234567812345678........2212121212121212312312312.3..............1231231231456782345678123",
	"456781234567811234567823456781123456782345678112211221122112211231123232.112323.112.32311234567823456781123456782345678112345678",
	"23456781123456782345678.............234.234...23456785678..234567811112345678234567823456782345678123456782345678234567823456782",
	"34567823456782345678..2345678234567812345678123456781234567812345678.1123.456.782345678.1123456.7823456781.123456782345678......",
	"..............232312323112323............1122....221122112211221122.....12323...123456782345678112345678234567811234567823456781",
	"1234567823456781123456782345678121211221122.......112323112323..................................................................",
	"..................................9ABCDEF9ABCDEF9ABCDEF9ABDEFC9ABCDEF9BCDEFA9ABCDEF9ABCDEF.9ABCDEF9ABCDEF....1.................1",
	"1111111111.......11...123123..1..12345........1...1..41123452345123452134534122.3.34.....111.11111..1111.....21224311112222....1",
	"....1.1..1..........11.1111....12.1.123.2345.234511...1211113124.......111111............1.9ABCDEF.9ABCDEF9ABCDEF.1123423412345.",
	"...........22122.1.1...1....1.....................G9ABCDE..............9ABCDE1239ABCDE12312339ABCDEF12321231.1..9ABCDE.123.....1",
	"2311123.F..9ABCDEF.12312312.9ABCDEF123..1239ABCDEF1239ABCDEF23..61612233345454.11232323..12312222323.2..323.123232.12....12.2234",
	"56789ABCDEF23.312123456789ABCDEF.....111..1111...345678345678..1......111...1.....123....1.231211111111111.11123456789ABCDEF12.1",
	"11121231456789ABCDEF.11..1234567845645612345678....123412339A49A34123412311.23234349A9A1123234341.......1123234349AA9341123.234.",
	"..9A34.11234239A3411.23423.111349A1234123349A112323412341234...12345671234567...112323456.71123234567...........1234....123412..",
	".........123..12.12341..626.............133666345656223412345623456.23456789A112231112345678A2239..113111322..444433123123222211",
	".2222.11263456234511234.5234523232.2...2222..2233...........33123123223333221232322.1111...................................1....",
	".......1234.15....2345............1...1.12345....2345..1.12345....234512..1..2341......121234.234523452435234.2312.2.234234.2342",
	"34......1............1...........1........12345.1....2345................1...................1............1.....1111............",
	".............4411234234112323112323112233111122.......................................................12..1.334.4333..1...1.....",
	"..1.............11....................................11...........1.1.1....11111.33...............3...234234..22122222..6666422",
	"112.121.22...2222....1123123....................................................................................................",
	".......21.....1............11.......1.......1..1.234566.22....2344232.32323....21222222.1.........................234234........",
	"............................................................3...1..1...................222......1.................1......1..1...",
	".........1...................5555.6789678966.................1234512435123451234512345.............123..1..............1.1...1.1",
	"1..231.................214441111111..........1....................1..1..2112323.4233.1.111...23231.....22331221.................",
	"................................................................................................................................",
	"........................................................................................66...44441444....23231.111..............",
	"...............................................11..................................1..................................2345.23123",
	"23412123............1..2345...................................123231232.1234112.2............................11......56....11...",
	"..1....................1.............1....................11...1...1771223322...123123.111223323111.222..11234234112323112211...",
	"2....1111.111........1....11123123...2345623456123123123111221111122155....1......1..111.232323232323.........1..1..111111111112",
	"222..2111..3434...1....1..........1.111111222........4.222221.4....1.11111..........1..........23231.......................2323.",
	"...........................1111.......................1....33.....2222......1..567567567567454545544534.34331.....1.234234123423",
	"42323.2223232323..............2342.34234...222323232323232323..11111............................................................",
	"................1..1.3.................1....6656561.3323423433232322..112323.....................1.1.11111..22233.3222222..12...",
	".......1........5.523.23.......1...................................................4.....................3.4.....4.22.2323......",
	"..111....................................1...23.......................777755.77..44..2.211.2345672345671123452345...23423422....",
	"...........44234234...33...111.33.1111122...1111..........................1.....................1...............................",
	"...........................................1...................................................................1................",
	"....1111.........1......................2.......................................................................................",
	"........................................................................................4..................11..................2",
	"34234...6..122...332323..................................................................................2323..........44.......",
	"...............................11...............................................................................................",
	"....1..11..11...554436644445588.......................................1.....................22222333454589A89A89A89A343445556567",
	"89789343434345656.5656.676767679A9A33556655.33.44.455688333............................................................1........",
	"................................33.................................2....34......................................................",
	".........................567567565689AB89AB4553453453434343445454489A89A456456456456667756565675676767565634344455...443344.....",
	"............................45456744.3345454564562467246723452345334433456456232.223333787878784545...6........................1",
	"......................787889894145456456456567567.67675656565667675656564443444545.....333.4545454564563434232323..3.3.3..2.3423",
	"4..............2.34.....3.33.3.3.....23.23.23.....................................2342342342342323111232323.4.2223332323.....232",
	"3222............................................................................................................................",
	"............................................1........................................78..................................3453453",
	"43423333344678678789A789A...222323567567......789789787856565656789789563333233344234...........................................",
	"................56.........................................1111......1.2..1.1........11....1..1....1....1.1...12...1............",
	"..............1........1....1....1....1....1....1...11......454522....1.11..1........1.........1....1....1....1....1..1......1..",
	"..4564564564566786784545565678783378784434545454545453........1.2.....456456456456......343434134....1234511....................",
	".....3333...........123..........1..........................................432.................................................",
	"..................1.........4565634534523235678..785675673356563434456456..45454545343434.......................................",
	"..........7897895567675656443434232323456456567567565634345656456456442223232323....3453452323...................676745454545565",
	"64564563434.................................................1...................................................................",
	"................................................................................................................................",
	"..................1.............................................................................................................",
	".11.1........4444.4..................1..................................................................................11.11111",
	"11...11.1111111...21..111...111111.1111.12.......2345345....23232.1.2345.................2...................345................",
	"..............................................23..2.3...2.2........1232323...1.23452345.2............23..345678.................",
	"................1.......243.52345.23...........23....2.345.222...................................................23...2323.2...2",
	"...2345.....1.........122..123451.23..2345........12345......................2345.......23452...............2.345..23.45....1123",
	"..22..3..232345..2..1..2342342345123452345...34522.2314523.451234533...234523451.....2..........................................",
	"...............31....2.234.152234521.123452345.......2345.............2345........34.56782345623453...2345672345672.2345........",
	".23..................1......................................................................................1...................",
	".................................1111234234234234...............................................................................",
	"...............................................................................................................1................",
	".........................................1.......11...................................1....1.........567567.23456782345678......",
	"................................................................................................................................",
	"........111.11.11.1................11.......1111.......2.1.................................234532.1.1.123452345....111..........",
	".......2..1.......345..23.452345..2...2.232....2..23...................1...........1............................................",
	".....1.12345.234523451111.231.1.........................................................................123452345234523234511212",
	"31212..1..23123.............1...12345.1........1...2..3451234511...22334455111223123123123123123....1....1...2..345.....2345....",
	"............................................1.12345234567823234232234.232345678234...232.23452345..2323..23232345623423....23456",
	"78232342322342323456783423223452.3.2323456....................................................23.4..........23..................",
	".......................................................111112345..1.............................................................",
	"................................................................................................................................",
	"......................1..11111.1..............22323222.2345234523452345..........................233............................",
	"........................................1..11....11.1..11..1111111.234567234567.................................................",
	"...............................2345223452232.2.23452345..214..........3....45....123.......2....................................",
	"..1123231.23..............................34567.......................................................9A9A......................",
	"....1...................1111823456711112111..........1....................23452234.521.3452345234523452345..........223453452.34",
	"52345..........................1..............1......................2345345.1.........2.3.2.34.5.67............................",
	"....................3.........................1...............................234............................1...1..............",
	"............3456....3456...1.1..................................................1............................................1..",
	".............................................................................1..................................................",
	"................................................................................................................................",
	"..................................11.1111.1.........................................11.1.1..............2345234523452345..2...2.",
	"22345......................23452345.........1..1111111111.1..11111.2.345234523452234523452345234523452.34522345345........111111",
	"1111111111....2345..234523452222323223232234523452345.56756767....................4.5656..56...45.4545..444.....................",
	"..444....42.345..............................................................12345....................1.2..312........45......1.",
	"123......................12345.2.12..1.....................1.....12345....................1.............1.......................",
	"................................................1.......66....................45..1..........12345.................112....3.4511",
	"45.145111111.1...........................2345123451212345.1234561231..2345..123451....1.112345..........633567............315451",
	"2.34512345..1234512..123..2345..1234512345.1212345123451.234511.2345.1.2...1.2345....1...............1212.1234..................",
	".........................12.3451.2345.1.23451234512345112233.............1.23451.1234512345..1234512............................",
	".1....................................345.......................................1...........1.234...1123456782345678............",
	"..............................2345.345...12.3...6...1.............23..1..22223333231........3456..........234234.3434...23...3..",
	"..................12345.....................................................12345.1.............................................",
	"........6.......................................................................................................................",
	"......................................................................11.............234234...........1........1.123451234512345",
	"1..2....34512345.123451.................2345.............23456234.56.1.11...........1.......................................1223",
	"456223122345....22......2.3.4....123451..1....1.................................................................................",
	"........................2.......1.......1....121....1.................12345..121212345121.1..............23456.223......2....123",
	"4512312...1.5.......................1....121..............111...........................1.....12345..111........................",
	".....1234..........................................................2........1...........21................................123...",
	"..........................12.1234545.............................................................12.345..45....1..234512345.....",
	"...............................................9.A....................................22........2323............................",
	"...1212312345.12123.12....................1..1........2345.12345.12312.....1..121234512..............................8668.......",
	"...112345.1.231...................................234562..3456234.............................................234234234.2323....",
	"...................................1...11.......................................................................................",
	"..............................................................................12345...12.34.5..1...........23..1................",
	"...........................1...23452.314567123452.345612345.23.45623452.3452345623456123213452122335445671.23456234561.234561234",
	"56123456.123456712345123456712345........12.3451212.1234512345................1....2345123451234512.345..1...2234563456......123",
	"45..12.12345.....111111..11.1.23451.23...1231...1112345.....................................123123451212345........1212..11...12",
	"345..1.2345..123451.234512435.11234512345.....................21.2.23423.1.41234................................................",
	"..................223344234111111....11..................................................................................2345623",
	"456......2.3452345...........12..1.1...........1..1111232323...232323.............................2345623456....................",
	".6543212123..............212366..........................................11123451......234512345..........................123451",
	"2345123451234512345212345.....1..2....34512345123451234511.......21.111111...12.1.2435111112122231212345...1123541.2345........1",
	"2.....111122123.1211234512311123123451234511.2.........23456782345678......3456634566..3456722345123.45..34523123544234234234232",
	"32323.12345...........1.345612345612345612341234561234....234523452.345.1234123412..2345678234566123451234123.....1123451.......",
	"...11.12345....3345121212......1...........................1..................4545......5.5.....................................",
	"231..2323...23........1..........................2.345........................................45.7....1.................22.....1",
	".12..3.23.4545...................554545452345.................1...A........................................................1....",
	"2345.67.............11111..2.323...2345623232312342.2345.34513232323456..3.2323234512343451232.3322345451.......................",
	".................................................................................1.......1111.......................1...........",
	"..........................................1....1..............1..11.............................................................",
	"................................................................................................111111..........................",
	"................................................................................................................................",
	"..............................................234.2.34.1.1.2..112.................1111.11111111111111111111111111...............",
	".....................................................................................................................1..........",
	"......................................................................3.................1212.....................1..............",
	"...................................................................1.1..........11....................1.................5.......",
	"..............................1111..............................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	".................................................................................1..............................................",
	".......................................1111...........123.......................................................................",
	".................................................................................1...........................1...........1...232",
	"3...............1..1......................234234.........1........1.2.......34...............................12323..............",
	"...............................................12345............................................................1.1111..........",
	"..........................................................11..1.....2323................................112323...........112323.",
	".........................................1.......................................................1..............................",
	"...................................................................................................1.123.....................5..",
	"..............................1..23....................1234.....................................................................",
	"..............A86..............12345.............1..............................................................................",
	"..............3A................................................................................................................",
	".....................................444.4..............................1..........234...234.....................1234234........",
	"..........56..........88...............................1.................................................44.....................",
	"................................................123..123..........12323.........................................................",
	"...............................1.........1...63........4....................1234521123....3..45.....1234512.....................",
	".................................................................45..........1.......1.....68A.1......11..............2121134123",
	"4112323.......34...2.3.41.1234..2..34..1.1.1111.2..342342342342342341112342342342...123456789...1.11234567823456782.345678......",
	"23423422.3434.......4.4...312.321...................9A9A9A.A...11........................................1.1......3.............",
	"...............................................7................................................................................",
	"...........11................................................5....11.....................1....................2345..............",
	".......12345.23452345..........................2345623456..........................................................11...........",
	"....................................................1...........................................................................",
	".....................................................................9.67679.597B7B9.5.B.CA.8.7..5A5............................",
	"8854555A5967A.3355...................................6793A5597B7B.955BC8A87.....................................................",
	"..........................................................................................................................1.....",
	"...............................................................................................................38.8...........76",
	"54321176543211..1.....4.......2345...................1..........................1....1.6............5......2....................",
	".................................1...1....1..33.....1.2121122212...................B.......1451....12976679A53597B7B95.5BC8A875A",
	"5..2........1..................22345312........................................11...1....................1...1..................",
	"................................................................234....2342323..........55.......................1..............",
	"..........................................................................................................................71234.",
	"56......1.......................................................................................................................",
	"............................................................................12..................................................",
	"...........................111.............................................................................................1....",
	"................................................................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"........................................................3654...3....................89A724....2.26..335622.....63...............",
	"................................11116..................................................2................3.......................",
	"............12.....1..4564456.....1.1.2323..456....2..........1245451........................23.2323.......................12345",
	"................................................................................................................................",
	"................................................................................................................................",
	".............................................................................................................1.............1....",
	"...........................................2..........6.................................123456...............123................",
	".............1....23............................................................................................................",
	"...............................................2345............654477...........................................................",
	"..........1.....................................................................................................................",
	"..............................................................................................................4.................",
	"...................................................................12312....1...................................................",
	".....1.23........123..23.1.2.345...................................................1.12345................1...1.........2323....",
	"..1.2.312........3..21.....................66...................................................................................",
	".............................................................................................................................123",
	"1..2345.....................12.................................................4......................................1.........",
	"...................23.................A.........................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"...............................................................................1....1...........................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"...............................................2.........................................32.....................................",
	"..............................................................................1231123452345123.1.2345...........................",
	"............123123123451.......1...........12123.....12345............12........................................................",
	".............................12........995.5....................................................................................",
	"................................................................................................................................",
	"......................1.........................................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"................................................................................................................................",
	"................................................................................................................................"
})
local rankTranslation = {
	[49] =  1, [50] =  2, [51] =  3, [52] =  4, [53] =  5, [54] =  6, [55] =  7, [56] =  8, [57] =  9, 
	[65] = 10, [66] = 11, [67] = 12, [68] = 13, [69] = 14, [70] = 15, [71] = 16, [72] = 17, [73] = 18, 
	[74] = 19, [75] = 20, [76] = 21, [77] = 22, [78] = 23, [79] = 24, [80] = 25, [81] = 26, [82] = 27
}

LibAura.GetSpellRank = function(self, spellID)
	if (type(spellID)=="number") then
		return rankTranslation[string_byte(spellRanks, spellID)]
	elseif (type(spellID) == "string") then
		local s = string_find(spellID, "%(")
		if (s) then
			local e = string_find(spellID,"%)", s)
			if (e) then
  				rank = string_sub(spellID, s+1, e-1)
				return rank
			end
		end
	end
end

-- Blizzard API: 
-- local name, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(spellId or "spellName"[, "spellRank"])
LibAura.GetSpellInfo = function(self, spellID, spellRank)
	local name, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(spellID)
	return name, rank or self:GetSpellRank(spellID), icon, castTime, minRange, maxRange, spellId
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
------------------------------------------------------------------------
AddFlags( 1066, IsDruid) 					-- Aquatic Form
AddFlags( 8983, IsDruid + IsStun) 			-- Bash
AddFlags(  768, IsDruid) 					-- Cat Form
AddFlags( 5209, IsDruid + IsTaunt) 			-- Challenging Roar (Taunt)
AddFlags( 9821, IsDruid) 					-- Dash
AddFlags( 9634, IsDruid) 					-- Dire Bear Form
AddFlags( 5229, IsDruid) 					-- Enrage
AddFlags(16857, IsDruid) 					-- Faerie Fire (Feral)
AddFlags(22896, IsDruid) 					-- Frenzied Regeneration
AddFlags( 6795, IsDruid + IsTaunt) 			-- Growl (Taunt)
AddFlags(24932, IsDruid) 					-- Leader of the Pack
AddFlags( 9826, IsDruid + IsStun) 			-- Pounce
AddFlags( 6783, IsDruid) 					-- Prowl
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
