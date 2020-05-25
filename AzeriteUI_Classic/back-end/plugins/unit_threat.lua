local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "UnitThreat requires LibClientBuild to be loaded.")

-- WoW API
local CreateFrame = CreateFrame
local IsInGroup = IsInGroup
local IsInInstance = IsInInstance
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local UnitExists = UnitExists
local UnitThreatSituation = UnitThreatSituation

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

-- Only used by classic
local ThreatLib, UnitThreatDB, Frames

-- Setup the classic threat environment
if (IsClassic) then

	-- Add in support for LibThreatClassic2.
	ThreatLib = LibStub("LibThreatClassic2")

	-- Replace the threat API with LibThreatClassic2
	UnitThreatSituation = function (unit, mob)
		return ThreatLib:UnitThreatSituation (unit, mob)
	end

	UnitDetailedThreatSituation = function (unit, mob)
		return ThreatLib:UnitDetailedThreatSituation (unit, mob)
	end

	-- I do NOT like exposing this, but I don't want multiple update handlers either,
	-- neither from multiple frames using this element or multiple versions of the plugin.
	local LibDB = Wheel("LibDB")
	assert(LibDB, "UnitThreat requires LibDB to be loaded.")

	UnitThreatDB = LibDB:GetDatabase("UnitThreatDB", true) or LibDB:NewDatabase("UnitThreatDB")
	UnitThreatDB.frames = UnitThreatDB.frames or {}

	-- Shortcut it
	Frames = UnitThreatDB.frames

end

local UpdateColor = function(element, unit, status, r, g, b)
	if (element.OverrideColor) then
		return element:OverrideColor(unit, status, r, g, b)
	end
	-- Just some little trickery to easily support both textures and frames
	local colorFunc = element.SetVertexColor or element.SetBackdropBorderColor
	if (colorFunc) then
		colorFunc(element, r, g, b)
	end
	if (element.PostUpdateColor) then
		element:PostUpdateColor(unit, status, r, g, b)
	end 
end

local Update = function(self, event, unit, ...)
	if (not unit) or (unit ~= self.unit) then
		return 
	end 

	-- Combat ended, disable the classic update handler,
	-- and forcefully hide the entire threat element.
	if (event == "PLAYER_REGEN_ENABLED") then
		Frames[self]:Hide()
		element:Hide()
		if (element.PostUpdate) then
			return element:PostUpdate(unit, status, r, g, b)
		end
		return
	end

	-- Combat started, enable the classic update handler
	if (event == "PLAYER_REGEN_DISABLED") then
		Frames[self]:Show()
	end

	local element = self.Threat
	if (element.PreUpdate) then
		element:PreUpdate(unit)
	end

	local status

	-- BUG: Non-existent '*target' or '*pet' units cause UnitThreatSituation() errors (thank you oUF!)
	if UnitExists(unit) and ((not element.hideSolo) or (IsInGroup() or IsInInstance())) then
		local feedbackUnit = element.feedbackUnit
		if (feedbackUnit and (feedbackUnit ~= unit) and UnitExists(feedbackUnit)) then
			status = UnitThreatSituation(feedbackUnit, unit)
		else
			status = UnitThreatSituation(unit)
		end
	end

	local r, g, b
	if (status and (status > 0)) then
		r, g, b = self.colors.threat[status][1], self.colors.threat[status][2], self.colors.threat[status][3]
		element:UpdateColor(unit, status, r, g, b)
		element:Show()
	else
		element:Hide()
	end
	
	if (element.PostUpdate) then
		return element:PostUpdate(unit, status, r, g, b)
	end
end

local Proxy = function(self, ...)
	return (self.Threat.Override or Update)(self, ...)
end

local timer, HZ = 0, .2
local OnUpdate_Threat = function(this, elapsed)
	timer = timer + elapsed
	if (timer >= HZ) then
		local frame = this.frame
		Proxy(frame, "OnUpdate", frame.unit)
		timer = 0
	end
end

local ForceUpdate = function(element)
	return Proxy(element._owner, "Forced", element._owner.unit)
end

local Enable = function(self)
	local element = self.Threat
	if (element) then
		element._owner = self
		element.ForceUpdate = ForceUpdate
		element.UpdateColor = UpdateColor

		if (IsClassic) then
		
			self:RegisterEvent("PLAYER_TARGET_CHANGED", true)
			self:RegisterEvent("PLAYER_REGEN_DISABLED", true)
			self:RegisterEvent("PLAYER_REGEN_ENABLED", true)

			-- This could be a toggle
			if (not Frames[self]) then
				Frames[self] = CreateFrame("Frame")
				Frames[self].frame = self
			end
			Frames[self]:Hide()
			Frames[self]:SetScript("OnUpdate", OnUpdate_Threat)
	
		elseif (IsRetail) then
			self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", Proxy)
			self:RegisterEvent("UNIT_THREAT_LIST_UPDATE", Proxy)
		end

		return true
	end
end 

local Disable = function(self)
	local element = self.Threat
	if (element) then

		if (IsClassic) then
		
			self:UnregisterEvent("PLAYER_TARGET_CHANGED")
			self:UnregisterEvent("PLAYER_REGEN_DISABLED")
			self:UnregisterEvent("PLAYER_REGEN_ENABLED")

			if (Frames[self]) then
				Frames[self]:Hide()
				Frames[self]:SetScript("OnUpdate", nil)
			end
			
		elseif (IsRetail) then
			self:UnregisterEvent("UNIT_THREAT_SITUATION_UPDATE", Proxy)
			self:UnregisterEvent("UNIT_THREAT_LIST_UPDATE", Proxy)
		end

		element:Hide()
	end
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (Wheel("LibUnitFrame", true)), (Wheel("LibNamePlate", true)) }) do 
	Lib:RegisterElement("Threat", Enable, Disable, Proxy, 12)
end 
