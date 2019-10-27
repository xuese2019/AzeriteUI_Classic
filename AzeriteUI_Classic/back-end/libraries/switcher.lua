local LibSwitcher = Wheel:Set("LibSwitcher", 2)
if (not LibSwitcher) then
	return
end

local LibModule = Wheel("LibModule")
assert(LibModule, "LibSwitcher requires LibModule to be loaded.")

local LibSlash = Wheel("LibSlash")
assert(LibSlash, "LibSwitcher requires LibSlash to be loaded.")

-- We want this embedded
LibSlash:Embed(LibSwitcher)

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
local table_insert = table.insert
local tonumber = tonumber
local type = type

-- WoW API
local DisableAddOn = _G.DisableAddOn
local EnableAddOn = _G.EnableAddOn
local ReloadUI = _G.ReloadUI

-- Library registries
LibSwitcher.embeds = LibSwitcher.embeds or {}
LibSwitcher.switches = LibSwitcher.switches or { Addons = {}, Cmds = {} }

-- Keep the actual list of available UIs local.
local CurrentProjects = { Addons = {}, Cmds = {} }

-- List of known user interfaces. 
local KnownProjects = {
	["AzeriteUI"] = {
		azeriteui = true,
		azerite = true,
		azui = true,
		az = true
	},
	["DiabolicUI"] = { 
		diabolicui2 = true, 
		diabolicui = true, 
		diabolic = true, 
		diabloui = true, 
		dui2 = true, 
		dui = true 
	},
	["GoldieSix"] = { 
		goldpawui6 = true,
		goldpawui = true,
		goldpaw6 = true,
		goldpaw = true,
		goldui6 = true,
		goldui = true,
		gui6 = true,
		gui = true 
	},
	["GoldpawUI"] = { 
		goldpawui5 = true,
		goldpaw5 = true,
		goldui5 = true,
		gui5 = true
	},
	["LaeviaUI"] = { 
		laeviaui = true, 
		laevia = true, 
		lui = true 
	},
	["LaeviaUI"] = { 
		laeviaui = true, 
		laevia = true, 
		lui = true 
	},
	["KkthnxUI"] = { 
		kkthnxui = true, 
		kkthnx = true, 
		kui = true 
	},
	["SpartanUI"] = { 
		laeviaui = true, 
		laevia = true, 
		lui = true 
	},
	["Tukui"] = { 
		tukui = true, 
		tukz = true
	},
	["ElvUI"] = { 
		elvui = true, 
		elv = true
	}
}

-- Shortcuts for quality of life.
local Switches = LibSwitcher.switches
local Addons = LibSwitcher.switches.Addons
local Cmds = LibSwitcher.switches.Cmds

----------------------------------------------------------------
-- Utility Functions
----------------------------------------------------------------
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

----------------------------------------------------------------
-- Private Callbacks
----------------------------------------------------------------
local OnChatCommand = function(editBox, ...)
	local cmd = ...
	if ((not cmd) or (cmd == "")) then 
		return 
	end 
	local targetAddon = CurrentProjects.Cmds[cmd]
	if targetAddon then 
		LibSwitcher:SwitchToInterface(targetAddon)
	end 
end 

-- Internal method to update the stored switches
local UpdateInterfaceSwitches = function()
	-- Clean out the list of current ones. 
	for i in pairs(CurrentProjects) do 
		for v in pairs(CurrentProjects[i]) do 
			CurrentProjects[i][v] = nil
		end 
	end 
	-- Add in the currently available from our own lists.
	local counter = 0
	for addon,list in pairs(KnownProjects) do 
		if (LibModule:IsAddOnAvailable(addon)) then 
			counter = counter + 1
			CurrentProjects.Addons[addon] = list
			for cmd in pairs(list) do 
				CurrentProjects.Cmds[cmd] = addon
			end 
		end 
	end 
	-- Add in the currently available from the user lists.
	for addon,list in pairs(Addons) do 
		if (LibModule:IsAddOnAvailable(addon)) then 
			counter = counter + 1
			CurrentProjects.Addons[addon] = list
			for cmd in pairs(list) do 
				CurrentProjects.Cmds[cmd] = addon
			end 
		end 
	end 
	-- Register the commands. 
	if (counter > 0) then 
		LibSwitcher:RegisterChatCommand("go", OnChatCommand, true)
		LibSwitcher:RegisterChatCommand("goto", OnChatCommand, true)
	else
		LibSwitcher:UnregisterChatCommand("go")
		LibSwitcher:UnregisterChatCommand("goto")
	end 
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------
LibSwitcher.AddInterfaceSwitch = function(self, addon, ...)
	check(addon, 1, "string")
	-- Silently fail if the addon already has been registered
	if Addons[addon] then 
		return 
	end 
	-- Add the command to our globally available cache
	local numCmds = select("#", ...)
	if (numCmds > 0) then 
		Addons[addon] = {}
		for i = 1, numCmds do 
			local cmd = select(i, ...)
			check(cmd, i+1, "string")
			Addons[addon][i] = cmd
			Cmds[cmd] = addon
		end 
		-- Update the available switches
		UpdateInterfaceSwitches()
	end 
end

LibSwitcher.SwitchToInterface = function(self, targetAddon)
	check(targetAddon, 1, "string")
	-- Silently fail if an unavailable project is requested
	if (not CurrentProjects.Addons[targetAddon]) then 
		return 
	end 
	-- Iterate the currently available addons.
	for addon in pairs(CurrentProjects.Addons) do 
		if (addon == targetAddon) then 
			EnableAddOn(addon, true) -- enable the target addon
		else
			DisableAddOn(addon, true) -- disable all other addons in the lists
		end
	end 
	ReloadUI() -- instantly reload to apply the operations
end

-- Return a list of available interface addon names. 
LibSwitcher.GetInterfaceList = function(self)
	-- Generate a new list each time this is called, 
	-- as we don't want to provide any access to our own tables. 
	local listCopy = {}
	for addon in pairs(KnownProjects) do 
		if LibModule:IsAddOnAvailable(addon) then 
			table_insert(listCopy, addon)
		end 
	end 
	return unpack(listCopy)
end

-- Return an iterator of available interface addon names.
-- The key is the addon name, the value is whether its currently enabled. 
LibSwitcher.GetInterfaceIterator = function(self)
	-- Generate a new list each time this is called, 
	-- as we don't want to provide any access to our own tables. 
	local listCopy = {}
	for addon in pairs(KnownProjects) do 
		if LibModule:IsAddOnAvailable(addon) then 
			listCopy[addon] = LibModule:IsAddOnEnabled(addon) or false -- can't have nil here
		end 
	end
	return pairs(listCopy)
end

-- Run this once to initialize the database. 
UpdateInterfaceSwitches()

local embedMethods = {
	AddInterfaceSwitch = true, 
	GetInterfaceIterator = true, 
	GetInterfaceList = true, 
	SwitchToInterface = true
}

LibSwitcher.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibSwitcher.embeds) do
	LibSwitcher:Embed(target)
end
