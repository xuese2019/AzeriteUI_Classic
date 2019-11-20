local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("GroupTools", "PLUGIN", "LibEvent", "LibDB", "LibFader", "LibFrame", "LibSound")

-- Lua API
local _G = _G
local rawget = rawget
local setmetatable = setmetatable

-- WoW API
local CanBeRaidTarget = CanBeRaidTarget
local ConvertToParty = ConvertToParty
local ConvertToRaid = ConvertToRaid
local DoReadyCheck = DoReadyCheck
local GetNumGroupMembers = GetNumGroupMembers
local GetNumSubgroupMembers = GetNumSubgroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local GetRaidTargetIndex = GetRaidTargetIndex
local InCombatLockdown = InCombatLockdown
local IsAddOnLoaded = IsAddOnLoaded
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local IsInInstance = IsInInstance
local SetRaidTarget = SetRaidTarget
local UnitIsGroupAssistant = UnitIsGroupAssistant
local UnitIsGroupLeader = UnitIsGroupLeader
local UnitIsDeadOrGhost = UnitIsDeadOrGhost

-- Private API
local GetConfig = Private.GetConfig
local GetLayout = Private.GetLayout

-- WoW Constants
local MAX_PARTY_MEMBERS = MAX_PARTY_MEMBERS
local SOUNDKIT = SOUNDKIT

-- WoW Strings
local CONVERT_TO_PARTY = CONVERT_TO_PARTY
local CONVERT_TO_RAID = CONVERT_TO_RAID
local PARTY_MEMBERS = PARTY_MEMBERS
local RAID_CONTROL = RAID_CONTROL
local RAID_MEMBERS = RAID_MEMBERS
local READY_CHECK = READY_CHECK

-- Uncomment to show tools when solo 
local DEV --= true

-- Secure Snippets
local SECURE = {
	HealerMode_SecureCallback = [=[
		if name then 
			name = string.lower(name); 
		end 
		if (name == "change-enablehealermode") then 
			self:SetAttribute("enableHealerMode", value); 

			local window = self:GetFrameRef("Window"); 
			if window then 
				local anchor = value and self:GetFrameRef("WindowAnchorHealer") or self:GetFrameRef("WindowAnchor"); 
				local point, _, rpoint = anchor:GetPoint(); 
				if (point and anchor and rpoint) then 
					window:ClearAllPoints(); 
					window:SetPoint(point, anchor, rpoint, 0, 0); 
				end
			end

			local button = self:GetFrameRef("ToggleButton"); 
			if button then 
				local anchor = value and self:GetFrameRef("ButtonAnchorHealer") or self:GetFrameRef("ButtonAnchor"); 
				local point, _, rpoint = anchor:GetPoint(); 
				if (point and anchor and rpoint) then 
					button:ClearAllPoints(); 
					button:SetPoint(point, anchor, rpoint, 0, 0); 
				end
			end
		end
	]=]
}

local hasLeaderTools = function()
	local inInstance, instanceType = IsInInstance()
	return DEV or (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") or (IsInGroup() and (not IsInRaid()))) 
		and (instanceType ~= "pvp" and instanceType ~= "arena")
end

local updateButton = function(self)
	if self.down then 
		(self.Msg or self.Bg):SetPoint("CENTER", 0, -1)
	else 
		(self.Msg or self.Bg):SetPoint("CENTER", 0, 0)
	end 
end 

local updateMarker = function(self)
	if (self.down or self.mouseOver) then 
		self.Icon:SetDesaturated(false)
		self.Icon:SetVertexColor(1, 1, 1, 1)
	elseif (UnitExists("target") and CanBeRaidTarget("target") and (GetRaidTargetIndex("target") == self:GetID())) then 
		self.Icon:SetDesaturated(false)
		self.Icon:SetVertexColor(1, 1, 1, .85)
	else 
		self.Icon:SetDesaturated(true)
		self.Icon:SetVertexColor(.6, .6, .6, .85)
	end 
	if self.down then 
		self.Icon:SetPoint("CENTER", 0, -1)
	else 
		self.Icon:SetPoint("CENTER", 0, 0)
	end 
end 

local onButtonDown = function(self)
	self.down = true 
	updateButton(self)
end

local onButtonUp = function(self)
	self.down = false
	updateButton(self)
end

local onButtonEnter = function(self)
	self.mouseOver = true
	updateButton(self)
end

local onButtonLeave = function(self)
	self.mouseOver = false
	updateButton(self)
end

local onRollPollClick = function(self) 
	if hasLeaderTools() then 
		Module:PlaySoundKitID(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "SFX")
		InitiateRolePoll() 
	end 
end

local onReadyCheckClick = function(self) 
	if hasLeaderTools() then 
		Module:PlaySoundKitID(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "SFX")
		DoReadyCheck() 
	end 
end

local onMarkerClick = function(self)
	local id = self:GetID()
	if (UnitExists("target") and CanBeRaidTarget("target")) then
		if (GetRaidTargetIndex("target") == id) then
			Module:PlaySoundKitID(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF, "SFX")
			SetRaidTarget("target", 0)
		else
			Module:PlaySoundKitID(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "SFX")
			SetRaidTarget("target", id)
		end
	end
end

local onMarkerDown = function(self)
	self.down = true 
	updateMarker(self)
end 

local onMarkerUp = function(self)
	self.down = false
	updateMarker(self)
end 

local onMarkerEnter = function(self)
	self.mouseOver = true
	updateMarker(self)
end 

local onMarkerLeave = function(self)
	self.mouseOver = false
	updateMarker(self)
end 

local onConvertClick = function(self) 
	if InCombatLockdown() then 
		return 
	end
	if IsInRaid() then
		if (GetNumGroupMembers() < 6) then
			ConvertToParty()
		end
	else
		ConvertToRaid()
	end
end

Module.UpdateRaidTargets = function(self)
	for id = 1,8 do 
		updateMarker(self.RaidIcons[id])
	end 
end

Module.UpdateCounts = function(self)
	local alive, dead = 0, 0 

	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML  = GetRaidRosterInfo(i)
			if rank then
				if isDead then 
					dead = dead + 1
				else 
					alive = alive + 1
				end 
			end
		end
	else
	
		if UnitIsDeadOrGhost("player") then 
			dead = dead + 1
		else 
			alive = alive + 1
		end 

		for i = 1, GetNumSubgroupMembers() do
			if UnitIsDeadOrGhost("party" .. i) then 
				dead = dead + 1
			else 
				alive = alive + 1
			end 
		end
	end	

	local label = IsInRaid() and RAID_MEMBERS or PARTY_MEMBERS
	if (dead > 0) then
		self.GroupMemberCount:SetFormattedText("%s: |cffffffff%s|r/|cffffffff%s|r", label, alive, alive + dead)
	else
		self.GroupMemberCount:SetFormattedText("%s: |cffffffff%s|r", label, alive)
	end
end

Module.UpdateConvertButton = function(self)
	if IsInRaid() and not self.inRaid then
		self.inRaid = true
		self.ConvertButton.Msg:SetText(CONVERT_TO_PARTY)
	elseif not IsInRaid() and self.inRaid then
		self.inRaid = nil
		self.ConvertButton.Msg:SetText(CONVERT_TO_RAID)
	end
end 

Module.UpdateAvailableButtons = function(self, inLockdown)
	local enableConvert
	if (not inLockdown) then 
		if IsInRaid() then 
			enableConvert = UnitIsGroupLeader("player") and (GetNumGroupMembers() < 6)
		else
			enableConvert = IsInGroup() 
		end 
	end 
	if enableConvert then 
		self.ConvertButton:Enable()
		self.ConvertButton:SetAlpha(.85)
	else
		self.ConvertButton:Disable()
		self.ConvertButton:SetAlpha(.5)
	end 
end

Module.UpdateAll = function(self)
	self:ToggleLeaderTools()
	self:UpdateAvailableButtons(InCombatLockdown())
	self:UpdateCounts()
	self:UpdateRaidTargets()
	self:UpdateConvertButton()
end

Module.ToggleLeaderTools = function(self)
	if InCombatLockdown() then 
		self.queueLeaderToolsToggle = true
		return 
	end 
	if hasLeaderTools() then
		self.ToggleButton:Show()
	else
		self.Window:Hide()
		self.ToggleButton:Hide()
	end
	self.queueLeaderToolsToggle = false
end

Module.CreateLeaderTools = function(self)
	local enableHealerMode = GetConfig(ADDON).enableHealerMode

	-- visibility handler assuring it's hidden when solo
	self.visibility = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	self.visibility:SetAttribute("_onattributechanged", [=[
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
	RegisterAttributeDriver(self.visibility, "state-vis", DEV and "show" or "[group]show;hide")

	-- toggle button
	local toggleButton = self.visibility:CreateFrame("CheckButton", nil, "SecureHandlerClickTemplate")
	toggleButton:SetFrameStrata("DIALOG")
	toggleButton:SetFrameLevel(50)
	toggleButton:SetSize(unpack(self.layout.MenuToggleButtonSize))
	toggleButton:RegisterForClicks("AnyUp")
	toggleButton:SetAttribute("_onclick", [[
		if (button == "LeftButton") then
			local leftclick = self:GetAttribute("leftclick");
			if leftclick then
				self:RunAttribute("leftclick", button);
			end
		elseif (button == "RightButton") then 
			local rightclick = self:GetAttribute("rightclick");
			if rightclick then
				self:RunAttribute("rightclick", button);
			end
		end
		local window = self:GetFrameRef("Window"); 
		if window then 
			if window:IsShown() then 
				window:Hide(); 
			else 
				window:Show(); 
			end 
		end 
	]])

	toggleButton.Icon = toggleButton:CreateTexture()
	toggleButton.Icon:SetTexture(self.layout.MenuToggleButtonIcon)
	toggleButton.Icon:SetSize(unpack(self.layout.MenuToggleButtonIconSize))
	toggleButton.Icon:SetPoint(unpack(self.layout.MenuToggleButtonIconPlace))
	toggleButton.Icon:SetVertexColor(unpack(self.layout.MenuToggleButtonIconColor))
	self.ToggleButton = toggleButton

	-- Group Tools Frame
	local frame = self.visibility:CreateFrame("Frame", nil, "SecureHandlerAttributeTemplate")
	frame:Hide()
	frame:SetSize(unpack(self.layout.MenuSize))
	frame:EnableMouse(true)
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(10)
	self.Window = frame

	toggleButton:HookScript("OnClick", function()
		if frame:IsShown() then 
			Module:PlaySoundKitID(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "SFX") 
		else 
			Module:PlaySoundKitID(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF, "SFX")
		end  
	end)

	local callbackFrame = self:GetSecureUpdater()

	local frameAnchor = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	frameAnchor:SetSize(1,1)
	frameAnchor:Place(unpack(self.layout.MenuPlace))

	local frameAnchorAlternate = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	frameAnchorAlternate:SetSize(1,1)
	frameAnchorAlternate:Place(unpack(self.layout.MenuAlternatePlace)) 

	local buttoAnchor = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	buttoAnchor:SetSize(1,1)
	buttoAnchor:Place(unpack(self.layout.MenuToggleButtonPlace)) 

	local buttoAnchorAlternate = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	buttoAnchorAlternate:SetSize(1,1)
	buttoAnchorAlternate:Place(unpack(self.layout.MenuToggleButtonAlternatePlace)) 

	-- Reference all secure frames
	frame:SetFrameRef("Button", toggleButton)
	toggleButton:SetFrameRef("Window", frame)
	callbackFrame:SetFrameRef("WindowAnchor", frameAnchor)
	callbackFrame:SetFrameRef("WindowAnchorHealer", frameAnchorAlternate)
	callbackFrame:SetFrameRef("ButtonAnchor", buttoAnchor)
	callbackFrame:SetFrameRef("ButtonAnchorHealer", buttoAnchorAlternate)

	-- Attach the module's menu window to the proxy
	callbackFrame:SetFrameRef("Window", self.Window)

	-- Attach the module's menu window toggle button to the proxy
	callbackFrame:SetFrameRef("ToggleButton", self.ToggleButton)

	-- Fake a menu update and hopefully move the thing. 
	-- We need to do this since the frame references didn't exist when the menu did it at startup. 
	callbackFrame:SetAttribute("change-enablehealermode", enableHealerMode)

	frame.Border = self.layout.MenuWindow_CreateBorder(frame)

	local count = frame:CreateFontString()
	count:SetPoint(unpack(self.layout.MemberCountNumberPlace))
	count:SetFontObject(self.layout.MemberCountNumberFont)
	count:SetJustifyH(self.layout.MemberCountNumberJustifyH)
	count:SetJustifyV(self.layout.MemberCountNumberJustifyV)
	count:SetTextColor(unpack(self.layout.MemberCountNumberColor))
	count:SetIndentedWordWrap(false)
	count:SetWordWrap(false)
	count:SetNonSpaceWrap(false)
	self.GroupMemberCount = count

	self.RaidIcons = {}
	for id = 1,8 do 
		local button = frame:CreateFrame("CheckButton")
		button:SetID(id)
		button:SetScript("OnClick", onMarkerClick) 
		button:SetScript("OnMouseDown", onMarkerDown)
		button:SetScript("OnMouseUp", onMarkerUp)
		button:SetScript("OnEnter", onMarkerEnter) 
		button:SetScript("OnLeave", onMarkerLeave)
		button:SetSize(unpack(self.layout.RaidTargetIconsSize))
		button:SetPoint(unpack(self.layout["RaidTargetIcon"..id.."Place"]))

		local icon = button:CreateTexture()
		icon:SetSize(unpack(self.layout.RaidTargetIconsSize))
		icon:SetPoint("CENTER", 0, 0)
		icon:SetTexture(self.layout.RaidRoleRaidTargetTexture)
		SetRaidTargetIconTexture(icon, id)
		button.Icon = icon

		self.RaidIcons[id] = button
	end 

	local button = frame:CreateFrame("Button")
	button:Place(unpack(self.layout.ReadyCheckButtonPlace))
	button:SetSize(unpack(self.layout.ReadyCheckButtonSize))
	button:SetScript("OnClick", onReadyCheckClick)
	button:SetScript("OnMouseDown", onButtonDown)
	button:SetScript("OnMouseUp", onButtonUp)
	button:SetScript("OnEnter", onButtonEnter)
	button:SetScript("OnLeave", onButtonLeave)

	local msg = button:CreateFontString()
	msg:SetPoint("CENTER", 0, 0)
	msg:SetFontObject(self.layout.ReadyCheckButtonTextFont)
	msg:SetTextColor(unpack(self.layout.ReadyCheckButtonTextColor))
	msg:SetShadowOffset(unpack(self.layout.ReadyCheckButtonTextShadowOffset))
	msg:SetShadowColor(unpack(self.layout.ReadyCheckButtonTextShadowColor))
	msg:SetJustifyH("CENTER")
	msg:SetJustifyV("MIDDLE")
	msg:SetIndentedWordWrap(false)
	msg:SetWordWrap(false)
	msg:SetNonSpaceWrap(false)
	msg:SetText(READY_CHECK)
	button.Msg = msg

	local bg = button:CreateTexture()
	bg:SetDrawLayer("ARTWORK")
	bg:SetTexture(self.layout.ReadyCheckButtonTextureNormal)
	bg:SetVertexColor(.9, .9, .9)
	bg:SetSize(unpack(self.layout.ReadyCheckButtonTextureSize))
	bg:SetPoint("CENTER", msg, "CENTER", 0, 0)
	button.Bg = bg
	self.ReadyCheckButton = button

	local button = frame:CreateFrame("CheckButton")
	button:Place(unpack(self.layout.ConvertButtonPlace))
	button:SetSize(unpack(self.layout.ConvertButtonSize))
	button:SetScript("OnClick", onConvertClick)
	button:SetScript("OnMouseDown", onButtonDown)
	button:SetScript("OnMouseUp", onButtonUp)
	button:SetScript("OnEnter", onButtonEnter)
	button:SetScript("OnLeave", onButtonLeave)

	local msg = button:CreateFontString()
	msg:SetPoint("CENTER", 0, 0)
	msg:SetFontObject(self.layout.ConvertButtonTextFont)
	msg:SetTextColor(unpack(self.layout.ConvertButtonTextColor))
	msg:SetShadowOffset(unpack(self.layout.ConvertButtonTextShadowOffset))
	msg:SetShadowColor(unpack(self.layout.ConvertButtonTextShadowColor))
	msg:SetJustifyH("CENTER")
	msg:SetJustifyV("MIDDLE")
	msg:SetIndentedWordWrap(false)
	msg:SetWordWrap(false)
	msg:SetNonSpaceWrap(false)
	msg:SetText(CONVERT_TO_RAID)
	button.Msg = msg

	local bg = button:CreateTexture()
	bg:SetDrawLayer("ARTWORK")
	bg:SetTexture(self.layout.ConvertButtonTextureNormal)
	bg:SetVertexColor(.9, .9, .9)
	bg:SetSize(unpack(self.layout.ConvertButtonTextureSize))
	bg:SetPoint("CENTER", msg, "CENTER", 0, 0)
	button.Bg = bg
	self.ConvertButton = button

	self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnEvent")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_FLAGS_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent")
	self:RegisterEvent("RAID_TARGET_UPDATE", "OnEvent")
	self:RegisterEvent("UNIT_FLAGS", "OnEvent")
	self:UpdateAll()
end

Module.GetSecureUpdater = function(self)
	if (not self.proxyUpdater) then 

		-- Create a secure proxy frame for the menu system. 
		local callbackFrame = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	
		-- Now that attributes have been defined, attach the onattribute script.
		callbackFrame:SetAttribute("_onattributechanged", SECURE.HealerMode_SecureCallback)

		self.proxyUpdater = callbackFrame
	end

	-- Return the proxy updater to the module
	return self.proxyUpdater
end

Module.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		self:ToggleLeaderTools()
		self:UpdateAvailableButtons(InCombatLockdown())
		self:UpdateCounts()
		self:UpdateRaidTargets()
		self:UpdateConvertButton()

	elseif (event == "GROUP_ROSTER_UPDATE") then
		self:ToggleLeaderTools()
		self:UpdateAvailableButtons(InCombatLockdown())
		self:UpdateCounts()
		self:UpdateConvertButton()

	elseif (event == "UNIT_FLAGS") or (event == "PLAYER_FLAGS_CHANGED") then
		self:UpdateCounts()

	elseif (event == "RAID_TARGET_UPDATE") then
		self:UpdateRaidTargets()

	elseif (event == "PLAYER_TARGET_CHANGED") then
		self:UpdateRaidTargets()

	elseif (event == "ADDON_LOADED") then
		if ((...) == "Blizzard_CompactRaidFrames") then
			self:UnregisterEvent("ADDON_LOADED", "OnEvent")
			self:CreateLeaderTools()
		end

	elseif event == "PLAYER_REGEN_DISABLED" then
		self:UpdateAvailableButtons(true)

	elseif event == "PLAYER_REGEN_ENABLED" then
		self:UpdateAvailableButtons(false)
		if self.queueLeaderToolsToggle then 
			self:ToggleLeaderTools()
		end 
	end
end 

Module.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
end 

Module.OnEnable = function(self)
	if IsAddOnLoaded("Blizzard_CompactRaidFrames") then 
		self:CreateLeaderTools()
	else 
		self:RegisterEvent("ADDON_LOADED", "OnEvent")
	end 
end 
