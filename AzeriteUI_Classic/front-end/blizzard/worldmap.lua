local ADDON = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then
	return
end

local Module = Core:NewModule("BlizzardWorldMap", "LibEvent", "LibBlizzard", "LibClientBuild")
Module:SetIncompatible("ClassicWorldMapEnhanced")
Module:SetIncompatible("Leatrix_Maps")

-- Constants for client version
local IsClassic = Module:IsClassic()
local IsRetail = Module:IsRetail()

Module.OnInit = function(self)
	-- Report system is tainted when we move the Map,
	-- so we're attempting to just remove the whole thing instad.
	if (IsClassic) then
		--SetCVar("enablePVPNotifyAFK","0") -- doesn't work
	end
end

Module.OnEnable = function(self)
	-- This does NOT disable the map,
	-- but rather shrink it and adds some
	-- conveniences like coordinates and movement fading.
	if (IsClassic) then
		self:DisableUIWidget("WorldMap")
	end
end 
