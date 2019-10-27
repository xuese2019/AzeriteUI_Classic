local LibZone = Wheel:Set("LibZone", 1)
if (not LibZone) then
	return
end

-- Lua API
local _G = _G
local assert = assert
local date = date
local debugstack = debugstack
local error = error
local pairs = pairs
local select = select
local string_format = string.format
local string_join = string.join
local string_match = string.match
local tonumber = tonumber
local type = type

-- WoW API
local GetBestMapForUnit = _G.C_Map.GetBestMapForUnit
local GetMapInfo = _G.C_Map.GetMapInfo
local UnitFactionGroup = _G.UnitFactionGroup

-- Library registries
LibZone.embeds = LibZone.embeds or {}
LibZone.frame = LibZone.frame or CreateFrame("Frame")

-- Syntax check 
local check = function(value, num, ...)
	assert(type(num) == "number", ("Bad argument #%.0f to '%s': %s expected, got %s"):format(2, "Check", "number", type(num)))
	for i = 1,select("#", ...) do
		if type(value) == select(i, ...) then 
			return 
		end
	end
	local types = string_join(", ", ...)
	local name = string_match(debugstack(2, 2, 0), ": in function [`<](.-)['>]")
	error(("Bad argument #%.0f to '%s': %s expected, got %s"):format(num, name, types, type(value)), 3)
end

local MapFactions
local PlayerIsAlliance, PlayerIsHorde, PlayerIsNeutral, PlayerFaction, PlayerFactionLabel
do 
	PlayerFaction, PlayerFactionLabel = UnitFactionGroup("player")
	PlayerIsAlliance = PlayerFaction == "Alliance"
	PlayerIsHorde = PlayerFaction == "Horde"
	PlayerIsNeutral = (not PlayerIsAlliance) and (not PlayerIsHorde)

	local frame = LibZone.frame
	frame:UnregisterAllEvents()
	frame:SetScript("OnEvent", function(self, event, ...) 

		PlayerFaction, PlayerFactionLabel = UnitFactionGroup("player")
		PlayerIsAlliance = PlayerFaction == "Alliance"
		PlayerIsHorde = PlayerFaction == "Horde"
		PlayerIsNeutral = (not PlayerIsAlliance) and (not PlayerIsHorde)

		if (not PlayerIsNeutral) then 
			self:UnregisterEvent("UNIT_FACTION")
		end
	end)
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterUnitEvent("UNIT_FACTION", "player") 
end 

-- Currently this only returns sanctuary, friendly, hostile and contested. 
-- We have not included arena or combat. 
LibZone.GetPvPType = function(self, uiMapID)
	local mapName, mapPvPType, mapPvPLabel
	local mapInfo = GetMapInfo(uiMapID)
	if mapInfo then 
		mapName = mapInfo.name
		if mapName then 
			local faction = MapFactions[uiMapID]
			if faction then 
				if (faction == "Sanctuary") then 
					mapPvPType = "sanctuary"
					mapPvPLabel = SANCTUARY_TERRITORY
				elseif (faction == PlayerFaction) then 
					mapPvPType = "friendly"
					mapPvPLabel = string_format(FACTION_CONTROLLED_TERRITORY, PlayerFactionLabel)
				else
					mapPvPType = "hostile"
					mapPvPLabel = string_format(FACTION_CONTROLLED_TERRITORY, PlayerFactionLabel)
				end 
			else
				mapPvPType = "contested"
				mapPvPLabel = CONTESTED_TERRITORY
			end
		end 
	end
	return mapName, mapPvPType, mapPvPLabel
end

LibZone.IsMapAlliance = function(self)
end

LibZone.IsMapHorde = function(self)
end

LibZone.IsMapSanctuary = function(self)
end

LibZone.IsMapFriendly = function(self)
end

LibZone.IsMapNeutral = function(self)
end

LibZone.IsMapContested = function(self)
end

LibZone.IsMapHostile = function(self)
end

local embedMethods = {
	GetPvPType = true,
	IsMapAlliance = true, 
	IsMapHorde = true, 
	IsMapSanctuary = true, 
	IsMapFriendly = true, 
	IsMapNeutral = true,
	IsMapContested = true, 
	IsMapHostile = true
}

LibZone.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibZone.embeds) do
	LibZone:Embed(target)
end

-- PvP Zone info for Battle for Azeroth (post Cataclysm)
-- Must be updated!!
-- https://wow.gamepedia.com/UiMapID
MapFactions = {
	[ 468] = "Alliance", 	-- Ammen Vale
	[  76] = "Horde", 		-- Azshara
	[ 697] = "Horde", 		-- Azshara
	[1317] = "Horde", 		-- Azshara
	[  97] = "Alliance", 	-- Azuremyst Isle
	[ 776] = "Alliance", 	-- Azuremyst Isle
	[ 891] = "Alliance", 	-- Azuremyst Isle
	[ 892] = "Alliance", 	-- Azuremyst Isle
	[ 893] = "Alliance", 	-- Azuremyst Isle
	[ 894] = "Alliance", 	-- Azuremyst Isle
	[1325] = "Alliance", 	-- Azuremyst Isle
	[ 106] = "Alliance", 	-- Bloodmyst Isle
	[1327] = "Alliance", 	-- Bloodmyst Isle
	[1161] = "Alliance", 	-- Boralus
	[ 462] = "Horde", 		-- Camp Narache
	[ 427] = "Alliance", 	-- Coldridge Valley
	[ 834] = "Alliance", 	-- Coldridge Valley
	[  41] = "Sanctuary", 	-- Dalaran (Eastern Kingdoms) (Micro)
	[ 125] = "Sanctuary", 	-- Dalaran (Crystalsong Forest) (Dungeon) (Dalaran City)
	[ 126] = "Sanctuary", 	-- Dalaran (Crystalsong Forest) (Dungeon) (The Underbelly)
	[ 501] = "Sanctuary", 	-- Dalaran (Eastern Kingdoms) (Dungeon) (Dalaran City)
	[ 502] = "Sanctuary", 	-- Dalaran (Eastern Kingdoms) (Dungeon) (The Underbelly)
	[ 625] = "Sanctuary", 	-- Dalaran (Broken Isles)
	[ 626] = "Sanctuary", 	-- Dalaran (Broken Isles) (Dungeon) (The Hall of Shadows)
	[ 627] = "Sanctuary", 	-- Dalaran (Broken Isles) (Dungeon)
	[ 628] = "Sanctuary", 	-- Dalaran (Broken Isles) (Dungeon) (The Underbelly)
	[ 629] = "Sanctuary", 	-- Dalaran (Broken Isles) (Dungeon) (Aegwynn's Gallery)
	[  62] = "Alliance", 	-- Darkshore
	[1203] = "Alliance", 	-- Darkshore
	[1309] = "Alliance", 	-- Darkshore
	[1332] = "Alliance", 	-- Darkshore
	[1333] = "Alliance", 	-- Darkshore
	[1338] = "Alliance", 	-- Darkshore
	[1343] = "Alliance", 	-- Darkshore (8.1 Darkshore Outdoor Final Phase)
	[  89] = "Alliance", 	-- Darnassus
	[1324] = "Alliance", 	-- Darnassus
	[1163] = "Horde", 		-- Dazar'alor (Micro) (The Great Seal)
	[1164] = "Horde", 		-- Dazar'alor (Micro) (Hall of Chroniclers)
	[1165] = "Horde", 		-- Dazar'alor
	[ 465] = "Horde", 		-- Deathknell
	[ 896] = "Alliance", 	-- Drustvar
	[1197] = "Alliance", 	-- Drustvar
	[  27] = "Alliance", 	-- Dun Morogh
	[ 523] = "Alliance", 	-- Dun Morogh
	[1253] = "Alliance", 	-- Dun Morogh
	[   1] = "Horde", 		-- Durotar
	[1305] = "Horde", 		-- Durotar
	[ 463] = "Horde", 		-- Echo Isles
	[  37] = "Alliance", 	-- Elwynn Forest
	[1256] = "Alliance", 	-- Elwynn Forest
	[  94] = "Horde", 		-- Eversong Woods
	[1267] = "Horde", 		-- Eversong Woods
	[ 590] = "Horde", 		-- Frostwall (Horde Garrison)
	[ 585] = "Horde", 		-- Frostwall Mine (Horde Garrison) (Micro)
	[ 586] = "Horde", 		-- Frostwall Mine (Horde Garrison) (Micro)
	[ 587] = "Horde", 		-- Frostwall Mine (Horde Garrison) (Micro)
	[  95] = "Horde", 		-- Ghostlands
	[1268] = "Horde", 		-- Ghostlands
	[ 179] = "Alliance", 	-- Gilneas
	[1271] = "Alliance", 	-- Gilneas
	[ 202] = "Alliance", 	-- Gilneas City
	[  25] = "Horde", 		-- Hillsbrad Foothills
	[1251] = "Horde", 		-- Hillsbrad Foothills
	[  87] = "Alliance", 	-- Ironforge
	[1265] = "Alliance", 	-- Ironforge
	[ 194] = "Horde", 		-- Kezan
	[  48] = "Alliance", 	-- Loch Modan
	[1259] = "Alliance", 	-- Loch Modan
	[ 579] = "Alliance", 	-- Lunarfall Excavation (Alliance Garrison) (Micro)
	[ 580] = "Alliance", 	-- Lunarfall Excavation (Alliance Garrison) (Micro)
	[ 581] = "Alliance", 	-- Lunarfall Excavation (Alliance Garrison) (Micro)
	[ 582] = "Alliance", 	-- Lunarfall (Alliance Garrison)
	[   7] = "Horde", 		-- Mulgore
	[1306] = "Horde", 		-- Mulgore
	[  30] = "Alliance", 	-- New Tinkertown
	[ 469] = "Alliance", 	-- New Tinkertown
	[ 863] = "Horde", 		-- Nazmir
	[1194] = "Horde", 		-- Nazmir
	[  10] = "Horde", 		-- Northern Barrens
	[1307] = "Horde", 		-- Northern Barrens
	[ 425] = "Alliance", 	-- Northshire
	[  85] = "Horde", 		-- Orgrimmar
	[  86] = "Horde", 		-- Orgrimmar (Cleft of Shadows)
	[ 460] = "Alliance", 	-- Shadowglen
	[ 111] = "Sanctuary", 	-- Shattrath City
	[ 594] = "Sanctuary", 	-- Shattrath City
	[ 393] = "Alliance", 	-- Shrine of Seven Stars (The Emperor's Step)
	[ 394] = "Alliance", 	-- Shrine of Seven Stars (The Imperial Exchange)
	[ 391] = "Horde", 		-- Shrine of Two Moons (Hall of the Crescent Moon)
	[ 392] = "Horde", 		-- Shrine of Two Moons (The Imperial Mercantile)
	[ 110] = "Horde", 		-- Silvermoon City
	[1269] = "Horde", 		-- Silvermoon City
	[  21] = "Horde", 		-- Silverpine Forest
	[1248] = "Horde", 		-- Silverpine Forest
	[ 622] = "Alliance", 	-- Stormshield
	[ 942] = "Alliance", 	-- Stormsong Valley
	[1198] = "Alliance", 	-- Stormsong Valley
	[  84] = "Alliance", 	-- Stormwind City
	[1012] = "Alliance", 	-- Stormwind City
	[1264] = "Alliance", 	-- Stormwind City
	[ 467] = "Horde", 		-- Sunstrider Isle
	[  57] = "Alliance", 	-- Teldrassil
	[1308] = "Alliance", 	-- Teldrassil
	[ 103] = "Alliance", 	-- The Exodar
	[ 775] = "Alliance", 	-- The Exodar
	[1326] = "Alliance", 	-- The Exodar
	[1331] = "Alliance", 	-- The Exodar
	[ 174] = "Horde", 		-- The Lost Isles
	[ 276] = "Sanctuary", 	-- The Maelstrom
	[ 725] = "Sanctuary", 	-- The Maelstrom
	[ 726] = "Sanctuary", 	-- The Maelstrom
	[ 839] = "Sanctuary", 	-- The Maelstrom
	[ 948] = "Sanctuary", 	-- The Maelstrom
	[ 378] = "Sanctuary", 	-- The Wandering Isle
	[ 709] = "Sanctuary", 	-- The Wandering Isle
	[  88] = "Horde", 		-- Thunder Bluff
	[1323] = "Horde", 		-- Thunder Bluff
	[ 652] = "Sanctuary", 	-- Thunder Totem
	[ 750] = "Sanctuary", 	-- Thunder Totem
	[ 895] = "Alliance", 	-- Tiragarde Sound
	[1196] = "Alliance", 	-- Tiragarde Sound
	[  18] = "Horde", 		-- Tirisfal Glades
	[ 997] = "Horde", 		-- Tirisfal Glades
	[1247] = "Horde", 		-- Tirisfal Glades
	[ 739] = "Sanctuary", 	-- Trueshot Lodge
	[  90] = "Horde", 		-- Undercity
	[ 998] = "Horde", 		-- Undercity
	[1266] = "Horde", 		-- Undercity
	[ 461] = "Horde", 		-- Valley of Trials
	[ 864] = "Horde", 		-- Vol'dun
	[1195] = "Horde", 		-- Vol'dun
	[ 624] = "Horde", 		-- Warspear
	[  52] = "Alliance", 	-- Westfall
	[1262] = "Alliance", 	-- Westfall
	[ 862] = "Horde", 		-- Zuldazar
	[1181] = "Horde", 		-- Zuldazar
	[1193] = "Horde" 		-- Zuldazar
}
