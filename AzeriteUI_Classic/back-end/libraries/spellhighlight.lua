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
local debugstack = debugstack
local error = error
local string_join = string.join
local string_match = string.match
local type = type

-- WoW API
local UnitClass = UnitClass

-- Doing it this way to make the transition to library later on easier
LibSpellHighlight.embeds = LibSpellHighlight.embeds or {} 
LibSpellHighlight.highlightSpellsByAuraID = LibSpellHighlight.highlightSpellsByAuraID or {} 
LibSpellHighlight.highlightTypeByAuraID = LibSpellHighlight.highlightTypeByAuraID or {} 
LibSpellHighlight.activeHighlights = LibSpellHighlight.activeHighlights or {}

-- Shortcuts
local HighlightSpellsByAuraID = LibSpellHighlight.highlightSpellsByAuraID
local HighlightTypeByAuraID = LibSpellHighlight.highlightTypeByAuraID
local ActiveHighlights = LibSpellHighlight.activeHighlights

-- Constants
local _,playerClass = UnitClass("player")

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

LibSpellHighlight.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		self:UpdateHighlightsByAura()

	elseif (event == "GP_UNIT_AURA") then
		local unit = ...
		if (unit == "player") then
			self:UpdateHighlightsByAura()
		end
	end
end

LibSpellHighlight:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
LibSpellHighlight:RegisterMessage("GP_UNIT_AURA", "OnEvent")

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
