-- WoW Dummy API for now.
-- We will find a way to figure this out better later on. Maybe. 
local UnitGroupRolesAssigned = function(unit)
	return "DAMAGER"
end

local roleToObject = { TANK = "Tank", HEALER = "Healer", DAMAGER = "Damager" }

local Update = function(self, event, unit)
	if (not unit) or (unit ~= self.unit) then 
		return 
	end 

	local element = self.GroupRole
	if element.PreUpdate then
		element:PreUpdate(unit)
	end

	local groupRole = UnitGroupRolesAssigned(self.unit)
	if (groupRole == "TANK" or groupRole == "HEALER" or groupRole == "DAMAGER") then
		local hasRoleTexture
		for role, objectName in pairs(roleToObject) do 
			local object = element[objectName]
			if object then 
				object:SetShown(role == groupRole)
				hasRoleTexture = true
			end 
		end 
		if (element.Show and hasRoleTexture) then 
			element:Show()
		elseif element.Hide then  
			element:Hide()
		end 
	else
		for role, objectName in pairs(roleToObject) do 
			local object = element[objectName]
			if object then 
				object:Hide()
			end 
		end 
		if element.Hide then 
			element:Hide()
		end 
	end

	if element.PostUpdate then 
		return element:PostUpdate(unit, groupRole)
	end
end 

local Proxy = function(self, ...)
	return (self.GroupRole.Override or Update)(self, ...)
end 

local ForceUpdate = function(element)
	return Proxy(element._owner, "Forced", element._owner.unit)
end

local Enable = function(self)
	local element = self.GroupRole
	if element then
		element._owner = self
		element.ForceUpdate = ForceUpdate

		for role, objectName in pairs(roleToObject) do 
			local object = element[objectName]
			if object then 
				object:Hide()
			end 
		end 
		if element.Hide then 
			element:Hide()
		end 

		self:RegisterEvent("GROUP_ROSTER_UPDATE", Proxy, true)

		return true 
	end
end 

local Disable = function(self)
	local element = self.GroupRole
	if element then
		for role, objectName in pairs(roleToObject) do 
			local object = element[objectName]
			if object then 
				object:Hide()
			end 
		end 
		if element.Hide then 
			element:Hide()
		end 
		self:UnregisterEvent("GROUP_ROSTER_UPDATE", Proxy)
	end
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (Wheel("LibUnitFrame", true)), (Wheel("LibNamePlate", true)) }) do 
	Lib:RegisterElement("GroupRole", Enable, Disable, Proxy, 15)
end 
