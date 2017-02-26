local ENTITY = FindMetaTable("Entity")

function ENTITY:SetDormant(bDormant)
	self:AddEFlags(EFL_DORMANT)
	self:SetNoDraw(true)
	
	local pParent = self:GetParent()
	
	if (pParent:IsValid()) then
		pParent:SetDormant(bDormant) -- Recursion
	end
end

function ENTITY:PhysicsCheckSweep(vAbsStart, vAbsDelta, iMask --[[= MASK_SOLID]])
	if (not iMask) then
		iMask = MASK_SOLID
	end
	
	// Set collision type
	if (not self:IsSolid() or self:SolidFlagSet(FSOLID_VOLUME_CONTENTS)) then
		// don't collide with monsters
		iMask = bit.band(iMask, bit.bnot(CONTENTS_MONSTER))
	end
	
	local vMins, vMaxs = self:WorldSpaceAABB()
	
	return util.TraceHull({
		start = vAbsStart,
		endpos = vAbsStart + vAbsDelta,
		mins = vMins,
		maxs = vMaxs,
		filter = self,
		mask = iMask,
		collisiongroup = self:GetCollisionGroup()
	}, self)
end

function ENTITY:_SetAbsVelocity(vAbsVelocity)
	-- No equivalent; do nothing
end
