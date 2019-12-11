local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("BlizzardPopupStyling", "LibEvent")

-- WoW API
local InCombatLockdown = _G.InCombatLockdown

-- Private API
local GetLayout = Private.GetLayout

Module.StylePopUp = function(self, popup)
	if (self.styled and self.styled[popup]) then 
		return 
	end 
	if (not self.styled) then
		self.styled = {}
	end
	self.layout.PostCreatePopup(self, popup)
	self.styled[popup] = true
end

Module.StylePopUps = function(self)
	for i = 1, STATICPOPUP_NUMDIALOGS do
		local popup = _G["StaticPopup"..i]
		if popup then
			self:StylePopUp(popup)
		end
	end
end

Module.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	self:StylePopUps() 
end 
