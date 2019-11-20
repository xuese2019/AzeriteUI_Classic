local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("NamePlates", "LibEvent", "LibNamePlate", "LibDB", "LibFrame")
Module:SetIncompatible("Kui_Nameplates")
Module:SetIncompatible("NeatPlates")
Module:SetIncompatible("Plater")
Module:SetIncompatible("SimplePlates")
Module:SetIncompatible("TidyPlates")
Module:SetIncompatible("TidyPlates_ThreatPlates")
Module:SetIncompatible("TidyPlatesContinued")

-- Lua API
local _G = _G

-- WoW API
local GetQuestGreenRange = GetQuestGreenRange
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance 
local SetCVar = SetCVar
local SetNamePlateEnemyClickThrough = C_NamePlate.SetNamePlateEnemyClickThrough
local SetNamePlateFriendlyClickThrough = C_NamePlate.SetNamePlateFriendlyClickThrough
local SetNamePlateSelfClickThrough = C_NamePlate.SetNamePlateSelfClickThrough

-- Private API
local Colors = Private.Colors
local GetConfig = Private.GetConfig
local GetLayout = Private.GetLayout

-- Local cache of the nameplates, for easy access to some methods
local Plates = {} 

-- Library Updates
-- *will be called by the library at certain times
-----------------------------------------------------------------
-- Called on PLAYER_ENTERING_WORLD by the library, 
-- but before the library calls its own updates.
Module.PreUpdateNamePlateOptions = function(self)

	--[[
	local _, instanceType = IsInInstance()
	if (instanceType == "none") then
		SetCVar("nameplateMaxDistance", 30)
	else
		SetCVar("nameplateMaxDistance", 45)
	end

	local _, instanceType = IsInInstance()
	if (instanceType == "none") then
		if self.layout.SetConsoleVars then 
			local value = self.layout.SetConsoleVars.nameplateMaxDistance or GetCVarDefault("nameplateMaxDistance")
			SetCVar("nameplateMaxDistance", value)
		else 
			SetCVar("nameplateMaxDistance", 30)
		end 
	else
		SetCVar("nameplateMaxDistance", 45)
	end
	]]

	-- If these are enabled the GameTooltip will become protected, 
	-- and all sort of taints and bugs will occur.
	-- This happens on specs that can dispel when hovering over nameplate auras.
	-- We create our own auras anyway, so we don't need these. 
	SetCVar("nameplateShowDebuffsOnFriendly", 0) 
		
end 

-- Called when certain bindable blizzard settings change, 
-- or when the VARIABLES_LOADED event fires. 
Module.PostUpdateNamePlateOptions = function(self, isInInstace)
	local layout = self.layout

	-- Make an extra call to the preupdate
	self:PreUpdateNamePlateOptions()

	if layout.SetConsoleVars then 
		for name,value in pairs(layout.SetConsoleVars) do 
			SetCVar(name, value or GetCVarDefault(name))
		end 
	end 

	-- Setting the base size involves changing the size of secure unit buttons, 
	-- but since we're using our out of combat wrapper, we should be safe.
	-- Default size 110, 45
	C_NamePlate.SetNamePlateFriendlySize(unpack(layout.Size))
	C_NamePlate.SetNamePlateEnemySize(unpack(layout.Size))
	C_NamePlate.SetNamePlateSelfSize(unpack(layout.Size))

	--NamePlateDriverFrame.UpdateNamePlateOptions = function() end
end

-- Called after a nameplate is created.
-- This is where we create our own custom elements.
Module.PostCreateNamePlate = function(self, plate, baseFrame)
	local db = self.db
	local layout = self.layout
	
	plate:SetSize(unpack(layout.Size))
	plate.colors = Colors
	plate.layout = layout

	-- Health bar
	local health = plate:CreateStatusBar()
	health:Hide()
	health:SetSize(unpack(layout.HealthSize))
	health:SetPoint(unpack(layout.HealthPlace))
	health:SetStatusBarTexture(layout.HealthTexture)
	health:SetOrientation(layout.HealthBarOrientation)
	health:SetSmoothingFrequency(.1)
	health:SetSparkMap(layout.HealthSparkMap)
	health:SetTexCoord(unpack(layout.HealthTexCoord))
	health.absorbThreshold = layout.AbsorbThreshold
	health.colorTapped = layout.HealthColorTapped
	health.colorDisconnected = layout.HealthColorDisconnected
	health.colorClass = layout.HealthColorClass
	health.colorCivilian = layout.HealthColorCivilian
	health.colorReaction = layout.HealthColorReaction
	health.colorHealth = layout.HealthColorHealth -- color anything else in the default health color
	health.colorPlayer = layout.HealthColorPlayer
	health.frequent = layout.HealthFrequent
	plate.Health = health

	local healthBg = health:CreateTexture()
	healthBg:SetPoint(unpack(layout.HealthBackdropPlace))
	healthBg:SetSize(unpack(layout.HealthBackdropSize))
	healthBg:SetDrawLayer(unpack(layout.HealthBackdropDrawLayer))
	healthBg:SetTexture(layout.HealthBackdropTexture)
	healthBg:SetVertexColor(unpack(layout.HealthBackdropColor))
	plate.Health.Bg = healthBg

	local cast = (plate.Health or plate):CreateStatusBar()
	cast:SetSize(unpack(layout.CastSize))
	cast:SetPoint(unpack(layout.CastPlace))
	cast:SetStatusBarTexture(layout.CastTexture)
	cast:SetOrientation(layout.CastOrientation)
	cast:SetTexCoord(unpack(layout.CastTexCoord))
	cast:SetSparkMap(layout.CastSparkMap)
	cast:SetSmoothingFrequency(.1)
	cast.timeToHold = layout.CastTimeToHoldFailed
	plate.Cast = cast
	plate.Cast.PostUpdate = layout.CastPostUpdate

	local castBg = cast:CreateTexture()
	castBg:SetPoint(unpack(layout.CastBackdropPlace))
	castBg:SetSize(unpack(layout.CastBackdropSize))
	castBg:SetDrawLayer(unpack(layout.CastBackdropDrawLayer))
	castBg:SetTexture(layout.CastBackdropTexture)
	castBg:SetVertexColor(unpack(layout.CastBackdropColor))
	plate.Cast.Bg = castBg

	local castName = cast:CreateFontString()
	castName:SetPoint(unpack(layout.CastNamePlace))
	castName:SetDrawLayer(unpack(layout.CastNameDrawLayer))
	castName:SetFontObject(layout.CastNameFont)
	castName:SetTextColor(unpack(layout.CastNameColor))
	castName:SetJustifyH(layout.CastNameJustifyH)
	castName:SetJustifyV(layout.CastNameJustifyV)
	cast.Name = castName

	local castShield = cast:CreateTexture()
	castShield:SetPoint(unpack(layout.CastShieldPlace))
	castShield:SetSize(unpack(layout.CastShieldSize))
	castShield:SetTexture(layout.CastShieldTexture) 
	castShield:SetDrawLayer(unpack(layout.CastShieldDrawLayer))
	castShield:SetVertexColor(unpack(layout.CastShieldColor))
	cast.Shield = castShield

	local raidTarget = baseFrame:CreateTexture()
	raidTarget:SetPoint(unpack(layout.RaidTargetPlace))
	raidTarget:SetSize(unpack(layout.RaidTargetSize))
	raidTarget:SetDrawLayer(unpack(layout.RaidTargetDrawLayer))
	raidTarget:SetTexture(layout.RaidTargetTexture)
	raidTarget:SetScale(plate:GetScale())
	plate.RaidTarget = raidTarget
	plate.RaidTarget.PostUpdate = layout.PostUpdateRaidTarget
	hooksecurefunc(plate, "SetScale", function(plate,scale) raidTarget:SetScale(scale) end)

	local auras = plate:CreateFrame("Frame")
	auras:SetSize(unpack(layout.AuraFrameSize)) -- auras will be aligned in the available space, this size gives us 8x1 auras
	auras.point = layout.AuraPoint
	auras.anchor = plate[layout.AuraAnchor] or plate
	auras.relPoint = layout.AuraRelPoint
	auras.offsetX = layout.AuraOffsetX
	auras.offsetY = layout.AuraOffsetY
	auras:ClearAllPoints()
	auras:SetPoint(auras.point, auras.anchor, auras.relPoint, auras.offsetX, auras.offsetY)
	for property,value in pairs(layout.AuraProperties) do 
		auras[property] = value
	end
	plate.Auras = auras
	plate.Auras.PostCreateButton = layout.PostCreateAuraButton -- post creation styling
	plate.Auras.PostUpdateButton = layout.PostUpdateAuraButton -- post updates when something changes (even timers)
	plate.Auras.PostUpdate = layout.PostUpdateAura
	if (not db.enableAuras) then 
		plate:DisableElement("Auras")
	end 

	-- The library does this too, but isn't exposing it to us.
	Plates[plate] = baseFrame
end

Module.PostUpdateSettings = function(self)
	local db = self.db
	for plate, baseFrame in pairs(Plates) do 
		if db.enableAuras then 
			plate:EnableElement("Auras")
			plate.Auras:ForceUpdate()
			plate.RaidTarget:ForceUpdate()
		else 
			plate:DisableElement("Auras")
			plate.RaidTarget:ForceUpdate()
		end 
	end
end

Module.PostUpdateCVars = function(self, event, ...)
	if InCombatLockdown() then 
		return self:RegisterEvent("PLAYER_REGEN_ENABLED", "PostUpdateCVars")
	end 
	if (event == "PLAYER_REGEN_ENABLED") then 
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "PostUpdateCVars")
	end 
	local db = self.db
	SetNamePlateEnemyClickThrough(db.clickThroughEnemies)
	SetNamePlateFriendlyClickThrough(db.clickThroughFriends)
	SetNamePlateSelfClickThrough(db.clickThroughSelf)
end

Module.GetSecureUpdater = function(self)
	return self.proxyUpdater
end

Module.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then 
		self:PostUpdateCVars()
	end 
end

Module.OnInit = function(self)
	self.db = GetConfig(self:GetName())
	self.layout = GetLayout(self:GetName())

	local proxy = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	proxy.PostUpdateSettings = function() self:PostUpdateSettings() end
	proxy.PostUpdateCVars = function() self:PostUpdateCVars() end
	for key,value in pairs(self.db) do 
		proxy:SetAttribute(key,value)
	end 
	proxy:SetAttribute("_onattributechanged", [=[
		if name then 
			name = string.lower(name); 
		end 
		if (name == "change-enableauras") then 
			self:SetAttribute("enableAuras", value); 
			self:CallMethod("PostUpdateSettings"); 

		elseif (name == "change-clickthroughenemies") then
			self:SetAttribute("clickThroughEnemies", value); 
			self:CallMethod("PostUpdateCVars"); 

		elseif (name == "change-clickthroughfriends") then 
			self:SetAttribute("clickThroughFriends", value); 
			self:CallMethod("PostUpdateCVars"); 

		elseif (name == "change-clickthroughself") then 
			self:SetAttribute("clickThroughSelf", value); 
			self:CallMethod("PostUpdateCVars"); 

		end 
	]=])

	self.proxyUpdater = proxy
end 

Module.OnEnable = function(self)
	self:StartNamePlateEngine()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
end 
