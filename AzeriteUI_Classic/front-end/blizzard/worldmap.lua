local ADDON = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("BlizzardWorldMap", "LibEvent", "LibBlizzard")
Module:SetIncompatible("ClassicWorldMapEnhanced")
Module:SetIncompatible("Leatrix_Maps")

Module.OnInit = function(self)
	-- Report system is tainted when we move the Map,
	-- so we're attempting to just remove the whole thing instad.
	SetCVar("enablePVPNotifyAFK","0")
end

Module.OnEnable = function(self)
	-- This does NOT disable the map,
	-- but rather shrink it and adds some
	-- conveniences like coordinates and movement fading.
	self:DisableUIWidget("WorldMap")
end 
