local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "GenericAzeritePower requires LibClientBuild to be loaded.")

-- This library is for Classic only!
if (LibClientBuild:IsClassic()) then
	return
end

-- Lua API
local _G = _G
local math_floor = math.floor
local math_min = math.min
local tonumber = tonumber
local tostring = tostring

-- WoW API
local Item = Item
local IsAzeriteItemLocationBankBag = AzeriteUtil.IsAzeriteItemLocationBankBag
local FindActiveAzeriteItem = C_AzeriteItem.FindActiveAzeriteItem
local GetAzeriteItemXPInfo = C_AzeriteItem.GetAzeriteItemXPInfo
local GetPowerLevel = C_AzeriteItem.GetPowerLevel

local short = function(value)
	value = tonumber(value)
	if (not value) then return "" end
	if (value >= 1e9) then
		return ("%.1fb"):format(value / 1e9):gsub("%.?0+([kmb])$", "%1")
	elseif value >= 1e6 then
		return ("%.1fm"):format(value / 1e6):gsub("%.?0+([kmb])$", "%1")
	elseif value >= 1e3 or value <= -1e3 then
		return ("%.1fk"):format(value / 1e3):gsub("%.?0+([kmb])$", "%1")
	else
		return tostring(math_floor(value))
	end	
end

-- zhCN exceptions
local gameLocale = GetLocale()
if (gameLocale == "zhCN") then 
	short = function(value)
		value = tonumber(value)
		if (not value) then return "" end
		if (value >= 1e8) then
			return ("%.1f亿"):format(value / 1e8):gsub("%.?0+([km])$", "%1")
		elseif value >= 1e4 or value <= -1e3 then
			return ("%.1f万"):format(value / 1e4):gsub("%.?0+([km])$", "%1")
		else
			return tostring(math_floor(value))
		end 
	end
end 

local UpdateValue = function(element, min, max, level)
	if element.OverrideValue then
		return element:OverrideValue(min, max, level)
	end
	local value = element.Value or element:IsObjectType("FontString") and element 
	if value.showPercent then 
		if (max > 0) then 
			local perc = math_floor(min/max*100)
			if (perc == 100) and (min < max) then 
				perc = 99
			end
			if (perc >= 1) then 
				value:SetFormattedText("%.0f%%", perc)
			else 
				value:SetText(_G.ARTIFACT_POWER)
			end
		else 
			value:SetText("")
		end 
	elseif value.showDeficit then 
		value:SetFormattedText(short(max - min))
	else 
		value:SetFormattedText(short(min))
	end
	local percent = value.Percent
	if percent then 
		if (max > 0) then 
			local perc = math_floor(min/max*100)
			if (perc == 100) and (min < max) then 
				perc = 99
			end
			if (perc >= 1) then 
				percent:SetFormattedText("%.0f%%", perc)
			else 
				percent:SetText(_G.ARTIFACT_POWER)
			end
			percent:SetFormattedText("%.0f%%", perc)
		else 
			percent:SetText("")
		end 
	end 
	if element.colorValue then 
		local color = element._owner.colors.artifact
		value:SetTextColor(color[1], color[2], color[3])
		if percent then 
			percent:SetTextColor(color[1], color[2], color[3])
		end 
	end 
end 

local Update = function(self, event, ...)
	local element = self.ArtifactPower
	if element.PreUpdate then
		element:PreUpdate()
	end

	if (event == "BAG_UPDATE") then 
		local bagID = ...
		if not(bagID > NUM_BAG_SLOTS) then
			return
		end
	end 

	local azeriteItemLocation = FindActiveAzeriteItem() -- check return values here
	if (not azeriteItemLocation) or (IsAzeriteItemLocationBankBag(azeriteItemLocation)) then 
		if (element.showEmpty) then 
			element:SetMinMaxValues(0, 100)
			element:SetValue(0)
			if element.Value then 
				element:UpdateValue(0, 100, 1)
			end 
			if (not element:IsShown()) then 
				element:Show()
			end
			return 
		else
			return element:Hide()
		end 
	end
	
	local min, max, level 
	local min, max = GetAzeriteItemXPInfo(azeriteItemLocation) 
	local level = GetPowerLevel(azeriteItemLocation) 

	if element:IsObjectType("StatusBar") then 
		element:SetMinMaxValues(0, max)
		element:SetValue(min)

		if element.colorPower then 
			local color = self.colors.artifact 
			element:SetStatusBarColor(color[1], color[2], color[3])
		end 
	end 

	if element.Value then 
		element:UpdateValue(min, max, level)
	end 

	if (not element:IsShown()) then 
		element:Show()
	end

	if element.PostUpdate then 
		element:PostUpdate(min, max, level)
	end 
	
end 

local Proxy = function(self, ...)
	return (self.ArtifactPower.Override or Update)(self, ...)
end 

local ForceUpdate = function(element, ...)
	return Proxy(element._owner, "Forced", ...)
end

local Enable = function(self)
	local element = self.ArtifactPower
	if element then
		element._owner = self
		element.ForceUpdate = ForceUpdate
		element.UpdateValue = UpdateValue

		self:RegisterEvent("AZERITE_ITEM_EXPERIENCE_CHANGED", Proxy, true)
		self:RegisterEvent("PLAYER_ENTERING_WORLD", Proxy, true)
		self:RegisterEvent("PLAYER_LOGIN", Proxy, true)
		self:RegisterEvent("PLAYER_ALIVE", Proxy, true)
		self:RegisterEvent("CVAR_UPDATE", Proxy, true)
		self:RegisterEvent("BAG_UPDATE", Proxy, true)

		return true
	end
end 

local Disable = function(self)
	local element = self.ArtifactPower
	if element then
		self:UnregisterEvent("AZERITE_ITEM_EXPERIENCE_CHANGED", Proxy)
		self:UnregisterEvent("PLAYER_ENTERING_WORLD", Proxy)
		self:UnregisterEvent("PLAYER_LOGIN", Proxy)
		self:UnregisterEvent("PLAYER_ALIVE", Proxy)
		self:UnregisterEvent("CVAR_UPDATE", Proxy)
		self:UnregisterEvent("BAG_UPDATE", Proxy)
		element:Hide()
	end
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (Wheel("LibUnitFrame", true)), (Wheel("LibNamePlate", true)), (Wheel("LibMinimap", true)) }) do 
	Lib:RegisterElement("ArtifactPower", Enable, Disable, Proxy, 19)
end 
