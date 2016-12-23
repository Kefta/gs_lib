local ENTITY = FindMetaTable("Entity")

-- Create a wrapper for env_particlesmokegrenade since we are missing some engine methods
local SMOKE = {
	FillVolume = function(self, vMin --[[= vDefaultMin]], vMax --[[= vDefaultMax]])
		self:SetSaveValue("m_CurrentStage", 1)
		self:SetCollisionBounds(vMin or vDefaultMin, vMax or vDefaultMax)
	end,
	
	SetFadeTime = function(self, flStartTime, flEndTime)
		self:SetSaveValue("m_FadeStartTime", flStartTime)
		self:SetSaveValue("m_FadeEndTime", flEndTime)
	end,
	
	// Fade start and end are relative to current time
	SetRelativeFadeTime = function(self, flStartTime, flEndTime)
		local flTime = CurTime() - self.m_flSpawnTime
		
		self:SetSaveValue("m_FadeStartTime", flTime + flStartTime)
		self:SetSaveValue("m_FadeEndTime", flTime + flEndTime)
	end,
	
	__type = function(self) -- One day :(
		return type(self.m_pEntity)
	end
}

-- Inherit base entity functions
function SMOKE.__index(t, k)
	local val = rawget(t, k) or rawget(SMOKE, k) or ENTITY[k]
	
	return isfunction(val) and function(_, ...) return val(t.m_pEntity, ...) end or val	
end

function Smoke()
	local pEntity = ents.Create("env_particlesmokegrenade")
	pEntity.m_flSpawnTime = CurTime()
	pEntity:Spawn()
	
	return setmetatable({m_pEntity = pEntity}, SMOKE)
end