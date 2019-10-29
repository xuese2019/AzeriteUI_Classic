local LibFader = Wheel:Set("LibFader", 23)
if (not LibFader) then	
	return
end

local LibFrame = Wheel("LibFrame")
assert(LibFrame, "LibFader requires LibFrame to be loaded.")

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibFader requires LibEvent to be loaded.")

local LibMessage = Wheel("LibMessage")
assert(LibMessage, "LibFader requires LibMessage to be loaded.")

local LibAura = Wheel("LibAura")
assert(LibAura, "LibFader requires LibAura to be loaded.")

LibFrame:Embed(LibFader)
LibEvent:Embed(LibFader)
LibMessage:Embed(LibFader)
LibAura:Embed(LibFader)

-- Lua API
local assert = assert
local debugstack = debugstack
local error = error
local ipairs = ipairs
local pairs = pairs
local select = select
local setmetatable = setmetatable
local string_join = string.join
local string_match = string.match
local table_concat = table.concat
local table_insert = table.insert
local type = type

-- WoW API
local CursorHasItem = CursorHasItem
local CursorHasSpell = CursorHasSpell
local GetCursorInfo = GetCursorInfo
local InCombatLockdown = InCombatLockdown
local IsInGroup = IsInGroup
local IsInInstance = IsInInstance
local RegisterAttributeDriver = RegisterAttributeDriver
local SpellFlyout = SpellFlyout
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local UnregisterAttributeDriver = UnregisterAttributeDriver

-- WoW Constants
local DEBUFF_MAX_DISPLAY = DEBUFF_MAX_DISPLAY or 16
local POWER_TYPE_MANA = Enum.PowerType.Mana

-- Player Constants
local _,playerClass = UnitClass("player")
local playerLevel = UnitLevel("player")

-- Library registries
LibFader.embeds = LibFader.embeds or {}
LibFader.objects = LibFader.objects or {} -- all currently registered objects
LibFader.defaultAlphas = LibFader.defaultAlphas or {} -- maximum opacity for registered objects
LibFader.data = LibFader.data or {} -- various global data
LibFader.frame = LibFader.frame or LibFader:CreateFrame("Frame", nil, "UICenter")
LibFader.frame._owner = LibFader
LibFader.FORCED = nil -- we want this disabled from the start

-- Speed!
local Data = LibFader.data
local Objects = LibFader.objects

-- These are debuffs which are ignored, 
-- allowing the interface to fade out even though they are present. 
local safeDebuffs = {
	-- deserters
	[ 26013] = true, -- PvP Deserter 
	[ 71041] = true, -- Dungeon Deserter 
	[144075] = true, -- Dungeon Deserter
	[ 99413] = true, -- Deserter (no idea what type)

	-- heal cooldowns
	[ 11196] = true, -- Recently Bandaged
	[  6788] = true, -- Weakened Soul
	
	-- burst cooldowns
	[ 57723] = true, -- Exhaustion from Heroism
	[ 95809] = true, -- Insanity from Ancient Hysteria
	[ 57724] = true, -- Sated from Bloodlust
	[ 80354] = true, -- Temporal Displacement from Time Warp
	
	-- Resources
	[ 36032] = true, -- Arcane Charges
	
	-- Seasonal 
	[ 26680] = true, -- Adored "You have received a gift of adoration!" 
	[ 42146] = true, -- Brewfest Racing Ram Aura
	[ 26898] = true, -- Heartbroken "You have been rejected and can no longer give Love Tokens!"
	[ 71909] = true, -- Heartbroken "Suffering from a broken heart."
	[ 43052] = true, -- Ram Fatigue "Your racing ram is fatigued."
	[ 69438] = true, -- Sample Satisfaction (some love crap)
	[ 24755] = true  -- Tricked or Treated (Hallow's End)
}

-- These are buffs that will keep the interface visible while active. 
local unsafeBuffs = {
	[   430] = true, -- Drink
	[   431] = true, -- Drink
	[   432] = true, -- Drink
	[  1133] = true, -- Drink
	[  1135] = true, -- Drink
	[  1137] = true, -- Drink
	[ 10250] = true, -- Drink
	[ 22734] = true, -- Drink
	[ 24355] = true, -- Drink
	[ 25696] = true, -- Drink
	[ 26261] = true, -- Drink
	[ 26402] = true, -- Drink
	[ 26473] = true, -- Drink
	[ 26475] = true, -- Drink
	[ 29007] = true  -- Drink
}

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

local InitiateDelay = function(self, elapsed) 
	return self._owner:InitiateDelay(elapsed) 
end

local OnUpdate = function(self, elapsed) 
	return self._owner:OnUpdate(elapsed) 
end

local SetToDefaultAlpha = function(object) 
	object:SetAlpha(Objects[object]) 
end

local SetToZeroAlpha = function(object)
	object:SetAlpha(0)
end 

local SetToProgressAlpha = function(object, progress)
	object:SetAlpha(Objects[object] * progress) 
end

-- Register an object with a fade manager
LibFader.RegisterObjectFade = function(self, object)
	-- Don't re-register existing objects, 
	-- as that will overwrite the default alpha value 
	-- which in turn can lead to max alphas of zero. 
	if Objects[object] then 
		return 
	end 
	Objects[object] = object:GetAlpha()
end

-- Unregister an object from a fade manager, and hard reset its alpha
LibFader.UnregisterObjectFade = function(self, object)
	if (not Objects[object]) then 
		return 
	end

	-- Retrieve original alpha
	local alpha = Objects[object]

	-- Remove the object from the manager
	Objects[object] = nil

	-- Restore the original alpha
	object:SetAlpha(alpha)
end

-- Force all faded objects visible 
LibFader.SetObjectFadeOverride = function(self, force)
	if (force) then 
		LibFader.FORCED = true 
	else 
		LibFader.FORCED = nil 
	end 
end

-- Prevent objects from fading out in instances
LibFader.DisableInstanceFading = function(self, fade)
	if (fade) then 
		Data.disableInstanceFade = true 
	else 
		Data.disableInstanceFade = false 
	end
end

-- Prevent objects from fading out while grouped
LibFader.DisableGroupFading = function(self, fade)
	if (fade) then 
		Data.disableGroupFade = true 
	else 
		Data.disableGroupFade = false 
	end
end

-- Set the default alpha of an opaque object
LibFader.SetObjectAlpha = function(self, object, alpha)
	check(alpha, 2, "number")
	if (not Objects[object]) then 
		return 
	end
	Objects[object] = alpha
end 

LibFader.CheckMouse = function(self)
	if (SpellFlyout and SpellFlyout:IsShown()) then 
		Data.mouseOver = true 
		return true
	end 
	for object in pairs(Objects) do 
		if object.GetExplorerHitRects then 
			local top, bottom, left, right = object:GetExplorerHitRects()
			if (object:IsMouseOver(top, bottom, left, right) and object:IsShown()) then 
				Data.mouseOver = true 
				return true
			end 
		else 
			if (object:IsMouseOver() and object:IsShown()) then 
				Data.mouseOver = true 
				return true
			end 
		end 
	end 
	Data.mouseOver = nil
end

LibFader.CheckCursor = function(self)
	if (CursorHasSpell() or CursorHasItem()) then 
		Data.busyCursor = true 
		return 
	end 

	-- other values: money, merchant
	local cursor = GetCursorInfo()
	if (cursor == "petaction") 
	or (cursor == "spell") 
	or (cursor == "macro") 
	or (cursor == "mount") 
	or (cursor == "item") then 
		Data.busyCursor = true 
		return 
	end 
	Data.busyCursor = nil
end 

-- TODO: Integration with LibAura
LibFader.CheckAuras = function(self)
	for i = 1, BUFF_MAX_DISPLAY do
		local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = LibFader:GetUnitBuff("player", i)

		-- No name means no more debuffs matching the filter
		if (not name) then
			break
		end

		-- Set the flag and return if a filtered buff is encountered
		if (unsafeBuffs[spellId]) then
			Data.badAura = true
			return
		end
	end
	for i = 1, DEBUFF_MAX_DISPLAY do
		local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = LibFader:GetUnitDebuff("player", i)

		-- No name means no more debuffs matching the filter
		if (not name) then
			break
		end

		-- Set the flag and return if a non-filtered debuff is encountered
		if (not safeDebuffs[spellId]) then
			Data.badAura = true
			return
		end
	end
	Data.badAura = nil
end

LibFader.CheckHealth = function(self)
	local min = UnitHealth("player") or 0
	local max = UnitHealthMax("player") or 0
	if (max > 0) and (min/max < .9) then 
		Data.lowHealth = true
		return
	end 
	Data.lowHealth = nil
end 

LibFader.CheckPower = function(self)
	local powerID, powerType = UnitPowerType("player")
	if (powerType == "MANA") then 
		local min = UnitPower("player") or 0
		local max = UnitPowerMax("player") or 0
		if (max > 0) and (min/max < .75) then 
			Data.lowPower = true
			return
		end 
	elseif (powerType == "ENERGY" or powerType == "FOCUS") then 
		local min = UnitPower("player") or 0
		local max = UnitPowerMax("player") or 0
		if (max > 0) and (min/max < .5) then 
			Data.lowPower = true
			return
		end 
		if (playerClass == "DRUID") then 
			min = UnitPower("player", POWER_TYPE_MANA) or 0
			max = UnitPowerMax("player", POWER_TYPE_MANA) or 0
			if (max > 0) and (min/max < .5) then 
				Data.lowPower = true
				return
			end 
		end
	end 
	Data.lowPower = nil
end 

LibFader.CheckTarget = function(self)
	if UnitExists("target") then 
		Data.hasTarget = true
		return 
	end 
	Data.hasTarget = nil
end 

LibFader.CheckGroup = function(self)
	if IsInGroup() then 
		Data.inGroup = true
		return 
	end 
	Data.inGroup = nil
end

LibFader.CheckInstance = function(self)
	if IsInInstance() then 
		Data.inInstance = true
		return 
	end 
	Data.inInstance = nil
end

LibFader.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then 

		Data.inCombat = InCombatLockdown()

		self:CheckInstance()
		self:CheckGroup()
		self:CheckTarget()
		self:CheckHealth()
		self:CheckPower()
		self:CheckAuras()
		self:CheckCursor()

		self:ForAll(SetToDefaultAlpha)

		self.FORCED = nil
		self.elapsed = 0
		self.frame:SetScript("OnUpdate", InitiateDelay)
	
	elseif (event == "PLAYER_LEVEL_UP") then 
			local level = ...
			if (level and (level ~= playerLevel)) then
				playerLevel = level
			else
				local level = UnitLevel("player")
				if (not playerLevel) or (playerLevel < level) then
					playerLevel = level
				end
			end
		
	elseif (event == "PLAYER_REGEN_DISABLED") then 
		Data.inCombat = true

	elseif (event == "PLAYER_REGEN_ENABLED") then 
		Data.inCombat = false

	elseif (event == "PLAYER_TARGET_CHANGED") then 
		self:CheckTarget()

	elseif (event == "GROUP_ROSTER_UPDATE") then 
		self:CheckGroup()

	elseif (event == "UNIT_POWER_FREQUENT") 
		or (event == "UNIT_DISPLAYPOWER") then
			self:CheckPower()

	elseif (event == "UNIT_HEALTH_FREQUENT") then 
		self:CheckHealth()

	elseif (event == "GP_UNIT_AURA") then 
		self:CheckAuras()

	elseif (event == "ZONE_CHANGED_NEW_AREA") then 
		self:CheckInstance()
	end 
end

LibFader.InitiateDelay = function(self, elapsed)
	self.elapsed = self.elapsed + elapsed

	-- Enforce a delay at the start
	if (self.elapsed < 15) then 
		return 
	end

	self.elapsed = 0
	self.totalElapsed = 0
	self.totalElapsedIn = 0
	self.totalElapsedOut = 0
	self.totalDurationIn = .15
	self.totalDurationOut = .75
	self.currentPosition = 1
	self.achievedState = "peril"

	self.frame:SetScript("OnUpdate", OnUpdate)
end 

LibFader.OnUpdate = function(self, elapsed)
	self.elapsed = self.elapsed + elapsed

	-- Throttle any and all updates
	if (self.elapsed < 1/60) then 
		return 
	end 

	if self.FORCED
	or Data.inCombat 
	or Data.hasTarget 
	or (Data.inGroup and Data.disableGroupFade)
	or (Data.inInstance and Data.disableInstanceFade)
	or Data.lowHealth 
	or Data.lowPower 
	or Data.busyCursor 
	or Data.badAura 
	or self:CheckMouse() then 
		if (self.currentPosition == 1) and (self.achievedState == "peril") then 
			self.elapsed = 0
			return 
		end 
		local progress = self.elapsed / self.totalDurationIn
		if ((self.currentPosition + progress) < 1) then 
			self.currentPosition = self.currentPosition + progress
			self.achievedState = nil
			self:ForAll(SetToProgressAlpha, self.currentPosition)
		else 
			self.currentPosition = 1
			self.achievedState = "peril"
			self:ForAll(SetToDefaultAlpha)
		end 
	else 
		local progress = self.elapsed / self.totalDurationOut
		if ((self.currentPosition - progress) > 0) then 
			self.currentPosition = self.currentPosition - progress
			self.achievedState = nil
			self:ForAll(SetToProgressAlpha, self.currentPosition)
		else 
			self.currentPosition = 0
			self.achievedState = "safe"
			self:ForAll(SetToZeroAlpha)
		end 
	end 
	self.elapsed = 0
end

LibFader.ForAll = function(self, method, ...)
	for object in pairs(Objects) do 
		if (type(method) == "string") then 
			object[method](object, ...)
		elseif (type(method) == "function") then 
			method(object, ...)
		end 
	end 
end

local embedMethods = {
	SetObjectFadeOverride = true, 
	RegisterObjectFade = true,
	UnregisterObjectFade = true,
	DisableInstanceFading = true, 
}

LibFader.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibFader.embeds) do
	LibFader:Embed(target)
end

LibFader:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnEvent")
LibFader:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
LibFader:RegisterEvent("PLAYER_LEVEL_UP", "OnEvent")
LibFader:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent") 
LibFader:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent") 
LibFader:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent") 
LibFader:RegisterEvent("GROUP_ROSTER_UPDATE", "OnEvent") 
LibFader:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", "OnEvent", "player") 
LibFader:RegisterUnitEvent("UNIT_POWER_FREQUENT", "OnEvent", "player") 
LibFader:RegisterUnitEvent("UNIT_DISPLAYPOWER", "OnEvent", "player") 
LibFader:RegisterMessage("GP_UNIT_AURA", "OnEvent")
