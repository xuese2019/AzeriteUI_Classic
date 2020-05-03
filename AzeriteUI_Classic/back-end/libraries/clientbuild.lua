local LibClientBuild = Wheel:Set("LibClientBuild", 37)
if (not LibClientBuild) then
	return
end

-- Lua API
local pairs = pairs
local select = select
local string_match = string.match
local string_split = string.split
local tonumber = tonumber
local tostring = tostring

LibClientBuild.embeds = LibClientBuild.embeds or {}

local currentClientPatch, currentClientBuild = GetBuildInfo()
currentClientBuild = tonumber(currentClientBuild)

-- Let's create some constants for faster lookups
local MAJOR,MINOR,PATCH = string_split(".", currentClientPatch)

local builds = {}

-- Patch to build
builds["1.13.2"] 	= 31446
builds["1.13.3"] 	= 33526
builds["1.13.4"] 	= 34219
builds["8.0.1"] 	= 27101
builds["8.1.0"] 	= 29600
builds["8.1.5"] 	= 29704
builds["8.2.0"] 	= 30920
builds["8.2.0"] 	= 31229
builds["8.2.5"] 	= 31960
builds["8.3.0"] 	= 34220

-- Metas
builds["Classic"] 	= builds["1.13.4"]
builds["Retail"] 	= builds["8.3.0"]

-- Returns true if we're on a classic patch
LibClientBuild.IsClassic = function(self)
	return tonumber(MAJOR) == 1
end

-- Returns true if we're on a classic TBC patch
LibClientBuild.IsClassicTBC = function(self)
	return tonumber(MAJOR) == 2
end

-- Returns true if we're on a retail patch
LibClientBuild.IsRetail = function(self)
	return tonumber(MAJOR) >= 8
end

-- Returns true if we're on a retail BFA patch
LibClientBuild.IsRetailBFA = function(self)
	return tonumber(MAJOR) == 8
end

-- Returns true if we're on a retail Shadowlands patch
LibClientBuild.IsRetailShadowlands = function(self)
	return tonumber(MAJOR) == 9
end

-- Return the build number for a given patch.
-- Return current build if the given patch is the current. EXPERIMENTAL!
LibClientBuild.GetClientBuildByPatch = function(self, patch)
	return (currentClientPatch == patch) and currentClientBuild or builds[patch]
end 

-- Return the current WoW client build
LibClientBuild.GetCurrentClientBuild = function(self)
	return currentClientBuild
end 

-- Module embedding
local embedMethods = {
	IsClassic = true,
	IsClassicTBC = true,
	IsRetail = true,
	IsRetailBFA = true,
	IsRetailShadowlands = true,
	GetClientBuildByPatch = true,
	GetCurrentClientBuild = true
}

LibClientBuild.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibClientBuild.embeds) do
	LibClientBuild:Embed(target)
end
