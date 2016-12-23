function LocalPlayer()
	return Entity(1)
end

local ENTITY = FindMetaTable("Entity")

-- For util.RadiusDamage fallback
function ENTITY:Classify()
	return CLASS_NONE
end

--- CSGameRules
// returns the percentage of the player that is visible from the given point in the world.
// return value is between 0 and 1.
function ENTITY:GetAmoutVisible(vSrc)
	return util.GetExplosionDamageAdjustment(vSrc, self:BodyTarget(vSrc), self)
end

function ENTITY:PhysicsCheckSweep(vAbsStart, vAbsDelta)
	local iMask = MASK_SOLID -- FIXME: Support custom ent masks
	
	// Set collision type
	if (not self:IsSolid() or self:SolidFlagSet(FSOLID_VOLUME_CONTENTS)) then
		if (self:GetMoveParent() ~= NULL) then
			return util.ClearTrace()
		end
		
		// don't collide with monsters
		iMask = bit.band(iMask, bit.bnot(CONTENTS_MONSTER))
	end
	
	return util.TraceEntity({
		start = vAbsStart,
		endpos = vAbsStart + vAbsDelta,
		filter = self,
		mask = iMask,
		collisiongroup = self:GetCollisionGroup()
	}, self)
end

function ENTITY:_SetAbsVelocity(vAbsVelocity)
	if (self:GetInternalVariable("m_vecAbsVelocity") ~= vAbsVelocity) then
		// The abs velocity won't be dirty since we're setting it here
		self:RemoveEFlags(EFL_DIRTY_ABSVELOCITY)
		
		// All children are invalid, but we are not
		local tChildren = self:GetChildren()
			
		for i = 1, #tChildren do
			tChildren[i]:AddEFlags(EFL_DIRTY_ABSVELOCITY)
		end
		
		self:SetSaveValue("m_vecAbsVelocity", vAbsVelocity)
		
		// NOTE: Do *not* do a network state change in this case.
		// m_vVelocity is only networked for the player, which is not manual mode
		local pMoveParent = self:GetMoveParent()
		
		if (pMoveParent ~= NULL) then
			// First subtract out the parent's abs velocity to get a relative
			// velocity measured in world space
			// Transform relative velocity into parent space
			--self:SetSaveValue("m_vecVelocity", (vAbsVelocity - pMoveParent:_GetAbsVelocity()):IRotate(pMoveParent:EntityToWorldTransform()))
			self:SetSaveValue("velocity", vAbsVelocity)
		else
			self:SetSaveValue("velocity", vAbsVelocity)
		end
	end
end
