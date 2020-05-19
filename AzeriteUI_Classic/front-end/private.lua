local ADDON, Private = ...

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, ADDON.." requires LibClientBuild to be loaded.")

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
local UnitClassification = UnitClassification
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitIsUnit = UnitIsUnit
local UnitLevel = UnitLevel
local UnitPlayerControlled = UnitPlayerControlled

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

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
colorDB.quest.orange = createColor(255/255, 106/255, 26/255)
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
local OnFocus 			= 2^5 -- Shown on focus frame
local OnParty 			= 2^6 -- Show on party members
local OnBoss 			= 2^7 -- Show on boss frames
local OnFriend 			= 2^8 -- Show on friendly units, regardless of frame
local OnEnemy 			= 2^9 -- Show on enemy units, regardless of frame

-- Player role visibility
local PlayerIsDPS 		= 2^10-- Show when player is a damager
local PlayerIsHealer 	= 2^11 -- Show when player is a healer
local PlayerIsTank 		= 2^12 -- Show when player is a tank 

-- Aura visibility priority
local Never 			= 2^13 -- Never show (Blacklist)
local PrioLow 			= 2^14 -- Low priority, will only be displayed if room
local PrioMedium 		= 2^15 -- Normal priority, same as not setting any
local PrioHigh 			= 2^16 -- High priority, shown first after boss
local PrioBoss 			= 2^17 -- Same priority as boss debuffs
local Always 			= 2^18 -- Always show (Whitelist)

local NeverOnPlate 		= 2^19 -- Never show on plates 

local NoCombat 			= 2^20 -- Never show in combat 
local Warn 				= 2^21 -- Show when there is 30 secs left or less

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
		-- Blacklisted
		if (HasUserFlags(Private, spellID, Never)) then -- fully blacklisted
			return nil, nil, hideFilteredSpellID

		-- Attempting to show vehicle or possessed unit's buffs 
		-- *This fixes style multipliers now showing in the BFA horse riding
		elseif (IsRetail) and (UnitHasVehicleUI("player") and (isCastByPlayer or unitCaster == "pet" or unitCaster == "vehicle")) then
			return true, nil, hideFilteredSpellID

		-- Hidden in combat
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

		-- Whitelisted
		elseif (HasUserFlags(Private, spellID, Always)) -- fully whitelisted
			or (HasUserFlags(Private, spellID, OnPlayer)) -- shown on player
			or (HasUserFlags(Private, spellID, PrioBoss)) then -- shown when cast by boss
		
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
		-- Blacklisted
		if (HasUserFlags(Private, spellID, Never)) then -- fully blacklisted
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

		-- Whitelisted
		elseif (HasUserFlags(Private, spellID, Always)) -- fully whitelisted
			or (HasUserFlags(Private, spellID, OnTarget)) -- shown on target
			or (HasUserFlags(Private, spellID, PrioBoss)) then -- shown when cast by boss
		
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
		-- Blacklisted
		if (HasUserFlags(Private, spellID, Never)) -- fully blacklisted
		or (HasUserFlags(Private, spellID, NeverOnPlate)) then -- blacklisted on plates
				return nil, nil, hideFilteredSpellID

		-- Whitelisted
		elseif (HasUserFlags(Private, spellID, Always)) then -- fully whitelisted
			return true, nil, hideFilteredSpellID
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

auraFilters.focus = function(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)
	return auraFilters.target(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)
end

auraFilters.targettarget = function(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)
	return auraFilters.target(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)
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
local PopulateClassicDatabase = function()

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

end

local PopulateRetailDatabase = function()

	-- Musts that are game-breaking to not have there
	------------------------------------------------------------------------
	AddUserFlags(Private, 105241, Always) -- Absorb Blood (Amalgamation Stacks, some raid)
	AddUserFlags(Private, 304696, OnPlayer) -- Alpha Fin (constantly moving mount)
	AddUserFlags(Private, 295858, OnPlayer) -- Molted Shell (constantly moving mount)
	AddUserFlags(Private, 304037, OnPlayer) -- Fermented Deviate Fish (transform)

	-- Spammy stuff that is implicit and not really needed
	--AddUserFlags(Private, 155722, NeverOnPlate) -- Rake (just for my own testing purposes)
	AddUserFlags(Private, 204242, NeverOnPlate) -- Consecration (talent Consecrated Ground)

	-- NPC buffs that are completely useless
	------------------------------------------------------------------------
	AddUserFlags(Private,  63501, Never) -- Argent Crusade Champion's Pennant
	AddUserFlags(Private,  60023, Never) -- Scourge Banner Aura (Boneguard Commander in Icecrown)
	AddUserFlags(Private,  63406, Never) -- Darnassus Champion's Pennant
	AddUserFlags(Private,  63405, Never) -- Darnassus Valiant's Pennant
	AddUserFlags(Private,  63423, Never) -- Exodar Champion's Pennant
	AddUserFlags(Private,  63422, Never) -- Exodar Valiant's Pennant
	AddUserFlags(Private,  63396, Never) -- Gnomeregan Champion's Pennant
	AddUserFlags(Private,  63395, Never) -- Gnomeregan Valiant's Pennant
	AddUserFlags(Private,  63427, Never) -- Ironforge Champion's Pennant
	AddUserFlags(Private,  63426, Never) -- Ironforge Valiant's Pennant
	AddUserFlags(Private,  63433, Never) -- Orgrimmar Champion's Pennant
	AddUserFlags(Private,  63432, Never) -- Orgrimmar Valiant's Pennant
	AddUserFlags(Private,  63399, Never) -- Sen'jin Champion's Pennant
	AddUserFlags(Private,  63398, Never) -- Sen'jin Valiant's Pennant
	AddUserFlags(Private,  63403, Never) -- Silvermoon Champion's Pennant
	AddUserFlags(Private,  63402, Never) -- Silvermoon Valiant's Pennant
	AddUserFlags(Private,  62594, Never) -- Stormwind Champion's Pennant
	AddUserFlags(Private,  62596, Never) -- Stormwind Valiant's Pennant
	AddUserFlags(Private,  63436, Never) -- Thunder Bluff Champion's Pennant
	AddUserFlags(Private,  63435, Never) -- Thunder Bluff Valiant's Pennant
	AddUserFlags(Private,  63430, Never) -- Undercity Champion's Pennant
	AddUserFlags(Private,  63429, Never) -- Undercity Valiant's Pennant

	-- Legion Consumables
	------------------------------------------------------------------------
	AddUserFlags(Private, 188030, ByPlayer) -- Leytorrent Potion (channeled)
	AddUserFlags(Private, 188027, ByPlayer) -- Potion of Deadly Grace
	AddUserFlags(Private, 188028, ByPlayer) -- Potion of the Old War
	AddUserFlags(Private, 188029, ByPlayer) -- Unbending Potion

	-- Quest related auras
	------------------------------------------------------------------------
	AddUserFlags(Private, 127372, OnPlayer) -- Unstable Serum (Klaxxi Enhancement: Raining Blood)
	AddUserFlags(Private, 240640, OnPlayer) -- The Shadow of the Sentinax (Mark of the Sentinax)

	-- Heroism
	------------------------------------------------------------------------
	AddUserFlags(Private,  90355, OnPlayer + PrioHigh) -- Ancient Hysteria
	AddUserFlags(Private,   2825, OnPlayer + PrioHigh) -- Bloodlust
	AddUserFlags(Private,  32182, OnPlayer + PrioHigh) -- Heroism
	AddUserFlags(Private, 160452, OnPlayer + PrioHigh) -- Netherwinds
	AddUserFlags(Private,  80353, OnPlayer + PrioHigh) -- Time Warp

	-- Deserters
	------------------------------------------------------------------------
	AddUserFlags(Private,  26013, OnPlayer + PrioHigh) -- Deserter
	AddUserFlags(Private,  99413, OnPlayer + PrioHigh) -- Deserter
	AddUserFlags(Private,  71041, OnPlayer + PrioHigh) -- Dungeon Deserter
	AddUserFlags(Private, 144075, OnPlayer + PrioHigh) -- Dungeon Deserter
	AddUserFlags(Private, 170616, OnPlayer + PrioHigh) -- Pet Deserter

	-- Other big ones
	------------------------------------------------------------------------
	AddUserFlags(Private,  67556, OnPlayer) -- Cooking Speed
	AddUserFlags(Private,  29166, OnPlayer) -- Innervate
	AddUserFlags(Private, 102342, OnPlayer) -- Ironbark
	AddUserFlags(Private,  33206, OnPlayer) -- Pain Suppression
	AddUserFlags(Private,  10060, OnPlayer) -- Power Infusion
	AddUserFlags(Private,  64901, OnPlayer) -- Symbol of Hope

	AddUserFlags(Private,  57723, OnPlayer) -- Exhaustion "Cannot benefit from Heroism or other similar effects." (Alliance version)
	AddUserFlags(Private, 160455, OnPlayer) -- Fatigued "Cannot benefit from Netherwinds or other similar effects." (Pet version)
	AddUserFlags(Private, 243138, OnPlayer) -- Happy Feet event 
	AddUserFlags(Private, 246050, OnPlayer) -- Happy Feet buff gained restoring health
	AddUserFlags(Private,  95809, OnPlayer) -- Insanity "Cannot benefit from Ancient Hysteria or other similar effects." (Pet version)
	AddUserFlags(Private,  15007, OnPlayer) -- Resurrection Sickness
	AddUserFlags(Private,  57724, OnPlayer) -- Sated "Cannot benefit from Bloodlust or other similar effects." (Horde version)
	AddUserFlags(Private,  80354, OnPlayer) -- Temporal Displacement

	------------------------------------------------------------------------
	-- BfA Dungeons
	-- *some auras might be under the wrong dungeon, 
	--  this is because wowhead doesn't always tell what casts this.
	------------------------------------------------------------------------
	-- Atal'Dazar
	------------------------------------------------------------------------
	AddUserFlags(Private, 253721, PrioBoss) -- Bulwark of Juju
	AddUserFlags(Private, 253548, PrioBoss) -- Bwonsamdi's Mantle
	AddUserFlags(Private, 256201, PrioBoss) -- Incendiary Rounds
	AddUserFlags(Private, 250372, PrioBoss) -- Lingering Nausea
	AddUserFlags(Private, 257407, PrioBoss) -- Pursuit
	AddUserFlags(Private, 255434, PrioBoss) -- Serrated Teeth
	AddUserFlags(Private, 254959, PrioBoss) -- Soulburn
	AddUserFlags(Private, 256577, PrioBoss) -- Soulfeast
	AddUserFlags(Private, 254958, PrioBoss) -- Soulforged Construct
	AddUserFlags(Private, 259187, PrioBoss) -- Soulrend
	AddUserFlags(Private, 255558, PrioBoss) -- Tainted Blood
	AddUserFlags(Private, 255577, PrioBoss) -- Transfusion
	AddUserFlags(Private, 260667, PrioBoss) -- Transfusion
	AddUserFlags(Private, 260668, PrioBoss) -- Transfusion
	AddUserFlags(Private, 255371, PrioBoss) -- Terrifying Visage
	AddUserFlags(Private, 252781, PrioBoss) -- Unstable Hex
	AddUserFlags(Private, 250096, PrioBoss) -- Wracking Pain

	-- Tol Dagor
	------------------------------------------------------------------------
	AddUserFlags(Private, 256199, PrioBoss) -- Azerite Rounds: Blast
	AddUserFlags(Private, 256955, PrioBoss) -- Cinderflame
	AddUserFlags(Private, 256083, PrioBoss) -- Cross Ignition
	AddUserFlags(Private, 256038, PrioBoss) -- Deadeye
	AddUserFlags(Private, 256044, PrioBoss) -- Deadeye
	AddUserFlags(Private, 258128, PrioBoss) -- Debilitating Shout
	AddUserFlags(Private, 256105, PrioBoss) -- Explosive Burst
	AddUserFlags(Private, 257785, PrioBoss) -- Flashing Daggers
	AddUserFlags(Private, 258075, PrioBoss) -- Itchy Bite
	AddUserFlags(Private, 260016, PrioBoss) -- Itchy Bite  NEEDS CHECK!
	AddUserFlags(Private, 258079, PrioBoss) -- Massive Chomp
	AddUserFlags(Private, 258317, PrioBoss) -- Riot Shield
	AddUserFlags(Private, 257495, PrioBoss) -- Sandstorm
	AddUserFlags(Private, 258153, PrioBoss) -- Watery Dome

	-- The MOTHERLODE!!
	------------------------------------------------------------------------
	AddUserFlags(Private, 262510, PrioBoss) -- Azerite Heartseeker
	AddUserFlags(Private, 262513, PrioBoss) -- Azerite Heartseeker
	AddUserFlags(Private, 262515, PrioBoss) -- Azerite Heartseeker
	AddUserFlags(Private, 262516, PrioBoss) -- Azerite Heartseeker
	AddUserFlags(Private, 281534, PrioBoss) -- Azerite Heartseeker
	AddUserFlags(Private, 270276, PrioBoss) -- Big Red Rocket
	AddUserFlags(Private, 270277, PrioBoss) -- Big Red Rocket
	AddUserFlags(Private, 270278, PrioBoss) -- Big Red Rocket
	AddUserFlags(Private, 270279, PrioBoss) -- Big Red Rocket
	AddUserFlags(Private, 270281, PrioBoss) -- Big Red Rocket
	AddUserFlags(Private, 270282, PrioBoss) -- Big Red Rocket
	AddUserFlags(Private, 256163, PrioBoss) -- Blazing Azerite
	AddUserFlags(Private, 256493, PrioBoss) -- Blazing Azerite
	AddUserFlags(Private, 270882, PrioBoss) -- Blazing Azerite
	AddUserFlags(Private, 259853, PrioBoss) -- Chemical Burn
	AddUserFlags(Private, 280604, PrioBoss) -- Iced Spritzer
	AddUserFlags(Private, 260811, PrioBoss) -- Homing Missile
	AddUserFlags(Private, 260813, PrioBoss) -- Homing Missile
	AddUserFlags(Private, 260815, PrioBoss) -- Homing Missile
	AddUserFlags(Private, 260829, PrioBoss) -- Homing Missile
	AddUserFlags(Private, 260835, PrioBoss) -- Homing Missile
	AddUserFlags(Private, 260836, PrioBoss) -- Homing Missile
	AddUserFlags(Private, 260837, PrioBoss) -- Homing Missile
	AddUserFlags(Private, 260838, PrioBoss) -- Homing Missile
	AddUserFlags(Private, 257582, PrioBoss) -- Raging Gaze
	AddUserFlags(Private, 258622, PrioBoss) -- Resonant Pulse
	AddUserFlags(Private, 271579, PrioBoss) -- Rock Lance
	AddUserFlags(Private, 263202, PrioBoss) -- Rock Lance
	AddUserFlags(Private, 257337, PrioBoss) -- Shocking Claw
	AddUserFlags(Private, 262347, PrioBoss) -- Static Pulse
	AddUserFlags(Private, 275905, PrioBoss) -- Tectonic Smash
	AddUserFlags(Private, 275907, PrioBoss) -- Tectonic Smash
	AddUserFlags(Private, 269298, PrioBoss) -- Widowmaker Toxin

	-- Temple of Sethraliss
	------------------------------------------------------------------------
	AddUserFlags(Private, 263371, PrioBoss) -- Conduction
	AddUserFlags(Private, 263573, PrioBoss) -- Cyclone Strike
	AddUserFlags(Private, 263914, PrioBoss) -- Blinding Sand
	AddUserFlags(Private, 256333, PrioBoss) -- Dust Cloud
	AddUserFlags(Private, 260792, PrioBoss) -- Dust Cloud
	AddUserFlags(Private, 272659, PrioBoss) -- Electrified Scales
	AddUserFlags(Private, 269670, PrioBoss) -- Empowerment
	AddUserFlags(Private, 266923, PrioBoss) -- Galvanize
	AddUserFlags(Private, 268007, PrioBoss) -- Heart Attack
	AddUserFlags(Private, 263246, PrioBoss) -- Lightning Shield
	AddUserFlags(Private, 273563, PrioBoss) -- Neurotoxin
	AddUserFlags(Private, 272657, PrioBoss) -- Noxious Breath
	AddUserFlags(Private, 275566, PrioBoss) -- Numb Hands
	AddUserFlags(Private, 269686, PrioBoss) -- Plague
	AddUserFlags(Private, 263257, PrioBoss) -- Static Shock
	AddUserFlags(Private, 272699, PrioBoss) -- Venomous Spit

	-- Underrot
	------------------------------------------------------------------------
	AddUserFlags(Private, 272592, PrioBoss) -- Abyssal Reach
	AddUserFlags(Private, 264603, PrioBoss) -- Blood Mirror
	AddUserFlags(Private, 260292, PrioBoss) -- Charge
	AddUserFlags(Private, 265568, PrioBoss) -- Dark Omen
	AddUserFlags(Private, 272180, PrioBoss) -- Death Bolt
	AddUserFlags(Private, 273226, PrioBoss) -- Decaying Spores
	AddUserFlags(Private, 265377, PrioBoss) -- Hooked Snare
	AddUserFlags(Private, 260793, PrioBoss) -- Indigestion
	AddUserFlags(Private, 257437, PrioBoss) -- Poisoning Strike
	AddUserFlags(Private, 269301, PrioBoss) -- Putrid Blood
	AddUserFlags(Private, 264757, PrioBoss) -- Sanguine Feast
	AddUserFlags(Private, 265019, PrioBoss) -- Savage Cleave
	AddUserFlags(Private, 260455, PrioBoss) -- Serrated Fangs
	AddUserFlags(Private, 260685, PrioBoss) -- Taint of G'huun
	AddUserFlags(Private, 266107, PrioBoss) -- Thirst For Blood
	AddUserFlags(Private, 259718, PrioBoss) -- Upheaval
	AddUserFlags(Private, 269843, PrioBoss) -- Vile Expulsion
	AddUserFlags(Private, 273285, PrioBoss) -- Volatile Pods
	AddUserFlags(Private, 265468, PrioBoss) -- Withering Curse

	-- Freehold
	------------------------------------------------------------------------
	AddUserFlags(Private, 258323, PrioBoss) -- Infected Wound
	AddUserFlags(Private, 257908, PrioBoss) -- Oiled Blade
	AddUserFlags(Private, 274555, PrioBoss) -- Scabrous Bite
	AddUserFlags(Private, 274507, PrioBoss) -- Slippery Suds
	AddUserFlags(Private, 265168, PrioBoss) -- Caustic Freehold Brew
	AddUserFlags(Private, 278467, PrioBoss) -- Caustic Freehold Brew
	AddUserFlags(Private, 265085, PrioBoss) -- Confidence-Boosting Freehold Brew
	AddUserFlags(Private, 265088, PrioBoss) -- Confidence-Boosting Freehold Brew
	AddUserFlags(Private, 264608, PrioBoss) -- Invigorating Freehold Brew
	AddUserFlags(Private, 265056, PrioBoss) -- Invigorating Freehold Brew
	AddUserFlags(Private, 257739, PrioBoss) -- Blind Rage
	AddUserFlags(Private, 258777, PrioBoss) -- Sea Spout
	AddUserFlags(Private, 257732, PrioBoss) -- Shattering Bellow
	AddUserFlags(Private, 274383, PrioBoss) -- Rat Traps
	AddUserFlags(Private, 268717, PrioBoss) -- Dive Bomb
	AddUserFlags(Private, 257305, PrioBoss) -- Cannon Barrage

	-- Shrine of the Storm
	------------------------------------------------------------------------
	AddUserFlags(Private, 269131, PrioBoss) -- Ancient Mindbender
	AddUserFlags(Private, 268086, PrioBoss) -- Aura of Dread
	AddUserFlags(Private, 268214, PrioBoss) -- Carve Flesh
	AddUserFlags(Private, 264560, PrioBoss) -- Choking Brine
	AddUserFlags(Private, 267899, PrioBoss) -- Hindering Cleave
	AddUserFlags(Private, 268391, PrioBoss) -- Mental Assault
	AddUserFlags(Private, 268212, PrioBoss) -- Minor Reinforcing Ward
	AddUserFlags(Private, 268183, PrioBoss) -- Minor Swiftness Ward
	AddUserFlags(Private, 268184, PrioBoss) -- Minor Swiftness Ward
	AddUserFlags(Private, 267905, PrioBoss) -- Reinforcing Ward
	AddUserFlags(Private, 268186, PrioBoss) -- Reinforcing Ward
	AddUserFlags(Private, 268239, PrioBoss) -- Shipbreaker Storm
	AddUserFlags(Private, 267818, PrioBoss) -- Slicing Blast
	AddUserFlags(Private, 276286, PrioBoss) -- Slicing Hurricane
	AddUserFlags(Private, 264101, PrioBoss) -- Surging Rush
	AddUserFlags(Private, 274633, PrioBoss) -- Sundering Blow
	AddUserFlags(Private, 267890, PrioBoss) -- Swiftness Ward
	AddUserFlags(Private, 267891, PrioBoss) -- Swiftness Ward
	AddUserFlags(Private, 268322, PrioBoss) -- Touch of the Drowned
	AddUserFlags(Private, 264166, PrioBoss) -- Undertow
	AddUserFlags(Private, 268309, PrioBoss) -- Unending Darkness
	AddUserFlags(Private, 276297, PrioBoss) -- Void Seed
	AddUserFlags(Private, 267034, PrioBoss) -- Whispers of Power
	AddUserFlags(Private, 267037, PrioBoss) -- Whispers of Power
	AddUserFlags(Private, 269399, PrioBoss) -- Yawning Gate

	-- Waycrest Manor
	------------------------------------------------------------------------
	AddUserFlags(Private, 268080, PrioBoss) -- Aura of Apathy
	AddUserFlags(Private, 260541, PrioBoss) -- Burning Brush
	AddUserFlags(Private, 268202, PrioBoss) -- Death Lens
	AddUserFlags(Private, 265881, PrioBoss) -- Decaying Touch
	AddUserFlags(Private, 268306, PrioBoss) -- Discordant Cadenza
	AddUserFlags(Private, 265880, PrioBoss) -- Dread Mark
	AddUserFlags(Private, 263943, PrioBoss) -- Etch
	AddUserFlags(Private, 278444, PrioBoss) -- Infest
	AddUserFlags(Private, 278456, PrioBoss) -- Infest
	AddUserFlags(Private, 260741, PrioBoss) -- Jagged Nettles
	AddUserFlags(Private, 261265, PrioBoss) -- Ironbark Shield
	AddUserFlags(Private, 265882, PrioBoss) -- Lingering Dread
	AddUserFlags(Private, 271178, PrioBoss) -- Ravaging Leap
	AddUserFlags(Private, 264694, PrioBoss) -- Rotten Expulsion
	AddUserFlags(Private, 264105, PrioBoss) -- Runic Mark
	AddUserFlags(Private, 261266, PrioBoss) -- Runic Ward
	AddUserFlags(Private, 261264, PrioBoss) -- Soul Armor
	AddUserFlags(Private, 260512, PrioBoss) -- Soul Harvest
	AddUserFlags(Private, 264923, PrioBoss) -- Tenderize
	AddUserFlags(Private, 265761, PrioBoss) -- Thorned Barrage
	AddUserFlags(Private, 260703, PrioBoss) -- Unstable Runic Mark
	AddUserFlags(Private, 261440, PrioBoss) -- Virulent Pathogen
	AddUserFlags(Private, 263961, PrioBoss) -- Warding Candles

	-- King's Rest
	------------------------------------------------------------------------
	AddUserFlags(Private, 274387, PrioBoss) -- Absorbed in Darkness 
	AddUserFlags(Private, 266951, PrioBoss) -- Barrel Through
	AddUserFlags(Private, 268586, PrioBoss) -- Blade Combo
	AddUserFlags(Private, 267639, PrioBoss) -- Burn Corruption
	AddUserFlags(Private, 270889, PrioBoss) -- Channel Lightning
	AddUserFlags(Private, 271640, PrioBoss) -- Dark Revelation
	AddUserFlags(Private, 267626, PrioBoss) -- Dessication
	AddUserFlags(Private, 267618, PrioBoss) -- Drain Fluids
	AddUserFlags(Private, 271564, PrioBoss) -- Embalming Fluid
	AddUserFlags(Private, 269936, PrioBoss) -- Fixate
	AddUserFlags(Private, 268419, PrioBoss) -- Gale Slash
	AddUserFlags(Private, 270514, PrioBoss) -- Ground Crush
	AddUserFlags(Private, 265923, PrioBoss) -- Lucre's Call
	AddUserFlags(Private, 270284, PrioBoss) -- Purification Beam
	AddUserFlags(Private, 270289, PrioBoss) -- Purification Beam
	AddUserFlags(Private, 270507, PrioBoss) -- Poison Barrage
	AddUserFlags(Private, 265781, PrioBoss) -- Serpentine Gust
	AddUserFlags(Private, 266231, PrioBoss) -- Severing Axe
	AddUserFlags(Private, 270487, PrioBoss) -- Severing Blade
	AddUserFlags(Private, 266238, PrioBoss) -- Shattered Defenses
	AddUserFlags(Private, 265773, PrioBoss) -- Spit Gold
	AddUserFlags(Private, 270003, PrioBoss) -- Suppression Slam

	-- Siege of Boralus
	------------------------------------------------------------------------
	AddUserFlags(Private, 269029, PrioBoss) -- Clear the Deck
	AddUserFlags(Private, 272144, PrioBoss) -- Cover
	AddUserFlags(Private, 257168, PrioBoss) -- Cursed Slash
	AddUserFlags(Private, 260954, PrioBoss) -- Iron Gaze
	AddUserFlags(Private, 261428, PrioBoss) -- Hangman's Noose
	AddUserFlags(Private, 273930, PrioBoss) -- Hindering Cut
	AddUserFlags(Private, 275014, PrioBoss) -- Putrid Waters
	AddUserFlags(Private, 272588, PrioBoss) -- Rotting Wounds
	AddUserFlags(Private, 257170, PrioBoss) -- Savage Tempest
	AddUserFlags(Private, 272421, PrioBoss) -- Sighted Artillery
	AddUserFlags(Private, 269266, PrioBoss) -- Slam
	AddUserFlags(Private, 275836, PrioBoss) -- Stinging Venom
	AddUserFlags(Private, 257169, PrioBoss) -- Terrifying Roar
	AddUserFlags(Private, 276068, PrioBoss) -- Tidal Surge
	AddUserFlags(Private, 272874, PrioBoss) -- Trample
	AddUserFlags(Private, 260569, PrioBoss) -- Wildfire (?) Waycrest Manor? CHECK!

end

if (IsClassic) then
	PopulateClassicDatabase()
elseif (IsRetail) then
	PopulateRetailDatabase()
end
