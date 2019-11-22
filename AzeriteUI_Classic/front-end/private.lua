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
local AddFlags = Wheel("LibAuraData").AddAuraUserFlags
local HasUserFlags = Wheel("LibAuraData").HasAuraUserFlags
local GetUserFlags = Wheel("LibAuraData").GetAllAuraUserFlags

-- Library Databases
local infoFilter = Wheel("LibAuraData"):GetAllAuraInfoBitFilters() -- Aura flags by keywords
local auraInfoFlags = Wheel("LibAuraData"):GetAllAuraInfoFlags() -- Aura info flags

-- Local Databases
local auraUserFlags = {} -- Aura filter flags 
local auraFilters = {} -- Aura filter functions
local colorDB = {} -- Addon color schemes
local fontsDB = { normal = {}, outline = {} } -- Addon fonts

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
colorDB.power.ENERGY_CRYSTAL = Fast -- Rogues, Druids, Monks
colorDB.power.FOCUS_CRYSTAL = Slow -- Hunters Pets (?)
colorDB.power.RAGE_CRYSTAL = Angry -- Druids, Warriors

-- Orb Power Colors
colorDB.power.MANA_ORB = createColor(135/255, 125/255, 255/255) -- Druid, Mage, Monk, Paladin, Priest, Shaman, Warlock

-- Standard Power Colors
colorDB.power.ENERGY = createColor(254/255, 245/255, 145/255) -- Rogues, Druids, Monks
colorDB.power.FOCUS = createColor(125/255, 168/255, 195/255) -- Hunters and Hunter Pets
colorDB.power.MANA = createColor(80/255, 116/255, 255/255) -- Druid, Mage, Paladin, Priest, Shaman, Warlock
colorDB.power.RAGE = createColor(215/255, 7/255, 7/255) -- Druids, Warriors

-- Secondary Resource Colors
colorDB.power.COMBO_POINTS = createColor(255/255, 0/255, 30/255) -- Rogues, Druids
colorDB.power.SOUL_SHARDS = createColor(148/255, 130/255, 201/255) -- Warlock 

-- Fallback for the rare cases where an unknown type is requested.
colorDB.power.UNUSED = createColor(195/255, 202/255, 217/255) 

-- Allow us to use power type index to get the color
-- FrameXML/UnitFrame.lua
colorDB.power[0] = colorDB.power.MANA
colorDB.power[1] = colorDB.power.RAGE
colorDB.power[2] = colorDB.power.FOCUS
colorDB.power[3] = colorDB.power.ENERGY
colorDB.power[7] = colorDB.power.SOUL_SHARDS

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

local playerName = UnitName("player")
local showUnfilteredSpellID = (playerName == "Goldpaw" or playerName == "Lars") and (GetRealmName() == "Dragonfang") and (GetCurrentRegion() == 3)

-- Aura Filter Functions
-----------------------------------------------------------------
auraFilters.default = function(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)

	return true
end

auraFilters.player = function(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)

	local all = element.all

	local hasFlags = not not GetUserFlags(Private)[spellID]
	if (hasFlags) then 
		if (HasUserFlags(Private, spellID, Never)) then 
			return nil, nil, true
		elseif (UnitAffectingCombat("player") and HasUserFlags(Private, spellID, NoCombat)) then 
			if (isBuff and HasUserFlags(Private, spellID, Warn)) then 
				if (timeLeft and (timeLeft > 0) and (timeLeft < 30)) or (duration and (duration > 0) and (duration < 30)) then
					return true, nil, true
				else 
					return nil, nil, true
				end
			else
				return nil, nil, true
			end
		elseif (HasUserFlags(Private, spellID, OnPlayer)) then 
			return true, nil, true
		end
	end 
	if (UnitAffectingCombat("player")) then 
		local timeLeft 
		if (expirationTime and expirationTime > 0) then 
			timeLeft = expirationTime - GetTime()
		end
		if (isBuff) then 
			if (timeLeft and (timeLeft > 0) and (timeLeft < 30)) or (duration and (duration > 0) and (duration < 30)) then
				return true, nil, not showUnfilteredSpellID
			else 
				return nil, nil, not showUnfilteredSpellID
			end
		else 
			if (timeLeft and (timeLeft > 0) and (timeLeft < 601)) then 
				return true, nil, not showUnfilteredSpellID
			else
				return nil, nil, not showUnfilteredSpellID
			end
		end 
	else 
		return true, nil, not showUnfilteredSpellID
	end 
end 

auraFilters.target = function(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)

	local hasFlags = not not GetUserFlags(Private)[spellID]
	if (hasFlags) then 
		if (HasUserFlags(Private, spellID, Never)) then 
			return nil, nil, true
		elseif (UnitAffectingCombat("player") and HasUserFlags(Private, spellID, NoCombat)) then 
			return nil, nil, true
		elseif (HasUserFlags(Private, spellID, OnTarget)) then 
			return true, nil, true
		end
	end 
	return true, nil, not showUnfilteredSpellID
end

auraFilters.nameplate = function(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)

	local hasFlags = not not GetUserFlags(Private)[spellID]
	if (hasFlags) then 
	end
	return true, nil, not showUnfilteredSpellID
end 

auraFilters.targettarget = function(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)
	return auraFilters.target(element, button, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)
end

auraFilters.party = function(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)

	local timeLeft 
	if (expirationTime and expirationTime > 0) then 
		timeLeft = expirationTime - GetTime()
	end
	if (isBuff) then 
		if (timeLeft and (timeLeft > 0) and (timeLeft < 30)) then
			return true, nil, not showUnfilteredSpellID
		else 
			return nil, nil, not showUnfilteredSpellID
		end
	else 
		if (timeLeft and (timeLeft > 0) and (timeLeft < 601)) then 
			return true, nil, not showUnfilteredSpellID
		else
			return nil, nil, not showUnfilteredSpellID
		end
	end 

end

auraFilters.boss = function(element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)
end


-- Add a fallback system
-- *needed in case non-existing unit filters are requested 
local filterFuncs = setmetatable(auraFilters, { __index = function(t,k) return rawget(t,k) or rawget(t, "default") end})

-- Private API
-----------------------------------------------------------------
Private.Colors = colorDB
Private.GetAuraFilterFunc = function(unit) return filterFuncs[unit or "default"] end
Private.GetFont = function(size, outline) return fontsDB[outline and "outline" or "normal"][size] end
Private.GetMedia = function(name, type) return ([[Interface\AddOns\%s\media\%s.%s]]):format(ADDON, name, type or "tga") end

-----------------------------------------------------------------
-- Aura Filter Flag Database
-----------------------------------------------------------------
-- Will update this once we get proper combat log parsing going
local ByPlayer = OnPlayer + OnTarget

-- General Blacklist
------------------------------------------------------------------------
AddFlags(Private, 17670, Never) 	-- Argent Dawn Commission

-- Druid (Balance)
------------------------------------------------------------------------
AddFlags(Private, 22812, OnPlayer) 	-- Barkskin
AddFlags(Private,   339, OnTarget) 	-- Entangling Roots (Rank 1)
AddFlags(Private,  1062, OnTarget) 	-- Entangling Roots (Rank 2)
AddFlags(Private,  5195, OnTarget) 	-- Entangling Roots (Rank 3)
AddFlags(Private,  5196, OnTarget) 	-- Entangling Roots (Rank 4)
AddFlags(Private,  9852, OnTarget) 	-- Entangling Roots (Rank 5)
AddFlags(Private,  9853, OnTarget) 	-- Entangling Roots (Rank 6)
AddFlags(Private,   770, OnTarget) 	-- Faerie Fire (Rank 1)
AddFlags(Private, 18658, OnTarget) 	-- Hibernate (Rank 3)
AddFlags(Private, 16689, OnPlayer) 	-- Nature's Grasp (Rank 1)
AddFlags(Private, 16689, OnPlayer) 	-- Nature's Grasp (Rank 2)
AddFlags(Private, 16689, OnPlayer) 	-- Nature's Grasp (Rank 3)
AddFlags(Private, 16689, OnPlayer) 	-- Nature's Grasp (Rank 4)
AddFlags(Private, 16689, OnPlayer) 	-- Nature's Grasp (Rank 5)
AddFlags(Private, 16689, OnPlayer) 	-- Nature's Grasp (Rank 6)
AddFlags(Private, 16864, OnPlayer + NoCombat + Warn) 	-- Omen of Clarity (Proc)
AddFlags(Private, 16870, OnPlayer + NoCombat + Warn) 	-- Omen of Clarity (Proc)  -- where did this come from?
AddFlags(Private,   467, ByPlayer + NoCombat + Warn) 	-- Thorns (Rank 1)
AddFlags(Private,   782, ByPlayer + NoCombat + Warn) 	-- Thorns (Rank 2)
AddFlags(Private,  1075, ByPlayer + NoCombat + Warn) 	-- Thorns (Rank 3)
AddFlags(Private,  8914, ByPlayer + NoCombat + Warn) 	-- Thorns (Rank 4)
AddFlags(Private,  9756, ByPlayer + NoCombat + Warn) 	-- Thorns (Rank 5)
AddFlags(Private,  9910, ByPlayer + NoCombat + Warn) 	-- Thorns (Rank 6)

AddFlags(Private, 00000, OnTarget) 	-- Faerie Fire (Rank 2)
AddFlags(Private, 00000, OnTarget) 	-- Faerie Fire (Rank 3)
AddFlags(Private, 00000, OnTarget) 	-- Faerie Fire (Rank 4)

AddFlags(Private, 00000, OnTarget) 	-- Moonfire (Rank 1)
AddFlags(Private, 00000, OnTarget) 	-- Moonfire (Rank 1)
AddFlags(Private, 00000, OnTarget) 	-- Moonfire (Rank 3)
AddFlags(Private, 00000, OnTarget) 	-- Moonfire (Rank 4)
AddFlags(Private, 00000, OnTarget) 	-- Moonfire (Rank 5)
AddFlags(Private, 00000, OnTarget) 	-- Moonfire (Rank 6)

AddFlags(Private, 00000, OnTarget) 	-- Hurricane (Rank 1)

-- Druid (Feral)
------------------------------------------------------------------------
AddFlags(Private,  1066, Never) 	-- Aquatic Form
AddFlags(Private,  8983, OnTarget) 	-- Bash
AddFlags(Private,   768, Never) 	-- Cat Form
AddFlags(Private,  5209, OnTarget) 	-- Challenging Roar (Taunt)
AddFlags(Private,  9821, OnPlayer) 	-- Dash
AddFlags(Private,  9634, Never) 	-- Dire Bear Form
AddFlags(Private,  5229, OnPlayer) 	-- Enrage
AddFlags(Private, 16857, ByPlayer) 	-- Faerie Fire (Feral)
AddFlags(Private, 22896, OnPlayer) 	-- Frenzied Regeneration
AddFlags(Private,  6795, OnTarget) 	-- Growl (Taunt)
AddFlags(Private, 24932, Never) 	-- Leader of the Pack
AddFlags(Private,  9007, ByPlayer) 	-- Pounce Bleed (Rank 1)
AddFlags(Private,  9824, ByPlayer) 	-- Pounce Bleed (Rank 2)
AddFlags(Private,  9826, ByPlayer) 	-- Pounce Bleed (Rank 3)
AddFlags(Private,  5215, OnPlayer) 	-- Prowl (Rank 1)
AddFlags(Private,  6783, OnPlayer) 	-- Prowl (Rank 2)
AddFlags(Private,  9913, OnPlayer) 	-- Prowl (Rank 3)
AddFlags(Private,  9904, ByPlayer) 	-- Rake
AddFlags(Private,  9894, ByPlayer) 	-- Rip
AddFlags(Private,  9845, OnPlayer) 	-- Tiger's Fury
AddFlags(Private,   783, Never) 	-- Travel Form

-- Druid (Restoration)
------------------------------------------------------------------------
AddFlags(Private,  2893, ByPlayer) 			-- Abolish Poison
AddFlags(Private, 29166, ByPlayer) 			-- Innervate
AddFlags(Private,  1126, ByPlayer + NoCombat + Warn) 	-- Mark of the Wild (Rank 1)
AddFlags(Private,  5232, ByPlayer + NoCombat + Warn) 	-- Mark of the Wild (Rank 2)
AddFlags(Private,  6756, ByPlayer + NoCombat + Warn) 	-- Mark of the Wild (Rank 3)
AddFlags(Private,  5234, ByPlayer + NoCombat + Warn) 	-- Mark of the Wild (Rank 4)
AddFlags(Private,  8907, ByPlayer + NoCombat + Warn) 	-- Mark of the Wild (Rank 5)
AddFlags(Private,  9884, ByPlayer + NoCombat + Warn) 	-- Mark of the Wild (Rank 6)
AddFlags(Private,  9885, ByPlayer + NoCombat + Warn) 	-- Mark of the Wild (Rank 7)
AddFlags(Private,  8936, ByPlayer) 	-- Regrowth (Rank 1)
AddFlags(Private,  8938, ByPlayer) 	-- Regrowth (Rank 2)
AddFlags(Private,  8939, ByPlayer) 	-- Regrowth (Rank 3)
AddFlags(Private,  8940, ByPlayer) 	-- Regrowth (Rank 4)
AddFlags(Private,  8941, ByPlayer) 	-- Regrowth (Rank 5)
AddFlags(Private,  9750, ByPlayer) 	-- Regrowth (Rank 6)
AddFlags(Private,  9856, ByPlayer) 	-- Regrowth (Rank 7)
AddFlags(Private,  9857, ByPlayer) 	-- Regrowth (Rank 8)
AddFlags(Private,  9858, ByPlayer) 	-- Regrowth (Rank 9)
AddFlags(Private,   774, ByPlayer) 	-- Rejuvenation (Rank 1)
AddFlags(Private,  1058, ByPlayer) 	-- Rejuvenation (Rank 2)
AddFlags(Private,  1430, ByPlayer) 	-- Rejuvenation (Rank 3)
AddFlags(Private,  2090, ByPlayer) 	-- Rejuvenation (Rank 4)
AddFlags(Private,  2091, ByPlayer) 	-- Rejuvenation (Rank 5)
AddFlags(Private,  3627, ByPlayer) 	-- Rejuvenation (Rank 6)
AddFlags(Private,  8910, ByPlayer) 	-- Rejuvenation (Rank 7)
AddFlags(Private,  9839, ByPlayer) 	-- Rejuvenation (Rank 8)
AddFlags(Private,  9840, ByPlayer) 	-- Rejuvenation (Rank 9)
AddFlags(Private,  9841, ByPlayer) 	-- Rejuvenation (Rank 10)
AddFlags(Private,   740, ByPlayer) 	-- Tranquility (Rank 1)
AddFlags(Private,  8918, ByPlayer) 	-- Tranquility (Rank 2)
AddFlags(Private,  9862, ByPlayer) 	-- Tranquility (Rank 3)
AddFlags(Private,  9863, ByPlayer) 	-- Tranquility (Rank 4)

-- Warrior (Arms)
------------------------------------------------------------------------
AddFlags(Private,  7922, OnTarget) 	-- Charge Stun (Rank 1)
AddFlags(Private,   772, OnTarget) 	-- Rend (Rank 1)
AddFlags(Private,  6343, OnTarget) 	-- Thunder Clap (Rank 1)

-- Warrior (Fury)
------------------------------------------------------------------------
AddFlags(Private,  6673, OnPlayer) 	-- Battle Shout (Rank 1)
