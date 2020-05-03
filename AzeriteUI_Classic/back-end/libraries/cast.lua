local LibCast = Wheel:Set("LibCast", 8)
if (not LibCast) then
	return
end

local LibMessage = Wheel("LibMessage")
assert(LibMessage, "LibCast requires LibMessage to be loaded.")

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibCast requires LibEvent to be loaded.")

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibCast requires LibClientBuild to be loaded.")

local LibFrame = Wheel("LibFrame")
assert(LibFrame, "LibCast requires LibFrame to be loaded.")

local LibSpellData = Wheel("LibSpellData", true)
if (LibClientBuild:IsClassic()) then
	assert(LibSpellData, "LibCast requires LibSpellData to be loaded.")
end

LibMessage:Embed(LibCast)
LibEvent:Embed(LibCast)
LibFrame:Embed(LibCast)

if (LibClientBuild:IsClassic()) then
	LibSpellData:Embed(LibCast)
end

-- Lua API
local _G = _G
local assert = assert
local bit_band = bit.band
local date = date
local debugstack = debugstack
local error = error
local math_max = math.max
local math_min = math.min
local pairs = pairs
local select = select
local string_join = string.join
local string_match = string.match
local tonumber = tonumber
local type = type

-- WoW API
local CastingInfo = CastingInfo
local ChannelInfo = ChannelInfo
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local GetSpellInfo = GetSpellInfo
local GetSpellTexture = GetSpellTexture
local GetTime = GetTime
local IsLoggedIn = IsLoggedIn
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local UnitIsUnit = UnitIsUnit

-- Library registries
LibCast.embeds = LibCast.embeds or {}
LibCast.unitCastsByGUID = LibCast.unitCastsByGUID or {}

-- Quality of Life
local UnitCasts = LibCast.unitCastsByGUID
local playerGUID = UnitGUID("player")

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

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

-- Library API
--------------------------------------------------------------------------
if (IsClassic) then

	-- @return spellName, spellText, spellIcon, castStart, castEnd, isTradeSkill, notInterruptible, spellID
	LibCast.UnitCastingInfo = function(self, unit)
		if (UnitIsUnit(unit, "player")) then 
			local spellName, spellText, spellIcon, castStart, castEnd, isTradeSkill, _, notInterruptible = CastingInfo()
			if (spellName) then 
				return spellName, spellText, spellIcon, castStart/1e3, castEnd/1e3, isTradeSkill, notInterruptible, self:GetSpellID(spellName)
			end 
		end 
		local unitGUID = UnitGUID(unit)
		if (not unitGUID) then 
			return 
		end
		local castData = UnitCasts[unitGUID]
		if (not castData) then 
			return 
		end 
		if (not castData.isChanneled) then 
			return 	castData.spellName, -- name
					castData.spellText, -- text
					castData.spellIcon, -- texture
					castData.castStart, -- startTime
					castData.castEnd, 	-- endTime
					nil, 				-- isTradeSkill
					nil, 				-- notInterruptible
					castData.spellID 	-- spellID
		end
	end
	
	-- @return spellName, spellText, spellIcon, castStart, castEnd, isTradeSkill, notInterruptible, spellID
	LibCast.UnitChannelInfo = function(self, unit)
		if (UnitIsUnit(unit, "player")) then 
			local spellName, spellText, spellIcon, castStart, castEnd, isTradeSkill, _, notInterruptible = ChannelInfo()
			if (spellName) then 
				return spellName, spellText, spellIcon, castStart/1e3, castEnd/1e3, isTradeSkill, notInterruptible, self:GetSpellID(spellName)
			end 
		end 
		local unitGUID = UnitGUID(unit)
		if (not unitGUID) then 
			return 
		end
		local castData = UnitCasts[unitGUID]
		if (not castData) then 
			return 
		end 
		if (castData.isChanneled) then 
			return 	castData.spellName, -- name
					castData.spellText, -- text
					castData.spellIcon, -- texture
					castData.castStart, -- startTime
					castData.castEnd, 	-- endTime
					nil, 				-- isTradeSkill
					nil, 				-- notInterruptible
					castData.spellID 	-- spellID
		end
	end

	LibCast.StoreCast = function(self, unitGUID, spellID, spellName, spellIcon, castTime, isChanneled)
		if (not UnitCasts[unitGUID]) then 
			UnitCasts[unitGUID] = {}
		end
		local castData = UnitCasts[unitGUID]
		castData.spellID = spellID
		castData.spellRank = self:GetSpellRank(spellID)
		castData.spellName = spellName
		castData.spellText = spellName -- assume the same?
		castData.spellIcon = spellIcon
		castData.castDuration = castTime/1000 -- the intended cast time
		castData.castStart = GetTime() -- the point in time the cast began
		castData.castEnd = castData.castStart + castData.castDuration -- when the cast is scheduled to end
		castData.castDelay = nil -- any other delays (?)
		castData.castPushback = nil -- pushbacks registered so far
		castData.castPushbackNext = nil -- the duration of the next pushback 
		castData.isChanneled = isChanneled
		castData.isCasting = not isChanneled
	end 
	
	LibCast.DeleteCast = function(self, unitGUID)
		if (not UnitCasts[unitGUID]) then 
			return
		end
		local castData = UnitCasts[unitGUID]
		castData.spellID = nil
		castData.spellRank = nil
		castData.spellName = nil
		castData.spellText = nil
		castData.spellIcon = nil
		castData.castDuration = nil
		castData.castStart = nil
		castData.castEnd = nil
		castData.castDelay = nil
		castData.castPushback = nil
		castData.castPushbackNext = nil
		castData.isChanneled = nil
		castData.isCasting = nil
	end 
	
	-- Sets a cast delay
	LibCast.SetCastDelay = function(self, unitGUID, castDelay)
		if (not UnitCasts[unitGUID]) then 
			return
		end
		local castData = UnitCasts[unitGUID]
		if (castData.isCasting) or (castData.isChanneled) then 
			castData.castDelay = (castData.castDelay or 0) + castDelay
		end 
	end 
	
	-- Sets cast pushback.
	-- This shouldn't affect bar values,
	-- but rather the current position in the cast.
	LibCast.SetCastPushback = function(self, unitGUID)
		if (not UnitCasts[unitGUID]) then 
			return
		end
		local castData = UnitCasts[unitGUID]
		if (castData.isChanneled) then
			if (not castData.castDuration) then 
				return 
			end
	
			-- Channeled spells are reduced by 25% per hit.
			-- *CHECK: Is it 25% of the remaining or full duration?
			local reduction = castData.castDuration * .25
			local now = GetTime()
	
			-- Cast time cannot be less than zero. 
			castData.castDuration = math_max(castData.castDuration - reduction, 0)
	
			-- Cast end cannot suddenly be in the past.
			castData.castEnd = math_max(castData.castEnd - reduction, now)
	
		elseif (castData.isCasting) then
	
			-- (Source: https://wow.gamepedia.com/index.php?title=Interrupt&oldid=305918)
			--     "The first attack will set your casting time back by 1 sec.
			--      Any consequent attack will set it back by a lower amount.
			--      The amount decreases by 0.2 sec. with every attack,
			--      down to a minimum of 0.2 sec. per attack.
			--      However, no attack will actually increase the casting time.
			--      For example if you cast only 0.2 sec. of a spell,
			--      it would only be set back by that amount."
			-- 
			--  I'm going to interprete the above as that the pushback can
			--  only ever push the spell back to the beginning of the cast,
			--  not before it, meaning the maximum CURRENT pushback will only
			--  ever be as big as the position of the cast in the castbar.
			--  
			--  This clearly defines a few problems with how castbars traditionally
			--  have been displayed, as they tend to prolong the duration of the cast
			--  instead of adjusting/pushing back our own current position in it.
			--  
			--  The problem with this is that this approach increases the maxvalue
			--  of the cast, and thus giving the illusion that our current position
			--  is farther ahead relative to the full bar than it actually is.
			--  
			--  I'd prefer going with an approach that respects logic,
			--  but as it stands, logic doesn't exist in this dojo.
			--  So we do it their way.
			--  
			--  Goldpaw
	
			-- Make sure we have an initial pushback value
			local pushbackValue = castData.castPushbackNext or 1
	
			-- Retrieve the current position in the cast relative to its start time
			-- We take the previous delays into consideration here, 
			-- as this part actually does need to follow the laws of game logic.
			local currentCastPosition = GetTime() - castData.castStart - (castData.castPushback or 0)
	
			-- The current pushback can never excede how far the spell
			-- has currently cast, so we're adding in some magic to ensure that. 
			local currentPushback = math_min(pushbackValue, currentCastPosition)
	
			-- Move the point in time the cast is scheduled to end forward
			castData.castDuration = castData.castDuration + currentPushback
			castData.castEnd = castData.castEnd + currentPushback
	
			-- Register how much the cast has been delayed so far in total
			castData.castPushback = (castData.castPushback or 0) + currentPushback
	
			-- Decrease the pushback value for the next pushback
			-- The minimum pushback is 0.2 seconds, so keep it at or above that.
			castData.castPushbackNext = math_max(pushbackValue - .2, .2)
		end
	end
	
	-- CLEU event handler
	LibCast.OnCombatLogEvent = function(self, timeStamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
		destGUID, destName, destFlags, destRaidFlags, ...)
	
		if (eventType == "SPELL_CAST_START") then
			local _, spellName = ...
			local spellID = self:GetSpellID(spellName)
			if (not spellID) then 
				return 
			end
	
			local _, _, spellIcon, castTime = self:GetSpellInfo(spellID)
			if ((not castTime) or (castTime == 0)) then 
				return 
			end
	
			-- Assume people have talented cast time reductions active
			local reducedTime = self:GetSpellCastTimeDecrease(spellName)
			if (reducedTime) then
				-- Only reduce cast time for player casted ability
				if (bit_band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0) then 
					castTime = castTime - (reducedTime * 1000)
				end
			end
	
			-- Store the cast data
			self:StoreCast(sourceGUID, spellID, spellName, spellIcon, castTime, false)
	
			-- Tell listeners about the event
			self:SendMessage("GP_SPELL_CAST_START", sourceGUID)
			return
	
		elseif (eventType == "SPELL_CAST_SUCCESS") then 
			
			-- Channeled spells are started on SPELL_CAST_SUCCESS instead of stopped
			local _, spellName = ...
			local castTime, spellID = self:GetSpellChannelInfo(spellName) 
			if (spellID) then
				if ((not castTime) or (castTime == 0)) then 
					return 
				end
				local _, _, spellIcon = self:GetSpellInfo(spellID)
					
				-- Assume people have talented cast time reductions active
				local reducedTime = self:GetSpellCastTimeDecrease(spellName)
				if (reducedTime) then
					-- Only reduce cast time for player casted ability
					if (bit_band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0) then 
						castTime = castTime - (reducedTime * 1000)
					end
				end
	
				-- Store the channeled data 
				self:StoreCast(sourceGUID, spellID, spellName, spellIcon, castTime, true)
	
				-- Tell listeners about the event
				self:SendMessage("GP_SPELL_CAST_CHANNEL_START", sourceGUID)
				return 
			end
	
			-- Delete the cast data
			self:DeleteCast(sourceGUID)
	
			-- Tell listeners about the event
			self:SendMessage("GP_SPELL_CAST_STOP", sourceGUID)
			return
	
		elseif (eventType == "SPELL_AURA_APPLIED") then 
	
			local _, spellName = ...
			local castIncrease = self:GetSpellCastTimeIncrease(spellName)
			if (castIncrease) then
	
				-- An aura that slows cast speed was applied
				self:SetCastDelay(destGUID, castIncrease)
				return
	
			elseif (self:CanAuraInterruptSpellCast(spellName)) then
	
				-- An aura that interrupted the cast was applied
				self:DeleteCast(destGUID)
				
				-- Tell listeners about the event
				self:SendMessage("GP_SPELL_CAST_INTERRUPTED", destGUID)
				return 
			end
	
		elseif (eventType == "SPELL_AURA_REMOVED") then 
	
			-- Channeled spells have no events for channel stop,
			-- so we're relying on their aura to figure out when it's over.
			local _, spellName = ...
			if (self:GetSpellChannelInfo(spellName)) then
	
				-- This was a channeled cast, so delete it. 
				self:DeleteCast(sourceGUID)
	
				-- Tell listeners about the event
				self:SendMessage("GP_SPELL_CAST_CHANNEL_STOP", sourceGUID)
				return
	
			else
				local castIncrease = self:GetSpellCastTimeIncrease(spellName)
				if (castIncrease) then
					-- An aura that slows cast speed was removed.
					self:SetCastDelay(destGUID, castIncrease, true)
					return
				end
			end
	
	
		elseif (eventType == "SPELL_CAST_FAILED") then 
			local _, spellName, _, failedType = ...
	
			-- Spamming cast keybinds triggers SPELL_CAST_FAILED,
			-- so make sure we're not deleting active casts here. 
			if ((sourceGUID == playerGUID) and CastingInfo("player")) then
				return 
			end 
	
			-- Delete the cast
			self:DeleteCast(sourceGUID)
			
			-- Tell listeners about the event
			self:SendMessage("GP_SPELL_CAST_INTERRUPTED", sourceGUID)
			return
	
		elseif (eventType == "SPELL_INTERRUPT") then 
			local _, spellName, _, extraSpellId, extraSpellName, extraSchool = ...
	
			-- Delete the cast
			self:DeleteCast(sourceGUID)
			
			-- Tell listeners about the event
			self:SendMessage("GP_SPELL_CAST_INTERRUPTED", sourceGUID)
			return
			
		elseif (eventType == "PARTY_KILL") or (eventType == "UNIT_DIED") then 
	
			-- Figure out if it was channeled or a cast
			local castData = UnitCasts[sourceGUID]
			local isChanneled = castData and castData.isChanneled
	
			-- Delete the cast
			self:DeleteCast(sourceGUID)
			
			-- Tell listeners about the event
			if (isChanneled) then 
				self:SendMessage("GP_SPELL_CAST_CHANNEL_STOP", sourceGUID)
			else
				self:SendMessage("GP_SPELL_CAST_STOP", sourceGUID)
			end 
			return
	
		elseif (eventType == "SWING_DAMAGE") or (eventType == "RANGE_DAMAGE") or (eventType == "SPELL_DAMAGE") or (eventType == "ENVIRONMENTAL_DAMAGE") then 
			
			local environmentalType
			local spellId, spellName, spellSchool
			local amount, overkill, school
			local resisted, blocked, absorbed
			local critical, glancing, crushing
			local isOffHand
	
			if (eventType == "SWING_DAMAGE") then
				amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing, isOffHand = ...
			elseif (eventType == "ENVIRONMENTAL_DAMAGE") then
				environmentalType, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing, isOffHand = ...
			elseif (eventType == "RANGE_DAMAGE") or (eventType == "SPELL_DAMAGE") then
				spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing, isOffHand = ...
			end
	
			if (blocked or absorbed) then 
				return 
			end
	
			if (bit_band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0) then 
	
				-- Remove the delay
				self:SetCastPushback(destGUID)
	
				-- Tell listeners about the event
				self:SendMessage("GP_SPELL_CAST_DELAYED", destGUID)
				return
			end
		end
	end

end

if (IsRetail) then

	-- @return spellName, spellText, spellIcon, castStart, castEnd, isTradeSkill, notInterruptible, spellID
	LibCast.UnitCastingInfo = function(self, unit)
		local spellName, spellText, spellIcon, castStart, castEnd, isTradeSkill, castID, notInterruptible, spellID = UnitCastingInfo(unit)
		if (spellName) then
			return spellName, spellText, spellIcon, castStart/1e3, castEnd/1e3, isTradeSkill, notInterruptible, spellID
		end
	end

	-- @return spellName, spellText, spellIcon, castStart, castEnd, isTradeSkill, notInterruptible, spellID
	LibCast.UnitChannelInfo = function(self, unit)
		local spellName, spellText, spellIcon, castStart, castEnd, isTradeSkill, castID, notInterruptible, spellID = UnitChannelInfo(unit)
		if (spellName) then
			return spellName, spellText, spellIcon, castStart/1e3, castEnd/1e3, isTradeSkill, notInterruptible, spellID
		end
	end

end

-- These all function as proxies for WoW events.
-- Idea is to only register for custom messages in the front-end.
LibCast.OnEvent = function(self, event, unit, ...)

	if (event == "UNIT_SPELLCAST_START") then
		self:SendMessage("GP_SPELL_CAST_START", unit)

	elseif (event == "UNIT_SPELLCAST_FAILED") then
		self:SendMessage("GP_SPELL_CAST_FAILED", unit)

	elseif (event == "UNIT_SPELLCAST_STOP") then
		self:SendMessage("GP_SPELL_CAST_STOP", unit)

	elseif (event == "UNIT_SPELLCAST_CHANNEL_STOP") then
		self:SendMessage("GP_SPELL_CAST_CHANNEL_STOP", unit)

	elseif (event == "UNIT_SPELLCAST_SUCCEEDED") then
		self:SendMessage("GP_SPELL_CAST_SUCCESS", unit)

	elseif (event == "UNIT_SPELLCAST_INTERRUPTED") then
		self:SendMessage("GP_SPELL_CAST_INTERRUPTED", unit)

	elseif (event == "UNIT_SPELLCAST_DELAYED") then
		self:SendMessage("GP_SPELL_CAST_DELAYED", unit)

	elseif (event == "UNIT_SPELLCAST_CHANNEL_START") then
		self:SendMessage("GP_SPELL_CAST_CHANNEL_START", unit)

	elseif (event == "UNIT_SPELLCAST_CHANNEL_UPDATE") then
		self:SendMessage("GP_SPELL_CAST_CHANNEL_UPDATE", unit)
	end
end

if (IsClassic) then
	LibCast.OnInit = function(self)
		self:UnregisterEvent("PLAYER_LOGIN", "OnInit")

		-- These fire for the player only in Classic
		self:RegisterUnitEvent("UNIT_SPELLCAST_START", "OnEvent", "player")
		self:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "OnEvent", "player")
		self:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "OnEvent", "player")
		self:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "OnEvent", "player")
		self:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "OnEvent", "player")
		self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "OnEvent", "player")
		self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "OnEvent", "player")
		self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "OnEvent", "player")
	
		-- Just a little proxy here to make the API easier to work with. 
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", function(self, event, ...)
			return self:OnCombatLogEvent(CombatLogGetCurrentEventInfo())
		end)
	end
end

if (IsRetail) then
	LibCast.OnInit = function(self)
		self:UnregisterEvent("PLAYER_LOGIN", "OnInit")

		-- These are for all units in retail
		self:RegisterEvent("UNIT_SPELLCAST_START", "OnEvent")
		self:RegisterEvent("UNIT_SPELLCAST_FAILED", "OnEvent")
		self:RegisterEvent("UNIT_SPELLCAST_STOP", "OnEvent")
		self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", "OnEvent")
		self:RegisterEvent("UNIT_SPELLCAST_DELAYED", "OnEvent")
		self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "OnEvent")
		self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "OnEvent")
		self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "OnEvent")
	end
end

LibCast:UnregisterAllEvents()
LibCast:RegisterEvent("PLAYER_LOGIN", "OnInit")

if (IsLoggedIn()) then
	LibCast:OnInit()
end

local embedMethods = {
	UnitCastingInfo = true,
	UnitChannelInfo = true
}

LibCast.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibCast.embeds) do
	LibCast:Embed(target)
end
