-- Lua implementation for speed
function IsFirstTimePredicted()
	return true
end

local phys_pushscale = GetConVar("phys_pushscale")

function util.CSRadiusDamage(info, vSrc, flRadius, bIgnoreWorld --[[= false]], Filter --[[= NULL]], iClassIgnore --[[= CLASS_NONE]])
	vSrc = Vector(vSrc) -- Copy vector
	vSrc[3] = vSrc[3] + 1 // in case grenade is lying on the ground
	
	local bFilter = Filter ~= nil
	local bEntityFilter, bTableFilter, bFunctionFilter, iFilterLen
	
	if (bFilter) then
		if (isentity(Filter)) then
			bEntityFilter, bTableFilter, bFunctionFilter = true, false, false
		elseif (istable(Filter)) then
			bEntityFilter, bTableFilter, bFunctionFilter = false, true, false
			iFilterLen = #Filter
		elseif (isfunction(Filter)) then
			bEntityFilter, bTableFilter, bFunctionFilter = false, false, true
		else
			bFilter = false
		end
	end
	
	local flDamage = info:GetDamage()
	local flFalloff = flRadius == 0 and 1 or flDamage / flRadius
	local bInWater = bit.band(util.PointContents(vSrc), MASK_WATER) ~= 0
	local tEnts = ents.FindInSphere(vSrc, flRadius)
	
	// iterate on all entities in the vicinity.
	for i = 1, #tEnts do
		local pEntity = tEnts[i]
		
		if (pEntity:GetSaveValue("m_takedamage") == 0) then
			continue
		end
		
		// UNDONE: this should check a damage mask, not an ignore
		if (iClassIgnore and iClassIgnore ~= CLASS_NONE and pEntity:Classify() == iClassIgnore) then
			// houndeyes don't hurt other houndeyes with their attack
			continue
		end
		
		if (bFilter) then
			if (bEntityFilter) then
				if (Filter == pEntity) then
					continue
				end
			elseif (bTableFilter) then
				local bFound = false
				
				for i = 1, iFilterLen do
					if (Filter[i] == pEntity) then
						-- FIXME
						bFound = true
						
						break
					end
				end
				
				if (bFound) then
					continue
				end
			elseif (bFunctionFilter) then
				if (Filter(pEntity) == false) then
					continue
				end
			end
		end
		
		// blasts don't travel into or out of water
		if (not bIgnoreWorld) then
			if (bInWater) then
				if (pEntity:WaterLevel() == 0) then
					continue
				end
			else
				if (pEntity:WaterLevel() == 3) then
					continue
				end
			end
		end
		
		// radius damage can only be blocked by the world
		local flDamagePercentage
		
		// returns the percentage of the player that is visible from the given point in the world.
		// return value is between 0 and 1.
		if (bIgnoreWorld) then
			flDamagePercentage = 1
		elseif (pEntity:IsPlayer()) then
			local vChest = pEntity:BodyTarget(vSrc)
			
			// check what parts of the player we can see from this point and modify the return value accordingly.
			local flChestZ = vChest[3]
			
			local vFeet = pEntity:GetPos()
			local flPosX = vFeet[1]
			local flPosY = vFeet[2]
			local flPosZ = vFeet[3]
			
			-- FIXME: Adjust for crouch?
			local vMin, vMax = pEntity:GetHull()
			local vRightFacing = (vMax[2] - vMin[2]) / 2 * pEntity:GetAngles():Right()
			
			local flFacingX = vRightFacing[1]
			local flFacingY = vRightFacing[2]
			
				// check chest
			flDamagePercentage = 0.4 * util.GetExplosionDamageAdjustment(vSrc, vChest, pEntity)
				// check top of head
				+ 0.2 * util.GetExplosionDamageAdjustment(vSrc, Vector(flPosX, flPosY, vMax[3] - vMin[3] + flPosZ), pEntity)
				// check feet
				+ 0.2 * util.GetExplosionDamageAdjustment(vSrc, vFeet, pEntity)
				// check left "edge"
				+ 0.1 * util.GetExplosionDamageAdjustment(vSrc, Vector(flPosX - flFacingX, flPosY - flFacingY, flChestZ), pEntity)
				// check right "edge"
				+ 0.1 * util.GetExplosionDamageAdjustment(vSrc, Vector(flPosX + flFacingX, flPosY + flFacingY, flChestZ), pEntity)	
		else
			flDamagePercentage = util.GetExplosionDamageAdjustment(vSrc, pEntity:BodyTarget(vSrc), pEntity)
		end
		
		if (flDamagePercentage > 0) then
			// the explosion can 'see' this entity, so hurt them!
			local vSpot = pEntity:BodyTarget(vSrc, true)
			local vTarget = vSpot - vSrc
			
			// decrease damage for an ent that's farther from the bomb.
			local flAdjustedDamage = (flDamage - vTarget:Length() * flFalloff) * flDamagePercentage
			
			if (flAdjustedDamage > 0) then
				-- https://github.com/Facepunch/garrysmod-issues/issues/2771
				local infoAdjusted = info --:Copy()
				infoAdjusted:SetDamage(flAdjustedDamage)
				vTarget:Normalize()
				
				local vPos = infoAdjusted:GetDamagePosition()
				local vForce = infoAdjusted:GetDamageForce()
				infoAdjusted:SetDamagePosition(vSrc)
				
				// If we don't have a damage force, manufacture one
				if (vPos == vector_origin or vForce == vector_origin) then
					// Calculate an impulse large enough to push a 75kg man 4 in/sec per point of damage
					local flForceScale = infoAdjusted:GetBaseDamage() * 300
					
					if (flForceScale > 30000) then
						flForceScale = 30000
					end
					
					// Fudge blast forces a little bit, so that each
					// victim gets a slightly different trajectory. 
					// This simulates features that usually vary from
					// person-to-person variables such as bodyweight,
					// which are all indentical for characters using the same model.
					infoAdjusted:SetDamageForce(vTarget * flForceScale * gs.random:RandomFloat(0.85, 1.15) * phys_pushscale:GetFloat() * 1.5)
				else
					// Assume the force passed in is the maximum force. Decay it based on falloff.
					infoAdjusted:SetDamageForce(vTarget * vForce:Length() * flFalloff)
				end
				
				local tr = util.TraceLine({
					start = vSrc,
					endpos = pEntity:BodyTarget(vSrc),
					mask = MASK_SHOT
				})
				
				if (tr.Hit) then
					pEntity:DispatchTraceAttack(infoAdjusted, tr, vTarget)
				else
					pEntity:TakeDamageInfo(infoAdjusted)
				end
				
				-- https://github.com/Facepunch/garrysmod-requests/issues/755
				// Now hit all triggers along the way that respond to damage... 
				--pEntity:TraceAttackToTriggers(infoAdjusted, vSrc, vSpot, vTarget)
			end
		end
	end
end

function util.SDKRadiusDamage(info, vSrc, flRadius, bIgnoreWorld --[[= false]], Filter --[[= NULL]], iClassIgnore --[[= CLASS_NONE]])
	vSrc = Vector(vSrc) -- Copy vector
	vSrc[3] = vSrc[3] + 1 // in case grenade is lying on the ground
	
	local bFilter = Filter ~= nil
	local bEntityFilter, bTableFilter, bFunctionFilter, iFilterLen
	
	if (bFilter) then
		if (isentity(Filter)) then
			bEntityFilter, bTableFilter, bFunctionFilter = true, false, false
		elseif (istable(Filter)) then
			bEntityFilter, bTableFilter, bFunctionFilter = false, true, false
			iFilterLen = #Filter
		elseif (isfunction(Filter)) then
			bEntityFilter, bTableFilter, bFunctionFilter = false, false, true
		else
			bFilter = false
		end
	end
	
	local flDamage = info:GetDamage()
	local flFalloff = flRadius == 0 and 1 or flDamage / flRadius
	local bInWater = bit.band(util.PointContents(vSrc), MASK_WATER) ~= 0
	local tEnts = ents.FindInSphere(vSrc, flRadius)
	
	// iterate on all entities in the vicinity.
	for i = 1, #tEnts do
		local pEntity = tEnts[i]
		
		if (pEntity:GetSaveValue("m_takedamage") == 0) then
			continue
		end
		
		// UNDONE: this should check a damage mask, not an ignore
		if (iClassIgnore and iClassIgnore ~= CLASS_NONE and pEntity:Classify() == iClassIgnore) then
			// houndeyes don't hurt other houndeyes with their attack
			continue
		end
		
		if (bFilter) then
			if (bEntityFilter) then
				if (Filter == pEntity) then
					continue
				end
			elseif (bTableFilter) then
				local bFound = false
				
				for i = 1, iFilterLen do
					if (Filter[i] == pEntity) then
						-- FIXME
						bFound = true
						
						break
					end
				end
				
				if (bFound) then
					continue
				end
			elseif (bFunctionFilter) then
				if (Filter(pEntity) == false) then
					continue
				end
			end
		end
		
		// blasts don't travel into or out of water
		if (not bIgnoreWorld) then
			if (bInWater) then
				if (pEntity:WaterLevel() == 0) then
					continue
				end
			else
				if (pEntity:WaterLevel() == 3) then
					continue
				end
			end
		end
		
		local vSpot
		
		if (bIgnoreWorld) then
			vSpot = pEntity:BodyTarget(vSrc, true)
		else
			local tr = util.TraceLine({
				start = vSrc,
				endpos = pEntity:BodyTarget(vSrc, true),
				mask = MASK_SOLID_BRUSHONLY,
				filter = info:GetInflictor()
			})
			
			if (not (tr.StartSolid or tr.Hit) or tr.Entity == pEntity) then
				vSpot = tr.StartSolid and vSrc or tr.HitPos
			end
		end
		
		if (vSpot) then
			// the explosion can 'see' this entity, so hurt them!
			local vTarget = vSpot - vSrc
			
			// decrease damage for an ent that's farther from the bomb.
			local flAdjustedDamage = flDamage - vTarget:Length() * flFalloff
			
			if (flAdjustedDamage > 0) then
				-- https://github.com/Facepunch/garrysmod-issues/issues/2771
				local infoAdjusted = info --:Copy()
				infoAdjusted:SetDamage(flAdjustedDamage)
				vTarget:Normalize()
				
				local vPos = infoAdjusted:GetDamagePosition()
				local vForce = infoAdjusted:GetDamageForce()
				infoAdjusted:SetDamagePosition(vSrc)
				
				// If we don't have a damage force, manufacture one
				if (vPos == vector_origin or vForce == vector_origin) then
					// Calculate an impulse large enough to push a 75kg man 4 in/sec per point of damage
					local flForceScale = infoAdjusted:GetBaseDamage() * 300
					
					if (flForceScale > 30000) then
						flForceScale = 30000
					end
					
					// Fudge blast forces a little bit, so that each
					// victim gets a slightly different trajectory. 
					// This simulates features that usually vary from
					// person-to-person variables such as bodyweight,
					// which are all indentical for characters using the same model.
					infoAdjusted:SetDamageForce(vTarget * flForceScale * gs.random:RandomFloat(0.85, 1.15) * phys_pushscale:GetFloat() * 1.5)
				else
					// Assume the force passed in is the maximum force. Decay it based on falloff.
					infoAdjusted:SetDamageForce(vTarget * vForce:Length() * flFalloff)
				end
				
				pEntity:TakeDamageInfo(infoAdjusted)
				
				-- https://github.com/Facepunch/garrysmod-requests/issues/755
				// Now hit all triggers along the way that respond to damage... 
				--pEntity:TraceAttackToTriggers(infoAdjusted, vSrc, vSpot, vTarget)
			end
		end
	end
end

// return a multiplier that should adjust the damage done by a blast at position vecSrc to something at the position
// vecEnd.  This will take into account the density of an entity that blocks the line of sight from one position to
// the other.
//
// this algorithm was taken from the HL2 version of RadiusDamage.
DENSITY_ABSORB_ALL_DAMAGE = 3000

function util.GetExplosionDamageAdjustment(vSrc, vEnd, Filter --[[= NULL]])
	local tr = util.TraceLine({
		start = vSrc,
		endpos = vEnd,
		mask = MASK_SHOT,
		filter = Filter
	})
	
	if (not tr.Hit) then
		return 1
	end
	
	if (tr.HitWorld) then
		return 0
	end
	
	// if we didn't hit world geometry perhaps there's still damage to be done here.
	
	// check to see if this part of the player is visible if entities are ignored.
	-- FIXME: Apply filter?
	util.TraceLine({
		start = vSrc,
		endpos = vEnd,
		mask = CONTENTS_SOLID,
		output = tr
	})
	
	if (tr.Hit) then
		return 0
	end
	
	local pPhysObj = pEntity:GetPhysicsObject()
	
	if (pPhysObj:IsValid()) then
		local flScale = pPhysObj:GetDensity() / DENSITY_ABSORB_ALL_DAMAGE
		
		if (flScale < 1) then
			return 1 - flScale
		end
		
		return 0
	end
	
	return 0.75 // we're blocked by something that isn't an entity with a physics module or world geometry, just cut damage in half for now.
end
