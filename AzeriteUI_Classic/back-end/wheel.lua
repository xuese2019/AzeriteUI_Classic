-- Forcefully showing script errors because I need this.
-- I also forcefully enable the taint log. 
-- *will remove this later on and implement it in a safer way
if not InCombatLockdown() then
	SetCVar("scriptErrors", 1)
	SetCVar("taintLog", 1)
end

local Global, Version = "Wheel", 6

local Wheel = _G[Global]
if (Wheel and (Wheel.version >= Version)) then
	return
end

Wheel = Wheel or { cogs = {}, versions = {} }
Wheel.version = Version

Wheel.Set = function(self, name, version)
	assert(type(name) == "string", ("%s: Bad argument #1 to 'Set': Name must be a string."):format(Global))
	assert(type(version) == "number", ("%s: Bad argument #2 to 'Set': Version must be a number."):format(Global))

	local oldVersion = self.versions[name]
	if (oldVersion and (oldVersion >= version)) then 
		return 
	end

	self.cogs[name] = self.cogs[name] or {}
	self.versions[name] = version

	return self.cogs[name], oldVersion
end

Wheel.Get = function(self, name, silentFail)
	if (not self.cogs[name]) and (not silentFail) then
		error(("%s: Cannot find an instance of %q."):format(Global, tostring(name)), 2)
	end

	return self.cogs[name], self.versions[name]
end

Wheel.Spin = function(self) 
	return pairs(self.cogs) 
end

setmetatable(Wheel, { __call = Wheel.Get })

_G[Global] = Wheel
