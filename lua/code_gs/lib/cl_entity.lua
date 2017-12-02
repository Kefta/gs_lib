function LocalOrSpectatorEntity()
	local pPlayer = LocalPlayer()
	
	if (pPlayer:IsValid()) then
		local nMode = pPlayer:GetObserverMode()
		
		if (nMode == OBS_MODE_IN_EYE or nMode == OBS_MODE_CHASE or nMode == OBS_MODE_FIXED) then
			local pTarget = pPlayer:GetObserverTarget()
			
			-- https://github.com/Facepunch/garrysmod-issues/issues/3132
			if (pTarget and pTarget:IsValid()) then
				return pTarget
			end
		end
	end
	
	return pPlayer
end

local ENTITY = FindMetaTable("Entity")

function ENTITY:SetDormant(bDormant)
	if (bDormant) then
		self:AddEFlags(EFL_DORMANT)
		self:SetNoDraw(true)
	else
		self:RemoveEFlags(EFL_DORMANT)
		self:SetNoDraw(false)
	end
	
	local pParent = self:GetParent()
	
	if (pParent:IsValid()) then
		pParent:SetDormant(bDormant) -- Recursion
	end
end

function ENTITY:PhysicsCheckSweep(vAbsStart, vAbsDelta, iMask --[[= MASK_SOLID]])
	if (iMask == nil) then
		iMask = MASK_SOLID
	end
	
	// Set collision type
	if (not self:IsSolid() or self:IsSolidFlagSet(FSOLID_VOLUME_CONTENTS)) then
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

-- DeleteOnRemove for CSEnts
local tEntityList = {}

function ENTITY:DeleteOnRemove(pEntity)
	gs.CheckType(pEntity, 1, gs.TYPE_CSENT)
	
	local tRemoveList = tEntityList[self]
	
	if (tRemoveList == nil) then
		-- Store entity in hashtable and array for fast access, iteration, and deletion
		tEntityList[self] = {[pEntity] = 1, [0] = 1, pEntity}
	-- Don't insert duplicate entries
	elseif (tRemoveList[pEntity] == nil) then
		local iLen = tRemoveList[0] + 1
		tRemoveList[0] = iLen
		tRemoveList[iLen] = pEntity
		tRemoveList[pEntity] = iLen
	end
end

function ENTITY:DontDeleteOnRemove(pEntity)
	gs.CheckType(pEntity, 1, gs.TYPE_CSENT)
	
	local tRemoveList = tEntityList[self]
	
	if (tRemoveList ~= nil) then
		local iPos = tRemoveList[pEntity]
		
		if (iPos ~= nil) then
			local iLen = tRemoveList[0]
			
			if (iPos ~= iLen) then
				tRemoveList[iPos] = tRemoveList[iLen]
			end
			
			tRemoveList[0] = iLen - 1
			tRemoveList[iLen] = nil
			tRemoveList[pEntity] = nil
		end
	end
end

hook.Add("EntityRemoved", "gs_lib", function(pEntity)
	local tRemoveList = tEntityList[pEntity]
	
	if (tRemoveList ~= nil) then
		for i = 1, tRemoveList[0] do
			local pToRemove = tRemoveList[i]
			
			if (pToRemove:IsValid()) then
				pToRemove:Remove()
			end
		end
		
		tRemoveList[pEntity] = nil
	end
end)
