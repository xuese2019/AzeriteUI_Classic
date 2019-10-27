local ADDON = ...
local L = Wheel("LibLocale"):NewLocale(ADDON, "esMX")
if (not L) then 
	return 
end 

-- No, we don't want this. 
ADDON = ADDON:gsub("_Classic", "")
