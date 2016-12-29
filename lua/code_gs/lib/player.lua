local PLAYER = FindMetaTable("Player")

-- Equivalent of CBasePlayer::EyeVectors() before AngleVecotrs
function PLAYER:ActualEyeAngles()
	local pVehicle = self:GetVehicle()
	
	if (CLIENT or pVehicle == NULL) then
		return self:EyeAngles()
	end
	
	// Cache or retrieve our calculated position in the vehicle
	-- https://github.com/Facepunch/garrysmod-requests/issues/782
	local iFrameCount = FrameNumber and FrameNumber() or CurTime()

	// If we've calculated the view this frame, then there's no need to recalculate it
	if (self.m_iVehicleViewSavedFrame ~= iFrameCount) then
		self.m_iVehicleViewSavedFrame = iFrameCount
		
		// Get our view for this frame
		-- https://github.com/Facepunch/garrysmod-requests/issues/760
		local _, ang = pVehicle:GetVehicleViewPosition(1)
		self.m_aVehicleViewAngles = ang
	end
	
	return self.m_aVehicleViewAngles
end

local vPlayerOffset = Vector(0, 0, -4)

function PLAYER:ComputeTracerStartPosition(vSrc)
	// adjust tracer position for player
	local aEyes = self:ActualEyeAngles()
	
	return vSrc + vPlayerOffset + aEyes:Right() * 2 + aEyes:Forward() * 16
end

--- GameRules
-- bIgnoreCategory: Switch to weapon based purely on weight, and not the same category
-- bCritical: Emergency! Allow us to switch to a weapon with no ammo or NULL
function PLAYER:GetNextBestWeapon(bIgnoreCategory, bCritical)
	-- Why use a gamerules function for this when we can just do it here?
	-- This is a mix of the multiplay/singleplay algorithms
	local pCurrent = self:GetActiveWeapon()
	local pBestWep
	local pFallbackWep
	
	// Search for the best weapon to use next based on its weight
	for _, pCheck in pairs(self:GetWeapons()) do -- Discontinous table
		// If we have an active weapon and this weapon doesn't allow autoswitching away
		// from another weapon, skip it.
		if (pCheck:AllowsAutoSwitchTo() and pCheck ~= pCurrent) then
			if (pCheck:HasAmmo()) then
				local iWeight = pCheck:GetWeight()
		
				if (not bIgnoreCategory and iWeight == pCurrent:GetWeight()) then
					return pCheck -- We found a perfect match
				end
		
				if (not pBestWep or iWeight > pBestWep:GetWeight()) then
					pBestWep = pCheck
				end
			else
				-- If it's an emergency, have a backup regardless of ammo
				if (bCritical and not pFallbackWep) then
					pFallbackWep = pCheck
				end
			end
		end
	end
	
	-- If the weapon is going to be removed, do not re-deploy
	return pBestWep or pFallbackWep or (bCritical and NULL or pCurrent)
end

function PLAYER:MouseLifted()
	return not (self:KeyDown(IN_ATTACK) or self:KeyDown(IN_ATTACK2))
end

FIRE_BULLETS_FIRST_SHOT_ACCURATE = 0x1 // Pop the first shot with perfect accuracy
FIRE_BULLETS_DONT_HIT_UNDERWATER = 0x2 // If the shot hits its target underwater, don't damage it
FIRE_BULLETS_ALLOW_WATER_SURFACE_IMPACTS = 0x4 // If the shot hits water surface, still call DoImpactEffect
-- The engine alerts NPCs by pushing a sound onto a static sound manager
-- However, this cannot be accessed from the Lua state
--FIRE_BULLETS_TEMPORARY_DANGER_SOUND = 0x8 // Danger sounds added from this impact can be stomped immediately if another is queued

local ai_debug_shoot_positions = GetConVar("ai_debug_shoot_positions")
local phys_pushscale = GetConVar("phys_pushscale")
local sv_showimpacts = CreateConVar("sv_showimpacts", "0", FCVAR_REPLICATED, "Shows client (red) and server (blue) bullet impact point (1=both, 2=client-only, 3=server-only)")
local sv_showpenetration = CreateConVar("sv_showpenetration", "0", FCVAR_REPLICATED, "Shows penetration trace (if applicable) when the weapon fires")
local sv_showplayerhitboxes = CreateConVar("sv_showplayerhitboxes", "0", FCVAR_REPLICATED, "Show lag compensated hitboxes for the specified player index whenever a player fires.")

local vDefaultMax = Vector(3, 3, 3)
local vDefaultMin = -vDefaultMax

local nWhizTracer = bit.bor(0x0002, 0x0001)
local iTracerCount = 0 -- Instance global to interact with FireBullets functions

-- Player only as NPCs could not be overrided to use this function
function PLAYER:FireLuaBullets(bullets)
	if (hook.Run("EntityFireBullets", self, bullets) == false) then
		return
	end
	
	self:LagCompensation(true)
	
	local pWeapon = self:GetActiveWeapon()
	local bWeaponInvalid = pWeapon == NULL
	
	-- FireBullets info
	local sAmmoType
	local iAmmoType
	
	if (not bullets.AmmoType) then
		sAmmoType = ""
		iAmmoType = -1
	elseif (isstring(bullets.AmmoType)) then
		sAmmoType = bullets.AmmoType
		iAmmoType = game.GetAmmoID(sAmmoType)
	else
		iAmmoType = bullets.AmmoType
		sAmmoType = game.GetAmmoName(iAmmoType)
	end
	
	local pAttacker = bullets.Attacker and bullets.Attacker ~= NULL and bullets.Attacker or self
	local fCallback = bullets.Callback
	local iDamage = bullets.Damage or 1
	local vDir = bullets.Dir:GetNormal() or self:GetAimVector()
	local flDistance = bullets.Distance or MAX_TRACE_LENGTH
	local Filter = bullets.Filter or self
	local iFlags = bullets.Flags or 0
	local flForce = bullets.Force or 1
	local pInflictor = bullets.Inflictor and bullets.Inflictor ~= NULL and bullets.Inflictor or bWeaponInvalid and self or pWeapon
	local iMask = bullets.Mask or MASK_SHOT
	local iNPCDamage = bullets.NPCDamage or 0
	local iNum = bullets.Num or 1
	local iPlayerDamage = bullets.PlayerDamage or 0
	local vSrc = bullets.Src or self:GetShootPos()
	local iTracerFreq = bullets.Tracer or 1
	local sTracerName = bullets.TracerName or "Tracer"
	
	-- Ammo
	local iAmmoFlags = game.GetAmmoFlags(sAmmoType)
	local flAmmoForce = game.GetAmmoForce(sAmmoType)
	local iAmmoDamageType = game.GetAmmoDamageType(sAmmoType)
	local iAmmoPlayerDamage = game.GetAmmoPlayerDamage(sAmmoType)
	local iAmmoMinSplash = game.GetAmmoMinSplash(sAmmoType)
	local iAmmoMaxSplash = game.GetAmmoMaxSplash(sAmmoType)
	local iAmmoTracerType = game.GetAmmoTracerType(sAmmoType)
	
	if (bit.band(iAmmoFlags, AMMO_INTERPRET_PLRDAMAGE_AS_DAMAGE_TO_PLAYER) ~= 0) then
		if (iPlayerDamage == 0) then
			iPlayerDamage = iAmmoPlayerDamage
		end
		
		if (iNPCDamage == 0) then
			iNPCDamage = game.GetAmmoNPCDamage(sAmmoType)
		end
	end
	
	-- Loop values
	local bDrop = bit.band(iAmmoFlags, AMMO_FORCE_DROP_IF_CARRIED) ~= 0
	local bDebugShoot = ai_debug_shoot_positions:GetBool()
	local bFirstShotInaccurate = bit.band(iFlags, FIRE_BULLETS_FIRST_SHOT_ACCURATE) == 0
	local flPhysPush = phys_pushscale:GetFloat()
	local bShowPenetration = sv_showpenetration:GetBool()
	local bStartedInWater = bit.band(util.PointContents(vSrc), MASK_WATER) ~= 0
	local bFirstTimePredicted = IsFirstTimePredicted()
	local flSpreadBias, flFlatness, flSpreadX, flSpreadY, bNegBias, vFireBulletMax, vFireBulletMin, vSpreadRight, vSpreadUp
	
	// Wrap it for network traffic so it's the same between client and server
	local iSeed = self:GetMD5Seed() % 0x100 - 1
	
	-- Don't calculate stuff we won't end up using
	if (bFirstShotInaccurate or iNum ~= 1) then
		flSpreadBias = bullets.SpreadBias or 0.5
		bNegBias = false
		
		if (flSpreadBias > 1) then
			flSpreadBias = 1
			bNegBias = true
			flSpreadBias = -flSpreadBias
		elseif (flSpreadBias < -1) then
			flSpreadBias = -1
			bNegBias = false
		else
			bNegBias = flSpreadBias < 0
			
			if (bNegBias) then
				flSpreadBias = -flSpreadBias
			end
		end
		
		local vSpread = bullets.Spread or vector_origin
		flSpreadX = vSpread[1]
		flSpreadY = vSpread[2]
		vSpreadRight = vSpread:Right()
		vSpreadUp = vSpread:Up()
		
		if (iNum ~= 1) then
			local flHullSize = bullets.HullSize
			
			if (flHullSize) then
				vFireBulletMax = Vector(flHullSize, flHullSize, flHullSize)
				vFireBulletMin = -vFireBulletMax
			else
				vFireBulletMax = vDefaultMax
				vFireBulletMin = vDefaultMin
			end
		end
	end
	
	//Adrian: visualize server/client player positions
	//This is used to show where the lag compesator thinks the player should be at.
	local iHitNum = sv_showplayerhitboxes:GetInt()
	
	if (iHitNum > 0) then
		local pLagPlayer = Player(iHitNum)
		
		if (pLagPlayer ~= NULL) then
			pLagPlayer:DrawHitBoxes(DEBUG_LENGTH)
		end
	end
	
	iHitNum = sv_showimpacts:GetInt()
	
	for iShot = 1, iNum do
		local vShotDir
		iSeed = iSeed + 1 // use new seed for next bullet
		code_gs.random:SetSeed(iSeed) // init random system with this seed
		
		// If we're firing multiple shots, and the first shot has to be ba on target, ignore spread
		if (bFirstShotInaccurate or iShot ~= 1) then
			local x
			local y
			local z

			repeat
				x = code_gs.random:RandomFloat(-1, 1) * flSpreadBias + code_gs.random:RandomFloat(-1, 1) * (1 - flSpreadBias)
				y = code_gs.random:RandomFloat(-1, 1) * flSpreadBias + code_gs.random:RandomFloat(-1, 1) * (1 - flSpreadBias)

				if (bNegBias) then
					x = x < 0 and -(1 + x) or 1 - x
					y = y < 0 and -(1 + y) or 1 - y
				end

				z = x * x + y * y
			until (z <= 1)

			vShotDir = vDir + x * flSpreadX * vSpreadRight + y * flSpreadY * vSpreadUp
			vShotDir:Normalize()
		else
			vShotDir = vDir:GetNormal()
		end
		
		local bHitGlass
		local vEnd = vSrc + vShotDir * flDistance
		local vNewSrc = vSrc
		local vFinalHit
		
		repeat
			local tr = iShot % 2 == 0 and
				// Half of the shotgun pellets are hulls that make it easier to hit targets with the shotgun.
				util.TraceHull({
					start = vNewSrc,
					endpos = vEnd,
					mins = vFireBulletMin,
					maxs = vFireBulletMax,
					mask = iMask,
					filter = Filter
				})
			or
				util.TraceLine({
					start = vNewSrc,
					endpos = vEnd,
					mask = iMask,
					filter = Filter
				})
			
			--[[if (SERVER) then
				if (bStartedInWater) then
					local flLengthSqr = vSrc:DistToSqr(tr.HitPos)
					
					if (flLengthSqr > SHOT_UNDERWATER_BUBBLE_DIST * SHOT_UNDERWATER_BUBBLE_DIST) then
						util.BubbleTrail(self:ComputeTracerStartPosition(vSrc),
						vSrc + SHOT_UNDERWATER_BUBBLE_DIST * vShotDir,
						WATER_BULLET_BUBBLES_PER_INCH * SHOT_UNDERWATER_BUBBLE_DIST)
					else
						local flLength = math.sqrt(flLengthSqr) - 0.1
						util.BubbleTrail(self:ComputeTracerStartPosition(vSrc),
						vSrc + flLength * vShotDir,
						SHOT_UNDERWATER_BUBBLE_DIST * flLength)
					end
				end
				
				// Now hit all triggers along the ray that respond to shots...
				// Clip the ray to the first collided solid returned from traceline
				-- https://github.com/Facepunch/garrysmod-requests/issues/755
				local triggerInfo = DamageInfo()
					triggerInfo:SetAttacker(pAttacker)
					triggerInfo:SetInflictor(pAttacker)
					triggerInfo:SetDamage(iDamage)
					triggerInfo:SetDamageType(iAmmoDamageType)
					triggerInfo:CalculateBulletDamageForce(sAmmoType, vShotDir, tr.HitPos, tr.HitPos, flForce)
					triggerInfo:SetAmmoType(iAmmoType)
				triggerInfo:TraceAttackToTriggers(triggerInfo, vSrc, tr.HitPos, vShotDir)
			end]]
			
			local pEntity = tr.Entity
			local vHitPos = tr.HitPos
			vFinalHit = vHitPos
			
			local bEndNotWater = bit.band(util.PointContents(tr.HitPos), MASK_WATER) == 0
			local trSplash = bStartedInWater and bEndNotWater and
				util.TraceLine({
					start = vHitPos,
					endpos = vSrc,
					mask = MASK_WATER
				})
			// See if the bullet ended up underwater + started out of the water
			or not (bStartedInWater or bEndNotWater) and
				util.TraceLine({
					start = vSrc,
					endpos = vHitPos,
					mask = MASK_WATER
				})
			
			if (trSplash and (bWeaponInvalid or not (pWeapon.DoSplashEffect and pWeapon:DoSplashEffect(trSplash))) and bFirstTimePredicted) then
				local data = EffectData()
					data:SetOrigin(trSplash.HitPos)
					data:SetScale(code_gs.random:RandomFloat(iAmmoMinSplash, iAmmoMaxSplash))
					
					if (bit.band(util.PointContents(trSplash.HitPos), CONTENTS_SLIME) ~= 0) then
						data:SetFlags(FX_WATER_IN_SLIME)
					end
					
				util.Effect("gunshotsplash", data)
			end
			
			if (tr.Fraction == 1 or pEntity == NULL) then
				break // we didn't hit anything, stop tracing shoot
			end
			
			// draw server impact markers
			if (iHitNum == 1 or (CLIENT and iHitNum == 2) or (SERVER and iHitNum == 3)) then
				debugoverlay.Box(vHitPos, vector_debug_min, vector_debug_max, DEBUG_LENGTH, color_debug)
			end
			
			// do damage, paint decals
			-- https://github.com/Facepunch/garrysmod-issues/issues/2741
			bHitGlass = --[[tr.MatType == MAT_GLASS]] pEntity:GetClass():find("func_breakable", 1, true) and not pEntity:HasSpawnFlags(SF_BREAK_NO_BULLET_PENETRATION)
			
			if (not bStartedWater and bEndNotWater or bit.band(iFlags, FIRE_BULLETS_DONT_HIT_UNDERWATER) == 0) then
				-- The engine considers this a float
				-- Even though no values assigned to it are
				local iActualDamage = iDamage
				
				// If we hit a player, and we have player damage specified, use that instead
				// Adrian: Make sure to use the currect value if we hit a vehicle the player is currently driving.
				-- We don't check for vehicle passengers since GMod has no C++ vehicles with them
				if (pEntity:IsPlayer()) then
					if (iPlayerDamage ~= 0) then
						iActualDamage = iPlayerDamage
					end
				elseif (pEntity:IsNPC()) then
					if (iNPCDamage ~= 0) then
						iActualDamage = iNPCDamage
					end
				-- https://github.com/Facepunch/garrysmod-requests/issues/760
				elseif (SERVER and pEntity:IsVehicle()) then
					local pDriver = pEntity:GetDriver()
					
					if (iPlayerDamage ~= 0 and pDriver:IsPlayer()) then
						iActualDamage = iPlayerDamage
					elseif (iNPCDamage ~= 0 and pDriver:IsNPC()) then
						iActualDamage = iNPCDamage
					end
				end
				
				if (iActualDamage == 0) then
					iActualDamage = iAmmoPlayerDamage == 0 and iDamage or iAmmoPlayerDamage -- Only players fire through this
				end
				
				// Damage specified by function parameter
				local info = DamageInfo()
					info:SetAttacker(pAttacker)
					info:SetInflictor(pInflictor)
					info:SetDamage(iActualDamage)
					info:SetDamageType(iAmmoDamageType)
					info:SetDamagePosition(vHitPos)
					info:SetDamageForce(vShotDir * flAmmoForce * flForce * flPhysPush)
					info:SetAmmoType(iAmmoType)
					info:SetReportedPosition(vSrc)
				pEntity:DispatchTraceAttack(info, tr, vShotDir)
				
				if (fCallback) then
					fCallback(pAttacker, tr, info)
				end
				
				if (bEndNotWater or bit.band(iFlags, FIRE_BULLETS_ALLOW_WATER_SURFACE_IMPACTS) ~= 0) then
					if (bWeaponInvalid or not pWeapon.DoImpactEffect or not pWeapon:DoImpactEffect(tr, iAmmoDamageType)) then
						if (bFirstTimePredicted) then
							local data = EffectData()
								data:SetOrigin(tr.HitPos)
								data:SetStart(vSrc)
								data:SetSurfaceProp(tr.SurfaceProps)
								data:SetDamageType(iAmmoDamageType)
								data:SetHitBox(tr.HitBox)
								data:SetEntity(pEntity)
							util.Effect("Impact", data)
						end
					elseif (bFirstTimePredicted) then
						// We may not impact, but we DO need to affect ragdolls on the client
						local data = EffectData()
							data:SetOrigin(tr.HitPos)
							data:SetStart(vSrc)
							data:SetDamageType(iAmmoDamageType)
						util.Effect("RagdollImpact", data)
					end
				end
			end
			
			if (bDrop and SERVER) then
				// Make sure if the player is holding this, he drops it
				DropEntityIfHeld(pEntity)
			end
			
			// See if we hit glass
			// Query the func_breakable for whether it wants to allow for bullet penetration
			if (bHitGlass) then
				local tEnts = ents.GetAll()
				local iLen = #tEnts
				
				-- Trace for only the entity we hit
				for i = iLen, 1, -1 do
					if (tEnts[i] == pEntity) then
						tEnts[i] = tEnts[iLen]
						tEnts[iLen] = nil
						
						break
					end
				end
				
				util.TraceLine({
					start = vEnd,
					endpos = vHitPos,
					mask = iMask,
					filter = tEnts,
					ignoreworld = true,
					output = tr
				})
				
				if (bShowPenetration) then
					debugoverlay.Line(vEnd, vHitPos, DEBUG_LENGTH, color_altdebug)
				end
				
				if (iHitNum == 1 or (CLIENT and iHitNum == 2) or (SERVER and iHitNum == 3)) then
					debugoverlay.Box(tr.HitPos, vector_debug_min, vector_debug_max, DEBUG_LENGTH, color_altdebug)
				end
				
				// bullet did penetrate object, exit Decal
				if ((bWeaponInvalid or not pWeapon.DoImpactEffect or not pWeapon:DoImpactEffect(tr, iAmmoDamageType)) and bFirstTimePredicted) then
					local data = EffectData()
						data:SetOrigin(tr.HitPos)
						data:SetStart(tr.StartPos)
						data:SetSurfaceProp(tr.SurfaceProps)
						data:SetDamageType(iAmmoDamageType)
						data:SetHitBox(tr.HitBox)
						data:SetEntity(pEntity)
					util.Effect("Impact", data)
				end
			
				vNewSrc = tr.HitPos
			end
		until (not bHitGlass)
		
		if (bDebugShoot) then
			debugoverlay.Line(vSrc, vFinalHit, DEBUG_LENGTH, color_debug)
		end
		
		if (bFirstTimePredicted and iTracerFreq > 0) then
			if (iTracerCount % iTracerFreq == 0) then
				local data = EffectData()
					local iAttachment
					
					if (bWeaponInvalid) then
						data:SetStart(self:ComputeTracerStartPosition(vSrc, 1))
						data:SetAttachment(1)
					else
						local iAttachment = pWeapon.GetMuzzleAttachment and pWeapon:GetMuzzleAttachment() or 1
						data:SetStart(pWeapon.GetTracerOrigin and pWeapon:GetTracerOrigin() or self:ComputeTracerStartPosition(vSrc, iAttachment))
						data:SetAttachment(iAttachment)
					end
					
					data:SetOrigin(vFinalHit)
					data:SetScale(0)
					data:SetEntity(bWeaponInvalid and self or pWeapon)
					data:SetFlags(iAmmoTracerType == TRACER_LINE_AND_WHIZ and nWhizTracer or 0x0002)
				util.Effect(sTracerName, data)
			end
			
			iTracerCount = iTracerCount + 1
		end
	end
	
	self:LagCompensation(false)
end

function PLAYER:FireEntityBullets(tBullets, sClass)
	if (SERVER) then
		local pBullet = ents.Create(sClass or "gs_bullet")
		
		if (pBullet ~= NULL) then
			pBullet:SetupBullet(tBullets)
			pBullet:Spawn()
		end
	end
end

local tMaterialParameters = {
	[MAT_METAL] = {
		Penetration = 0.5,
		Damage = 0.3
	},
	[MAT_DIRT] = {
		Penetration = 0.5,
		Damage = 0.3
	},
	[MAT_CONCRETE] = {
		Penetration = 0.4,
		Damage = 0.25
	},
	[MAT_GRATE] = {
		Penetration = 1,
		Damage = 0.99
	},
	[MAT_VENT] = {
		Penetration = 0.5,
		Damage = 0.45
	},
	[MAT_TILE] = {
		Penetration = 0.65,
		Damage = 0.3
	},
	[MAT_COMPUTER] = {
		Penetration = 0.4,
		Damage = 0.45
	},
	[MAT_WOOD] = {
		Penetration = 1,
		Damage = 0.6
	},
	[MAT_GLASS] = {
		Penetration = 1,
		Damage = 0.99
	}
}

local tDoublePenetration = {
	[MAT_WOOD] = true,
	[MAT_METAL] = true,
	[MAT_GRATE] = true,
	[MAT_GLASS] = true
}

local MASK_HITBOX = bit.bor(MASK_SOLID, CONTENTS_DEBRIS, CONTENTS_HITBOX)

function PLAYER:FireCSSBullets(bullets)
	if (hook.Run("EntityFireCSSBullets", self, bullets) == false) then
		return
	end
	
	self:LagCompensation(true)
	
	local pWeapon = self:GetActiveWeapon()
	local bWeaponInvalid = pWeapon == NULL
	
	-- FireCSSBullets info
	local sAmmoType
	local iAmmoType
	
	if (not bullets.AmmoType) then
		sAmmoType = ""
		iAmmoType = -1
	elseif (isstring(bullets.AmmoType)) then
		sAmmoType = bullets.AmmoType
		iAmmoType = game.GetAmmoID(sAmmoType)
	else
		iAmmoType = bullets.AmmoType
		sAmmoType = game.GetAmmoName(iAmmoType)
	end
	
	local pAttacker = bullets.Attacker and bullets.Attacker ~= NULL and bullets.Attacker or self
	local fCallback = bullets.Callback
	local iDamage = bullets.Damage or 1
	local flDistance = bullets.Distance or MAX_TRACE_LENGTH
	local flExitMaxDistance = bullets.ExitMaxDistance or 128
	local flExitStepSize = bullets.ExitStepSize or 24
	
	local bFilterIsFunction
	local iFilterEnd
	local Filter = bullets.Filter
	
	-- Yes, this is dirty
	-- But this prevents tables from being created when it's not necessary
	-- Also supports functional filters
	if (Filter) then
		local sType = type(Filter)
		
		if (sType == "function") then
			bFilterIsFunction = true
		else
			iFilterEnd = sType ~= "table" and -1 or nil
		end
	else
		Filter = self
		iFilterEnd = -1
		bFilterIsFunction = false
	end
	
	local iFlags = bullets.Flags or 0
	local flForce = bullets.Force or 1
	--local flHitboxTolerance = bullets.HitboxTolerance or 40
	local pInflictor = bullets.Inflictor and bullets.Inflictor ~= NULL and bullets.Inflictor or bWeaponInvalid and self or pWeapon
	local iMask = bullets.Mask or MASK_HITBOX
	local iNum = bullets.Num or 1
	local iPenetration = bullets.Penetration or 0
	local flRangeModifier = bullets.RangeModifier or 1
	local aShootAngles = bullets.ShootAngles or self:EyeAngles()
	local vSrc = bullets.Src or self:GetShootPos()
	local iTracerFreq = bullets.Tracer or 1
	local sTracerName = bullets.TracerName or "Tracer"
	
	-- Ammo
	local iAmmoFlags = game.GetAmmoFlags(sAmmoType)
	local flAmmoForce = game.GetAmmoForce(sAmmoType)
	local iAmmoDamageType = game.GetAmmoDamageType(sAmmoType)
	local iAmmoMinSplash = game.GetAmmoMinSplash(sAmmoType)
	local iAmmoMaxSplash = game.GetAmmoMaxSplash(sAmmoType)
	local iAmmoTracerType = game.GetAmmoTracerType(sAmmoType)
	local flPenetrationDistance = game.GetAmmoKey(sAmmoType, "penetrationdistance", 0)
	local flPenetrationPower = game.GetAmmoKey(sAmmoType, "penetrationpower", 0)
	
	-- Loop values
	local bDrop = bit.band(iAmmoFlags, AMMO_FORCE_DROP_IF_CARRIED) ~= 0
	local bDebugShoot = ai_debug_shoot_positions:GetBool()
	local bFirstShotInaccurate = bit.band(iFlags, FIRE_BULLETS_FIRST_SHOT_ACCURATE) == 0
	local flPhysPush = phys_pushscale:GetFloat()
	local vShootForward = aShootAngles:Forward()
	local bShowPenetration = sv_showpenetration:GetBool()
	local bStartedInWater = bit.band(util.PointContents(vSrc), MASK_WATER) ~= 0
	local bFirstTimePredicted = IsFirstTimePredicted()
	local vShootRight, vShootUp, flSpreadBias
	
	// Wrap it for network traffic so it's the same between client and server
	local iSeed = self:GetMD5Seed() % 0x100
	
	-- Don't calculate stuff we won't end up using
	if (bFirstShotInaccurate or iNum ~= 1) then
		local vSpread = bullets.Spread or vector_origin
		flSpreadBias = bullets.SpreadBias or 0.5
		vShootRight = vSpread[1] * aShootAngles:Right()
		vShootUp = vSpread[2] * aShootAngles:Up()
	end
	
	//Adrian: visualize server/client player positions
	//This is used to show where the lag compesator thinks the player should be at.
	local iHitNum = sv_showplayerhitboxes:GetInt()
	
	if (iHitNum > 0) then
		local pLagPlayer = Player(iHitNum)
		
		if (pLagPlayer ~= NULL) then
			pLagPlayer:DrawHitBoxes(DEBUG_LENGTH)
		end
	end
	
	iHitNum = sv_showimpacts:GetInt()
	
	for iShot = 1, iNum do
		local vShotDir
		iSeed = iSeed + 1 // use new seed for next bullet
		code_gs.random:SetSeed(iSeed) // init random system with this seed
		
		-- Loop values
		local flCurrentDamage = iDamage	// damage of the bullet at it's current trajectory
		local flCurrentDistance = 0	// distance that the bullet has traveled so far
		local vNewSrc = vSrc
		local vFinalHit
		
		// add the spray 
		if (bFirstShotInaccurate or iShot ~= 1) then
			vShotDir = vShootForward + vShootRight * (code_gs.random:RandomFloat(-flSpreadBias, flSpreadBias) + code_gs.random:RandomFloat(-flSpreadBias, flSpreadBias))
			+ vShootUp * (code_gs.random:RandomFloat(-flSpreadBias, flSpreadBias) + code_gs.random:RandomFloat(-flSpreadBias, flSpreadBias))
			vShotDir:Normalize()
		else
			vShotDir = vShootForward
		end
		
		local vEnd = vNewSrc + vShotDir * flDistance
		
		repeat
			local tr = util.TraceLine({
				start = vNewSrc,
				endpos = vEnd,
				mask = iMask,
				filter = Filter
			})
			
			// Check for player hitboxes extending outside their collision bounds
			--util.ClipTraceToPlayers(tr, vNewSrc, vEnd + vShotDir * flHitboxTolerance, Filter, iMask)
			
			local pEntity = tr.Entity
			local vHitPos = tr.HitPos
			vFinalHit = vHitPos
			
			local bEndNotWater = bit.band(util.PointContents(tr.HitPos), MASK_WATER) == 0
			local trSplash = bStartedInWater and bEndNotWater and
				util.TraceLine({
					start = vHitPos,
					endpos = vSrc,
					mask = MASK_WATER
				})
			// See if the bullet ended up underwater + started out of the water
			or not (bStartedInWater or bEndNotWater) and
				util.TraceLine({
					start = vSrc,
					endpos = vHitPos,
					mask = MASK_WATER
				})
			
			if (trSplash and (bWeaponInvalid or not (pWeapon.DoSplashEffect and pWeapon:DoSplashEffect(trSplash))) and bFirstTimePredicted) then
				local data = EffectData()
					data:SetOrigin(trSplash.HitPos)
					data:SetScale(code_gs.random:RandomFloat(iAmmoMinSplash, iAmmoMaxSplash))
					
					if (bit.band(util.PointContents(trSplash.HitPos), CONTENTS_SLIME) ~= 0) then
						data:SetFlags(FX_WATER_IN_SLIME)
					end
				util.Effect("gunshotsplash", data)
			end
			
			if (tr.Fraction == 1 or pEntity == NULL) then
				break // we didn't hit anything, stop tracing shoot
			end
			
			// draw server impact markers
			if (iHitNum == 1 or (CLIENT and iHitNum == 2) or (SERVER and iHitNum == 3)) then
				debugoverlay.Box(vHitPos, vector_debug_min, vector_debug_max, DEBUG_LENGTH, color_debug)
			end
			
			/************* MATERIAL DETECTION ***********/
			-- FIXME: Change this to use SurfaceProps if we can load our own version
			local iEnterMaterial = tr.MatType
			
			-- https://github.com/Facepunch/garrysmod-requests/issues/787
			// since some railings in de_inferno are CONTENTS_GRATE but CHAR_TEX_CONCRETE, we'll trust the
			// CONTENTS_GRATE and use a high damage modifier.
			// If we're a concrete grate (TOOLS/TOOLSINVISIBLE texture) allow more penetrating power.
			local bHitGrate = iEnterMaterial == MAT_GRATE or bit.band(util.PointContents(vHitPos), CONTENTS_GRATE) ~= 0
			
			// calculate the damage based on the distance the bullet travelled.
			flCurrentDistance = flCurrentDistance + tr.Fraction * flDistance
			flCurrentDamage = flCurrentDamage * flRangeModifier ^ (flCurrentDistance / 500)
			
			// check if we reach penetration distance, no more penetrations after that
			if (flCurrentDistance > flPenetrationDistance and iPenetration > 0) then
				iPenetration = 0
			end
			
			if (not bStartedWater and bEndNotWater or bit.band(iFlags, FIRE_BULLETS_DONT_HIT_UNDERWATER) == 0) then
				// add damage to entity that we hit
				local info = DamageInfo()
					info:SetAttacker(pAttacker)
					info:SetInflictor(pInflictor)
					info:SetDamage(flCurrentDamage)
					info:SetDamageType(iAmmoDamageType)
					info:SetDamagePosition(vHitPos)
					info:SetDamageForce(vShotDir * flAmmoForce * flForce * flPhysPush)
					info:SetAmmoType(iAmmoType)
					info:SetReportedPosition(vSrc)
				pEntity:DispatchTraceAttack(info, tr, vShotDir)
				
				if (fCallback) then
					fCallback(pAttacker, tr, info)
				end
				
				if (bEndNotWater or bit.band(iFlags, FIRE_BULLETS_ALLOW_WATER_SURFACE_IMPACTS) ~= 0) then
					if (bWeaponInvalid or not pWeapon.DoImpactEffect or not pWeapon:DoImpactEffect(tr, iAmmoDamageType)) then
						if (bFirstTimePredicted) then
							local data = EffectData()
								data:SetOrigin(tr.HitPos)
								data:SetStart(vSrc)
								data:SetSurfaceProp(tr.SurfaceProps)
								data:SetDamageType(iAmmoDamageType)
								data:SetHitBox(tr.HitBox)
								data:SetEntity(pEntity)
							util.Effect("Impact", data)
						end
					elseif (bFirstTimePredicted) then
						// We may not impact, but we DO need to affect ragdolls on the client
						local data = EffectData()
							data:SetOrigin(tr.HitPos)
							data:SetStart(vSrc)
							data:SetDamageType(iAmmoDamageType)
						util.Effect("RagdollImpact", data)
					end
				end
			end
			
			if (bDrop and SERVER) then
				// Make sure if the player is holding this, he drops it
				DropEntityIfHeld(pEntity)
			end
			
			// check if bullet can penetrate another entity
			// If we hit a grate with iPenetration == 0, stop on the next thing we hit
			if (iPenetration == 0 and not bHitGrate or iPenetration < 0 or pEntity:GetClass():find("func_breakable", 1, true) and pEntity:HasSpawnFlags(SF_BREAK_NO_BULLET_PENETRATION)) then
				break // no, stop
			end
			
			if (pEntity:IsWorld()) then
				local flExitDistance = 0
				local vPenetrationEnd
				
				// try to penetrate object, maximum penetration is 128 inch
				while (flExitDistance <= flExitMaxDistance) do
					flExitDistance = flExitDistance + flExitStepSize
				
					local vHit = vHitPos + flExitDistance * vShotDir
				
					if (bit.band(util.PointContents(vHit), MASK_SOLID) == 0) then
						// found first free point
						vPenetrationEnd = vHit
					end
				end
			
				-- Nowhere to penetrate
				if (not vPenetrationEnd) then
					break
				end
				
				util.TraceLine({
					start = vPenetrationEnd,
					endpos = vHitPos,
					mask = CONTENTS_SOLID,
					filter = ents.GetAll(),
					output = tr
				})
				
				if (bShowPenetration) then
					debugoverlay.Line(vPenetrationEnd, vHitPos, DEBUG_LENGTH, color_altdebug)
				end
			else
				-- FIXME: Cache this!
				local tEnts = ents.GetAll()
				local iLen = #tEnts
				
				-- Trace for only the entity we hit
				for i = iLen, 1, -1 do
					if (tEnts[i] == pEntity) then
						tEnts[i] = tEnts[iLen]
						tEnts[iLen] = nil
						
						break
					end
				end
				
				util.TraceLine({
					start = vEnd,
					endpos = vHitPos,
					mask = iMask,
					filter = tEnts,
					ignoreworld = true,
					output = tr
				})
				
				if (bShowPenetration) then
					debugoverlay.Line(vEnd, vHitPos, DEBUG_LENGTH, color_altdebug)
				end
			end
			
			local iExitMaterial = tr.MatType
			local tMatParams = tMaterialParameters[iEnterMaterial]
			local flPenetrationModifier = bHitGrate and 1 or tMatParams and tMatParams.Penetration or 1
			local flDamageModifier = bHitGrate and 0.99 or tMatParams and tMatParams.Damage or 0.5
			local flTraceDistance = (tr.HitPos - vHitPos):LengthSqr()
			
			// get material at exit point
			-- https://github.com/Facepunch/garrysmod-requests/issues/787
			if (bHitGrate) then
				bHitGrate = iExitMaterial == MAT_GRATE or bit.band(util.PointContents(tr.HitPos), CONTENTS_GRATE) ~= 0
			end
			
			// if enter & exit point is wood or metal we assume this is 
			// a hollow crate or barrel and give a penetration bonus
			if (bHitGrate and (iExitMaterial == MAT_GRATE or bit.band(util.PointContents(tr.HitPos), CONTENTS_GRATE) ~= 0) or iEnterMaterial == iExitMaterial and tDoublePenetration[iExitMaterial]) then
				flPenetrationModifier = flPenetrationModifier * 2	
			end

			// check if bullet has enough power to penetrate this distance for this material
			if (flTraceDistance > (flPenetrationPower * flPenetrationModifier)^2) then
				break // bullet hasn't enough power to penetrate this distance
			end
			
			if (iHitNum == 1 or (CLIENT and iHitNum == 2) or (SERVER and iHitNum == 3)) then
				debugoverlay.Box(tr.HitPos, vector_debug_min, vector_debug_max, DEBUG_LENGTH, color_altdebug)
			end
			
			// bullet did penetrate object, exit Decal
			if ((bWeaponInvalid or not pWeapon.DoImpactEffect or not pWeapon:DoImpactEffect(tr, iAmmoDamageType)) and bFirstTimePredicted) then
				local data = EffectData()
					data:SetOrigin(tr.HitPos)
					data:SetStart(tr.StartPos)
					data:SetSurfaceProp(tr.SurfaceProps)
					data:SetDamageType(iAmmoDamageType)
					data:SetHitBox(tr.HitBox)
					data:SetEntity(pEntity)
				util.Effect("Impact", data)
			end	
			
			// penetration was successful
			flTraceDistance = math.sqrt(flTraceDistance)
			
			// setup new start end parameters for successive trace
			flPenetrationPower = flPenetrationPower - flTraceDistance / flPenetrationModifier
			flCurrentDistance = flCurrentDistance + flTraceDistance
			
			// reduce damage power each time we hit something other than a grate
			flCurrentDamage = flCurrentDamage * flDamageModifier
			flDistance = (flDistance - flCurrentDistance) * 0.5
			
			vNewSrc = tr.HitPos
			vEnd = vNewSrc + vShotDir * flDistance
			
			// reduce penetration counter
			iPenetration = iPenetration - 1
			
			-- Can't hit players more than once
			if (pEntity:IsPlayer() or pEntity:IsNPC()) then
				if (bFilterIsFunction) then
					local fOldFilter = Filter
					Filter = function(pTest)
						return fOldFilter(pTest) and pTest ~= pEntity
					end
				elseif (iFilterEnd == -1) then
					Filter = {Filter, pEntity}
					iFilterEnd = 2
				else
					iFilterEnd = (iFilterEnd or #Filter) + 1
					Filter[iFilterEnd] = pEntity
				end
			end
		until (flCurrentDamage < FLT_EPSILON) -- Account for float handling; very rare case
		
		if (bDebugShoot) then
			debugoverlay.Line(vSrc, vFinalHit, DEBUG_LENGTH, color_debug)
		end
		
		if (bFirstTimePredicted and iTracerFreq > 0) then
			if (iTracerCount % iTracerFreq == 0) then
				local data = EffectData()
					local iAttachment
					
					if (bWeaponInvalid) then
						data:SetStart(self:ComputeTracerStartPosition(vSrc, 1))
						data:SetAttachment(1)
					else
						local iAttachment = pWeapon.GetMuzzleAttachment and pWeapon:GetMuzzleAttachment() or 1
						data:SetStart(pWeapon.GetTracerOrigin and pWeapon:GetTracerOrigin() or self:ComputeTracerStartPosition(vSrc, iAttachment))
						data:SetAttachment(iAttachment)
					end
					
					data:SetOrigin(vFinalHit)
					data:SetScale(0)
					data:SetEntity(bWeaponInvalid and self or pWeapon)
					data:SetFlags(iAmmoTracerType == TRACER_LINE_AND_WHIZ and nWhizTracer or 0x0002)
				util.Effect(sTracerName, data)
			end
			
			iTracerCount = iTracerCount + 1
		end
	end
	
	self:LagCompensation(false)
end

-- FireCSSBullets without penetration
function PLAYER:FireSDKBullets(bullets)
	if (hook.Run("EntityFireSDKBullets", self, bullets) == false) then
		return
	end
	
	self:LagCompensation(true)
	
	local pWeapon = self:GetActiveWeapon()
	local bWeaponInvalid = pWeapon == NULL
	
	local sAmmoType
	local iAmmoType
	
	if (not bullets.AmmoType) then
		sAmmoType = ""
		iAmmoType = -1
	elseif (isstring(bullets.AmmoType)) then
		sAmmoType = bullets.AmmoType
		iAmmoType = game.GetAmmoID(sAmmoType)
	else
		iAmmoType = bullets.AmmoType
		sAmmoType = game.GetAmmoName(iAmmoType)
	end
	
	local pAttacker = bullets.Attacker and bullets.Attacker ~= NULL and bullets.Attacker or self
	local fCallback = bullets.Callback
	local iDamage = bullets.Damage or 1
	local flDistance = bullets.Distance or 8000
	local Filter = bullets.Filter or self
	local iFlags = bullets.Flags or 0
	local flForce = bullets.Force or 1
	local pInflictor = bullets.Inflictor and bullets.Inflictor ~= NULL and bullets.Inflictor or bWeaponInvalid and self or pWeapon
	local iMask = bullets.Mask or MASK_HITBOX
	local iNum = bullets.Num or 1
	local flRangeModifier = bullets.RangeModifier or 0.85
	local aShootAngles = bullets.ShootAngles or self:EyeAngles()
	local vSrc = bullets.Src or self:GetShootPos()
	local iTracerFreq = bullets.Tracer or 1
	local sTracerName = bullets.TracerName or "Tracer"
	
	-- Ammo
	local iAmmoFlags = game.GetAmmoFlags(sAmmoType)
	local flAmmoForce = game.GetAmmoForce(sAmmoType)
	local iAmmoDamageType = game.GetAmmoDamageType(sAmmoType)
	local iAmmoMinSplash = game.GetAmmoMinSplash(sAmmoType)
	local iAmmoMaxSplash = game.GetAmmoMaxSplash(sAmmoType)
	local iAmmoTracerType = game.GetAmmoTracerType(sAmmoType)
	
	-- Loop values
	local bDrop = bit.band(iAmmoFlags, AMMO_FORCE_DROP_IF_CARRIED) ~= 0
	local bDebugShoot = ai_debug_shoot_positions:GetBool()
	local bFirstShotInaccurate = bit.band(iFlags, FIRE_BULLETS_FIRST_SHOT_ACCURATE) == 0
	local flPhysPush = phys_pushscale:GetFloat()
	local vShootForward = aShootAngles:Forward()
	local bStartedInWater = bit.band(util.PointContents(vSrc), MASK_WATER) ~= 0
	local bFirstTimePredicted = IsFirstTimePredicted()
	local vShootRight, vShootUp, flSpreadBias
	
	// Wrap it for network traffic so it's the same between client and server
	local iSeed = self:GetMD5Seed() % 0x100
	
	-- Don't calculate stuff we won't end up using
	if (bFirstShotInaccurate or iNum ~= 1) then
		local vSpread = bullets.Spread or vector_origin
		flSpreadBias = bullets.SpreadBias or 0.5
		vShootRight = vSpread[1] * aShootAngles:Right()
		vShootUp = vSpread[2] * aShootAngles:Up()
	end
	
	//Adrian: visualize server/client player positions
	//This is used to show where the lag compesator thinks the player should be at.
	local iHitNum = sv_showplayerhitboxes:GetInt()
	
	if (iHitNum > 0) then
		local pLagPlayer = Player(iHitNum)
		
		if (pLagPlayer ~= NULL) then
			pLagPlayer:DrawHitBoxes(DEBUG_LENGTH)
		end
	end
	
	iHitNum = sv_showimpacts:GetInt()
	
	for iShot = 1, iNum do
		local vShotDir
		iSeed = iSeed + 1 // use new seed for next bullet
		code_gs.random:SetSeed(iSeed) // init random system with this seed
		
		// add the spray 
		if (bFirstShotInaccurate or iShot ~= 1) then
			vShotDir = vShootForward + vShootRight * (code_gs.random:RandomFloat(-flSpreadBias, flSpreadBias) + code_gs.random:RandomFloat(-flSpreadBias, flSpreadBias))
			+ vShootUp * (code_gs.random:RandomFloat(-flSpreadBias, flSpreadBias) + code_gs.random:RandomFloat(-flSpreadBias, flSpreadBias))
			vShotDir:Normalize()
		else
			vShotDir = vShootForward
		end
		
		local vEnd = vSrc + vShotDir * flDistance
		
		local tr = util.TraceLine({
			start = vSrc,
			endpos = vEnd,
			mask = iMask,
			filter = Filter
		})
		
		local pEntity = tr.Entity
		local vHitPos = tr.HitPos
		
		local bEndNotWater = bit.band(util.PointContents(tr.HitPos), MASK_WATER) == 0
		local trSplash = bStartedInWater and bEndNotWater and
			util.TraceLine({
				start = vHitPos,
				endpos = vSrc,
				mask = MASK_WATER
			})
		// See if the bullet ended up underwater + started out of the water
		or not (bStartedInWater or bEndNotWater) and
			util.TraceLine({
				start = vSrc,
				endpos = vHitPos,
				mask = MASK_WATER
			})
		
		if (trSplash and (bWeaponInvalid or not (pWeapon.DoSplashEffect and pWeapon:DoSplashEffect(trSplash))) and bFirstTimePredicted) then
			if (bFirstTimePredicted) then
				local data = EffectData()
					data:SetOrigin(trSplash.HitPos)
					data:SetScale(code_gs.random:RandomFloat(iAmmoMinSplash, iAmmoMaxSplash))
					
					if (bit.band(util.PointContents(trSplash.HitPos), CONTENTS_SLIME) ~= 0) then
						data:SetFlags(FX_WATER_IN_SLIME)
					end
					
				util.Effect("gunshotsplash", data)
			end
		end
		
		if (tr.Fraction == 1 or pEntity == NULL) then
			break // we didn't hit anything, stop tracing shoot
		end
		
		// draw server impact markers
		if (iHitNum == 1 or (CLIENT and iHitNum == 2) or (SERVER and iHitNum == 3)) then
			debugoverlay.Box(vHitPos, vector_debug_min, vector_debug_max, DEBUG_LENGTH, color_debug)
		end
		
		if (not bStartedWater and bEndNotWater or bit.band(iFlags, FIRE_BULLETS_DONT_HIT_UNDERWATER) == 0) then
			// add damage to entity that we hit
			local info = DamageInfo()
				info:SetAttacker(pAttacker)
				info:SetInflictor(pInflictor)
				info:SetDamage(iDamage * flRangeModifier ^ (tr.Fraction * flDistance / 500))
				info:SetDamageType(iAmmoDamageType)
				info:SetDamagePosition(vHitPos)
				info:SetDamageForce(vShotDir * flAmmoForce * flForce * flPhysPush)
				info:SetAmmoType(iAmmoType)
				info:SetReportedPosition(vSrc)
			pEntity:DispatchTraceAttack(info, tr, vShotDir)
			
			if (fCallback) then
				fCallback(pAttacker, tr, info)
			end
			
			if (bEndNotWater or bit.band(iFlags, FIRE_BULLETS_ALLOW_WATER_SURFACE_IMPACTS) ~= 0) then
				if (bWeaponInvalid or not pWeapon.DoImpactEffect or not pWeapon:DoImpactEffect(tr, iAmmoDamageType)) then
					if (bFirstTimePredicted) then
						local data = EffectData()
							data:SetOrigin(tr.HitPos)
							data:SetStart(vSrc)
							data:SetSurfaceProp(tr.SurfaceProps)
							data:SetDamageType(iAmmoDamageType)
							data:SetHitBox(tr.HitBox)
							data:SetEntity(pEntity)
						util.Effect("Impact", data)
					end
				elseif (bFirstTimePredicted) then
					// We may not impact, but we DO need to affect ragdolls on the client
					local data = EffectData()
						data:SetOrigin(tr.HitPos)
						data:SetStart(vSrc)
						data:SetDamageType(iAmmoDamageType)
					util.Effect("RagdollImpact", data)
				end
			end
		end
		
		if (bDrop and SERVER) then
			// Make sure if the player is holding this, he drops it
			DropEntityIfHeld(pEntity)
		end
		
		if (bDebugShoot) then
			debugoverlay.Line(vSrc, vHitPos, DEBUG_LENGTH, color_debug)
		end
		
		if (bFirstTimePredicted and iTracerFreq > 0) then
			if (iTracerCount % iTracerFreq == 0) then
				local data = EffectData()
					local iAttachment
					
					if (bWeaponInvalid) then
						data:SetStart(self:ComputeTracerStartPosition(vSrc, 1))
						data:SetAttachment(1)
					else
						local iAttachment = pWeapon.GetMuzzleAttachment and pWeapon:GetMuzzleAttachment() or 1
						data:SetStart(pWeapon.GetTracerOrigin and pWeapon:GetTracerOrigin() or self:ComputeTracerStartPosition(vSrc, iAttachment))
						data:SetAttachment(iAttachment)
					end
					
					data:SetOrigin(vHitPos)
					data:SetScale(0)
					data:SetEntity(bWeaponInvalid and self or pWeapon)
					data:SetFlags(iAmmoTracerType == TRACER_LINE_AND_WHIZ and nWhizTracer or 0x0002)
				util.Effect(sTracerName, data)
			end
			
			iTracerCount = iTracerCount + 1
		end
	end
	
	self:LagCompensation(false)
end

function PLAYER:GetMD5Seed()
	local iFrameCount = CurTime()
	
	if (self.m_iMD5SeedSavedFrame ~= iFrameCount) then
		self.m_iMD5SeedSavedFrame = iFrameCount
		self.m_iMD5Seed = math.MD5Random(self:GetCurrentCommand():CommandNumber())
	end
	
	return self.m_iMD5Seed
end
