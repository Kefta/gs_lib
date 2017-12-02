-- FIXME: Load pathing

if (gs.random == nil) then
	local bSuccess, tRand = gs.SafeInclude("code_gs/lib/modules/minstd.lua")
	
	if (SERVER) then
		AddCSLuaFile("code_gs/lib/modules/minstd.lua")
	end
	
	if (not bSuccess) then
		error("[GS Lib] MINSTD failed to load!")
	end
	
	gs.random = tRand
end

function gs.random:SharedRandomFloat(pPlayer, sName, flMin --[[= 0]], flMax --[[= 0]], iAdditionalSeed --[[= 0]])
	self:SetSeed(util.SeedFileLineHash(pPlayer:GetMD5Seed() % 0x80000000, sName, iAdditionalSeed))
	
	return self:RandomFloat(flMin, flMax)
end

function gs.random:SharedRandomInt(pPlayer, sName, iMin, iMax, iAdditionalSeed --[[= 0]])
	self:SetSeed(util.SeedFileLineHash(pPlayer:GetMD5Seed() % 0x80000000, sName, iAdditionalSeed))
	
	return self:RandomInt(iMin, iMax)
end

function gs.random:SharedRandomVector(pPlayer, sName, flMin, flMax, iAdditionalSeed --[[= 0]])
	self:SetSeed(util.SeedFileLineHash(pPlayer:GetMD5Seed() % 0x80000000, sName, iAdditionalSeed))

	return Vector(self:RandomFloat(flMin, flMax), 
			self:RandomFloat(flMin, flMax), 
			self:RandomFloat(flMin, flMax))
end

function gs.random:SharedRandomAngle(pPlayer, sName, flMin, flMax, iAdditionalSeed --[[= 0]])
	self:SetSeed(util.SeedFileLineHash(pPlayer:GetMD5Seed() % 0x80000000, sName, iAdditionalSeed))

	return Angle(self:RandomFloat(flMin, flMax), 
			self:RandomFloat(flMin, flMax), 
			self:RandomFloat(flMin, flMax))
end

function gs.random:SharedRandomColor(pPlayer, sName, iMin, iMax, iAdditionalSeed --[[= 0]])
	self:SetSeed(util.SeedFileLineHash(pPlayer:GetMD5Seed() % 0x80000000, sName, iAdditionalSeed))
	
	return Color(self:RandomInt(iMin, iMax), 
			self:RandomInt(iMin, iMax), 
			self:RandomInt(iMin, iMax))
end
