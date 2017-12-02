BCF_NO_ANIMATION_SKIP = bit.lshift(1, 0) // Do not allow PVS animation skipping (mostly for attachments being critical to an entity)
BCF_IS_IN_SPAWN = bit.lshift(1, 1) // Is currently inside of spawn, always evaluate animations

function LocalPlayer()
	return Entity(1)
end

local ENTITY = FindMetaTable("Entity")

-- For util.RadiusDamage fallback
function ENTITY:Classify()
	return CLASS_NONE
end

function ENTITY:GetHolder()
	return self:GetSaveValue("m_hOwnerEntity")
end

function ENTITY:PhysicsCheckSweep(vAbsStart, vAbsDelta, nMask --[[= MASK_SOLID]])
	if (not nMask) then
		nMask = MASK_SOLID
	end
	
	// Set collision type
	if (not self:IsSolid() or self:IsSolidFlagSet(FSOLID_VOLUME_CONTENTS)) then
		if (self:GetMoveParent():IsValid()) then
			return util.ClearTrace()
		end
		
		// don't collide with monsters
		nMask = bit.band(nMask, bit.bnot(CONTENTS_MONSTER))
	end
	
	return util.TraceEntity({
		start = vAbsStart,
		endpos = vAbsStart + vAbsDelta,
		filter = self,
		mask = nMask,
		collisiongroup = self:GetCollisionGroup()
	}, self)
end

function ENTITY:_SetAbsVelocity(vAbsVelocity)
	if (self:GetSaveValue("m_vecAbsVelocity") ~= vAbsVelocity) then
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
		
		if (pMoveParent:IsValid()) then
			// First subtract out the parent's abs velocity to get a relative
			// velocity measured in world space
			// Transform relative velocity into parent space
			-- FIXME
			--self:SetSaveValue("m_vecVelocity", (vAbsVelocity - pMoveParent:_GetAbsVelocity()):IRotate(pMoveParent:EntityToWorldTransform()))
			self:SetSaveValue("velocity", vAbsVelocity)
		else
			self:SetSaveValue("velocity", vAbsVelocity)
		end
	end
end

function ENTITY:CreateServerRagdoll(iForceBone, info, iCollisionGroup, bUseLRURetirement --[[= false]])
	local pRagdoll = ents.Create("prop_ragdoll")
	
	if (not pRagdoll:IsValid()) then
		return pRagdoll
	end
	
	local nDamageType = info:GetDamageType()
	local bVehicle = bit.band(nDamageType, DMG_VEHICLE) ~= 0
	local vPos
	
	// if the entity was killed by physics or a vehicle, move to the vphysics shadow position before creating the ragdoll.
	if (bVehicle or bit.band(nDamageType, DMG_CRUSH) ~= 0) then
		local pPhysObj = self:GetPhysicsObject()
		
		if (pPhysObj:IsValid()) then
			--[[vPos = pPhysObj:GetShadowPosition()
			self:SetPos(vPos)]]
			vPos = self:GetPos()
		else
			vPos = self:GetPos()
		end
	else
		vPos = self:GetPos()
	end
	
	pRagdoll:SetPos(vPos)
	pRagdoll:SetOwner(self)
	
	-- InitRagdollAnimation
	pRagdoll:SetAnimTime(CurTime())
	pRagdoll:SetPlaybackRate(0)
	pRagdoll:SetCycle(0)
	
	// put into ACT_DIERAGDOLL if it exists, otherwise use sequence 0
	local nSequence = self:SelectWeightedSequence(ACT_DIERAGDOLL)
	self:ResetSequence(nSequence == -1 and 0 or nSequence)
	
	// Copy over dissolve state...
	if (self:IsEFlagSet(EFL_NO_DISSOLVE)) then
		self:AddEFlags(EFL_NO_DISSOLVE)
	end
	
	// NOTE: This currently is only necessary to prevent manhacks from
	// colliding with server ragdolls they kill
	self:SetSaveValue("m_hKiller", info:GetAttacker())
	self:SetSaveValue("m_strSourceClassName", self:GetClass())
	
	// NPC_STATE_DEAD npc's will have their COND_IN_PVS cleared, so this needs to force SetupBones to happen
	self:SetBoneCacheFlags(BCF_NO_ANIMATION_SKIP)
	
	// UNDONE: Extract velocity from bones via animation (like we do on the client)
	// UNDONE: For now, just move each bone by the total entity velocity if set.
	// Get Bones positions before
	// Store current cycle
	local flProgress = 0.1
	local flSequenceDuration = self:SequenceDuration(self:GetSequence())
	local flCycle = self:GetCycle()
	local flSequenceTime = flCycle * flSequenceDuration
	
	// Avoid having negative cycle
	local flProgress = flSequenceTime > 0 and flSequenceTime <= 0.1 and flSequenceTime or 0.1
	local flPreviousCycle = flCycle - flProgress * 1 / flSequenceDuration
	
	if (flPreviousCycle < 0) then
		flPreviousCycle = 0
	end
	
	local vVelocity = self:_GetAbsVelocity():LengthSqr()
	local iBoneCount = self:GetBoneCount() - 1
	
	// Get current bones positions
	local tBoneToWorldNext = {}
	--self:SetupBones(BONE_USED_BY_ANYTHING)
	
	for i = 0, iBoneCount do
		tBoneToWorldNext[i] = self:GetBoneMatrix(i)
	end
	
	// Get previous bones positions
	self:SetCycle(flPreviousCycle)
	local tBoneToWorld = Matrix()
	--self:SetupBones(BONE_USED_BY_ANYTHING)
	
	if (vVelocity:LengthSqr() == 0 or flProgress == 0) then
		for i = 0, iBoneCount do
			tBoneToWorld[i] = self:GetBoneMatrix(i)
		end
	else
		vVelocity:Mul(flProgress)
		
		for i = 0, iBoneCount do
			local vmatBone = self:GetBoneMatrix(i)
			tBoneToWorld[i] = vmatBone
			
			local vPos = vmatBone:GetColumnVector(4)
			vPos:Sub(vVelocity)
			vmatBone:SetColumnVector(4, vPos)
		end
	end
	
	// Restore current cycle
	self:SetCycle(flCycle)
	
	// Reset previous bone flags
	self:ClearBoneCacheFlags(BCF_NO_ANIMATION_SKIP)
	
	if (gs_developer:GetBool()) then
		self:DrawRawSkeleton(tBoneToWorld, BONE_USED_BY_ANYTHING, true, 20)
		self:DrawRawSkeleton(tBoneToWorldNext, BONE_USED_BY_ANYTHING, true, 20)
	end
	-- FIXME
	// Is this a vehicle / NPC collision?
	if (bVehicle and self:IsNPC()) then
		// init the ragdoll with no forces
	else
		
	end
	
	// Are we dissolving?
	if (self:IsFlagSet(FL_DISSOLVING)) then
		
	elseif (bUseLRURetirement) then
		pRagdoll:AddSpawnFlags(SF_RAGDOLLPROP_USE_LRU_RETIREMENT)
	end
	
	// Tracker 22598:  If we don't set the OBB mins/maxs to something valid here, then the client will have a zero sized hull
	//  for the ragdoll for one frame until Vphysics updates the real obb bounds after the first simulation frame.  Having
	//  a zero sized hull makes the ragdoll think it should be faded/alpha'd to zero for a frame, so you get a blink where
	//  the ragdoll doesn't draw initially.
	pRagdoll:SetCollisionBounds(self:OBBMins(), self:OBBMaxs())
	
	return pRagdoll
end

function ENTITY:SetAnimTime(flTime)
	return self:SetSaveValue("m_flAnimTime", flTime)
end

function ENTITY:GetAnimTime()
	return self:GetSaveValue("m_flAnimTime")
end

function ENTITY:GetBoneCacheFlags()
	return self:GetSaveValue("m_fBoneCacheFlags")
end

function ENTITY:SetBoneCacheFlags(nFlags)
	return self:SetSaveValue("m_fBoneCacheFlags", bit.bor(self:GetSaveValue("m_fBoneCacheFlags"), nFlags))
end

function ENTITY:ClearBoneCacheFlags(nFlags)
	return self:SetSaveValue("m_fBoneCacheFlags", bit.bor(self:GetSaveValue("m_fBoneCacheFlags"), bit.bnot(nFlags)))
end

function ENTITY:AttemptGravGunPickup(pPlayer, nReason)
	return true
end
