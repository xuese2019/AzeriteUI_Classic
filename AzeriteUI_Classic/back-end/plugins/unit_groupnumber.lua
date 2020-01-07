-- WoW API
local GetRaidRosterInfo = GetRaidRosterInfo
local UnitExists = UnitExists
local UnitInRaid = UnitInRaid
local UnitIsUnit = UnitIsUnit

local Update = function(self, event, unit)
	if (not unit) or (unit ~= self.unit) then 
		return 
	end 

	local element = self.GroupNumber
	if element.PreUpdate then
		element:PreUpdate(unit)
	end

	local groupNumber
	if (UnitExists(unit) and UnitInRaid(unit)) then
		for i = 1,40 do
			if (UnitIsUnit("raid"..i, unit)) then
				local _, _, subgroup = GetRaidRosterInfo(i)
				if (subgroup) then
					groupNumber = subgroup
					break
				end
			end
		end
	end

	if (groupNumber) then
		element:SetText(groupNumber)
		element:Show()
	else
		element:Hide()
		element:SetText("")
	end

	if element.PostUpdate then 
		return element:PostUpdate(unit, groupNumber)
	end
end

local Proxy = function(self, ...)
	return (self.GroupNumber.Override or Update)(self, ...)
end 

local ForceUpdate = function(element)
	return Proxy(element._owner, "Forced", element._owner.unit)
end

local Enable = function(self)
	local element = self.GroupNumber
	if element then
		element._owner = self
		element.ForceUpdate = ForceUpdate
		element:Hide()

		self:RegisterEvent("GROUP_ROSTER_UPDATE", Proxy, true)

		return true 
	end
end 

local Disable = function(self)
	local element = self.GroupNumber
	if element then
		element:Hide()
		self:UnregisterEvent("GROUP_ROSTER_UPDATE", Proxy)
	end
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (Wheel("LibUnitFrame", true)), (Wheel("LibNamePlate", true)) }) do 
	Lib:RegisterElement("GroupNumber", Enable, Disable, Proxy, 1)
end 
