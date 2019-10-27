local ADDON = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("BlizzardWorldMap", "LibEvent", "LibBlizzard")
Module:SetIncompatible("ClassicWorldMapEnhanced")
Module:SetIncompatible("Leatrix_Maps")

Module.OnEnable = function(self)
	self:DisableUIWidget("WorldMap")
end 
