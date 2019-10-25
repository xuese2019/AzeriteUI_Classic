local ADDON, Private = ...

local Core = CogWheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("BlizzardTooltipStyling", "LibEvent", "LibDB", "LibFrame", "LibTooltip", "LibTooltipScanner", "LibPlayerData")
local Layout

Module:SetIncompatible("TipTac")
Module:SetIncompatible("TinyTip")
Module:SetIncompatible("TinyTooltip")

-- Lua API
local _G = _G
local math_floor = math.floor
local math_mod = math.fmod
local string_find = string.find
local string_format = string.format
local table_concat = table.concat
local table_wipe = table.wipe
local type = type
local unpack = unpack

-- WoW API
local GetItemInfo = GetItemInfo
local GetQuestGreenRange = GetQuestGreenRange
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitLevel = UnitLevel

-- Private API
local Colors = Private.Colors
local GetFont = Private.GetFont
local GetMedia = Private.GetMedia

-- Blizzard textures we use 
local BOSS_TEXTURE = "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:14:14:-2:1|t" -- 1:1
local FFA_TEXTURE = "|TInterface\\TargetingFrame\\UI-PVP-FFA:14:10:-2:1:64:64:6:34:0:40|t" -- 4:3
local FACTION_ALLIANCE_TEXTURE = "|TInterface\\TargetingFrame\\UI-PVP-Alliance:14:10:-2:1:64:64:6:34:0:40|t" -- 4:3
local FACTION_NEUTRAL_TEXTURE = "|TInterface\\TargetingFrame\\UI-PVP-Neutral:14:10:-2:1:64:64:6:34:0:40|t" -- 4:3
local FACTION_HORDE_TEXTURE = "|TInterface\\TargetingFrame\\UI-PVP-Horde:14:14:-4:0:64:64:0:40:0:40|t" -- 1:1

-- Lockdowns
local LOCKDOWNS = {}

-- Returns the correct difficulty color compared to the player.
-- Using this as a tooltip method to access our custom colors.
local GetDifficultyColorByLevel = function(level)
	local colors = Colors.quest

	level = level - UnitLevel("player") -- LEVEL
	if (level > 4) then
		return colors.red[1], colors.red[2], colors.red[3], colors.red.colorCode
	elseif (level > 2) then
		return colors.orange[1], colors.orange[2], colors.orange[3], colors.orange.colorCode
	elseif (level >= -2) then
		return colors.yellow[1], colors.yellow[2], colors.yellow[3], colors.yellow.colorCode
	elseif (level >= -GetQuestGreenRange()) then
		return colors.green[1], colors.green[2], colors.green[3], colors.green.colorCode
	else
		return colors.gray[1], colors.gray[2], colors.gray[3], colors.gray.colorCode
	end
end

-- Update the color of the tooltip's current unit
-- Returns the r, g, b value
local GetUnitHealthColor = function(unit, data)
	local r, g, b
	if data then 
		if (data.isPet and data.petRarity) then 
			r, g, b = unpack(Colors.quality[data.petRarity - 1])
		else
			if ((not UnitPlayerControlled(unit)) and UnitIsTapDenied(unit)) then
				r, g, b = unpack(Colors.tapped)
			elseif (not UnitIsConnected(unit)) then
				r, g, b = unpack(Colors.disconnected)
			elseif (UnitIsDeadOrGhost(unit)) then
				r, g, b = unpack(Colors.dead)
			elseif (UnitIsPlayer(unit)) then
				local _, class = UnitClass(unit)
				if class then 
					r, g, b = unpack(Colors.class[class])
				else 
					r, g, b = unpack(Colors.disconnected)
				end 
			elseif (UnitReaction(unit, "player")) then
				r, g, b = unpack(Colors.reaction[UnitReaction(unit, "player")])
			else
				r, g, b = 1, 1, 1
			end
		end 
	else 
		if ((not UnitPlayerControlled(unit)) and UnitIsTapDenied(unit)) then
			r, g, b = unpack(Colors.tapped)
		elseif (not UnitIsConnected(unit)) then
			r, g, b = unpack(Colors.disconnected)
		elseif (UnitIsDeadOrGhost(unit)) then
			r, g, b = unpack(Colors.dead)
		elseif (UnitIsPlayer(unit)) then
			local _, class = UnitClass(unit)
			if class then 
				r, g, b = unpack(Colors.class[class])
			else 
				r, g, b = unpack(Colors.disconnected)
			end 
		elseif (UnitReaction(unit, "player")) then
			r, g, b = unpack(Colors.reaction[UnitReaction(unit, "player")])
		else
			r, g, b = 1, 1, 1
		end
	end 
	return r,g,b
end 

local GetTooltipUnit = function(tooltip)
	local _, unit = tooltip:GetUnit()
	if (not unit) and UnitExists("mouseover") then
		unit = "mouseover"
	end
	if unit and UnitIsUnit(unit, "mouseover") then
		unit = "mouseover"
	end
	return UnitExists(unit) and unit
end

-- Bar post updates
-- Show health values for tooltip health bars, and hide others.
-- Will expand on this later to tailer all tooltips to our needs.  
local StatusBar_UpdateValue = function(bar, value, max)

	local unit = bar:GetParent().unit
	if (unit) then 
		if not(UnitIsUnit(unit, "player") or UnitIsUnit(unit, "pet") or UnitInParty(unit) or UnitInRaid(unit)) then 
			local healthCur = Module:UnitHealth(unit)
			local healthMax = Module:UnitHealthMax(unit)
			if (healthCur and healthMax) then 
				value, max = healthCur, healthMax
			else
				value, max = nil, nil
			end 
		end
	end

	if value then 
		if (value >= 1e8) then 			bar.value:SetFormattedText("%.0fm", value/1e6) 		-- 100m, 1000m, 2300m, etc
		elseif (value >= 1e6) then 		bar.value:SetFormattedText("%.1fm", value/1e6) 		-- 1.0m - 99.9m 
		elseif (value >= 1e5) then 		bar.value:SetFormattedText("%.0fk", value/1e3) 		-- 100k - 999k
		elseif (value >= 1e3) then 		bar.value:SetFormattedText("%.1fk", value/1e3) 		-- 1.0k - 99.9k
		elseif (value > 0) then 		bar.value:SetText(tostring(math_floor(value))) 		-- 1 - 999
		else 							bar.value:SetText(DEAD)
		end 
		if (not bar.value:IsShown()) then 
			bar.value:Show()
		end
	else 
		if (bar.value:IsShown()) then 
			bar.value:Hide()
			bar.value:SetText("")
		end
	end 
end 

local StatusBar_OnValueChanged = function(statusbar)
	local value = statusbar:GetValue()
	local min, max = statusbar:GetMinMaxValues()
	
	-- Hide the bar if values are missing, or if max or min is 0. 
	if (not min) or (not max) or (not value) or (max == 0) or (value == min) then
		statusbar:Hide()
		return
	end
	
	-- Just in case somebody messed up, 
	-- we silently correct out of range values.
	if value > max then
		value = max
	elseif value < min then
		value = min
	end
	
	if statusbar.value then
		StatusBar_UpdateValue(statusbar, value, max)
	end

	-- Because blizzard shrink the textures instead of cropping them.
	statusbar:GetStatusBarTexture():SetTexCoord(0, (value-min)/(max-min), 0, 1)

	-- Add the green if no other color was detected. Like objects that aren't units, but still have health. 
	if (not statusbar.color) or (not statusbar:GetParent().unit) then
		local colors = statusbar:GetParent().colors or Layout.Colors
		if colors then 
			statusbar.color = colors.quest.green
		end 
	end

	-- The color needs to be updated, or it will pop back to green
	statusbar:SetStatusBarColor(unpack(statusbar.color))
end

local StatusBar_OnShow = function(statusbar)
	if (not statusbar._owner) or (not GetTooltipUnit(statusbar._owner)) then 
		statusbar:Hide()
		return
	end
	Module:SetBlizzardTooltipBackdropOffsets(statusbar._owner, 10, 10, 10, 18)
	StatusBar_OnValueChanged(statusbar)
end

-- Do a color and texture reset upon hiding, to make sure it looks right when next shown. 
local StatusBar_OnHide = function(statusbar)
	local colors = statusbar:GetParent().colors or Layout.Colors
	if colors then 
		statusbar.color = colors.quest.green
	end 
	statusbar:GetStatusBarTexture():SetTexCoord(0, 1, 0, 1)
	statusbar:SetStatusBarColor(unpack(statusbar.color))
	Module:SetBlizzardTooltipBackdropOffsets(statusbar._owner, 10, 10, 10, 12)
end

local OnTooltipShow = function(tooltip)

	-- Set the tooltip to the same scale as our own. 
	local targetScale = Module:GetFrame("UICenter"):GetEffectiveScale()
	local tooltipParentScale = (tooltip:GetParent() or WorldFrame):GetEffectiveScale()
	tooltip:SetScale(targetScale/tooltipParentScale)

	local lineIndex = 1
	repeat 
		local left = _G[tooltip:GetName().."TextLeft"..lineIndex]
		local right = _G[tooltip:GetName().."TextRight"..lineIndex]
		if (left) then 
			local oldLeftObject = left:GetFontObject()
			local oldRightObject = right:GetFontObject()
			local leftObject = (lineIndex == 1) and GetFont(15, true) or GetFont(13, true)
			local rightObject = (lineIndex == 1) and GetFont(15, true) or GetFont(13, true)
			if (leftObject ~= oldLeftObject) then 
				left:SetFontObject(leftObject)
			end
			if (rightObject ~= oldRightObject) then 
				right:SetFontObject(rightObject)
			end
			--if (lineIndex > 1) then 
			--	left:SetPoint("TOPLEFT", _G[tooltip:GetName().."TextLeft"..(lineIndex-1)], "BOTTOMLEFT", 0, -4)
			--end 
			lineIndex = lineIndex + 1
		else
			lineIndex = nil
		end
	until (not lineIndex)
end

local OnTooltipAddLine = function(tooltip, msg)
	if not(LOCKDOWNS[tooltip]) then
		return OnTooltipShow(tooltip)
	end 
	for i = 2, tooltip:NumLines() do
		local line = _G[tooltip:GetName().."TextLeft"..i]
		if line then
			local text = line:GetText()
			if (text == msg) then
				line:SetText("")
				return
			end 
		end
	end
end

local OnTooltipAddDoubleLine = function(tooltip, leftText, rightText)
	if not(LOCKDOWNS[tooltip]) then
		return OnTooltipShow(tooltip)
	end 
	for i = 2, tooltip:NumLines() do
		local left = _G[tooltip:GetName().."TextLeft"..i]
		local right = _G[tooltip:GetName().."TextRight"..i]
		if (left) then
			local leftMsg = left:GetText()
			local rightMsg = right:GetText()
			if (leftMsg == leftText) or (rightMsg == rightText) then
				left:SetText("")
				right:SetText("")
				return
			end 
		end
	end
end

local AddLine = function(tooltip, lineIndex, msg, r, g, b)
	r = r or Colors.offwhite[1]
	g = g or Colors.offwhite[2]
	b = b or Colors.offwhite[3]
	local numLines = tooltip:NumLines()
	if (lineIndex > numLines) then 
		tooltip:AddLine(msg, r, g, b)
	else
		local left = _G[tooltip:GetName().."TextLeft"..lineIndex]
		left:SetText(msg)
		if (r and g and b) then 
			left:SetTextColor(r, g, b)
		end
	end
	return lineIndex + 1
end

local OnTooltipHide = function(tooltip)
	tooltip.unit = nil
	LOCKDOWNS[tooltip] = nil
	if (tooltip:IsForbidden()) then 
		return
	end
end

local formatMoney = function(money)
	local gold = math_floor(money / (COPPER_PER_SILVER * SILVER_PER_GOLD))
	local silver = math_floor((money - (gold * COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER)
	local copper = math_mod(money, COPPER_PER_SILVER)
	
	--local goldIcon = [[|TInterface\MoneyFrame\UI-GoldIcon:16:16:0:0|t]]
	--local silverIcon = [[|TInterface\MoneyFrame\UI-SilverIcon:16:16:0:0|t]]
	--local copperIcon = [[|TInterface\MoneyFrame\UI-CopperIcon:16:16:0:0|t]]

	local goldIcon = string_format([[|T%s:16:16:0:0:64:64:%d:%d:%d:%d|t]], GetMedia("coins"), 0,32,0,32)
	local silverIcon = string_format([[|T%s:16:16:0:0:64:64:%d:%d:%d:%d|t]], GetMedia("coins"), 32,64,0,32)
	local copperIcon = string_format([[|T%s:16:16:0:0:64:64:%d:%d:%d:%d|t]], GetMedia("coins"), 0,32,32,64)

	local moneyString
	if (gold > 0) then 
		moneyString = string_format("%d%s", gold, goldIcon)
	end
	if (silver > 0) then 
		moneyString = (moneyString and moneyString.." " or "") .. string_format("%d%s", silver, silverIcon)
	end
	if (copper > 0) then 
		moneyString = (moneyString and moneyString.." " or "") .. string_format("%d%s", copper, copperIcon)
	end 

	return moneyString
end

local OnTooltipSetItem = function(tooltip)
	if (tooltip:IsForbidden()) then 
		return
	end

	local frame = GetMouseFocus()
	if (frame and frame.GetName and not frame:IsForbidden()) then
		local name = frame:GetName()
		if (not MerchantFrame:IsShown()) or (name and (string_find(name, "Character") or string_find(name, "TradeSkill"))) then
			local _,link = tooltip:GetItem()
			if (link) then
				local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
				itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
				isCraftingReagent = GetItemInfo(link)
				if (itemSellPrice and (itemSellPrice > 0)) then
					LOCKDOWNS[tooltip] = nil

					tooltip:AddLine(" ")
					tooltip:AddDoubleLine(string_format("%s:", SELL_PRICE), formatMoney((itemStackCount or 1) * itemSellPrice), Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])

					-- Not doing this yet. But we will. Oh yes we will. 
					--LOCKDOWNS[tooltip] = true
				end
			end
		end
	end
end

local OnTooltipSetUnit = function(tooltip)
	if (tooltip:IsForbidden()) then 
		return
	end

	local unit = GetTooltipUnit(tooltip)
	if (not unit) then
		tooltip:Hide()
		OnTooltipHide(tooltip)
		return
	end

	local data = Module:GetTooltipDataForUnit(unit)
	if (not data) then
		tooltip:Hide()
		OnTooltipHide(tooltip)
		return
	end

	LOCKDOWNS[tooltip] = nil
	tooltip.unit = unit
	local numLines = tooltip:NumLines()
	local lineIndex = 1
	for i = numLines,1,-1 do 
		local left = _G[tooltip:GetName().."TextLeft"..i]
		local right = _G[tooltip:GetName().."TextRight"..i]
		if (left) then
			left:SetText("")
		end
		if (right) then
			right:SetText("")
		end
	end

	-- name 
	local displayName = data.name
	if data.isPlayer then 
		if (data.showPvPFactionWithName) then 
			if data.isFFA then
				displayName = FFA_TEXTURE .. " " .. displayName
			elseif (data.isPVP and data.englishFaction) then
				if (data.englishFaction == "Horde") then
					displayName = FACTION_HORDE_TEXTURE .. " " .. displayName
				elseif (data.englishFaction == "Alliance") then
					displayName = FACTION_ALLIANCE_TEXTURE .. " " .. displayName
				elseif (data.englishFaction == "Neutral") then
					-- They changed this to their new atlas garbage in Legion, 
					-- so for the sake of simplicty we'll just use the FFA PvP icon instead. Works.
					displayName = FFA_TEXTURE .. " " .. displayName
				end
			end
		end
	else 
		if data.isBoss then
			displayName = BOSS_TEXTURE .. " " .. displayName
		end
	end

	local levelText
	if (data.effectiveLevel and (data.effectiveLevel > 0)) then 
		local r, g, b, colorCode = GetDifficultyColorByLevel(data.effectiveLevel)
		levelText = colorCode .. data.effectiveLevel .. "|r"
	end 

	local r, g, b = GetUnitHealthColor(unit,data)
	if levelText then 
		lineIndex = AddLine(tooltip, lineIndex, levelText .. Colors.quest.gray.colorCode .. ": |r" .. displayName, r, g, b)
	else
		lineIndex = AddLine(tooltip, lineIndex, displayName, r, g, b)
	end 

	-- Players
	if data.isPlayer then 
		if data.guild then 
			lineIndex = AddLine(tooltip, lineIndex, "<"..data.guild..">", Colors.title[1], Colors.title[2], Colors.title[3])
		end 

		local levelLine

		if data.raceDisplayName then 
			levelLine = (levelLine and levelLine.." " or "") .. data.raceDisplayName
		end 

		if (data.classDisplayName and data.class) then 
			levelLine = (levelLine and levelLine.." " or "") .. data.classDisplayName
		end 

		if levelLine then 
			lineIndex = AddLine(tooltip, lineIndex, levelLine, Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
		end 

		-- player faction (Horde/Alliance/Neutral)
		if data.localizedFaction then 
			lineIndex = AddLine(tooltip, lineIndex, data.localizedFaction)
		end 

	-- Battle Pets
	elseif data.isPet then 

	-- All other NPCs
	else  
	-- titles
		if data.title then 
			lineIndex = AddLine(tooltip, lineIndex, "<"..data.title..">", Colors.normal[1], Colors.normal[2], Colors.normal[3])
		end 

		if data.city then 
			lineIndex = AddLine(tooltip, lineIndex, data.city, Colors.title[1], Colors.title[2], Colors.title[3])
		end 

		-- Beast etc 
		if data.creatureFamily then 
			lineIndex = AddLine(tooltip, lineIndex, data.creatureFamily, Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])

		-- Humanoid, Crab, etc 
		elseif data.creatureType then 
			lineIndex = AddLine(tooltip, lineIndex, data.creatureType, Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
		end 

		-- player faction (Horde/Alliance/Neutral)
		if data.localizedFaction then 
			lineIndex = AddLine(tooltip, lineIndex, data.localizedFaction)
		end 
	end 

	tooltip:Show()
	LOCKDOWNS[tooltip] = true

	local bar = _G[tooltip:GetName().."StatusBar"]
	bar.color = { r, g, b }
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 3, -1)
	bar:SetPoint("TOPRIGHT", tooltip, "BOTTOMRIGHT", -3, -1)
	bar:SetStatusBarColor(r, g, b)
end

Module.OnInit = function(self)
	Layout = CogWheel("LibDB"):GetDatabase(Core:GetPrefix()..":[TooltipStyling]")
end 

Module.OnEnable = function(self)
	for tooltip in self:GetAllBlizzardTooltips() do 
		self:KillBlizzardBorderedFrameTextures(tooltip)
		self:KillBlizzardTooltipBackdrop(tooltip)
		self:SetBlizzardTooltipBackdrop(tooltip, Layout.TooltipBackdrop)
		self:SetBlizzardTooltipBackdropColor(tooltip, unpack(Layout.TooltipBackdropColor))
		self:SetBlizzardTooltipBackdropBorderColor(tooltip, unpack(Layout.TooltipBackdropBorderColor))
		self:SetBlizzardTooltipBackdropOffsets(tooltip, 10, 10, 10, 12)

		if tooltip.SetText then 
			hooksecurefunc(tooltip, "SetText", OnTooltipAddLine)
		end

		if tooltip.AddLine then 
			hooksecurefunc(tooltip, "AddLine", OnTooltipAddLine)
		end 

		if tooltip.AddDoubleLine then 
			hooksecurefunc(tooltip, "AddDoubleLine", OnTooltipAddDoubleLine)
		end 

		if tooltip:HasScript("OnTooltipSetUnit") then 
			tooltip:HookScript("OnTooltipSetUnit", OnTooltipSetUnit)
		end

		if tooltip:HasScript("OnTooltipSetItem") then 
			tooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
		end

		if tooltip:HasScript("OnHide") then 
			tooltip:HookScript("OnHide", OnTooltipHide)
		end
		
		if tooltip:HasScript("OnShow") then 
			tooltip:HookScript("OnShow", OnTooltipShow)
		end

		local bar = _G[tooltip:GetName().."StatusBar"]
		if bar then 
			bar:ClearAllPoints()
			bar:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 3, -1)
			bar:SetPoint("TOPRIGHT", tooltip, "BOTTOMRIGHT", -3, -1)
			bar:SetHeight(3)
			bar._owner = tooltip

			bar.value = bar:CreateFontString()
			bar.value:SetDrawLayer("OVERLAY")
			bar.value:SetFontObject(Game13Font_o1)
			bar.value:SetPoint("CENTER", 0, 0)
			bar.value:SetTextColor(235/255, 235/255, 235/255, .75)

			bar:HookScript("OnShow", StatusBar_OnShow)
			bar:HookScript("OnHide", StatusBar_OnHide)
			bar:HookScript("OnValueChanged", StatusBar_OnValueChanged)
		end 
	end 
end 
