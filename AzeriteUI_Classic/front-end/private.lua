local ADDON, Private = ...

-- Lua API
local _G = _G
local bit_band = bit.band
local math_floor = math.floor
local pairs = pairs
local rawget = rawget
local select = select
local setmetatable = setmetatable
local string_gsub = string.gsub
local tonumber = tonumber
local unpack = unpack

-- WoW API
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local UnitAffectingCombat = UnitAffectingCombat
local UnitCanAttack = UnitCanAttack
local UnitIsUnit = UnitIsUnit
local UnitPlayerControlled = UnitPlayerControlled

-- Addon API
local GetPlayerRole = Wheel("LibPlayerData").GetPlayerRole
local HasInfoFlags = Wheel("LibAuraData").HasAuraInfoFlags
local AddUserFlags = Wheel("LibAuraData").AddAuraUserFlags
local HasUserFlags = Wheel("LibAuraData").HasAuraUserFlags
local GetUserFlags = Wheel("LibAuraData").GetAllAuraUserFlags

-- Library Databases
local infoFilter = Wheel("LibAuraData"):GetAllAuraInfoBitFilters() -- Aura flags by keywords
local auraInfoFlags = Wheel("LibAuraData"):GetAllAuraInfoFlags() -- Aura info flags

-- Local Databases
local auraUserFlags = {} -- Aura filter flags 
local auraFilters = {} -- Aura filter functions
local colorDB = {} -- Addon color schemes
local fontsDB = { normal = {}, outline = {}, chatNormal = {}, chatOutline = {} } -- Addon fonts

-- List of units we all count as the player
local unitIsPlayer = { player = true, 	pet = true }

-- Utility Functions
-----------------------------------------------------------------
-- Emulate some of the Blizzard methods, 
-- since they too do colors this way now. 
-- Goal is not to be fully interchangeable. 
local colorTemplate = {
	GetRGB = function(self)
		return self[1], self[2], self[3]
	end,
	GetRGBAsBytes = function(self)
		return self[1]*255, self[2]*255, self[3]*255
	end, 
	GenerateHexColor = function(self)
		return ("ff%02x%02x%02x"):format(math_floor(self[1]*255), math_floor(self[2]*255), math_floor(self[3]*255))
	end, 
	GenerateHexColorMarkup = function(self)
		return "|c" .. self:GenerateHexColor()
	end
}

-- Convert a Blizzard Color or RGB value set 
-- into our own custom color table format. 
local createColor = function(...)
	local tbl
	if (select("#", ...) == 1) then
		local old = ...
		if (old.r) then 
			tbl = {}
			tbl[1] = old.r or 1
			tbl[2] = old.g or 1
			tbl[3] = old.b or 1
		else
			tbl = { unpack(old) }
		end
	else
		tbl = { ... }
	end
	for name,method in pairs(colorTemplate) do 
		tbl[name] = method
	end
	if (#tbl == 3) then
		tbl.colorCode = tbl:GenerateHexColorMarkup()
		tbl.colorCodeClean = tbl:GenerateHexColor()
	end
	return tbl
end

-- Convert a whole Blizzard color table
local createColorGroup = function(group)
	local tbl = {}
	for i,v in pairs(group) do 
		tbl[i] = createColor(v)
	end 
	return tbl
end 

-- Populate Font Tables
-----------------------------------------------------------------
do 
	local fontPrefix = ADDON 
	fontPrefix = string_gsub(fontPrefix, "UI", "")
	fontPrefix = string_gsub(fontPrefix, "_Classic", "Classic")
	for i = 10,100 do 
		local fontNormal = _G[fontPrefix .. "Font" .. i]
		if fontNormal then 
			fontsDB.normal[i] = fontNormal
		end
		local fontOutline = _G[fontPrefix .. "Font" .. i .. "_Outline"]
		if fontOutline then 
			fontsDB.outline[i] = fontOutline
		end
		local fontChatNormal = _G[fontPrefix .. "ChatFont" .. i]
		if fontChatNormal then 
			fontsDB.chatNormal[i] = fontChatNormal
		end
		local fontChatOutline = _G[fontPrefix .. "ChatFont" .. i .. "_Outline"]
		if fontChatOutline then 
			fontsDB.chatOutline[i] = fontChatOutline
		end 
	end 
end 

-- Populate Color Tables
-----------------------------------------------------------------
--colorDB.health = createColor(191/255, 0/255, 38/255)
colorDB.health = createColor(245/255, 0/255, 45/255)
colorDB.cast = createColor(229/255, 204/255, 127/255)
colorDB.disconnected = createColor(120/255, 120/255, 120/255)
colorDB.tapped = createColor(121/255, 101/255, 96/255)
colorDB.dead = createColor(121/255, 101/255, 96/255)

-- Global UI vertex coloring
colorDB.ui = {
	stone = createColor(192/255, 192/255, 192/255),
	wood = createColor(192/255, 192/255, 192/255)
}

-- quest difficulty coloring 
colorDB.quest = {}
colorDB.quest.red = createColor(204/255, 26/255, 26/255)
colorDB.quest.orange = createColor(255/255, 128/255, 64/255)
colorDB.quest.yellow = createColor(255/255, 178/255, 38/255)
colorDB.quest.green = createColor(89/255, 201/255, 89/255)
colorDB.quest.gray = createColor(120/255, 120/255, 120/255)

-- some basic ui colors used by all text
colorDB.normal = createColor(229/255, 178/255, 38/255)
colorDB.highlight = createColor(250/255, 250/255, 250/255)
colorDB.title = createColor(255/255, 234/255, 137/255)
colorDB.offwhite = createColor(196/255, 196/255, 196/255)

colorDB.xp = createColor(116/255, 23/255, 229/255) -- xp bar 
colorDB.xpValue = createColor(145/255, 77/255, 229/255) -- xp bar text
colorDB.rested = createColor(163/255, 23/255, 229/255) -- xp bar while being rested
colorDB.restedValue = createColor(203/255, 77/255, 229/255) -- xp bar text while being rested
colorDB.restedBonus = createColor(69/255, 17/255, 134/255) -- rested bonus bar
colorDB.artifact = createColor(229/255, 204/255, 127/255) -- artifact or azerite power bar

-- Unit Class Coloring
-- Original colors at https://wow.gamepedia.com/Class#Class_colors
colorDB.class = {}
colorDB.class.DEATHKNIGHT = createColor(176/255, 31/255, 79/255)
colorDB.class.DEMONHUNTER = createColor(163/255, 48/255, 201/255)
colorDB.class.DRUID = createColor(255/255, 125/255, 10/255)
colorDB.class.HUNTER = createColor(191/255, 232/255, 115/255) 
colorDB.class.MAGE = createColor(105/255, 204/255, 240/255)
colorDB.class.MONK = createColor(0/255, 255/255, 150/255)
colorDB.class.PALADIN = createColor(225/255, 160/255, 226/255)
colorDB.class.PRIEST = createColor(176/255, 200/255, 225/255)
colorDB.class.ROGUE = createColor(255/255, 225/255, 95/255) 
colorDB.class.SHAMAN = createColor(32/255, 122/255, 222/255) 
colorDB.class.WARLOCK = createColor(148/255, 130/255, 201/255) 
colorDB.class.WARRIOR = createColor(229/255, 156/255, 110/255) 
colorDB.class.UNKNOWN = createColor(195/255, 202/255, 217/255)

-- debuffs
colorDB.debuff = {}
colorDB.debuff.none = createColor(204/255, 0/255, 0/255)
colorDB.debuff.Magic = createColor(51/255, 153/255, 255/255)
colorDB.debuff.Curse = createColor(204/255, 0/255, 255/255)
colorDB.debuff.Disease = createColor(153/255, 102/255, 0/255)
colorDB.debuff.Poison = createColor(0/255, 153/255, 0/255)
colorDB.debuff[""] = createColor(0/255, 0/255, 0/255)

-- faction 
colorDB.faction = {}
colorDB.faction.Alliance = createColor(74/255, 84/255, 232/255)
colorDB.faction.Horde = createColor(229/255, 13/255, 18/255)
colorDB.faction.Neutral = createColor(249/255, 158/255, 35/255) 

-- power
colorDB.power = {}

local Fast = createColor(0/255, 208/255, 176/255) 
local Slow = createColor(116/255, 156/255, 255/255)
local Angry = createColor(156/255, 116/255, 255/255)

-- Crystal Power Colors
colorDB.power.ENERGY_CRYSTAL = Fast -- Rogues, Druids
colorDB.power.FOCUS_CRYSTAL = Slow -- Hunters Pets (?)
colorDB.power.FURY_CRYSTAL = Angry -- Havoc Demon Hunter 
colorDB.power.INSANITY_CRYSTAL = Angry -- Shadow Priests
colorDB.power.LUNAR_POWER_CRYSTAL = Slow -- Balance Druid Astral Power 
colorDB.power.MAELSTROM_CRYSTAL = Slow -- Elemental Shamans
colorDB.power.PAIN_CRYSTAL = Angry -- Vengeance Demon Hunter 
colorDB.power.RAGE_CRYSTAL = Angry -- Druids, Warriors
colorDB.power.RUNIC_POWER_CRYSTAL = Slow -- Death Knights

-- Only occurs when the orb is manually disabled by the player.
colorDB.power.MANA_CRYSTAL = createColor(101/255, 93/255, 191/255) -- Druid, Hunter, Mage, Paladin, Priest, Shaman, Warlock

-- Orb Power Colors
colorDB.power.MANA_ORB = createColor(135/255, 125/255, 255/255) -- Druid, Hunter, Mage, Paladin, Priest, Shaman, Warlock

-- Standard Power Colors
colorDB.power.ENERGY = createColor(254/255, 245/255, 145/255) -- Rogues, Druids
colorDB.power.FURY = createColor(255/255, 0/255, 111/255) -- Vengeance Demon Hunter
colorDB.power.FOCUS = createColor(125/255, 168/255, 195/255) -- Hunter Pets
colorDB.power.INSANITY = createColor(102/255, 64/255, 204/255) -- Shadow Priests 
colorDB.power.LUNAR_POWER = createColor(121/255, 152/255, 192/255) -- Balance Druid Astral Power 
colorDB.power.MAELSTROM = createColor(0/255, 188/255, 255/255) -- Elemental Shamans
colorDB.power.MANA = createColor(80/255, 116/255, 255/255) -- Druid, Hunter, Mage, Paladin, Priest, Shaman, Warlock
colorDB.power.PAIN = createColor(190 *.75/255, 255 *.75/255, 0/255) 
colorDB.power.RAGE = createColor(215/255, 7/255, 7/255) -- Druids, Warriors
colorDB.power.RUNIC_POWER = createColor(0/255, 236/255, 255/255) -- Death Knights

-- Secondary Resource Colors
colorDB.power.ARCANE_CHARGES = createColor(121/255, 152/255, 192/255) -- Arcane Mage
colorDB.power.CHI = createColor(126/255, 255/255, 163/255) -- Monk 
colorDB.power.COMBO_POINTS = createColor(255/255, 0/255, 30/255) -- Rogues, Druids
colorDB.power.HOLY_POWER = createColor(245/255, 254/255, 145/255) -- Retribution Paladins 
colorDB.power.RUNES = createColor(100/255, 155/255, 225/255) -- Death Knight 
colorDB.power.SOUL_SHARDS = createColor(148/255, 130/255, 201/255) -- Warlock 

-- Alternate Power
colorDB.power.ALTERNATE = createColor(70/255, 255/255, 131/255)

-- Vehicle Powers
colorDB.power.AMMOSLOT = createColor(204/255, 153/255, 0/255)
colorDB.power.FUEL = createColor(0/255, 140/255, 127/255)
colorDB.power.STAGGER = {}
colorDB.power.STAGGER[1] = createColor(132/255, 255/255, 132/255) 
colorDB.power.STAGGER[2] = createColor(255/255, 250/255, 183/255) 
colorDB.power.STAGGER[3] = createColor(255/255, 107/255, 107/255) 

-- Fallback for the rare cases where an unknown type is requested.
colorDB.power.UNUSED = createColor(195/255, 202/255, 217/255) 

-- Allow us to use power type index to get the color
-- FrameXML/UnitFrame.lua
colorDB.power[0] = colorDB.power.MANA
colorDB.power[1] = colorDB.power.RAGE
colorDB.power[2] = colorDB.power.FOCUS
colorDB.power[3] = colorDB.power.ENERGY
colorDB.power[4] = colorDB.power.CHI
colorDB.power[5] = colorDB.power.RUNES
colorDB.power[6] = colorDB.power.RUNIC_POWER
colorDB.power[7] = colorDB.power.SOUL_SHARDS
colorDB.power[8] = colorDB.power.LUNAR_POWER
colorDB.power[9] = colorDB.power.HOLY_POWER
colorDB.power[11] = colorDB.power.MAELSTROM
colorDB.power[13] = colorDB.power.INSANITY
colorDB.power[17] = colorDB.power.FURY
colorDB.power[18] = colorDB.power.PAIN

-- reactions
colorDB.reaction = {}
colorDB.reaction[1] = createColor(205/255, 46/255, 36/255) -- hated
colorDB.reaction[2] = createColor(205/255, 46/255, 36/255) -- hostile
colorDB.reaction[3] = createColor(192/255, 68/255, 0/255) -- unfriendly
colorDB.reaction[4] = createColor(249/255, 188/255, 65/255) -- neutral 
--colorDB.reaction[4] = createColor(249/255, 158/255, 35/255) -- neutral 
colorDB.reaction[5] = createColor(64/255, 131/255, 38/255) -- friendly
colorDB.reaction[6] = createColor(64/255, 131/255, 69/255) -- honored
colorDB.reaction[7] = createColor(64/255, 131/255, 104/255) -- revered
colorDB.reaction[8] = createColor(64/255, 131/255, 131/255) -- exalted
colorDB.reaction.civilian = createColor(64/255, 131/255, 38/255) -- used for friendly player nameplates

-- friendship
-- just using this as pointers to the reaction colors, 
-- so there won't be a need to ever edit these.
colorDB.friendship = {}
colorDB.friendship[1] = colorDB.reaction[3] -- Stranger
colorDB.friendship[2] = colorDB.reaction[4] -- Acquaintance 
colorDB.friendship[3] = colorDB.reaction[5] -- Buddy
colorDB.friendship[4] = colorDB.reaction[6] -- Friend (honored color)
colorDB.friendship[5] = colorDB.reaction[7] -- Good Friend (revered color)
colorDB.friendship[6] = colorDB.reaction[8] -- Best Friend (exalted color)
colorDB.friendship[7] = colorDB.reaction[8] -- Best Friend (exalted color) - brawler's stuff
colorDB.friendship[8] = colorDB.reaction[8] -- Best Friend (exalted color) - brawler's stuff

-- player specializations
colorDB.specialization = {}
colorDB.specialization[1] = createColor(0/255, 215/255, 59/255)
colorDB.specialization[2] = createColor(217/255, 33/255, 0/255)
colorDB.specialization[3] = createColor(218/255, 30/255, 255/255)
colorDB.specialization[4] = createColor(48/255, 156/255, 255/255)

-- timers (breath, fatigue, etc)
colorDB.timer = {}
colorDB.timer.UNKNOWN = createColor(179/255, 77/255, 0/255) -- fallback for timers and unknowns
colorDB.timer.EXHAUSTION = createColor(179/255, 77/255, 0/255)
colorDB.timer.BREATH = createColor(0/255, 128/255, 255/255)
colorDB.timer.DEATH = createColor(217/255, 90/255, 0/255) 
colorDB.timer.FEIGNDEATH = createColor(217/255, 90/255, 0/255) 

-- threat
colorDB.threat = {}
colorDB.threat[0] = colorDB.reaction[4] -- not really on the threat table
colorDB.threat[1] = createColor(249/255, 158/255, 35/255) -- tanks having lost threat, dps overnuking 
colorDB.threat[2] = createColor(255/255, 96/255, 12/255) -- tanks about to lose threat, dps getting aggro
colorDB.threat[3] = createColor(255/255, 0/255, 0/255) -- securely tanking, or totally fucked :) 

-- zone names
colorDB.zone = {}
colorDB.zone.arena = createColor(175/255, 76/255, 56/255)
colorDB.zone.combat = createColor(175/255, 76/255, 56/255) 
colorDB.zone.contested = createColor(229/255, 159/255, 28/255)
colorDB.zone.friendly = createColor(64/255, 175/255, 38/255) 
colorDB.zone.hostile = createColor(175/255, 76/255, 56/255) 
colorDB.zone.sanctuary = createColor(104/255, 204/255, 239/255)
colorDB.zone.unknown = createColor(255/255, 234/255, 137/255) -- instances, bgs, contested zones on pve realms 

-- Item rarity coloring
colorDB.quality = createColorGroup(ITEM_QUALITY_COLORS)

-- world quest quality coloring
-- using item rarities for these colors
colorDB.worldquestquality = {}
colorDB.worldquestquality[LE_WORLD_QUEST_QUALITY_COMMON] = colorDB.quality[ITEM_QUALITY_COMMON]
colorDB.worldquestquality[LE_WORLD_QUEST_QUALITY_RARE] = colorDB.quality[ITEM_QUALITY_RARE]
colorDB.worldquestquality[LE_WORLD_QUEST_QUALITY_EPIC] = colorDB.quality[ITEM_QUALITY_EPIC]

-- Aura Filter Bitflags
-----------------------------------------------------------------
-- These are front-end filters and describe display preference, 
-- they are unrelated to the factual, purely descriptive back-end filters. 
local ByPlayer 			= 2^0 -- Show when cast by player

-- Unit visibility
local OnPlayer 			= 2^1 -- Show on player frame
local OnTarget 			= 2^2 -- Show on target frame 
local OnPet 			= 2^3 -- Show on pet frame
local OnToT 			= 2^4 -- Shown on tot frame
local OnParty 			= 2^5 -- Show on party members
local OnBoss 			= 2^6 -- Show on boss frames
local OnFriend 			= 2^7 -- Show on friendly units, regardless of frame
local OnEnemy 			= 2^8 -- Show on enemy units, regardless of frame

-- Player role visibility
local PlayerIsDPS 		= 2^9 -- Show when player is a damager
local PlayerIsHealer 	= 2^10 -- Show when player is a healer
local PlayerIsTank 		= 2^11 -- Show when player is a tank 

-- Aura visibility priority
local Never 			= 2^12 -- Never show (Blacklist)
local PrioLow 			= 2^13 -- Low priority, will only be displayed if room
local PrioMedium 		= 2^14 -- Normal priority, same as not setting any
local PrioHigh 			= 2^15 -- High priority, shown first after boss
local PrioBoss 			= 2^16 -- Same priority as boss debuffs
local Always 			= 2^17 -- Always show (Whitelist)

local NeverOnPlate 		= 2^18 -- Never show on plates 

local NoCombat 			= 2^19 -- Never show in combat 
local Warn 				= 2^20 -- Show when there is 30 secs left or less

local hideUnfilteredSpellID, hideFilteredSpellID = false, false
local buffDurationThreshold, debuffDurationThreshold = 61, 601
local shortBuffDurationThreshold, shortDebuffDurationThreshold = 31, 31

-- Aura Filter Functions
-----------------------------------------------------------------
-- Just to have a fallback.
auraFilters.default = function() return true end

auraFilters.player = function(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)

	local all = element.all
	local hasFlags = not not GetUserFlags(Private)[spellID]

	if (hasFlags) then 
		if (HasUserFlags(Private, spellID, Never)) then 
			return nil, nil, hideFilteredSpellID
		elseif (UnitAffectingCombat("player") and HasUserFlags(Private, spellID, NoCombat)) then 
			if (isBuff and HasUserFlags(Private, spellID, Warn)) then 
				local timeLeft 
				if (expirationTime and expirationTime > 0) then 
					timeLeft = expirationTime - GetTime()
				end
				if (timeLeft and (timeLeft > 0) and (timeLeft < buffDurationThreshold)) or (duration and (duration > 0) and (duration < buffDurationThreshold)) then
					return true, nil, hideFilteredSpellID
				else 
					return nil, nil, hideFilteredSpellID
				end
			else
				return nil, nil, hideFilteredSpellID
			end
		elseif (HasUserFlags(Private, spellID, OnPlayer)) then 
			return true, nil, hideFilteredSpellID
		end
	end 

	if (UnitAffectingCombat("player")) then 
		local timeLeft 
		if (expirationTime and expirationTime > 0) then 
			timeLeft = expirationTime - GetTime()
		end
		if (isBuff) then 
			if (timeLeft and (timeLeft > 0) and (timeLeft < buffDurationThreshold)) or (duration and (duration > 0) and (duration < buffDurationThreshold)) then
				return true, nil, hideUnfilteredSpellID
			else 
				return nil, nil, hideUnfilteredSpellID
			end
		else 
			if (timeLeft and (timeLeft > 0) and (timeLeft < debuffDurationThreshold)) then 
				return true, nil, hideUnfilteredSpellID
			else
				return nil, nil, hideUnfilteredSpellID
			end
		end 
	else 
		return true, nil, hideUnfilteredSpellID
	end 
end 

auraFilters.target = function(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)

	local all = element.all
	local hasFlags = not not GetUserFlags(Private)[spellID]

	if (hasFlags) then 
		if (HasUserFlags(Private, spellID, Never)) then 
			return nil, nil, hideFilteredSpellID
		elseif (UnitAffectingCombat("player") and HasUserFlags(Private, spellID, NoCombat)) then 
			if (isBuff and HasUserFlags(Private, spellID, Warn)) then 
				local timeLeft 
				if (expirationTime and expirationTime > 0) then 
					timeLeft = expirationTime - GetTime()
				end
				if (timeLeft and (timeLeft > 0) and (timeLeft < buffDurationThreshold)) or (duration and (duration > 0) and (duration < buffDurationThreshold)) then
					return true, nil, hideFilteredSpellID
				else 
					return nil, nil, hideFilteredSpellID
				end
			else
				return nil, nil, hideFilteredSpellID
			end
		elseif (HasUserFlags(Private, spellID, OnTarget)) then 
			return true, nil, hideFilteredSpellID
		end
	end 
	
	if (UnitAffectingCombat("player")) then 
		local timeLeft 
		if (expirationTime and expirationTime > 0) then 
			timeLeft = expirationTime - GetTime()
		end
		if (isBuff) then 
			if (timeLeft and (timeLeft > 0) and (timeLeft < buffDurationThreshold)) or (duration and (duration > 0) and (duration < buffDurationThreshold)) then
				return true, nil, hideUnfilteredSpellID
			else 
				return nil, nil, hideUnfilteredSpellID
			end
		else 
			if (timeLeft and (timeLeft > 0) and (timeLeft < debuffDurationThreshold)) then 
				return true, nil, hideUnfilteredSpellID
			else
				return nil, nil, hideUnfilteredSpellID
			end
		end 
	else 
		return true, nil, hideUnfilteredSpellID
	end 
end

auraFilters.nameplate = function(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)

	local all = element.all
	local hasFlags = not not GetUserFlags(Private)[spellID]
	if (hasFlags) then 
		if (HasUserFlags(Private, spellID, NeverOnPlate)) then 
			return nil, nil, hideFilteredSpellID
		end
	end 
	local timeLeft 
	if (expirationTime and expirationTime > 0) then 
		timeLeft = expirationTime - GetTime()
		if (timeLeft and (timeLeft > 0) and (timeLeft < buffDurationThreshold)) or (duration and (duration > 0) and (duration < buffDurationThreshold)) then
			return true, nil, hideUnfilteredSpellID
		else 
			return nil, nil, hideUnfilteredSpellID
		end
	end
	return nil, nil, hideUnfilteredSpellID
end 

auraFilters.targettarget = function(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)
	return auraFilters.target(element, button, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)
end

auraFilters.party = function(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)

	local all = element.all
	local hasFlags = not not GetUserFlags(Private)[spellID]
	if (hasFlags) then 
		if (HasUserFlags(Private, spellID, NeverOnPlate)) then 
			return nil, nil, hideFilteredSpellID
		end
	end 
	local timeLeft 
	if (expirationTime and expirationTime > 0) then 
		timeLeft = expirationTime - GetTime()
		if (timeLeft and (timeLeft > 0) and (timeLeft < buffDurationThreshold)) or (duration and (duration > 0) and (duration < buffDurationThreshold)) then
			return true, nil, hideUnfilteredSpellID
		else 
			return nil, nil, hideUnfilteredSpellID
		end
	end
	return nil, nil, hideUnfilteredSpellID

end

auraFilters.boss = function(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)
end


-- Add a fallback system
-- *needed in case non-existing unit filters are requested 
local filterFuncs = setmetatable(auraFilters, { __index = function(t,k) return rawget(t,k) or rawget(t, "default") end})

-- Private API
-----------------------------------------------------------------
Private.Colors = colorDB

Private.GetAuraFilterFunc = function(unit) 
	return filterFuncs[unit or "default"] 
end

Private.GetFont = function(size, useOutline, useChatFont)
	if (useChatFont) then 
		return fontsDB[useOutline and "chatOutline" or "chatNormal"][size]
	else
		return fontsDB[useOutline and "outline" or "normal"][size]
	end
end

Private.GetMedia = function(name, type) return ([[Interface\AddOns\%s\media\%s.%s]]):format(ADDON, name, type or "tga") end

-----------------------------------------------------------------
-- Aura Filter Flag Database
-----------------------------------------------------------------
-- Will update this once we get proper combat log parsing going
--local ByPlayer = OnPlayer + OnTarget

-- General Blacklist
-- Auras listed here won't be shown on any unitframes.
------------------------------------------------------------------------
AddUserFlags(Private, 17670, Never) 		-- Argent Dawn Commission

-- General NoCombat Blacklist
-- Auras listed here won't be shown while in combat.
------------------------------------------------------------------------
AddUserFlags(Private, 26013, NoCombat) 		-- Deserter

-- Nameplate Blacklist
------------------------------------------------------------------------
-- Auras listed here will be excluded from the nameplates.
-- Many similar to these will be excluded by default filters too,
-- but we still with to eventually include all relevant ones.
------------------------------------------------------------------------
AddUserFlags(Private, 26013, NeverOnPlate) 	-- Deserter

-- Proximity Auras
AddUserFlags(Private, 13159, NeverOnPlate) 	-- Aspect of the Pack
AddUserFlags(Private,  7805, NeverOnPlate) 	-- Blood Pact
AddUserFlags(Private, 11767, NeverOnPlate) 	-- Blood Pact
AddUserFlags(Private, 19746, NeverOnPlate) 	-- Concentration Aura
AddUserFlags(Private, 10293, NeverOnPlate) 	-- Devotion Aura
AddUserFlags(Private, 19898, NeverOnPlate) 	-- Frost Resistance Aura
AddUserFlags(Private, 24932, NeverOnPlate) 	-- Leader of the Pack
AddUserFlags(Private, 24907, NeverOnPlate) 	-- Moonkin Aura
AddUserFlags(Private, 19480, NeverOnPlate) 	-- Paranoia
AddUserFlags(Private, 10301, NeverOnPlate) 	-- Retribution Aura
AddUserFlags(Private, 20218, NeverOnPlate) 	-- Sanctity Aura
AddUserFlags(Private, 19896, NeverOnPlate) 	-- Shadow Resistance Aura
AddUserFlags(Private, 20906, NeverOnPlate) 	-- Trueshot Aura

-- Timed Buffs
AddUserFlags(Private, 23028, NeverOnPlate) 	-- Arcane Brilliance (Rank ?)
AddUserFlags(Private,  1461, NeverOnPlate) 	-- Arcane Intellect (Rank ?)
AddUserFlags(Private, 10157, NeverOnPlate) 	-- Arcane Intellect (Rank ?)
AddUserFlags(Private,  6673, NeverOnPlate) 	-- Battle Shout (Rank 1)
AddUserFlags(Private, 11551, NeverOnPlate) 	-- Battle Shout (Rank ?)
AddUserFlags(Private, 20217, NeverOnPlate) 	-- Blessing of Kings (Rank ?)
AddUserFlags(Private, 19838, NeverOnPlate) 	-- Blessing of Might (Rank ?)
AddUserFlags(Private, 11743, NeverOnPlate) 	-- Detect Greater Invisibility
AddUserFlags(Private, 27841, NeverOnPlate) 	-- Divine Spirit (Rank ?)
AddUserFlags(Private, 25898, NeverOnPlate) 	-- Greater Blessing of Kings (Rank ?)
AddUserFlags(Private, 25899, NeverOnPlate) 	-- Greater Blessing of Sanctuary (Rank ?)
AddUserFlags(Private, 21850, NeverOnPlate) 	-- Gift of the Wild (Rank 2)
AddUserFlags(Private, 10220, NeverOnPlate) 	-- Ice Armor (Rank ?)
AddUserFlags(Private,  1126, NeverOnPlate) 	-- Mark of the Wild (Rank 1)
AddUserFlags(Private,  5232, NeverOnPlate) 	-- Mark of the Wild (Rank 2)
AddUserFlags(Private,  6756, NeverOnPlate) 	-- Mark of the Wild (Rank 3)
AddUserFlags(Private,  5234, NeverOnPlate) 	-- Mark of the Wild (Rank 4)
AddUserFlags(Private,  8907, NeverOnPlate) 	-- Mark of the Wild (Rank 5)
AddUserFlags(Private,  9884, NeverOnPlate) 	-- Mark of the Wild (Rank 6)
AddUserFlags(Private,  9885, NeverOnPlate) 	-- Mark of the Wild (Rank 7)
AddUserFlags(Private, 10938, NeverOnPlate) 	-- Power Word: Fortitude (Rank ?)
AddUserFlags(Private, 21564, NeverOnPlate) 	-- Prayer of Fortitude (Rank ?)
AddUserFlags(Private, 27681, NeverOnPlate) 	-- Prayer of Spirit (Rank ?)
AddUserFlags(Private, 10958, NeverOnPlate) 	-- Shadow Protection
AddUserFlags(Private,   467, NeverOnPlate) 	-- Thorns (Rank 1)
AddUserFlags(Private,   782, NeverOnPlate) 	-- Thorns (Rank 2)
AddUserFlags(Private,  1075, NeverOnPlate) 	-- Thorns (Rank 3)
AddUserFlags(Private,  8914, NeverOnPlate) 	-- Thorns (Rank 4)
AddUserFlags(Private,  9756, NeverOnPlate) 	-- Thorns (Rank 5)
AddUserFlags(Private,  9910, NeverOnPlate) 	-- Thorns (Rank 6)

-- Druid (Balance)
------------------------------------------------------------------------
AddUserFlags(Private, 22812, OnPlayer) 	-- Barkskin
AddUserFlags(Private,   339, OnTarget) 	-- Entangling Roots (Rank 1)
AddUserFlags(Private,  1062, OnTarget) 	-- Entangling Roots (Rank 2)
AddUserFlags(Private,  5195, OnTarget) 	-- Entangling Roots (Rank 3)
AddUserFlags(Private,  5196, OnTarget) 	-- Entangling Roots (Rank 4)
AddUserFlags(Private,  9852, OnTarget) 	-- Entangling Roots (Rank 5)
AddUserFlags(Private,  9853, OnTarget) 	-- Entangling Roots (Rank 6)
AddUserFlags(Private,   770, OnTarget) 	-- Faerie Fire (Rank 1)
AddUserFlags(Private, 18658, OnTarget) 	-- Hibernate (Rank 3)
AddUserFlags(Private, 16689, OnPlayer) 	-- Nature's Grasp (Rank 1)
AddUserFlags(Private, 16689, OnPlayer) 	-- Nature's Grasp (Rank 2)
AddUserFlags(Private, 16689, OnPlayer) 	-- Nature's Grasp (Rank 3)
AddUserFlags(Private, 16689, OnPlayer) 	-- Nature's Grasp (Rank 4)
AddUserFlags(Private, 16689, OnPlayer) 	-- Nature's Grasp (Rank 5)
AddUserFlags(Private, 16689, OnPlayer) 	-- Nature's Grasp (Rank 6)
AddUserFlags(Private, 16864, OnPlayer + NoCombat + Warn) 	-- Omen of Clarity (Buff)
AddUserFlags(Private, 16870, OnPlayer + NoCombat + Warn) 	-- Omen of Clarity (Proc)
AddUserFlags(Private,   467, ByPlayer + NoCombat + Warn) 	-- Thorns (Rank 1)
AddUserFlags(Private,   782, ByPlayer + NoCombat + Warn) 	-- Thorns (Rank 2)
AddUserFlags(Private,  1075, ByPlayer + NoCombat + Warn) 	-- Thorns (Rank 3)
AddUserFlags(Private,  8914, ByPlayer + NoCombat + Warn) 	-- Thorns (Rank 4)
AddUserFlags(Private,  9756, ByPlayer + NoCombat + Warn) 	-- Thorns (Rank 5)
AddUserFlags(Private,  9910, ByPlayer + NoCombat + Warn) 	-- Thorns (Rank 6)

AddUserFlags(Private, 00000, OnTarget) 	-- Faerie Fire (Rank 2)
AddUserFlags(Private, 00000, OnTarget) 	-- Faerie Fire (Rank 3)
AddUserFlags(Private, 00000, OnTarget) 	-- Faerie Fire (Rank 4)

AddUserFlags(Private, 00000, OnTarget) 	-- Moonfire (Rank 1)
AddUserFlags(Private, 00000, OnTarget) 	-- Moonfire (Rank 1)
AddUserFlags(Private, 00000, OnTarget) 	-- Moonfire (Rank 3)
AddUserFlags(Private, 00000, OnTarget) 	-- Moonfire (Rank 4)
AddUserFlags(Private, 00000, OnTarget) 	-- Moonfire (Rank 5)
AddUserFlags(Private, 00000, OnTarget) 	-- Moonfire (Rank 6)

AddUserFlags(Private, 00000, OnTarget) 	-- Hurricane (Rank 1)

-- Druid (Feral)
------------------------------------------------------------------------
AddUserFlags(Private,  1066, Never) 	-- Aquatic Form
AddUserFlags(Private,  8983, OnTarget) 	-- Bash
AddUserFlags(Private,   768, Never) 	-- Cat Form
AddUserFlags(Private,  5209, OnTarget) 	-- Challenging Roar (Taunt)
AddUserFlags(Private,  9821, OnPlayer) 	-- Dash
AddUserFlags(Private,  9634, Never) 	-- Dire Bear Form
AddUserFlags(Private,  5229, OnPlayer) 	-- Enrage
AddUserFlags(Private, 16857, ByPlayer) 	-- Faerie Fire (Feral)
AddUserFlags(Private, 22896, OnPlayer) 	-- Frenzied Regeneration
AddUserFlags(Private,  6795, OnTarget) 	-- Growl (Taunt)
AddUserFlags(Private, 24932, Never) 	-- Leader of the Pack
AddUserFlags(Private,  9007, ByPlayer) 	-- Pounce Bleed (Rank 1)
AddUserFlags(Private,  9824, ByPlayer) 	-- Pounce Bleed (Rank 2)
AddUserFlags(Private,  9826, ByPlayer) 	-- Pounce Bleed (Rank 3)
AddUserFlags(Private,  5215, OnPlayer) 	-- Prowl (Rank 1)
AddUserFlags(Private,  6783, OnPlayer) 	-- Prowl (Rank 2)
AddUserFlags(Private,  9913, OnPlayer) 	-- Prowl (Rank 3)
AddUserFlags(Private,  9904, ByPlayer) 	-- Rake
AddUserFlags(Private,  9894, ByPlayer) 	-- Rip
AddUserFlags(Private,  9845, OnPlayer) 	-- Tiger's Fury
AddUserFlags(Private,   783, Never) 	-- Travel Form

-- Druid (Restoration)
------------------------------------------------------------------------
AddUserFlags(Private,  2893, ByPlayer) 			-- Abolish Poison
AddUserFlags(Private, 29166, ByPlayer) 			-- Innervate
AddUserFlags(Private,  1126, ByPlayer + NoCombat + Warn) 	-- Mark of the Wild (Rank 1)
AddUserFlags(Private,  5232, ByPlayer + NoCombat + Warn) 	-- Mark of the Wild (Rank 2)
AddUserFlags(Private,  6756, ByPlayer + NoCombat + Warn) 	-- Mark of the Wild (Rank 3)
AddUserFlags(Private,  5234, ByPlayer + NoCombat + Warn) 	-- Mark of the Wild (Rank 4)
AddUserFlags(Private,  8907, ByPlayer + NoCombat + Warn) 	-- Mark of the Wild (Rank 5)
AddUserFlags(Private,  9884, ByPlayer + NoCombat + Warn) 	-- Mark of the Wild (Rank 6)
AddUserFlags(Private,  9885, ByPlayer + NoCombat + Warn) 	-- Mark of the Wild (Rank 7)
AddUserFlags(Private,  8936, ByPlayer) 	-- Regrowth (Rank 1)
AddUserFlags(Private,  8938, ByPlayer) 	-- Regrowth (Rank 2)
AddUserFlags(Private,  8939, ByPlayer) 	-- Regrowth (Rank 3)
AddUserFlags(Private,  8940, ByPlayer) 	-- Regrowth (Rank 4)
AddUserFlags(Private,  8941, ByPlayer) 	-- Regrowth (Rank 5)
AddUserFlags(Private,  9750, ByPlayer) 	-- Regrowth (Rank 6)
AddUserFlags(Private,  9856, ByPlayer) 	-- Regrowth (Rank 7)
AddUserFlags(Private,  9857, ByPlayer) 	-- Regrowth (Rank 8)
AddUserFlags(Private,  9858, ByPlayer) 	-- Regrowth (Rank 9)
AddUserFlags(Private,   774, ByPlayer) 	-- Rejuvenation (Rank 1)
AddUserFlags(Private,  1058, ByPlayer) 	-- Rejuvenation (Rank 2)
AddUserFlags(Private,  1430, ByPlayer) 	-- Rejuvenation (Rank 3)
AddUserFlags(Private,  2090, ByPlayer) 	-- Rejuvenation (Rank 4)
AddUserFlags(Private,  2091, ByPlayer) 	-- Rejuvenation (Rank 5)
AddUserFlags(Private,  3627, ByPlayer) 	-- Rejuvenation (Rank 6)
AddUserFlags(Private,  8910, ByPlayer) 	-- Rejuvenation (Rank 7)
AddUserFlags(Private,  9839, ByPlayer) 	-- Rejuvenation (Rank 8)
AddUserFlags(Private,  9840, ByPlayer) 	-- Rejuvenation (Rank 9)
AddUserFlags(Private,  9841, ByPlayer) 	-- Rejuvenation (Rank 10)
AddUserFlags(Private,   740, ByPlayer) 	-- Tranquility (Rank 1)
AddUserFlags(Private,  8918, ByPlayer) 	-- Tranquility (Rank 2)
AddUserFlags(Private,  9862, ByPlayer) 	-- Tranquility (Rank 3)
AddUserFlags(Private,  9863, ByPlayer) 	-- Tranquility (Rank 4)

-- Warrior (Arms)
------------------------------------------------------------------------
AddUserFlags(Private,  7922, OnTarget) 	-- Charge Stun (Rank 1)
AddUserFlags(Private,   772, OnTarget) 	-- Rend (Rank 1)
AddUserFlags(Private,  6343, OnTarget) 	-- Thunder Clap (Rank 1)

-- Warrior (Fury)
------------------------------------------------------------------------
AddUserFlags(Private,  6673, OnPlayer) 	-- Battle Shout (Rank 1)
