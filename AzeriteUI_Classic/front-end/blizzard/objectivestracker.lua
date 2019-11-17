local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local L = Wheel("LibLocale"):GetLocale(ADDON)
local Module = Core:NewModule("BlizzardObjectivesTracker", "LibEvent", "LibFrame")
Module:SetIncompatible("!KalielsTracker")

-- Lua API
local _G = _G
local math_min = math.min
local string_gsub = string.gsub
local string_match = string.match

-- WoW API
local hooksecurefunc = hooksecurefunc
local RegisterAttributeDriver = RegisterAttributeDriver
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local GetNumQuestLogEntries = GetNumQuestLogEntries
local GetNumQuestWatches = GetNumQuestWatches
local GetNumSubgroupMembers = GetNumSubgroupMembers
local GetQuestGreenRange = GetQuestGreenRange
local GetQuestIndexForWatch = GetQuestIndexForWatch
local GetQuestLogLeaderBoard = GetQuestLogLeaderBoard
local GetQuestLogSelection = GetQuestLogSelection
local GetQuestLogTitle = GetQuestLogTitle
local GetScreenHeight = GetScreenHeight
local IsQuestWatched = IsQuestWatched
local IsUnitOnQuest = IsUnitOnQuest

-- Private API
local Colors = Private.Colors
local GetFont = Private.GetFont
local GetLayout = Private.GetLayout

-----------------------------------------------------------------
-- Utility
-----------------------------------------------------------------
-- Returns the correct difficulty color compared to the player
local GetQuestDifficultyColor = function(level, playerLevel)
	level = level - (playerLevel or UnitLevel("player"))
	if (level > 4) then
		return Colors.quest.red
	elseif (level > 2) then
		return Colors.quest.orange
	elseif (level >= -2) then
		return Colors.quest.yellow
	elseif (level >= -GetQuestGreenRange()) then
		return Colors.quest.green
	else
		return Colors.quest.gray
	end
end

-----------------------------------------------------------------
-- Callbacks
-----------------------------------------------------------------
local QuestLogTitleButton_OnEnter = function(self)
	self.Text:SetTextColor(Colors.highlight[1], Colors.highlight[2], Colors.highlight[3])
	_G[self:GetName().."Tag"]:SetTextColor(Colors.highlight[1], Colors.highlight[2], Colors.highlight[3])
end

local QuestLogTitleButton_OnLeave = function(self)
	self.Text:SetTextColor(self.r, self.g, self.b)
	_G[self:GetName().."Tag"]:SetTextColor(self.r, self.g, self.b)
end

local QuestLog_Update = function(self)
	local numEntries, numQuests = GetNumQuestLogEntries()

	local questIndex, questLogTitle, questTitleTag, questNumGroupMates, questNormalText, questHighlight, questCheck
	local questLogTitleText, level, questTag, isHeader, isCollapsed, isComplete, color
	local numPartyMembers, partyMembersOnQuest, tempWidth, textWidth

	for i = 1,QUESTS_DISPLAYED do
		questIndex = i + FauxScrollFrame_GetOffset(QuestLogListScrollFrame)
		questLogTitle = _G["QuestLogTitle"..i]
		questTitleTag = _G["QuestLogTitle"..i.."Tag"]
		questNumGroupMates = _G["QuestLogTitle"..i.."GroupMates"]
		questCheck = _G["QuestLogTitle"..i.."Check"]
		questNormalText = _G["QuestLogTitle"..i.."NormalText"]
		questHighlight = _G["QuestLogTitle"..i.."Highlight"]

		if (questIndex <= numEntries) then
			local questLogTitleText, level, questTag, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isBounty, isStory, isHidden, isScaling = GetQuestLogTitle(questIndex)

			if (not isHeader) then 
				local msg = " "..questLogTitleText
				if (level) then 
					msg = "[" .. level .. "]" .. msg
				end 
				questLogTitle:SetText(msg)

				--Set Dummy text to get text width *SUPER HACK*
				QuestLogDummyText:SetText(msg)

				-- If not a header see if any nearby group mates are on this quest
				partyMembersOnQuest = 0
				for j=1, GetNumSubgroupMembers() do
					if (IsUnitOnQuest(questIndex, "party"..j) ) then
						partyMembersOnQuest = partyMembersOnQuest + 1
					end
				end
				if ( partyMembersOnQuest > 0 ) then
					questNumGroupMates:SetText("["..partyMembersOnQuest.."]")
				else
					questNumGroupMates:SetText("")
				end
			end

			-- Set the quest tag
			if ( isComplete and isComplete < 0 ) then
				questTag = FAILED
			elseif ( isComplete and isComplete > 0 ) then
				questTag = COMPLETE
			end
			if ( questTag ) then
				questTitleTag:SetText("("..questTag..")")
				-- Shrink text to accomdate quest tags without wrapping
				tempWidth = 275 - 15 - questTitleTag:GetWidth()
				
				if ( QuestLogDummyText:GetWidth() > tempWidth ) then
					textWidth = tempWidth
				else
					textWidth = QuestLogDummyText:GetWidth()
				end
				
				questNormalText:SetWidth(tempWidth)
				
				-- If there's quest tag position check accordingly
				questCheck:Hide()
				if ( IsQuestWatched(questIndex) ) then
					if ( questNormalText:GetWidth() + 24 < 275 ) then
						questCheck:SetPoint("LEFT", questLogTitle, "LEFT", textWidth+24, 0)
					else
						questCheck:SetPoint("LEFT", questLogTitle, "LEFT", textWidth+10, 0)
					end
					questCheck:Show()
				end
			else
				questTitleTag:SetText("")
				-- Reset to max text width
				if ( questNormalText:GetWidth() > 275 ) then
					questNormalText:SetWidth(260);
				end

				-- Show check if quest is being watched
				questCheck:Hide()
				if (IsQuestWatched(questIndex)) then
					if (questNormalText:GetWidth() + 24 < 275) then
						questCheck:SetPoint("LEFT", questLogTitle, "LEFT", QuestLogDummyText:GetWidth()+24, 0)
					else
						questCheck:SetPoint("LEFT", questNormalText, "LEFT", questNormalText:GetWidth(), 0)
					end
					questCheck:Show()
				end
			end

			-- Color the quest title and highlight according to the difficulty level
			local playerLevel = UnitLevel("player")
			if ( isHeader ) then
				color = Colors.offwhite
			else
				color = GetQuestDifficultyColor(level, playerLevel)
			end

			local r, g, b = color[1], color[2], color[3]
			if (QuestLogFrame.selectedButtonID and GetQuestLogSelection() == questIndex) then
				r, g, b = Colors.highlight[1], Colors.highlight[2], Colors.highlight[3]
			end

			questLogTitle.r, questLogTitle.g, questLogTitle.b = r, g, b
			questLogTitle:SetNormalFontObject(GetFont(12))
			questTitleTag:SetTextColor(r, g, b)
			questLogTitle.Text:SetTextColor(r, g, b)
			questNumGroupMates:SetTextColor(r, g, b)

		end
	end
end

-----------------------------------------------------------------
-- Styling
-----------------------------------------------------------------
Module.StyleLog = function(self)
	-- Just hook the global functions as far as possible
	hooksecurefunc("QuestLog_Update", QuestLog_Update)
	hooksecurefunc("QuestLogTitleButton_OnEnter", QuestLogTitleButton_OnEnter)
	-- These are defined directly in FrameXML
	local i = 1 
	while (_G["QuestLogTitle"..i]) do 
		_G["QuestLogTitle"..i]:HookScript("OnLeave", QuestLogTitleButton_OnLeave)
		i = i + 1
	end
end

Module.StyleTracker = function(self)
	local layout = self.layout

	local scaffold = self:CreateFrame("Frame", nil, "UICenter")
	scaffold:SetWidth(layout.Width)
	scaffold:SetHeight(22)
	scaffold:Place(unpack(layout.Place))
	
	QuestWatchFrame:SetParent(self.frame)
	QuestWatchFrame:ClearAllPoints()
	QuestWatchFrame:SetPoint("BOTTOMRIGHT", scaffold, "BOTTOMRIGHT")

	-- Create a dummy frame to cover the tracker  
	-- to block mouse input when it's faded out. 
	local mouseKiller = self:CreateFrame("Frame", nil, "UICenter")
	mouseKiller:SetParent(scaffold)
	mouseKiller:SetFrameLevel(QuestWatchFrame:GetFrameLevel() + 5)
	mouseKiller:SetAllPoints()
	mouseKiller:EnableMouse(true)
	mouseKiller:Hide()

	-- Minihack to fix mouseover fading
	self.frame:ClearAllPoints()
	self.frame:SetAllPoints(QuestWatchFrame)
	self.frame.holder = scaffold
	self.frame.cover = mouseKiller

	local top = QuestWatchFrame:GetTop() or 0
	local bottom = QuestWatchFrame:GetBottom() or 0
	local screenHeight = GetScreenHeight()
	local maxHeight = screenHeight - (layout.SpaceBottom + layout.SpaceTop)
	local objectiveFrameHeight = math_min(maxHeight, layout.MaxHeight)

	QuestWatchFrame:SetScale(layout.Scale or 1)
	QuestWatchFrame:SetWidth(layout.Width / (layout.Scale or 1))
	QuestWatchFrame:SetHeight(objectiveFrameHeight / (layout.Scale or 1))
	QuestWatchFrame:SetClampedToScreen(false)
	QuestWatchFrame:SetAlpha(.9)

	local QuestWatchFrame_SetPosition = function(_,_, parent)
		if (parent ~= scaffold) then
			QuestWatchFrame:ClearAllPoints()
			QuestWatchFrame:SetPoint("BOTTOMRIGHT", scaffold, "BOTTOMRIGHT")
		end
	end
	hooksecurefunc(QuestWatchFrame,"SetPoint", QuestWatchFrame_SetPosition)

	local dummyLine = QuestWatchFrame:CreateFontString()
	dummyLine:SetFontObject(layout.FontObject)
	dummyLine:SetWidth(layout.Width)
	dummyLine:SetJustifyH("RIGHT")
	dummyLine:SetJustifyV("BOTTOM") 
	dummyLine:SetIndentedWordWrap(false)
	dummyLine:SetWordWrap(true)
	dummyLine:SetNonSpaceWrap(false)
	dummyLine:SetSpacing(0)

	QuestWatchQuestName:ClearAllPoints()
	QuestWatchQuestName:SetPoint("TOPRIGHT", QuestWatchFrame, "TOPRIGHT", 0, 0)

	-- Hook line styling
	hooksecurefunc("QuestWatch_Update", function() 
		local questIndex
		local numObjectives
		local watchText
		local watchTextIndex = 1
		local objectivesCompleted
		local text, type, finished

		for i = 1, GetNumQuestWatches() do
			questIndex = GetQuestIndexForWatch(i)
			if (questIndex) then
				numObjectives = GetNumQuestLeaderBoards(questIndex)
				if (numObjectives > 0) then

					watchText = _G["QuestWatchLine"..watchTextIndex]
					watchText.isTitle = true

					-- Kill trailing nonsense
					text = watchText:GetText() or ""
					text = string_gsub(text, "%.$", "") 
					text = string_gsub(text, "%?$", "") 
					text = string_gsub(text, "%!$", "") 
					watchText:SetText(text)
					
					-- Align the quest title better
					if (watchTextIndex == 1) then
						watchText:ClearAllPoints()
						watchText:SetPoint("TOPRIGHT", QuestWatchQuestName, "TOPRIGHT", 0, -4)
					else
						watchText:ClearAllPoints()
						watchText:SetPoint("TOPRIGHT", _G["QuestWatchLine"..(watchTextIndex - 1)], "BOTTOMRIGHT", 0, -10)
					end
					watchTextIndex = watchTextIndex + 1

					-- Style the objectives
					objectivesCompleted = 0
					for j = 1, numObjectives do
						text, type, finished = GetQuestLogLeaderBoard(j, questIndex)
						watchText = _G["QuestWatchLine"..watchTextIndex]
						watchText.isTitle = nil

						-- Kill trailing nonsense
						text = string_gsub(text, "%.$", "") 
						text = string_gsub(text, "%?$", "") 
						text = string_gsub(text, "%!$", "") 

						local objectiveText, minCount, maxCount = string_match(text, "(.+): (%d+)/(%d+)")
						if (objectiveText and minCount and maxCount) then 
							minCount = tonumber(minCount)
							maxCount = tonumber(maxCount)
							if (minCount and maxCount) then 
								if (minCount == maxCount) then 
									text = Colors.quest.green.colorCode .. minCount .. "/" .. maxCount .. "|r " .. objectiveText
								elseif (maxCount > 0) and (minCount/maxCount >= 2/3 ) then 
									text = Colors.quest.yellow.colorCode .. minCount .. "/" .. maxCount .. "|r " .. objectiveText
								elseif (maxCount > 0) and (minCount/maxCount >= 1/3 ) then 
									text = Colors.quest.orange.colorCode .. minCount .. "/" .. maxCount .. "|r " .. objectiveText
								else 
									text = Colors.quest.red.colorCode .. minCount .. "/" .. maxCount .. "|r " .. objectiveText
								end 
							end 
						end 
						watchText:SetText(text)

						-- Color the objectives
						if (finished) then
							watchText:SetTextColor(Colors.highlight[1], Colors.highlight[2], Colors.highlight[3])
							objectivesCompleted = objectivesCompleted + 1
						else
							watchText:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
						end

						watchText:ClearAllPoints()
						watchText:SetPoint("TOPRIGHT", "QuestWatchLine"..(watchTextIndex - 1), "BOTTOMRIGHT", 0, -4)

						--watchText:Show()

						watchTextIndex = watchTextIndex + 1
					end

					-- Brighten the quest title if all the quest objectives were met
					watchText = _G["QuestWatchLine"..(watchTextIndex - numObjectives - 1)]
					if ( objectivesCompleted == numObjectives ) then
						watchText:SetTextColor(Colors.title[1], Colors.title[2], Colors.title[3])
					else
						watchText:SetTextColor(Colors.title[1]*.75, Colors.title[2]*.75, Colors.title[3]*.75)
					end

				end 
			end 
		end 

		local top, bottom

		local lineID = 1
		local line = _G["QuestWatchLine"..lineID]
		top = line:GetTop()

		while line do 
			if (line:IsShown()) then 
				line:SetShadowOffset(0,0)
				line:SetShadowColor(0,0,0,0)
				line:SetFontObject(line.isTitle and layout.FontObjectTitle or layout.FontObject)
				local _,size = line:GetFont()
				local spacing = size*.2 - size*.2%1

				line:SetJustifyH("RIGHT")
				line:SetJustifyV("BOTTOM") 
				line:SetIndentedWordWrap(false)
				line:SetWordWrap(true)
				line:SetNonSpaceWrap(false)
				line:SetSpacing(spacing)

				dummyLine:SetFontObject(line:GetFontObject())
				dummyLine:SetText(line:GetText() or "")
				dummyLine:SetSpacing(spacing)

				line:SetWidth(layout.Width)
				line:SetHeight(dummyLine:GetHeight())

				bottom = line:GetBottom()
			end 

			lineID = lineID + 1
			line = _G["QuestWatchLine"..lineID]
		end

		-- Avoid a nil bug that sometimes can happen with no objectives tracked, 
		-- in weird circumstances I have been unable to reproduce. 
		if (top and bottom) then 
			QuestWatchFrame:SetHeight(top - bottom)
		end

	end)
end

-----------------------------------------------------------------
-- Startup
-----------------------------------------------------------------
Module.CreateDriver = function(self)
	local layout = self.layout

	if (layout.HideInCombat or layout.HideInBossFights) then 
		local driverFrame = self:CreateFrame("Frame", nil, _G.UIParent, "SecureHandlerAttributeTemplate")
		driverFrame:HookScript("OnShow", function() 
			if _G.QuestWatchFrame then 
				_G.QuestWatchFrame:SetAlpha(.9)
				self.frame.cover:Hide()
			end
		end)
		driverFrame:HookScript("OnHide", function() 
			if _G.QuestWatchFrame then 
				_G.QuestWatchFrame:SetAlpha(0)
				self.frame.cover:Show()
			end
		end)
		driverFrame:SetAttribute("_onattributechanged", [=[
			if (name == "state-vis") then
				if (value == "show") then 
					if (not self:IsShown()) then 
						self:Show(); 
					end 
				elseif (value == "hide") then 
					if (self:IsShown()) then 
						self:Hide(); 
					end 
				end 
			end
		]=])
		local driver = "hide;show"
		if layout.HideInBossFights then 
			driver = "[@boss1,exists][@boss2,exists][@boss3,exists][@boss4,exists]" .. driver
		end 
		if layout.HideInCombat then 
			driver = "[combat]" .. driver
		end 
		RegisterAttributeDriver(driverFrame, "state-vis", driver)
	end 
end 

Module.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	self.frame = self:CreateFrame("Frame", nil, "UICenter")
	self:StyleLog()
	self:StyleTracker()
end 

Module.OnEnable = function(self)
	self:CreateDriver()
end
