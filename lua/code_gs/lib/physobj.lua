local PHYSOBJ = FindMetaTable("PhysObj")

function PHYSOBJ:GetDensity()
	return self:GetMass() / self:GetVolume()
end

function PHYSOBJ:SetAngleVelocity(aImpulse)
	self:AddAngleVelocity(aImpulse - self:GetAngleVelocity())
end
