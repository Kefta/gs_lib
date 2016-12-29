local phys_pushscale = GetConVar("phys_pushscale")

function util.CSRadiusDamage(info, vSrc, flRadius, bIgnoreWorld --[[= false]], Filter --[[= NULL]], iClassIgnore --[[= CLASS_NONE]])
	local flSrcZ = vSrc.z
	vSrc.z = flSrcZ + 1 // in case grenade is lying on the ground
	
	local bFilterTable = Filter and istable(Filter) or false
	local iFilterLen = bFilterTable and #Filter or nil
	local flDamage = info:GetDamage()
	local flFalloff = flRadius == 0 and 1 or flDamage / flRadius
	local bInWater = bit.band(util.PointContents(vSrc), MASK_WATER) ~= 0
	local tEnts = ents.FindInSphere(vSrc, flRadius)
	
	// iterate on all entities in the vicinity.
	for i = 1, #tEnts do
		local pEntity = tEnts[i]
		
		if (pEntity:GetInternalVariable("m_takedamage") == 0) then
			continue
		end
		
		// UNDONE: this should check a damage mask, not an ignore
		if (iClassIgnore and iClassIgnore ~= CLASS_NONE and pEntity:Classify() == iClassIgnore) then
			// houndeyes don't hurt other houndeyes with their attack
			continue
		end
		
		if (Filter) then
			if (bFilterTable) then
				local bPass = false
				
				for i = 1, iFilterLen do
					if (pEntity == Filter[i]) then
						bPass = true
						
						break
					end
				end
				
				if (bPass) then
					continue
				end
			elseif (pEntity == Filter) then
				continue
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
		local flDamagePercentage = bIgnoreWorld and 1 or pEntity:GetAmountVisible(vSrc)
		
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
					infoAdjusted:SetDamageForce(vTarget * flForceScale * code_gs.random:RandomFloat(0.85, 1.15) * phys_pushscale:GetFloat() * 1.5)
				else
					// Assume the force passed in is the maximum force. Decay it based on falloff.
					infoAdjusted:SetDamageForce(vTarget * vForce:Length() * flFalloff)
				end
				
				local tr = util.TraceLine({
					start = vSrc,
					endpos = pEntity:BodyTarget(vSrc),
					mask = MASK_SHOT
				})
				
				if (tr.Fraction == 1) then
					pEntity:TakeDamageInfo(infoAdjusted)
				else
					pEntity:DispatchTraceAttack(infoAdjusted, tr, vTarget)
				end
				
				-- https://github.com/Facepunch/garrysmod-requests/issues/755
				// Now hit all triggers along the way that respond to damage... 
				--pEntity:TraceAttackToTriggers(infoAdjusted, vSrc, vSpot, vTarget)
			end
		end
	end
	
	-- Restore the vector
	vSrc.z = flSrcZ
end

function util.SDKRadiusDamage(info, vSrc, flRadius, bIgnoreWorld --[[= false]], Filter --[[= NULL]], iClassIgnore --[[= CLASS_NONE]])
	local flSrcZ = vSrc.z
	vSrc.z = flSrcZ + 1 // in case grenade is lying on the ground
	
	local bFilterTable = Filter and istable(Filter) or false
	local iFilterLen = bFilterTable and #Filter or nil
	local flDamage = info:GetDamage()
	local flFalloff = flRadius == 0 and 1 or flDamage / flRadius
	local bInWater = bit.band(util.PointContents(vSrc), MASK_WATER) ~= 0
	local tEnts = ents.FindInSphere(vSrc, flRadius)
	
	// iterate on all entities in the vicinity.
	for i = 1, #tEnts do
		local pEntity = tEnts[i]
		
		if (pEntity:GetInternalVariable("m_takedamage") == 0) then
			continue
		end
		
		// UNDONE: this should check a damage mask, not an ignore
		if (iClassIgnore and iClassIgnore ~= CLASS_NONE and pEntity:Classify() == iClassIgnore) then
			// houndeyes don't hurt other houndeyes with their attack
			continue
		end
		
		if (Filter) then
			if (bFilterTable) then
				local bPass = false
				
				for i = 1, iFilterLen do
					if (pEntity == Filter[i]) then
						bPass = true
						
						break
					end
				end
				
				if (bPass) then
					continue
				end
			elseif (pEntity == Filter) then
				continue
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
			
			if (not tr.StartSolid and tr.Fraction == 1 or tr.Entity == pEntity) then
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
					infoAdjusted:SetDamageForce(vTarget * flForceScale * code_gs.random:RandomFloat(0.85, 1.15) * phys_pushscale:GetFloat() * 1.5)
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
	
	-- Restore the vector
	vSrc.z = flSrcZ
end

// return a multiplier that should adjust the damage done by a blast at position vecSrc to something at the position
// vecEnd.  This will take into account the density of an entity that blocks the line of sight from one position to
// the other.
//
// this algorithm was taken from the HL2 version of RadiusDamage.
DENSITY_ABSORB_ALL_DAMAGE = 3000

function util.GetExplosionDamageAdjustment(vSrc, vEnd, Filter)
	local tr = util.TraceLine({
		start = vSrc,
		endpos = vEnd,
		mask = MASK_SHOT,
		filter = Filter
	})
	
	if (tr.Fraction == 1) then
		return 1
	end
	
	if (tr.HitWorld) then
		return 0
	end
	
	local pEntity = tr.Entity
	
	if (pEntity == NULL or isentity(Filter) and pEntity:GetOwner() == Filter) then
		return 0
	end
	
	if (istable(Filter)) then
		for i = 1, #Filter do
			if (Filter[i] == pEntity) then
				return 0
			end
		end
	end
	
	// if we didn't hit world geometry perhaps there's still damage to be done here.
	// check to see if this part of the player is visible if entities are ignored.
	util.TraceLine({
		start = vSrc,
		endpos = vEnd,
		mask = CONTENTS_SOLID,
		output = tr
	})
	
	if (tr.Fraction == 1) then
		local pPhysicsObj = pEntity:GetPhysicsObject()
		
		if (pEntity == NULL or pPhysicsObj:IsValid()) then
			return 0.75 // we're blocked by something that isn't an entity with a physics module or world geometry, just cut damage in half for now.
		end
		
		local flScale = pPhysicsObj:GetDensity() / DENSITY_ABSORB_ALL_DAMAGE
		
		if (flScale < 1) then
			return 1 - flScale
		end
	end
	
	return 0
end