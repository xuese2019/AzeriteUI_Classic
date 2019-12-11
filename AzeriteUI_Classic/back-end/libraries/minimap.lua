local Version = 44
local LibMinimap = Wheel:Set("LibMinimap", Version)
if (not LibMinimap) then
	return
end

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibMinimap requires LibClientBuild to be loaded.")

local LibMessage = Wheel("LibMessage")
assert(LibMessage, "LibMinimap requires LibMessage to be loaded.")

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibMinimap requires LibEvent to be loaded.")

local LibFrame = Wheel("LibFrame")
assert(LibFrame, "LibMinimap requires LibFrame to be loaded.")

local LibSound = Wheel("LibSound")
assert(LibSound, "LibMinimap requires LibSound to be loaded.")

local LibTooltip = Wheel("LibTooltip")
assert(LibTooltip, "LibMinimap requires LibTooltip to be loaded.")

local LibHook = Wheel("LibHook")
assert(LibHook, "LibMinimap requires LibHook to be loaded.")

-- Embed library functionality into this
LibEvent:Embed(LibMinimap)
LibMessage:Embed(LibMinimap)
LibFrame:Embed(LibMinimap)
LibSound:Embed(LibMinimap)
LibTooltip:Embed(LibMinimap)
LibHook:Embed(LibMinimap)
LibClientBuild:Embed(LibMinimap)

-- Lua API
local debugstack = debugstack
local math_sqrt = math.sqrt
local pairs = pairs
local string_join = string.join
local string_match = string.match
local table_insert = table.insert
local table_remove = table.remove
local type = type
local unpack = unpack

-- WoW API
local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local GetCVar = GetCVar
local GetPlayerFacing = GetPlayerFacing
local ToggleDropDownMenu = ToggleDropDownMenu

-- WoW Objects
local WorldFrame = WorldFrame

-- Library registries
LibMinimap.embeds = LibMinimap.embeds or {} -- modules embedding this library
LibMinimap.private = LibMinimap.private or {} -- private registry of various frames and elements
LibMinimap.callbacks = LibMinimap.callbacks or {} -- events registered by the elements

-- Do we even use these? Copy&Paste gone wrong?
LibMinimap.embedMethods = LibMinimap.embedMethods or {} -- embedded module methods added by elements or modules
LibMinimap.embedMethodVersions = LibMinimap.embedMethodVersions or {} -- version registry for added module methods

-- Element handling. Transition to LibWidgetContainer soon?
LibMinimap.elements = LibMinimap.elements or {} -- registered module element templates
LibMinimap.elementPool = LibMinimap.elementPool or {} -- pool of element instances
LibMinimap.elementPoolEnabled = LibMinimap.elementPoolEnabled or {} -- per module registry of element having been enabled
LibMinimap.elementProxy = LibMinimap.elementProxy or {} -- event handler for a module's registered elements

-- The minimap button bag
LibMinimap.buttonBag = LibMinimap.buttonBag or LibFrame:CreateFrame("Frame", nil, LibFrame:CreateFrame("Frame")) -- two layers to make sure it's gone
LibMinimap.buttonBag:Hide() -- icons aren't hidden without this /doh

LibMinimap.baggedButtonsChecked = LibMinimap.baggedButtonsChecked or {} -- buttons already checked
LibMinimap.baggedButtonsHidden = LibMinimap.baggedButtonsHidden or {} -- buttons we have hidden
LibMinimap.baggedButtonsIgnored = LibMinimap.baggedButtonsIgnored or {} -- buttons we're ignoring
LibMinimap.minimapBlipScale = LibMinimap.minimapBlipScale or 1 -- current minimap blip scale
LibMinimap.minimapFrameScale = LibMinimap.minimapFrameScale or 1 -- current minimap scale
LibMinimap.minimapScale = nil
LibMinimap.numBaggedButtons = LibMinimap.numBaggedButtons or 0 -- current count of hidden buttons

-- Button bag icon list imported from GUI4's last updated list from Feb 1st 2018.
-- Not really sure about these, might change to hiding all.
do
	-- Should we hide these too maybe? Just enslave them to our upcoming system?
	LibMinimap.baggedButtonsIgnored["MBB_MinimapButtonFrame"] = true
	LibMinimap.baggedButtonsIgnored["MinimapButtonFrame"] = true
	LibMinimap.baggedButtonsIgnored["MiniMapBattlefieldFrame"] = true
	--LibMinimap.baggedButtonsIgnored["QueueStatusMinimapButton"] = true
	
	LibMinimap.baggedButtonsIgnored["BookOfTracksFrame"] = true
	LibMinimap.baggedButtonsIgnored["CartographerNotesPOI"] = true
	LibMinimap.baggedButtonsIgnored["DA_Minimap"] = true
	--LibMinimap.baggedButtonsIgnored["FishingExtravaganzaMini"] = true
	LibMinimap.baggedButtonsIgnored["FWGMinimapPOI"] = true
	LibMinimap.baggedButtonsIgnored["GatherArchNote"] = true
	LibMinimap.baggedButtonsIgnored["GatherMatePin"] = true
	LibMinimap.baggedButtonsIgnored["GatherNote"] = true
	LibMinimap.baggedButtonsIgnored["HandyNotesPin"] = true
	--LibMinimap.baggedButtonsIgnored["MiniMapPing"] = true
	LibMinimap.baggedButtonsIgnored["MiniNotePOI"] = true
	LibMinimap.baggedButtonsIgnored["poiMinimap"] = true
	LibMinimap.baggedButtonsIgnored["QuestPointerPOI"] = true
	LibMinimap.baggedButtonsIgnored["RecipeRadarMinimapIcon"] = true
	LibMinimap.baggedButtonsIgnored["TDial_TrackButton"] = true
	LibMinimap.baggedButtonsIgnored["TDial_TrackingIcon"] = true
	LibMinimap.baggedButtonsIgnored["ZGVMarker"] = true
end

-- Do not define this on creation, only retrieve it from older library versions.
-- The existence of this indicates an initialized map.
LibMinimap.minimap = LibMinimap.minimap

-- We parent our update frame to the WorldFrame,
-- as we need it to run even if the user has hidden the UI.
LibMinimap.frame = LibMinimap.frame or LibFrame:CreateFrame("Frame", nil, WorldFrame)

-- Just some magic to retrieve pure methods later on
-- We're not using an existing frame for this because we want it
-- to be completely pure and impossible for modules to tamper with
local meta = { __index = CreateFrame("Frame") }
local getMetaMethod = function(method) return meta.__index[method] end

local cog_meta = { __index = LibMinimap.frame }
local getLibMethod = function(method) return cog_meta.__index[method] end

-- Speed shortcuts
local Library = LibMinimap.private -- renaming our shortcut to indicate that it's meant to be a library only thing
local Callbacks = LibMinimap.callbacks
local Elements = LibMinimap.elements
local ElementPool = LibMinimap.elementPool
local ElementPoolEnabled = LibMinimap.elementPoolEnabled
local ElementProxy = LibMinimap.elementProxy
local Frame = LibMinimap.frame

-- No Operation
local noop = function() end

-- Utility Functions
---------------------------------------------------------
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

-- Element Template
---------------------------------------------------------
local ElementHandler = LibMinimap:CreateFrame("Frame")
local ElementHandler_MT = { __index = ElementHandler }

-- Methods we don't wish to expose to the modules
--------------------------------------------------------------------------
local IsEventRegistered = ElementHandler_MT.__index.IsEventRegistered
local RegisterEvent = ElementHandler_MT.__index.RegisterEvent
local RegisterUnitEvent = ElementHandler_MT.__index.RegisterUnitEvent
local UnregisterEvent = ElementHandler_MT.__index.UnregisterEvent
local UnregisterAllEvents = ElementHandler_MT.__index.UnregisterAllEvents

local IsMessageRegistered = LibMinimap.IsMessageRegistered
local RegisterMessage = LibMinimap.RegisterMessage
local UnregisterMessage = LibMinimap.UnregisterMessage
local UnregisterAllMessages = LibMinimap.UnregisterAllMessages

local OnElementEvent = function(proxy, event, ...)
	if (Callbacks[proxy] and Callbacks[proxy][event]) then
		local events = Callbacks[proxy][event]
		for i = 1, #events do
			-- Note: this has created a nil error once!
			events[i](proxy, event, ...)
		end
	end
end

local OnElementUpdate = function(proxy, elapsed)
	for func,data in pairs(proxy.updates) do
		data.elapsed = data.elapsed + elapsed
		if (data.elapsed > (data.hz or .2)) then
			func(proxy, data.elapsed)
			data.elapsed = 0
		end
	end
end

ElementHandler.RegisterUpdate = function(proxy, func, throttle)
	if (not proxy.updates) then
		proxy.updates = {}
	end
	if (proxy.updates[func]) then
		return
	end
	proxy.updates[func] = { hz = throttle, elapsed = throttle } -- set elapsed to throttle to trigger an instant initial update
	if (not proxy:GetScript("OnUpdate")) then
		proxy:SetScript("OnUpdate", OnElementUpdate)
	end
end

ElementHandler.UnregisterUpdate = function(proxy, func)
	if (not proxy.updates) or (not proxy.updates[func]) then
		return
	end
	proxy.updates[func] = nil
	local stillHasUpdates
	for func in pairs(self.updates) do
		stillHasUpdates = true
		break
	end
	if (not stillHasUpdates) then
		proxy:SetScript("OnUpdate", nil)
	end
end

ElementHandler.RegisterEvent = function(proxy, event, func)
	if (not Callbacks[proxy]) then
		Callbacks[proxy] = {}
	end
	if (not Callbacks[proxy][event]) then
		Callbacks[proxy][event] = {}
	end
	
	local events = Callbacks[proxy][event]
	if (#events > 0) then
		for i = #events, 1, -1 do
			if (events[i] == func) then
				return
			end
		end
	end

	table_insert(events, func)

	if (not IsEventRegistered(proxy, event)) then
		RegisterEvent(proxy, event)
	end
end

ElementHandler.RegisterMessage = function(proxy, event, func)
	if (not Callbacks[proxy]) then
		Callbacks[proxy] = {}
	end
	if (not Callbacks[proxy][event]) then
		Callbacks[proxy][event] = {}
	end
	
	local events = Callbacks[proxy][event]
	if (#events > 0) then
		for i = #events, 1, -1 do
			if (events[i] == func) then
				return
			end
		end
	end

	table_insert(events, func)

	if (not IsMessageRegistered(proxy, event)) then
		RegisterMessage(proxy, event)
	end
end

ElementHandler.UnregisterEvent = function(proxy, event, func)
	-- silently fail if the event isn't even registered
	if not Callbacks[proxy] or not Callbacks[proxy][event] then
		return
	end

	local events = Callbacks[proxy][event]

	if #events > 0 then
		-- find the function's id
		for i = #events, 1, -1 do
			if events[i] == func then
				table_remove(events, i)
				--events[i] = nil -- remove the function from the event's registry
				if #events == 0 then
					UnregisterEvent(proxy, event)
				end
			end
		end
	end
end

ElementHandler.UnregisterMessage = function(proxy, event, func)
	-- silently fail if the event isn't even registered
	if not Callbacks[proxy] or not Callbacks[proxy][event] then
		return
	end

	local events = Callbacks[proxy][event]

	if #events > 0 then
		-- find the function's id
		for i = #events, 1, -1 do
			if events[i] == func then
				table_remove(events, i)
				--events[i] = nil -- remove the function from the event's registry
				if #events == 0 then
					UnregisterMessage(proxy, event)
				end
			end
		end
	end
end

ElementHandler.UnregisterAllEvents = function(proxy)
	if not Callbacks[proxy] then
		return
	end
	for event, funcs in pairs(Callbacks[proxy]) do
		for i = #funcs, 1, -1 do
			table_remove(funcs, i)
			--funcs[i] = nil
		end
	end
	UnregisterAllEvents(proxy)
end

ElementHandler.UnregisterAllMessages = function(proxy)
	if not Callbacks[proxy] then
		return
	end
	for event, funcs in pairs(Callbacks[proxy]) do
		for i = #funcs, 1, -1 do
			table_remove(funcs, i)
			--funcs[i] = nil
		end
	end
	UnregisterAllMessages(proxy)
end

ElementHandler.CreateOverlayFrame = function(proxy, frameType)
	check(frameType, 1, "string", "nil")
	return LibMinimap:SyncMinimap(true) and Library.MapOverlay:CreateFrame(frameType or "Frame")
end

ElementHandler.CreateOverlayText = function(proxy)
	return LibMinimap:SyncMinimap(true) and Library.MapOverlay:CreateFontString()
end

ElementHandler.CreateOverlayTexture = function(proxy)
	return LibMinimap:SyncMinimap(true) and Library.MapOverlay:CreateTexture()
end

ElementHandler.CreateBorderFrame = function(proxy, frameType)
	check(frameType, 1, "string", "nil")
	return LibMinimap:SyncMinimap(true) and Library.MapBorder:CreateFrame(frameType or "Frame")
end

ElementHandler.CreateContentFrame = function(proxy, frameType)
	check(frameType, 1, "string", "nil")
	return LibMinimap:SyncMinimap(true) and Library.MapContent:CreateFrame(frameType or "Frame")
end

ElementHandler.CreateBorderText = function(proxy)
	return LibMinimap:SyncMinimap(true) and Library.MapBorder:CreateFontString()
end

ElementHandler.CreateBorderTexture = function(proxy)
	return LibMinimap:SyncMinimap(true) and Library.MapBorder:CreateTexture()
end

ElementHandler.CreateContentTexture = function(proxy)
	return LibMinimap:SyncMinimap(true) and Library.MapContent:CreateTexture()
end

ElementHandler.CreateBackdropTexture = function(proxy)
	return LibMinimap:SyncMinimap(true) and Library.MapVisibility:CreateTexture()
end

-- Return or create the library default tooltip
ElementHandler.GetTooltip = function(proxy)
	return LibMinimap:GetTooltip("GP_MinimapTooltip") or LibMinimap:CreateTooltip("GP_MinimapTooltip")
end

ElementHandler.EnableAllElements = function(proxy)
	local self = proxy._owner
	for elementName in pairs(Elements) do
		self:EnableMinimapElement(elementName)
	end
end

-- Public API
---------------------------------------------------------
-- Create or fetch our minimap. Only one can exist, this is a WoW limitation.
LibMinimap.SyncMinimap = function(self, onlyQuery)

	-- Careful not to use 'self' here,
	-- as the minimap key only exists in the library,
	-- not in the modules that embed it.
	if LibMinimap.minimap then

		-- Only return it if it's made by a compatible library version,
		-- otherwise reset it to our current standard.
		local minimapHolder, mapVersion = unpack(LibMinimap.minimap)
		if (mapVersion >= Version) then
			return minimapHolder
		end
	end

	-- Error if this is a query, and the mapversion is too old or not initialized yet
	if (onlyQuery) then
		local name = string_match(debugstack(2, 2, 0), ": in function [`<](.-)['>]")
		if (not LibMinimap.minimap) then
			error(("LibMinimap: '%s' failed, map not initialized. Did you forget to call 'SyncMinimap()' first?"):format(name),3)
		else
			error(("LibMinimap: '%s' failed, map version too old. Did you forget to call 'SyncMinimap()' first?"):format(name),3)
		end
	end

	-- Create Custom Scaffolding
	-----------------------------------------------------------
	-- Create missing custom frames

	-- Direct parent to the minimap, needed to avoid size callbacks from Blizzard.
	Library.MapParent = Library.MapParent or LibMinimap:CreateFrame("Frame")
	Library.MapParent:SetFrameStrata("LOW")
	Library.MapParent:SetFrameLevel(0)

	-- Custom visibility layer hooked into the minimap visibility.
	Library.MapVisibility = Library.MapVisibility or Library.MapParent:CreateFrame("Frame")
	Library.MapVisibility:SetFrameStrata("LOW")
	Library.MapVisibility:SetFrameLevel(0)
	Library.MapVisibility:SetScript("OnHide", function() LibMinimap:SendMessage("GP_MINIMAP_VISIBILITY_CHANGED", false) end)
	Library.MapVisibility:SetScript("OnShow", function() LibMinimap:SendMessage("GP_MINIMAP_VISIBILITY_CHANGED", true) end)

	-- Holder frame deciding the position and size of the minimap.
	Library.MapHolder = Library.MapHolder or Library.MapVisibility:CreateFrame("Frame")
	Library.MapHolder:SetFrameStrata("LOW")
	Library.MapHolder:SetFrameLevel(2)
	Library.MapVisibility:SetAllPoints(Library.MapHolder)

	-- Map border meant to place elements in.
	Library.MapBorder = Library.MapBorder or Library.MapVisibility:CreateFrame()
	Library.MapBorder:SetAllPoints(Library.MapHolder)
	Library.MapBorder:SetFrameLevel(10)

	-- Info frame for elements that should always be visible
	Library.MapInfo = Library.MapInfo or LibMinimap:CreateFrame("Frame")
	Library.MapInfo:SetAllPoints() -- This will by default fill the entire master frame
	Library.MapInfo:SetFrameStrata("LOW")
	Library.MapInfo:SetFrameLevel(20)

	-- Overlay frame for temporary elements
	Library.MapOverlay = Library.MapOverlay or Library.MapVisibility:CreateFrame("Frame")
	Library.MapOverlay:SetAllPoints() -- This will by default fill the entire master frame
	Library.MapOverlay:SetFrameStrata("MEDIUM")
	Library.MapOverlay:SetFrameLevel(50)
	

	-- Configure Blizzard Elements
	-----------------------------------------------------------
	-- Update links to original Blizzard Objects
	Library.OldBackdrop = MinimapBackdrop
	Library.OldCluster = MinimapCluster
	Library.OldMinimap = Minimap

	-- Insane Semantics
	-- Mainly just doing this double upvalue
	-- to have a simple and readable way to separate between
	-- code that removes old functionality and code that adds new.
	Library.MapContent = Library.OldMinimap

	-- Reposition the MinimapBackdrop to our frame structure
	Library.OldBackdrop:SetMovable(true)
	Library.OldBackdrop:SetUserPlaced(true)
	Library.OldBackdrop:ClearAllPoints()
	Library.OldBackdrop:SetPoint("CENTER", -8, -23)
	Library.OldBackdrop:SetParent(Library.MapHolder)

	-- The global function GetMaxUIPanelsWidth() calculates the available space for
	-- blizzard windows such as the character frame, pvp frame etc based on the
	-- position of the MinimapCluster.
	-- Unless the MinimapCluster is set to movable and user placed, it will be assumed
	-- that it's still in its default position, and the end result will be.... bad.
	Library.OldCluster:SetMovable(true)
	Library.OldCluster:SetUserPlaced(true)
	Library.OldCluster:ClearAllPoints()
	Library.OldCluster:EnableMouse(false)
	Library.OldCluster:SetAllPoints(Library.MapHolder)

	-- Parent the actual minimap to our dummy,
	-- and let the user decide minimap visibility
	-- by hooking our own regions' visibility to it.
	-- This way minimap visibility keybinds will still function.
	Library.OldMinimap:SetParent(Library.MapParent)
	Library.OldMinimap:ClearAllPoints()
	Library.OldMinimap:SetPoint("CENTER", Library.MapHolder, "CENTER", 0, 0)
	Library.OldMinimap:SetFrameStrata("LOW")
	Library.OldMinimap:SetFrameLevel(2)
	Library.OldMinimap:SetScale(1)

	-- Hook minimap visibility changes
	-- Use a unique hook identifier to prevent multiple library instances
	-- from registering multiple hooks. We only need one.
	LibMinimap:SetHook(Library.OldMinimap, "OnHide", function() Library.MapVisibility:Hide() end, "GP_MINIMAP_HIDE")
	LibMinimap:SetHook(Library.OldMinimap, "OnShow", function() Library.MapVisibility:Show() end, "GP_MINIMAP_SHOW")

	-- keep these two disabled
	-- or the map will change position
	Library.OldMinimap:SetResizable(true)
	Library.OldMinimap:SetMovable(false)
	Library.OldMinimap:SetUserPlaced(false)

	-- Just remove most of the old map functionality for now
	-- Will re-route or re-add stuff later if incompatibilities arise.
	Library.OldMinimap.SetParent = noop
	Library.OldMinimap.SetFrameLevel = noop
	Library.OldMinimap.ClearAllPoints = noop
	Library.OldMinimap.SetAllPoints = noop
	Library.OldMinimap.SetPoint = noop
	Library.OldMinimap.SetFrameStrata = noop
	Library.OldMinimap.SetResizable = noop
	Library.OldMinimap.SetMovable = noop
	Library.OldMinimap.SetUserPlaced = noop
	Library.OldMinimap.SetSize = noop
	Library.OldMinimap.SetScale = noop

	-- Proxy methods on the actual minimap
	-- that returns information about the custom map holder
	-- which these attributes are slaved to.
	for methodName in pairs({
		GetSize = true,
		GetPoint = true,
		GetHeight = true,
		GetWidth = true,
		GetFrameLevel = true,
		GetFrameStrata = true,
		GetScale = true
	}) do
		local func = getMetaMethod(methodName)
		Library.MapContent[methodName] = function(_, ...)
			return func(Library.MapHolder, ...)
		end
	end

	-- Proxy methods on our custom map holder
	-- that sends back information about the actual map.
	for methodName in pairs({
		IsShown = true,
		IsVisible = true
	}) do
		local func = getMetaMethod(methodName)
		Library.MapHolder[methodName] = function(_, ...)
			return func(Library.MapHolder, ...)
		end
	end

	Library.MapHolder.Place = function(self, ...)
		getLibMethod("Place")(self, ...)
		getMetaMethod("ClearAllPoints")(Library.MapContent)
		getMetaMethod("SetPoint")(Library.MapContent, "CENTER", self, "CENTER", 0, 0)
	end

	-- Methods that should do the exact same thing
	-- whether they are called from the custom map holder or the actual map.
	for methodName in pairs({
		SetSize = true -- probably the only one we need
	}) do
		local func = getMetaMethod(methodName)
		local method = function(_, ...)
			func(Library.MapContent, ...)
			func(Library.MapHolder, ...)
		end
		Library.MapHolder[methodName] = method
		Library.MapContent[methodName] = method
	end 	

	-- Should I move this to its own API call?	
	Library.MapContent:EnableMouseWheel(true)

	Library.MapContent:SetScript("OnMouseWheel", function(self, delta)
		if (delta > 0) then
			MinimapZoomIn:Click()
		elseif (delta < 0) then
			MinimapZoomOut:Click()
		end
	end)

	Library.MapContent:SetScript("OnMouseUp", function(self, button)
		if (button == "RightButton") then
			--ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, self)
			--LibMinimap:PlaySoundKitID(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "SFX")
		else
			local effectiveScale = self:GetEffectiveScale()
	
			local x, y = GetCursorPosition()
			x = x / effectiveScale
			y = y / effectiveScale
	
			local cx, cy = self:GetCenter()
			x = x - cx
			y = y - cy
	
			if (math_sqrt(x * x + y * y) < (self:GetWidth() / 2)) then
				self:PingLocation(x, y)
			end
		end
	end)
	
	-- Configure Custom Elements
	-----------------------------------------------------------
	-- Register our Minimap as a keyword with the Engine,
	-- to capture other module's attempt to anchor to it.
	LibMinimap:RegisterKeyword("Minimap", function() return Library.MapContent end)

	-- Store the minimap reference and library version that initialized it
	LibMinimap.minimap = LibMinimap.minimap or {}
	LibMinimap.minimap[1] = Library.MapHolder
	LibMinimap.minimap[2] = Version

	local w,h = Minimap:GetSize()
	local x,y = Minimap:GetCenter()
	if (not x or not y) then

		-- Set the scaffold size and position to the default blizz values
		Library.MapHolder:SetSize(140, 140)
		Library.MapHolder:Place("TOPRIGHT", UIParent, "TOPRIGHT", -61 -22)

		-- The following elements rely on but aren't slave to the holder size,
		-- and thus we need to manually update them after any size changes.
		LibMinimap:UpdateCompass()
		LibMinimap:UpdateScale()
	end

	return true
end

LibMinimap.SetMinimapSize = function(self, ...)
	self:SyncMinimap(true)

	-- Set the scaffold size
	Library.MapHolder:SetSize(...)

	-- The following elements rely on but aren't slave to the holder size,
	-- and thus we need to manually update them after any size changes.
	LibMinimap:UpdateCompass()
	LibMinimap:UpdateScale()
end

LibMinimap.UpdateScale = function(self)
	-- Retrieve the current minimap blip scale
	local blipScale = LibMinimap.minimapBlipScale or 1

	-- Retrieve the scaffold size
	local width, height = Library.MapHolder:GetSize()

	-- Scale and size the minimap content accordingly.
	local SetScale = getMetaMethod("SetScale")
	local SetSize = getMetaMethod("SetSize")

	SetScale(Library.MapContent, blipScale)
	SetSize(Library.MapContent, width/blipScale, height/blipScale)
end

LibMinimap.SetMinimapBlipScale = function(self, blipScale)
	check(blipScale, 1, "number", "nil")

	self:SyncMinimap(true)

	LibMinimap.minimapBlipScale = blipScale or LibMinimap.minimapBlipScale or 1
	LibMinimap:UpdateScale()
end

-- This isn't semantically intelligent,
-- but we're doing this for backwards compatibility,
-- since this method was used to changed the blip scale originally.
LibMinimap.SetMinimapScale = LibMinimap.SetMinimapBlipScale

LibMinimap.SetMinimapPosition = function(self, ...)
	return self:SyncMinimap(true) and Library.MapHolder:Place(...)
end

LibMinimap.SetMinimapBlips = function(self, path, patchMin, patchMax)
	check(path, 1, "string")
	check(patchMin, 2, "string")
	check(patchMax, 3, "string", "nil")

	local build = LibMinimap:GetBuild()
	local buildMin = LibMinimap:GetBuildForPatch(patchMin)
	local buildMax = LibMinimap:GetBuildForPatch(patchMax or patchMin)

	-- Only apply the blips if the match the given client interval
	if (buildMin and buildMax) and (build >= buildMin) and (build <= buildMax) then
		return self:SyncMinimap(true) and Library.MapContent:SetBlipTexture(path)
	end
end

LibMinimap.SetMinimapMaskTexture = function(self, path)
	check(path, 1, "string")
	return self:SyncMinimap(true) and Library.MapContent:SetMaskTexture(path)
end

-- Return or create the library default tooltip
LibMinimap.GetMinimapTooltip = function(self)
	return self:GetTooltip("GP_MinimapTooltip") or self:CreateTooltip("GP_MinimapTooltip")
end

LibMinimap.RemoveButton = function(self, button)

	if self.baggedButtonsHidden[button] then
		return
	end

	-- Increase the button counter
	self.numBaggedButtons = self.numBaggedButtons + 1

	-- Store the button's original data
	self.baggedButtonsHidden[button] = {
		parent = getMetaMethod("GetParent")(button),
		position = { getMetaMethod("GetPoint")(button) },
		size = { getMetaMethod("GetSize")(button) }
	}

	-- Grab it!
	getMetaMethod("SetParent")(button, self.buttonBag)
	getMetaMethod("SetSize")(button, 24,24)
	getMetaMethod("ClearAllPoints")(button)
	getMetaMethod("SetPoint")(button, "CENTER", 0, 0)

	-- Kill off the Blizzard API
	button.ClearAllPoints = noop
	button.SetPoint = noop
end

LibMinimap.RestoreButton = function(self, button)
	local data = self.baggedButtonsHidden[button]
	if (not data) then
		return
	end

	-- Decrease the button counter
	self.numBaggedButtons = self.numBaggedButtons - 1

	-- Release the button
	-- and return it to its original position
	getMetaMethod("SetParent")(button, data.parent)
	getMetaMethod("SetSize")(button, unpack(data.size))
	getMetaMethod("ClearAllPoints")(button)
	getMetaMethod("SetPoint")(button, unpack(data.position))

	-- Restore original meta methods.
	button.ClearAllPoints = nil
	button.SetPoint = nil

	-- Delete the entry
	self.baggedButtonsHidden[button] = nil

end

LibMinimap.ParseButton = function(self, button)
	if button and not(self.baggedButtonsChecked[button]) and (button.HasScript and button:HasScript("OnClick")) then

		local name = button.GetName and button:GetName()
		if (not name) or (not self.baggedButtonsIgnored[name]) then
			self:RemoveButton(button)
		end

		-- We've checked this, never do it again!
		self.baggedButtonsChecked[button] = true
	end
end

LibMinimap.OnUpdate = function(_, elapsed)

	-- Yes, we're doing this
	local self = LibMinimap

	self.shortTimer = (self.shortTimer or 0) - elapsed
	if (self.shortTimer <= 0) then
		if (self.enableCompass and self.rotateMinimap) then
			self:UpdateCompass()
		end
		self.shortTimer = 1/60
	end

	self.longTimer = (self.longTimer or 0) - elapsed
	if (self.longTimer <= 0) then
		if (not self.allowMinimapButtons) then
			local numMinimapChildren = Minimap:GetNumChildren()
			if (self.numMinimapChildren ~= numMinimapChildren) then
				for i = 1, numMinimapChildren do
					self:ParseButton((select(i, Minimap:GetChildren())))
				end
				self.numMinimapChildren = numMinimapChildren
			end

			local numMinimapBackdropChildren = MinimapBackdrop:GetNumChildren()
			if (self.numMinimapBackdropChildren ~= numMinimapBackdropChildren) then
				for i = 1, numMinimapBackdropChildren do
					self:ParseButton((select(i, MinimapBackdrop:GetChildren())))
				end
				self.numMinimapBackdropChildren = numMinimapBackdropChildren
			end
		end

		-- Don't really need to check for this very often
		-- It's not a problem that the user see the buttons disappear
		if (self.enableLongTimerCount) then
			self.longTimer = 5
		else
			-- Add a little system to check frequently for the first 5 seconds,
			-- then activate the throttled system to save resources.
			self.longTimer = .1
			if (not self.longTimerCount) then
				self.longTimerCount = 1
			else
				self.longTimerCount = self.longTimerCount + 1
			end
			if (self.longTimerCount > 50) then
				self.enableLongTimerCount = true
				self.longTimerCount = nil
			end
		end
	end
end

LibMinimap.EvaluateNeedForOnUpdate = function(self)
	if (self.allowMinimapButtons or (self.enableCompass and self.rotateMinimap)) then
		if (not Frame:GetScript("OnUpdate")) then
			Frame:SetScript("OnUpdate", self.OnUpdate)
		end
	else
		if (Frame:GetScript("OnUpdate")) then
			Frame:SetScript("OnUpdate", nil)
		end
	end
end

LibMinimap.UpdateMinimapButtonBag = function(self)

	-- Restore any hidden buttons
	if self.allowMinimapButtons then
		for button in pairs(self.baggedButtonsHidden) do
			self:RestoreButton(button)
		end
	end
	
end

LibMinimap.UpdateCompass = function()

	local compassFrame = LibMinimap:GetCompassFrame()
	if (not compassFrame) then
		return
	end

	local radius = LibMinimap.compassRadius
	if (not radius) then
		local width = compassFrame:GetWidth()
		if (not width) then
			return
		end
		radius = width/2
	end

	local inset = LibMinimap.compassRadiusInset
	if inset then
		radius = radius - inset
	end

	local playerFacing = GetPlayerFacing()
	if (not playerFacing or (compassFrame.supressCompass)) then
		compassFrame:SetAlpha(0)
	else
		compassFrame:SetAlpha(1)
	end

	local angle = (LibMinimap.rotateMinimap and playerFacing) and -playerFacing or 0

	compassFrame.east:SetPoint("CENTER", radius*math.cos(angle), radius*math.sin(angle))
	compassFrame.north:SetPoint("CENTER", radius*math.cos(angle + math.pi/2), radius*math.sin(angle + math.pi/2))
	compassFrame.west:SetPoint("CENTER", radius*math.cos(angle + math.pi), radius*math.sin(angle + math.pi))
	compassFrame.south:SetPoint("CENTER", radius*math.cos(angle + math.pi*3/2), radius*math.sin(angle + math.pi*3/2))
end

LibMinimap.CreateCompassFrame = function(self)
	if (not LibMinimap.compassFrame) then
		local compassFrame = LibMinimap:SyncMinimap(true) and Library.MapOverlay:CreateFrame("Frame")
		compassFrame:Hide()
		compassFrame:SetAllPoints()

		local north = compassFrame:CreateFontString()
		north:SetDrawLayer("ARTWORK", 1)
		north:SetFontObject(Game13Font_o1)
		north:SetShadowOffset(0,0)
		north:SetShadowColor(0,0,0,0)
		north:SetText("N")
		compassFrame.north = north

		local east = compassFrame:CreateFontString()
		east:SetDrawLayer("ARTWORK", 1)
		east:SetFontObject(Game13Font_o1)
		east:SetShadowOffset(0,0)
		east:SetShadowColor(0,0,0,0)
		east:SetText("E")
		compassFrame.east = east

		local south = compassFrame:CreateFontString()
		south:SetDrawLayer("ARTWORK", 1)
		south:SetFontObject(Game13Font_o1)
		south:SetShadowOffset(0,0)
		south:SetShadowColor(0,0,0,0)
		south:SetText("S")
		compassFrame.south = south

		local west = compassFrame:CreateFontString()
		west:SetDrawLayer("ARTWORK", 1)
		west:SetFontObject(Game13Font_o1)
		west:SetShadowOffset(0,0)
		west:SetShadowColor(0,0,0,0)
		west:SetText("W")
		compassFrame.west = west

		LibMinimap.compassFrame = compassFrame
	end
	return LibMinimap.compassFrame
end

LibMinimap.GetCompassFrame = function(self)
	return LibMinimap.compassFrame
end

LibMinimap.SetMinimapCompassRadius = function(self, radius)
	check(radius, 1, "number", "nil")
	LibMinimap.compassRadius = radius
	LibMinimap:UpdateCompass()
end

LibMinimap.SetMinimapCompassRadiusInset = function(self, inset)
	check(inset, 1, "number", "nil")
	LibMinimap.compassRadiusInset = inset
	LibMinimap:UpdateCompass()
end

LibMinimap.SetMinimapCompassText = function(self, north, east, south, west)
	check(north, 1, "string", "nil")
	check(east, 2, "string", "nil")
	check(south, 3, "string", "nil")
	check(west, 4, "string", "nil")

	local compassFrame = LibMinimap:GetCompassFrame() or LibMinimap:CreateCompassFrame()
	compassFrame.north:SetText(north or "")
	compassFrame.east:SetText(east or "")
	compassFrame.south:SetText(south or "")
	compassFrame.west:SetText(west or "")
end

LibMinimap.SetMinimapCompassTextColor = function(self, r, g, b, a)
	check(r, 1, "number")
	check(g, 2, "number")
	check(b, 3, "number")
	check(a, 4, "number", "nil")

	local compassFrame = LibMinimap:GetCompassFrame() or LibMinimap:CreateCompassFrame()
	compassFrame.north:SetTextColor(r, g, b, a or 1)
	compassFrame.east:SetTextColor(r, g, b, a or 1)
	compassFrame.south:SetTextColor(r, g, b, a or 1)
	compassFrame.west:SetTextColor(r, g, b, a or 1)
end

LibMinimap.SetMinimapCompassTextFontObject = function(self, fontObject)
	check(fontObject, 1, "table")

	local compassFrame = LibMinimap:GetCompassFrame() or LibMinimap:CreateCompassFrame()
	compassFrame.north:SetFontObject(fontObject)
	compassFrame.east:SetFontObject(fontObject)
	compassFrame.south:SetFontObject(fontObject)
	compassFrame.west:SetFontObject(fontObject)
end

LibMinimap.SetMinimapCompassEnabled = function(self, enableCompass)
	check(enableCompass, 1, "boolean", "nil")

	-- Store the setting locally
	LibMinimap.enableCompass = enableCompass

	if enableCompass then
		-- Hide blizzard textires
		MinimapCompassTexture:SetAlpha(0)
		MinimapNorthTag:SetAlpha(0)

		-- Get or create our compass frame
		local compassFrame = LibMinimap:GetCompassFrame() or LibMinimap:CreateCompassFrame()
		compassFrame:Show()
		
		-- Get the current rotation setting and store it locally
		LibMinimap.rotateMinimap = GetCVar("rotateMinimap") == "1"

		-- Rotate it properly
		LibMinimap:UpdateCompass()

		-- Watch out for changes to the rotation setting
		LibMinimap:RegisterEvent("CVAR_UPDATE", "OnEvent")
	else

		-- Hide our frame if it exists
		local compassFrame = LibMinimap:GetCompassFrame()
		if compassFrame then
			compassFrame:Hide()
		end

		-- Show the blizzard textures again
		MinimapCompassTexture:SetAlpha(1)
		MinimapNorthTag:SetAlpha(1)

		-- Remove the event
		if LibMinimap:IsEventRegistered("CVAR_UPDATE", "OnEvent") then
			LibMinimap:UnregisterEvent("CVAR_UPDATE", "OnEvent")
		end
	end

	-- Evaulate the need for an update handler
	LibMinimap:EvaluateNeedForOnUpdate()

end

LibMinimap.SetMinimapAllowAddonButtons = function(self, allow)
	check(allow, 1, "boolean", "nil")

	LibMinimap.allowMinimapButtons = allow

	-- Update the button bag, restore buttons if needed
	LibMinimap:UpdateMinimapButtonBag()

	-- Evaulate the need for an update handler
	LibMinimap:EvaluateNeedForOnUpdate()
end

LibMinimap.OnEvent = function(self, event, ...)
	if (event == "CVAR_UPDATE") then

		-- Store the setting locally
		self.rotateMinimap = GetCVar("rotateMinimap") == "1"

		-- Evaulate the need for an update handler
		self:EvaluateNeedForOnUpdate()

		-- Update the compass
		self:UpdateCompass()
	end
end

-- Element Updates
---------------------------------------------------------
LibMinimap.GetMinimapHandler = function(self)
	if (not ElementProxy[self]) then
		-- create a new instance of the element
		-- note that we're using the same template for all elements
		local proxy = setmetatable(LibMinimap:CreateFrame("Frame"), ElementHandler_MT)
		proxy:SetAllPoints(Library.MapContent)
		proxy._owner = self

		-- activate the event handler
		proxy:SetScript("OnEvent", OnElementEvent)

		-- store the proxy
		ElementProxy[self] = proxy
	end
	return ElementProxy[self]
end

LibMinimap.EnableMinimapElement = function(self, name)
	check(name, 1, "string")

	if (not ElementPool[self]) then
		ElementPool[self] = {}
		ElementPoolEnabled[self] = {}
	end

	-- avoid duplicates
	local found
	for i = 1, #ElementPool[self] do
		if (ElementPool[self][i] == name) then
			found = true
			break
		end
	end

	if (not found) then
		-- insert it into the module's element list
		table_insert(ElementPool[self], name)
	end

	-- enable the element instance
	if Elements[name].Enable(self:GetMinimapHandler()) then
		ElementPoolEnabled[self][name] = true
	end
end

LibMinimap.DisableMinimapElement = function(self, name)
	if ((not ElementPoolEnabled[self]) or (not ElementPoolEnabled[self][name])) then
		return
	end
	Elements[name].Disable(self:GetMinimapHandler())
	for i = #ElementPool[self], 1, -1 do
		if (ElementPool[self][i] == name) then
			table_remove(ElementPool[self], i)
			--ElementPool[self][i] = nil
		end
	end
	ElementPoolEnabled[self][name] = nil
end

LibMinimap.UpdateAllMinimapElements = function(self)
	if (ElementPool[self]) then
		for element in pairs(ElementPoolEnabled[self]) do
			Elements[element].Update(ElementProxy[self], "Forced")
		end
	end
end

-- register a element/element
LibMinimap.RegisterElement = function(self, elementName, enableFunc, disableFunc, updateFunc, version)
	check(elementName, 1, "string")
	check(enableFunc, 2, "function")
	check(disableFunc, 3, "function")
	check(updateFunc, 4, "function")
	check(version, 5, "number", "nil")
	
	-- Does an old version of the element exist?
	local old = Elements[elementName]
	local needUpdate
	if old then
		if old.version then
			if version then
				if version <= old.version then
					return
				end
				-- A more recent version is being registered
				needUpdate = true
			else
				return
			end
		else
			if version then
				-- A more recent version is being registered
				needUpdate = true
			else
				-- Two unversioned. just follow first come first served,
				-- to allow the standalone addon to trumph.
				return
			end
		end
		return
	end

	-- Create our new element
	local new = {
		Enable = enableFunc,
		Disable = disableFunc,
		Update = updateFunc,
		version = version
	}

	-- Change the pointer to the new element
	Elements[elementName] = new

	-- Postupdate existing frames embedding this if it exists
	if needUpdate then
		-- iterate all frames for it
		for module, element in pairs(ElementPoolEnabled) do
			if (element == elementName) then
				-- Run the old disable method,
				-- to get rid of old events and onupdate handlers
				if old.Disable then
					old.Disable(module)
				end

				-- Run the new enable method
				if new.Enable then
					new.Enable(module, "Update", true)
				end
			end
		end
	end
end

-- Module embedding
local embedMethods = {
	EnableMinimapElement = true,
	DisableMinimapElement = true,
	GetMinimapTooltip = true,
	SetMinimapAllowAddonButtons = true,
	SetMinimapBlips = true,
	SetMinimapCompassEnabled = true,
	SetMinimapCompassRadius = true,
	SetMinimapCompassRadiusInset = true,
	SetMinimapCompassText = true,
	SetMinimapCompassTextColor = true,
	SetMinimapCompassTextFontObject = true,
	GetMinimapHandler = true,
	SetMinimapMaskTexture = true,
	SetMinimapPosition = true,
	SetMinimapBlipScale = true,
	SetMinimapScale = true,
	SetMinimapSize = true,
	SyncMinimap = true,
	UpdateAllMinimapElements = true
}

LibMinimap.Embed = function(self, target)
	for method, func in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibMinimap.embeds) do
	LibMinimap:Embed(target)
end
