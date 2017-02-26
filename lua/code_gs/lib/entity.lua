local ENTITY = FindMetaTable("Entity")

// entity capabilities
// These are caps bits to indicate what an object's capabilities (currently used for +USE, save/restore and level transitions)
FCAP_MUST_SPAWN = 0x00000001		// Spawn after restore
FCAP_ACROSS_TRANSITION = 0x00000002		// should transfer between transitions 
// UNDONE: This will ignore transition volumes (trigger_transition), but not the PVS!!!
FCAP_FORCE_TRANSITION = 0x00000004		// ALWAYS goes across transitions
FCAP_NOTIFY_ON_TRANSITION = 0x00000008		// Entity will receive Inside/Outside transition inputs when a transition occurs

FCAP_IMPULSE_USE = 0x00000010		// can be used by the player
FCAP_CONTINUOUS_USE = 0x00000020		// can be used by the player
FCAP_ONOFF_USE = 0x00000040		// can be used by the player
FCAP_DIRECTIONAL_USE = 0x00000080		// Player sends +/- 1 when using (currently only tracktrains)
// NOTE: Normally +USE only works in direct line of sight.  Add these caps for additional searches
FCAP_USE_ONGROUND = 0x00000100
FCAP_USE_IN_RADIUS = 0x00000200
FCAP_SAVE_NON_NETWORKABLE = 0x00000400

FCAP_MASTER = 0x10000000		// Can be used to "master" other entities (like multisource)
FCAP_WCEDIT_POSITION = 0x40000000		// Can change position and update Hammer in edit mode
FCAP_DONT_SAVE = 0x80000000		// Don't save this

// Spawnflags for func breakable
SF_BREAK_TRIGGER_ONLY = 0x0001	// may only be broken by trigger
SF_BREAK_TOUCH = 0x0002	// can be 'crashed through' by running player (plate glass)
SF_BREAK_PRESSURE = 0x0004	// can be broken by a player standing on it
SF_BREAK_PHYSICS_BREAK_IMMEDIATELY = 0x0200	// the first physics collision this breakable has will immediately break it
SF_BREAK_DONT_TAKE_PHYSICS_DAMAGE = 0x0400	// this breakable doesn't take damage from physics collisions
SF_BREAK_NO_BULLET_PENETRATION = 0x0800  // don't allow bullets to penetrate

// Spawnflags for func_pushable (it's also func_breakable, so don't collide with those flags)
SF_PUSH_BREAKABLE = 0x0080
SF_PUSH_NO_USE = 0x0100	// player cannot +use pickup this ent

-- Effects
FX_WATER_IN_SLIME = 0x1

--TE_EXPLFLAG_NONE = 0x0	// all flags clear makes default Half-Life explosion
TE_EXPLFLAG_NOADDITIVE = 0x1	// sprite will be drawn opaque (ensure that the sprite you send is a non-additive sprite)
TE_EXPLFLAG_NODLIGHTS = 0x2	// do not render dynamic lights
TE_EXPLFLAG_NOSOUND = 0x4	// do not play client explosion sound
TE_EXPLFLAG_NOPARTICLES = 0x8	// do not draw particles
TE_EXPLFLAG_DRAWALPHA = 0x10	// sprite will be drawn alpha
TE_EXPLFLAG_ROTATE = 0x20	// rotate the sprite randomly
TE_EXPLFLAG_NOFIREBALL = 0x40	// do not draw a fireball
TE_EXPLFLAG_NOFIREBALLSMOKE = 0x80	// do not draw smoke with the fireball

MUZZLEFLASH_FIRSTPERSON = 0x100

ENTITY.LocalEyeAngles = ENTITY.EyeAngles

function ENTITY:ApplyAbsVelocityImpulse(vImpulse)
	if (vImpulse ~= vector_origin) then
		if (self:GetMoveType() == MOVETYPE_VPHYSICS) then
			self:GetPhysicsObject():AddVelocity(vImpulse)
		else
			// NOTE: Have to use GetAbsVelocity here to ensure it's the correct value
			self:_SetAbsVelocity(self:_GetAbsVelocity() + vImpulse)
		end
	end
end

function ENTITY:ApplyLocalAngularVelocityImpulse(vImpulse)
	if (vImpulse ~= vector_origin) then
		if (self:GetMoveType() == MOVETYPE_VPHYSICS) then
			self:GetPhysicsObject():AddAngleVelocity(vImpulse)
		else
			self:SetLocalAngularVelocity(self:GetLocalAngularVelocity() + vImpulse:ImpulseAngle())
		end
	end
end

function ENTITY:ApplyLocalVelocityImpulse(vImpulse)
	// NOTE: Don't have to use GetVelocity here because local values
	// are always guaranteed to be correct, unlike abs values which may 
	// require recomputation
	if (vImpulse ~= vector_origin) then
		if (self:GetMoveType() == MOVETYPE_VPHYSICS) then
			local pPhysObj = self:GetPhysicsObject()
			pPhysObj:AddVelocity(pPhysObj:LocalToWorld(vImpulse))
		else
			self:AddEFlags(EFL_DIRTY_ABSVELOCITY)
			
			local tChildren = self:GetChildren()
			
			for i = 1, #tChildren do
				tChildren[i]:AddEFlags(EFL_DIRTY_ABSVELOCITY)
			end
			
			self:_SetLocalVelocity(self:_GetLocalVelocity() + vImpulse)
		end
	end
end

function ENTITY:ComputeTracerStartPosition(vSrc, iAttachment)
	local tAttachment = self:GetAttachment(iAttachment or 1)
	
	if (tAttachment) then
		return tAttachment.Pos
	end
	
	return self:EyePos()
end

ENTITY.GetHitBoxSet = ENTITY.GetHitboxSet -- ONLY hitbox method with lower-case b

function ENTITY:DrawHitBoxes(flDuration, bMonoColored)
	local iSet = self:GetHitBoxSet()
	
	if (iSet) then
		flDuration = flDuration or 0
		
		for iGroup = 0, self:GetHitBoxGroupCount() - 1 do
			for iHitBox = 0, self:GetHitBoxCount(iGroup) - 1 do
				local vPos, ang = self:GetBonePosition(self:GetHitBoxBone(iHitBox, iGroup))
				local vMins, vMaxs = self:GetHitBoxBounds(iHitBox, iGroup)
				debugoverlay.BoxAngles(vPos, vMins, vMaxs, ang, flDuration, bMonoColored and color_white or color_debug)
			end
		end
	end
end

function ENTITY:DrawRawSkeleton(tBoneToWorld, flBoneMask, flDuration, bMonoColored, bNoDepthTest)
	local iBoneCount = self:GetBoneCount()
	
	if (iBoneCount) then
		flDuration = flDuration or 0
		
		for iBone = 0, iBoneCount - 1 do
			if (self:BoneHasFlag(iBone, flBoneMask)) then
				local iBoneParent = self:GetBoneParent(iBone)
				
				if (iBoneParent ~= -1) then
					debugoverlay.Line(tBoneToWorld[iBone + 1]:GetColumnVector(4), tBoneToWorld[iBoneParent + 1]:GetColumnVector(4), flDuration, bMonoColored and color_white or color_debug, bNoDepthTest)
				end
			end
		end
	end
end

function ENTITY:FollowEntity(pBaseEntity, bBoneMerge)
	if (pBaseEntity == NULL) then
		self:StopFollowingEntity()
	else
		self:SetParent(pBaseEntity)
		self:SetMoveType(MOVETYPE_NONE)
		
		if (bBoneMerge) then
			self:AddEffects(EF_BONEMERGE)
		end
		
		self:AddSolidFlags(FSOLID_NOT_SOLID)
		self:SetLocalPos(vector_origin)
		self:SetLocalAngles(angle_zero)
	end
end

function ENTITY:GetFollowedEntity()
	return self:GetMoveParent()
end

function ENTITY:FollowingEntity(bIgnoreBoneMerge)
	return (bIgnoreBoneMerge or self:IsEffectActive(EF_BONEMERGE)) and self:GetMoveType() == MOVETYPE_NONE and self:GetMoveParent():IsValid()
end

function ENTITY:StopFollowingEntity()
	self:SetParent(NULL)
	self:RemoveEffects(EF_BONEMERGE)
	self:RemoveSolidFlags(FSOLID_NOT_SOLID)
	self:SetMoveType(MOVETYPE_NONE)
end

function ENTITY:GetRootMoveParent()
	local pEntity = self
	local pParent = self:GetMoveParent()
	
	while (pParent:IsValid()) do
		pEntity = pParent
		pParent = pEntity:GetMoveParent()
	end
	
	return pEntity
end

function ENTITY:BoundsDefinedInEntitySpace()
	if (self:SolidFlagSet(FSOLID_FORCE_WORLD_ALIGNED)) then
		return false
	end
	
	local iSolidType = self:GetSolid()
	
	return iSolidType ~= SOLID_BBOX and iSolidType ~= SOLID_NONE
end

function ENTITY:ClearEffects()
	self:RemoveEffects(self:GetEffects())
end

function ENTITY:SetEffects(iEffects)
	if (bit.band(iEffects, EF_NOINTERP)) then
		-- Trigger AddPostClientMessageEntity and possibly IncrementEFNoInterpParity
		self:AddEffects(EF_NOINTERP)
	end
	
	self:SetSaveValue("effects", iEffects)
end

function ENTITY:ClearFlags()
	self:RemoveFlags(self:GetFlags())
end

function ENTITY:SetFlags(iFlags)
	-- Notify the engine of flag changes
	self:ClearFlags()
	self:AddFlags(iFlags)
end

function ENTITY:ClearSolidFlags()
	self:RemoveSolidFlags(self:GetSolidFlags())
end

function ENTITY:SolidFlagSet(iFlag)
	return bit.band(self:GetSolidFlags(), iFlag) ~= 0
end

-- https://github.com/Facepunch/garrysmod-requests/issues/660
-- https://github.com/Facepunch/garrysmod-requests/issues/811
ENTITY._GetAbsVelocity = ENTITY.GetVelocity
ENTITY._GetBaseVelocity = ENTITY.GetBaseVelocity
ENTITY._SetBaseVelocity = ENTITY.SetVelocity
ENTITY._GetLocalVelocity = ENTITY.GetAbsVelocity
ENTITY._SetLocalVelocity = ENTITY.SetLocalVelocity

-- BaseAnimating overrides this as well
function ENTITY:_GetVelocity()
	if (self:GetMoveType() == MOVETYPE_VPHYSICS) then
		local pPhysicsObject = self:GetPhysicsObject()
		
		if (pPhysicsObject:IsValid()) then
			return pPhysicsObject:GetVelocity()
		else
			return self:_GetAbsVelocity()
		end
	end
	
	if (not self:OnGround()) then
		return self:_GetAbsVelocity()
	end
	
	-- https://github.com/Facepunch/garrysmod-requests/issues/691
	return self:_GetAbsVelocity()
	
	--[[// Build a rotation matrix from NPC orientation
	Vector	vRawVel;
	
	GetSequenceLinearMotion(GetSequence(), &vRawVel);
	
	// Build a rotation matrix from NPC orientation
	matrix3x4_t fRotateMatrix;
	AngleMatrix(GetLocalAngles(), fRotateMatrix);
	VectorRotate(vRawVel, fRotateMatrix, *vVelocity);]]
end

-- Guessed based on the VPhysics interface comments
function ENTITY:_SetVelocity(vVelocity)
	if (self:GetMoveType() == MOVETYPE_VPHYSICS) then
		local pPhysicsObject = self:GetPhysicsObject()
		
		if (pPhysicsObject:IsValid()) then
			pPhysicsObject:SetVelocity(vVelocity)
		end
	else
		self:_SetAbsVelocity(vVelocity)
	end
end

-- https://github.com/Facepunch/garrysmod-requests/issues/550
function ENTITY:IsBSPModel()
	return self:GetSolid() == SOLID_BSP -- or self:GetSolid() == SOLID_VPHYSICS
end

function ENTITY:SolidFlagSet(iFlag)
	return bit.band(self:GetSolidFlags(), iFlag) ~= 0
end

function ENTITY:Standable()
	if (self:SolidFlagSet(FSOLID_NOT_STANDABLE)) then
		return false
	end
	
	local iSolid = self:GetSolid()
	
	return iSolid == SOLID_BSP or iSolid == SOLID_VPHYSICS or iSolid == SOLID_BBOX
	
	-- The engine calls IsBSPModel here as the fall-through case
	-- However, that always returns false if the above conditions are false
end

function ENTITY:Viewable()
	if (self:IsEffectActive(EF_NODRAW)) then
		return false
	end
	
	if (self:IsBSPModel()) then
		return self:GetMoveType() ~= MOVETYPE_NONE 
	end
	
	local sModel = self:GetModel()
	
	return sModel and sModel ~= ""
end

function ENTITY:SetWaterLevel(iLevel)
	self:SetSaveValue("waterlevel", iLevel)
end

--[[function ENTITY:SetWaterType(iType)
	local iWaterType = 0
	
	if (bit.band(iType, CONTENTS_WATER) ~= 0) then
		iWaterType = CONTENTS_WATER
	end
	
	if (bit.band(iType, CONTENTS_SLIME) ~= 0) then
		iWaterType = bit.bor(iWaterType, CONTENTS_SLIME)
	end
	
	self.m_iWaterType = iWaterType
end

function ENTITY:WaterType()
	return self.m_iWaterType or 0
end]]

-- Different than ENTITY:Visible(pEnt)!
function ENTITY:IsVisible()
	return not self:IsEffectActive(EF_NODRAW)
end

function ENTITY:SetVisible(bVisible)
	if (bVisible) then
		self:RemoveEffects(EF_NODRAW)
	else
		self:AddEffects(EF_NODRAW)
	end
end

function ENTITY:SequenceEnd()
	return (1 - self:GetCycle()) * self:SequenceDuration()
end

local sv_gravity = GetConVar("sv_gravity")

function ENTITY:GetActualGravity()
	local flGravity = self:GetGravity()
	
	return flGravity == 0 and 1 or flGravity * sv_gravity:GetFloat()
end

function ENTITY:PhysicsPushEntity(vPush)
	local tr = self:PhysicsCheckSweep(self:GetPos(), vPush)
	
	if (tr.Fraction ~= 0) then
		self:SetPos(tr.HitPos)
	end
	
	local pEntity = tr.Entity
	
	if (tr.Entity:IsValid()) then
		// If either of the entities is flagged to be deleted, 
		//  don't call the touch functions
		if (not (self:IsFlagSet(FL_KILLME) or pEntity:IsFlagSet(FL_KILLME))) then
			self.m_trTouch = tr
			self.m_bTouched = true
		end
	end
	
	return tr
end

function ENTITY:PhysicsClipVelocity(vIn, vNormal, flBounce)
	local flAngle = vNormal.z
	local vRet = vIn - vNormal * vIn:Dot(vNormal) * flBounce
	local x = vRet.x
	local y = vRet.y
	local z = vRet.z
	
	if (x > -0.1 and x < 0.1) then
		vRet.x = 0
	end
	
	if (y > -0.1 and y < 0.1) then
		vRet.y = 0
	end
	
	if (z > -0.1 and z < 0.1) then
		vRet.z = 0
	end
	
	return vRet
end

function ENTITY:CollisionToNormalizedSpace(vIn)
	local vMins = self:OBBMins()
	local vSize = self:OBBSize()
	return Vector(vSize.x ~= 0 and (vIn.x - vMins.x) / vSize.x or 0.5,
		vSize.y ~= 0 and (vIn.y - vMins.y) / vSize.y or 0.5,
		vSize.z ~= 0 and (vIn.z - vMins.z) / vSize.z or 0.5)
end

function ENTITY:NormalizedToCollisionSpace(vIn)
	return Vector(vIn:Lerp(self:OBBMins(), self:OBBMaxs()))
end

function ENTITY:CollisionToWorldSpace(vIn)
	// Makes sure we don't re-use the same temp twice
	if (not self:IsBoundsDefinedInEntitySpace() or self:GetAngles() == angle_zero) then
		return vIn + self:GetPos()
	end
	
	return vIn:Transform(self:CollisionToWorldTransform())
end

function ENTITY:CollisionToWorldTransform()
	if (self:BoundsDefinedInEntitySpace()) then
		--return self:EntityToWorldTransform() FIXME
	end
	
	return MatrixIdentity():SetColumnVector(4, self:GetPos())
end

function ENTITY:NormalizedToWorldSpace(vIn)
	return self:CollisionToWorldSpace(self:NormalizedToCollisionSpace(vIn))
end

function ENTITY:OBBSize()
	return self:OBBMaxs() - self:OBBMins()
end

local vDefaultDrop = Vector(0, 0, 256)

function ENTITY:DropToFloor(iMask, pIgnore, iRange --[[= 256]])
	// Assume no ground
	self:SetGroundEntity(NULL)
	
	local vPos = self:GetPos()
	local trace = util.TraceEntity({
		start = vPos,
		endpos = vPos - (iRange and Vector(0, 0, iRange) or vDefaultDrop),
		mask = iMask or MASK_SOLID,
		filter = pIgnore or self,
		collisiongroup = self:GetCollisionGroup()
	}, self)
	
	-- Already on ground 
	if (trace.AllSolid) then
		return -1
	end
	
	-- No floor in range
	if (trace.Fraction == 1) then
		return 0
	end
	
	self:SetPos(trace.HitPos)
	self:SetGroundEntity(trace.Entity)
	
	-- New floor
	return 1
end

function ENTITY:PhysicsToss()
	self.m_bTouched = false
	
	self:PhysicsCheckWater()
	
	local vAbsVelocity = self:_GetAbsVelocity()
	
	// Moving upward, off the ground, or  resting on a client/monster, remove FL_ONGROUND
	if (vAbsVelocity.z > 0) then
		self:SetGroundEntity(NULL)
	else
		local pGroundEntity = self:GetGroundEntity()
		
		if (pGroundEntity == NULL or not pGroundEntity:Standable()) then
			self:SetGroundEntity(NULL)
		end
	end
	
	local vBaseVelocity = self:_GetBaseVelocity()
	local bAngleVelSet = false
	local aLocalVelocity
	
	// Check to see if the entity is on the ground at rest
	if (self:IsFlagSet(FL_ONGROUND) and vAbsVelocity == vector_origin) then
		// Clear rotation if not moving (even if on a conveyor)
		self:SetLocalAngularVelocity(angle_zero)
		aLocalVelocity = angle_zero
		
		if (vBaseVelocity == vector_origin) then
			return
		end
		
		bAngleVelSet = true
	end
	
	-- Let the engine's physics manager handle this
	--PhysicsCheckVelocity();
	
	local iFrameTime = FrameTime()
	
	// add gravity
	// Base velocity is not properly accounted for since this entity will move again after the bounce without
	// taking it into account
	local vMove = self:IsFlagSet(FL_FLY) and (vAbsVelocity + vBaseVelocity) * iFrameTime or self:PhysicsAddGravityMove()
	
	// move angles
	self:SetLocalAngles(self:GetLocalAngles() + (aLocalVelocity or self:GetLocalAngularVelocity()) * iFrameTime)
	
	// move origin
	local tr = self:PhysicsPushEntity(vMove)
	local pPhysicsObject = self:GetPhysicsObject()
	
	if (pPhysicsObject:IsValid()) then
		pPhysicsObject:UpdateShadow(self:GetPos(), angle_zero, iFrameTime)
	end
	
	--PhysicsCheckVelocity();
	
	if (tr.AllSolid) then
		// entity is trapped in another solid
		// UNDONE: does this entity needs to be removed?
		self:_SetAbsVelocity(vector_origin)
		
		if (not bAngleVelSet) then
			self:SetLocalAngularVelocity(angle_zero)
		end
	else
		if (tr.Fraction ~= 1) then
			self:PerformFlyCollisionResolution(tr, vMove)
		end
		
		// check for in water
		self:PhysicsCheckWaterTransition()
	end
end

//-----------------------------------------------------------------------------
// Purpose: Check if entity is in the water and applies any current to velocity
// and sets appropriate water flags
// Output : Returns true on success, false on failure.
//-----------------------------------------------------------------------------
local iWaterMask = bit.bor(MASK_WATER, MASK_CURRENT)

function ENTITY:PhysicsCheckWater()
	if (self:GetMoveParent():IsValid()) then
		return self:WaterLevel() > 1
	end
	
	local iMask = util.PointContents(self:GetPos())
	
	// If we're not in water + don't have a current, we're done
	if (bit.band(iMask, iWaterMask) ~= iWaterMask) then
		return self:WaterLevel() > 1
	end
	
	// Compute current direction
	local x = 0
	local y = 0
	local z = 0
	
	if (bit.band(iMask, CONTENTS_CURRENT_0) ~= 0) then
		x = 1
	end
	
	if (bit.band(iMask, CONTENTS_CURRENT_90) ~= 0) then
		y = 1
	end
	
	if (bit.band(iMask, CONTENTS_CURRENT_180) ~= 0) then
		x = x - 1
	end
	
	if (bit.band(iMask, CONTENTS_CURRENT_270) ~= 0) then
		y = y - 1
	end
	
	if (bit.band(iMask, CONTENTS_CURRENT_UP) ~= 0) then
		z = 1
	end
	
	if (bit.band(iMask, CONTENTS_CURRENT_DOWN) ~= 0) then
		z = z - 1
	end
	
	// The deeper we are, the stronger the current.
	local iWaterLevel = self:WaterLevel()
	self:_SetBaseVelocity(self:_GetBaseVelocity() + Vector(x, y, z) * 50 * iWaterLevel)
	
	return iWaterLevel > 1
end

function ENTITY:PhysicsAddGravityMove()
	local vAbsVelocity = self:_GetAbsVelocity()
	local vBaseVelocity = self:_GetBaseVelocity()
	local iFrameTime = FrameTime()
	local vMove = (vAbsVelocity + vBaseVelocity) * iFrameTime
	
	if (self:IsFlagSet(FL_ONGROUND)) then
		vMove.z = vBaseVelocity.z * iFrameTime
	else
		local flAbsZ = vAbsVelocity.z
		
		// linear acceleration due to gravity
		local flNewZ = flAbsZ - self:GetActualGravity() * iFrameTime
		vMove.z = ((flAbsZ + flNewZ) / 2 + vBaseVelocity.z) * iFrameTime
		
		vBaseVelocity.z = 0
		self:_SetBaseVelocity(vBaseVelocity)
		vAbsVelocity.z = flNewZ
		self:_SetAbsVelocity(vAbsVelocity)
		
		--PhysicsCheckVelocity();
	end
	
	return vMove
end

local sv_gravity = GetConVar("sv_gravity")

function ENTITY:GetActualGravity()
	local flGravity = self:GetGravity()
	
	return flGravity == 0 and 1 or flGravity * sv_gravity:GetFloat()
end

function ENTITY:PhysicsPushEntity(vPush)
	local tr = self:PhysicsCheckSweep(self:GetPos(), vPush)
	
	if (tr.Fraction ~= 0) then
		self:SetPos(tr.HitPos)
	end
	
	local pEntity = tr.Entity
	
	if (tr.Entity:IsValid()) then
		// If either of the entities is flagged to be deleted, 
		//  don't call the touch functions
		if (not (self:IsFlagSet(FL_KILLME) or pEntity:IsFlagSet(FL_KILLME))) then
			self.m_trTouch = tr
			self.m_bTouched = true
		end
	end
	
	return tr
end

function ENTITY:PerformFlyCollisionResolution(tr)
	local iMoveCollide = self:GetMoveCollide()
	
	--if (iMoveCollisde == MOVECOLLIDE_FLY_CUSTOM) then
		self:ResolveFlyCollisionCustom(tr)
	--[[elseif (iMoveCollide == MOVECOLLIDE_FLY_BOUNCE) then
		self:ResolveFlyCollisionBounce(tr)
	elseif (iMoveCollide == MOVECOLLIDE_FLY_SLIDE or iMoveCollide == MOVECOLLIDE_DEFAULT) then
		// NOTE: The default fly collision state is the same as a slide (for backward capatability).
		self:ResolveFlyCollisionSlide(tr)
	end]]
end

function ENTITY:ResolveFlyCollisionCustom(tr)
	// Stop if on ground
	if (tr.HitNormal.z > 0.7) then // Floor
		// Get the total velocity (player + conveyors, etc.)
		local vAbsVelocity = self:_GetAbsVelocity()
		local vVelocity = vAbsVelocity + self:_GetBaseVelocity()
		
		// Are we on the ground?
		if (vVelocity.z < self:GetActualGravity() * FrameTime()) then
			vAbsVelocity.z = 0
			self:_SetAbsVelocity(vAbsVelocity)
		end
		
		if (self:Standable()) then
			self:SetGroundEntity(tr.Entity)
		end
	end
end

function ENTITY:PhysicsCheckWaterTransition()
	-- We need to generate the water type regardless if we're a child or not
	local iOldCont = self:WaterType()
	self:UpdateWaterState()
	local iNewCont = self:WaterType()
	
	// We can exit right out if we're a child... don't bother with this...
	if (self:GetMoveParent() == NULL) then
		if (bit.band(iNewCont, MASK_WATER) ~= 0) then
			if (iOldCont == CONTENTS_EMPTY) then
				self:Splash()
				
				// just crossed into water
				self:EmitSound("BaseEntity.EnterWater")
				
				if (not self:IsEFlagSet(EFL_NO_WATER_VELOCITY_CHANGE)) then
					local vAbsVelocity = self:GetAbsVelocity()
					vAbsVelocity.z = vAbsVelocity.z / 2
					self:SetAbsVelocity(vAbsVelocity)
				end
			end
		elseif (iOldCont ~= CONTENTS_EMPTY) then
			--self:Splash() -- Splash again!
			
			// just crossed out of water
			self:EmitSound("BaseEntity.ExitWater")
		end
	end
end

local vNormalizeSpace = Vector(0.5, 0.5, 0)

function ENTITY:UpdateWaterState()
	// FIXME: This computation is nonsensical for rigid child attachments
	// Should we just grab the type + level of the parent?
	// Probably for rigid children anyways...

	// Compute the point to check for water state
	local vPoint = self:NormalizedToWorldSpace(vNormalizeSpace)
	local iCont = util.PointContents(vPoint)
	
	if (bit.band(iCont, MASK_WATER) == 0) then
		self:SetWaterLevel(0)
		self:SetWaterType(CONTENTS_EMPTY)
	else
		self:SetWaterType(iCont)
		
		if (self:BoundingRadius() == 0) then
			self:SetWaterLevel(3)
		else
			// Check the exact center of the box
			vPoint.z = self:WorldSpaceCenter().z
			
			local iCont = util.PointContents(vPoint)
			
			if (bit.band(iCont, MASK_WATER) == 0) then
				self:SetWaterLevel(1)
			else
				// Now check where the eyes are...
				vPoint.z = self:EyePos().z
				local iCont = util.PointContents(vPoint)
				
				if (bit.band(iCont, MASK_WATER) == 0) then
					self:SetWaterLevel(2)
				else
					self:SetWaterLevel(3)
				end
			end
		end
	end
end

function ENTITY:PhysicsClipVelocity(vIn, vNormal, flBounce)
	local flAngle = vNormal.z
	local vRet = vIn - vNormal * vIn:Dot(vNormal) * flBounce
	local x = vRet.x
	local y = vRet.y
	local z = vRet.z
	
	if (x > -0.1 and x < 0.1) then
		vRet.x = 0
	end
	
	if (y > -0.1 and y < 0.1) then
		vRet.y = 0
	end
	
	if (z > -0.1 and z < 0.1) then
		vRet.z = 0
	end
	
	return vRet
end

