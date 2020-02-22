
-- Lua API
local _G = _G

-- WoW API
local GetExpansionLevel = GetExpansionLevel
local UnitCanAttack = UnitCanAttack
local UnitLevel = UnitLevel

-- WoW Objects
local MAX_PLAYER_LEVEL_TABLE = MAX_PLAYER_LEVEL_TABLE

local Update = function(self, event, unit)
	if (not unit) or (unit ~= self.unit) then 
		return 
	end 

	local element = self.Level

	-- Badge, dead skull and high level skull textures
	-- We will toggle them if they exist or ignore them otherwise. 
	local badge = element.Badge
	local dead = element.Dead
	local skull = element.Skull

	local unitLevel = UnitLevel(unit)

	if element.visibilityFilter then 
		if (not element:visibilityFilter(unit)) then 
			if badge then 
				badge:Hide()
			end
			if dead then 
				dead:Hide()
			end
			if skull then 
				skull:Hide()
			end
			return element:Hide()
		end
	end

	if element.PreUpdate then
		element:PreUpdate(unit)
	end


	-- Showing a skull badge for dead units
	if UnitIsDeadOrGhost(unit) then 
		element:SetText("")

		-- use the dead skull first, 
		-- fallback to high level skull if dead skull doesn't exist
		if dead then 
			dead:Show()
			if skull then 
				skull:Hide()
			end
		elseif skull then 
			skull:Show()
		end 
		if badge then 
			badge:Show()
		end 

	-- Hide capped and above, if so chosen ny the module
	elseif (element.hideCapped and (unitLevel >= MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()])) then 
		element:SetText("")
		if badge then 
			badge:Hide()
		end 
		if skull then 
			skull:Hide()
		end 
		if dead then 
			dead:Hide()
		end

	-- Hide floored units (level 1 mobs and criters)
	elseif (element.hideFloored and (unitLevel == 1)) then 
		element:SetText("")
		if badge then 
			badge:Hide()
		end 
		if skull then 
			skull:Hide()
		end 
		if dead then 
			dead:Hide()
		end

	-- Normal creatures in a level range we can read
	elseif (unitLevel > 0) then 
		element:SetText(unitLevel)
		if UnitCanAttack("player", unit) then 
			local color = GetCreatureDifficultyColor(unitLevel)
			element:SetVertexColor(color.r, color.g, color.b, element.alpha or 1)
		else 
			if (unitLevel ~= unitLevel) then 
				if element.scaledColor then
					element:SetTextColor(element.scaledColor[1], element.scaledColor[2], element.scaledColor[3], element.scaledColor[4] or element.alpha or 1)
				else 
					element:SetTextColor(.1, .8, .1, element.alpha or 1)
				end 
			else 
				if element.defaultColor then 
					element:SetTextColor(element.defaultColor[1], element.defaultColor[2], element.defaultColor[3], element.defaultColor[4] or element.alpha or 1)
				else 
					element:SetTextColor(.94, .94, .94, element.alpha or 1)
				end 
			end 
		end 
		if badge then 
			badge:Show()
		end 
		if skull then 
			skull:Hide()
		end 
		if dead then 
			dead:Hide()
		end

	-- Remaining creatures are boss level or too high to read (??)
	-- So we're giving these a skull.
	else 
		if skull then 
			skull:Show()
		end 
		if badge then 
			badge:Show()
		end 
		if dead then 
			dead:Hide()
		end
		element:SetText("")
	end 

	if (not element:IsShown()) then 
		element:Show()
	end

	if element.PostUpdate then 
		return element:PostUpdate(unit, unitLevel)
	end
end 

local Proxy = function(self, ...)
	return (self.Level.Override or Update)(self, ...)
end 

local ForceUpdate = function(element)
	return Proxy(element._owner, "Forced", element._owner.unit)
end

local Enable = function(self)
	local element = self.Level
	if element then
		element._owner = self
		element.ForceUpdate = ForceUpdate

		if (self.unit == "player" or self.unit == "pet") then 
			self:RegisterEvent("PLAYER_LEVEL_UP", Proxy, true)
		end 
		self:RegisterEvent("UNIT_LEVEL", Proxy)

		return true 
	end
end 

local Disable = function(self)
	local element = self.Level
	if element then
		self:UnregisterEvent("UNIT_LEVEL", Proxy)
		self:UnregisterEvent("PLAYER_LEVEL_UP", Proxy)
	end
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (Wheel("LibUnitFrame", true)), (Wheel("LibNamePlate", true)) }) do 
	Lib:RegisterElement("Level", Enable, Disable, Proxy, 8)
end 
