local PLAYER = FindMetaTable("Player")

hook.Add("Move", "gs_lib", function(pPlayer)
	pPlayer:SetNW2Bool("gs_lib_sprinting", pPlayer:KeyDown(IN_SPEED))
end)

function PLAYER:IsSprinting()
	return self:GetNW2Bool("gs_lib_sprinting")
end

-- FIXME: Add to all entitys/NPCs
-- Equivalent of CBasePlayer::EyeVectors() before AngleVecotrs
function PLAYER:ActualEyeAngles()
	-- FIXME: https://github.com/Facepunch/garrysmod-requests/issues/760
	do return self:EyeAngles() end
	
	local pVehicle = self:GetVehicle()
	
	if (pVehicle:IsValid()) then
		// Cache or retrieve our calculated position in the vehicle
		-- https://github.com/Facepunch/garrysmod-requests/issues/482
		local iFrameCount = UnPredictedCurTime()

		// If we've calculated the view this frame, then there's no need to recalculate it
		if (self.m_iVehicleViewSavedFrame ~= iFrameCount) then
			self.m_iVehicleViewSavedFrame = iFrameCount
			
			// Get our view for this frame
			local _, ang = pVehicle:GetVehicleViewPosition(1) -- FIXME: Passenger pos
			self.m_aVehicleViewAngles = ang
		end
		
		return self.m_aVehicleViewAngles
	end
	
	return self:EyeAngles()
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
	local bIsValid = pCurrent:IsValid()
	local iCurWeight = bIsValid and pCurrent:GetWeight()
	local pBestWep
	local pFallbackWep
	
	// Search for the best weapon to use next based on its weight
	for _, pCheck in pairs(self:GetWeapons()) do -- Discontinous table
		// If we have an active weapon and this weapon doesn't allow autoswitching away
		// from another weapon, skip it.
		if (pCheck:AllowsAutoSwitchTo() and pCheck ~= pCurrent) then
			if (pCheck:HasAmmo()) then				
				if (not bIgnoreCategory) then
					return pCheck -- We found a perfect match
				end
				
				local iWeight = pCheck:GetWeight()
				
				if (bIsValid and iWeight == iCurWeight) then
					return pCheck
				end
				
				if (pBestWep == nil or iWeight > pBestWep:GetWeight()) then
					pBestWep = pCheck
				end
			-- If it's an emergency, have a backup regardless of ammo
			elseif (bCritical and not pFallbackWep) then
				pFallbackWep = pCheck
			end
		end
	end
	
	-- If the weapon is going to be removed, do not re-deploy
	return pBestWep or pFallbackWep or (bCritical and NULL or pCurrent)
end

function PLAYER:MouseLifted()
	return not (self:KeyDown(IN_ATTACK) or self:KeyDown(IN_ATTACK2))
end

-- FIXME: Move to Entity
FIRE_BULLETS_FIRST_SHOT_ACCURATE = 0x1 // Pop the first shot with perfect accuracy
FIRE_BULLETS_DONT_HIT_UNDERWATER = 0x2 // If the shot hits its target underwater, don't damage it
FIRE_BULLETS_ALLOW_WATER_SURFACE_IMPACTS = 0x4 // If the shot hits water surface, still call DoImpactEffect
-- The engine alerts NPCs by pushing a sound onto a static sound manager
-- However, this cannot be accessed from the Lua state
--FIRE_BULLETS_TEMPORARY_DANGER_SOUND = 0x8 // Danger sounds added from this impact can be stomped immediately if another is queued

local ai_debug_shoot_positions = GetConVar("ai_debug_shoot_positions")
local phys_pushscale = GetConVar("phys_pushscale")
local sv_showimpacts = CreateConVar("gs_weapons_showimpacts", "0", bit.bor(FCVAR_REPLICATED, FCVAR_ARCHIVE), "Shows client (red) and server (blue) bullet impact point (1=both, 2=client-only, 3=server-only)")
local sv_showpenetration = CreateConVar("gs_weapons_showpenetration", "0", bit.bor(FCVAR_REPLICATED, FCVAR_ARCHIVE), "Shows penetration trace (if applicable) when the weapon fires")
local sv_showplayerhitboxes = CreateConVar("gs_weapons_showplayerhitboxes", "0", bit.bor(FCVAR_REPLICATED, FCVAR_ARCHIVE), "Show lag compensated hitboxes for the specified player index whenever a player fires.")

local nWhizTracer = bit.bor(0x0002, 0x0001)
local iTracerCount = 0 -- Instance global to interact with FireBullets functions

local function Splash(vHitPos, bStartedInWater, bEndNotWater, vSrc, pWeapon, bFirstTimePredicted, iAmmoMinSplash, iAmmoMaxSplash)
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
	
	if (trSplash and not (pWeapon and pWeapon.DoSplashEffect and pWeapon:DoSplashEffect(trSplash)) and bFirstTimePredicted) then
		local data = EffectData()
			data:SetOrigin(trSplash.HitPos)
			data:SetScale(gs.random:RandomFloat(iAmmoMinSplash, iAmmoMaxSplash))
			
			if (bit.band(util.PointContents(trSplash.HitPos), CONTENTS_SLIME) ~= 0) then
				data:SetFlags(FX_WATER_IN_SLIME)
			end
		util.Effect("gunshotsplash", data)
	end
end

local function Impact(Weapon, iAmmoDamageType, bFirstTimePredicted, vSrc, tr)
	if (not (Weapon and Weapon.DoImpactEffect and Weapon:DoImpactEffect(tr, iAmmoDamageType))) then
		if (bFirstTimePredicted) then
			local data = EffectData()
				data:SetOrigin(tr.HitPos)
				data:SetStart(vSrc)
				data:SetSurfaceProp(tr.SurfaceProps)
				data:SetDamageType(iAmmoDamageType)
				data:SetHitBox(tr.HitBox)
				data:SetEntity(tr.Entity)
				
				if (SERVER) then
					data:SetEntIndex(tr.Entity:EntIndex())
				end
				
			util.Effect("Impact", data)
		end
	elseif (bFirstTimePredicted) then
		// We may not impact, but we DO need to affect ragdolls on the client
		-- FIXME: Should we?
		local data = EffectData()
			data:SetOrigin(tr.HitPos)
			data:SetStart(vSrc)
			data:SetDamageType(iAmmoDamageType)
		util.Effect("RagdollImpact", data)
	end
end

local function Damage(bDoDebugHit, bStartedWater, bEndNotWater, iFlags, iDamage, iPlayerDamage, iNPCDamage, iAmmoDamage, pAttacker, pInflictor,
	iAmmoDamageType, tr, Weapon, vShotDir, flAmmoForce, flForce, flPhysPush, iAmmoType, vSrc, fCallback, bFirstTimePredicted, bDrop)
	
	local vHitPos = tr.HitPos
	local pEntity = tr.Entity
	
	// draw server impact markers
	if (bDoDebugHit) then
		debugoverlay.Box(vHitPos, vector_debug_min, vector_debug_max, DEBUG_LENGTH, color_debug)
	end
	
	if (not bStartedWater and bEndNotWater or bit.band(iFlags, FIRE_BULLETS_DONT_HIT_UNDERWATER) == 0) then
		-- The engine considers this a float
		-- Even though no values assigned to it are
		-- FIXME: Update these typedefs
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
		
		if (iActualDamage == 0 and iAmmoDamage ~= 0) then
			iActualDamage = iAmmoDamage
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
			Impact(Weapon, iAmmoDamageType, bFirstTimePredicted, vSrc, tr)
		end
	end
	
	if (bDrop and SERVER) then
		// Make sure if the player is holding this, he drops it
		DropEntityIfHeld(pEntity)
	end
end

local function Tracer(bDebugShoot, vSrc, vFinalHit, bFirstTimePredicted, iTracerFreq, Weapon, self, iAmmoTracerType, sTracerName)
	if (bDebugShoot) then
		debugoverlay.Line(vSrc, vFinalHit, DEBUG_LENGTH, color_debug)
	end
	
	if (bFirstTimePredicted and iTracerFreq > 0) then
		if (iTracerCount % iTracerFreq == 0) then
			local data = EffectData()
				if (Weapon) then
					local iAttachment = Weapon.GetMuzzleAttachment and Weapon:GetMuzzleAttachment() or 1
					data:SetStart(Weapon.GetTracerOrigin and Weapon:GetTracerOrigin() or self:ComputeTracerStartPosition(vSrc, iAttachment))
					data:SetAttachment(iAttachment)
				else
					data:SetStart(self:ComputeTracerStartPosition(vSrc, 1))
					data:SetAttachment(1)
				end
				
				data:SetOrigin(vFinalHit)
				data:SetScale(0)
				data:SetEntity(Weapon or self)
				data:SetFlags(iAmmoTracerType == TRACER_LINE_AND_WHIZ and nWhizTracer or 0x0002)
			util.Effect(sTracerName, data)
		end
		
		iTracerCount = iTracerCount + 1
	end
end

function PLAYER:FireLuaBullets(tInfo)
	if (hook.Run("EntityFireBullets", self, tInfo) == false) then
		return
	end
	
	local bIsPlayer = self:IsPlayer()
	
	if (bIsPlayer) then
		self:LagCompensation(true)
	end
	
	local pWeapon = self:GetActiveWeapon()
	local bWeaponValid = pWeapon:IsValid()
	
	-- FireBullets info
	local sAmmoType
	local iAmmoType
	
	if (tInfo.AmmoType == nil) then
		sAmmoType = ""
		iAmmoType = -1
	elseif (isstring(tInfo.AmmoType)) then
		sAmmoType = tInfo.AmmoType
		iAmmoType = game.GetAmmoID(sAmmoType)
	else
		iAmmoType = tInfo.AmmoType
		sAmmoType = game.GetAmmoName(iAmmoType) or ""
	end
	
	local pAttacker = tInfo.Attacker or self
	local fCallback = tInfo.Callback
	local iDamage = tInfo.Damage or 0
	local vDir = tInfo.Dir and tInfo.Dir:GetNormal() or self:GetAimVector()
	local flDistance = tInfo.Distance or MAX_TRACE_LENGTH
	local Filter = tInfo.Filter or self
	local iFlags = tInfo.Flags or 0
	local flForce = tInfo.Force or 1
	local bHullTrace = tInfo.HullTrace
	
	if (bHullTrace == nil) then
		bHullTrace = true
	end
	
	local pInflictor = tInfo.Inflictor and tInfo.Inflictor:IsValid() and tInfo.Inflictor or bWeaponValid and pWeapon or self
	local iMask = tInfo.Mask or MASK_SHOT
	local iNPCDamage = tInfo.NPCDamage or 0
	local iNum = tInfo.Num or 1
	local iPlayerDamage = tInfo.PlayerDamage or 0
	local vSrc = tInfo.Src or self:GetShootPos()
	local iTracerFreq = tInfo.Tracer or 1
	local sTracerName = tInfo.TracerName or "Tracer"
	
	-- Ammo
	local iAmmoFlags = game.GetAmmoFlags(sAmmoType)
	local flAmmoForce = game.GetAmmoForce(sAmmoType)
	local iAmmoDamageType = game.GetAmmoDamageType(sAmmoType)
	local iAmmoMinSplash = game.GetAmmoMinSplash(sAmmoType)
	local iAmmoMaxSplash = game.GetAmmoMaxSplash(sAmmoType)
	local iAmmoNPCDamage = game.GetAmmoNPCDamage(sAmmoType)
	local iAmmoPlayerDamage = game.GetAmmoPlayerDamage(sAmmoType)
	local iAmmoTracerType = game.GetAmmoTracerType(sAmmoType)
	
	if (bit.band(iAmmoFlags, AMMO_INTERPRET_PLRDAMAGE_AS_DAMAGE_TO_PLAYER) ~= 0) then
		if (iPlayerDamage == 0) then
			iPlayerDamage = iAmmoPlayerDamage
		end
		
		if (iNPCDamage == 0) then
			iNPCDamage = iAmmoNPCDamage
		end
	end
	
	local iAmmoDamage = bIsPlayer and iAmmoPlayerDamage or iAmmoNPCDamage
	
	-- Loop values
	local bDrop = bit.band(iAmmoFlags, AMMO_FORCE_DROP_IF_CARRIED) ~= 0
	local bDebugShoot = ai_debug_shoot_positions:GetBool()
	local bFirstShotInaccurate = bit.band(iFlags, FIRE_BULLETS_FIRST_SHOT_ACCURATE) == 0
	local flPhysPush = phys_pushscale:GetFloat()
	local bShowPenetration = sv_showpenetration:GetBool()
	local bStartedInWater = bit.band(util.PointContents(vSrc), MASK_WATER) ~= 0
	local bFirstTimePredicted = IsFirstTimePredicted()
	local flSpreadBias, flFlatness, bNegBias, vFireBulletMax, vFireBulletMin, vSpreadRight, vSpreadUp, tEnts, iEntsLen
	
	// Wrap it for network traffic so it's the same between client and server
	local iSeed = self:GetMD5Seed() % 0x100 - 1
	
	-- Don't calculate stuff we won't end up using
	if (bFirstShotInaccurate or iNum ~= 1) then
		flSpreadBias = tInfo.SpreadBias or 0.5
		
		if (flSpreadBias > 1) then
			flSpreadBias = 1
			bNegBias = false
		elseif (flSpreadBias < -1) then
			flSpreadBias = -1
			bNegBias = true
		else
			bNegBias = flSpreadBias < 0
			
			if (bNegBias) then
				flSpreadBias = -flSpreadBias
			end
		end
		
		local vSpread = tInfo.Spread or vector_origin
		vSpreadRight = vSpread:Right()
		vSpreadRight:Mul(vSpread[1])
		vSpreadUp = vSpread:Up()
		vSpreadUp:Mul(vSpread[2])
		
		if (bHullTrace and iNum ~= 1) then
			local flHullSize = tInfo.HullSize
			vFireBulletMax = flHullSize and Vector(flHullSize, flHullSize, flHullSize) or Vector(3, 3, 3)
			vFireBulletMin = -vFireBulletMax
		end
	end
	
	local bDoDebugHit
	
	do
		//Adrian: visualize server/client player positions
		//This is used to show where the lag compesator thinks the player should be at.
		local iHitNum = sv_showplayerhitboxes:GetInt()
		
		if (iHitNum > 0) then
			local pLagPlayer = Player(iHitNum)
			
			if (pLagPlayer:IsValid()) then
				pLagPlayer:DrawHitBoxes(DEBUG_LENGTH)
			end
		end
		
		iHitNum = sv_showimpacts:GetInt()
		bDoDebugHit = iHitNum == 1 or (CLIENT and iHitNum == 2) or (SERVER and iHitNum == 3)
	end
	
	for iShot = 1, iNum do
		local vShotDir
		iSeed = iSeed + 1 // use new seed for next bullet
		gs.random:SetSeed(iSeed) // init random system with this seed
		
		// If we're firing multiple shots, and the first shot has to be ba on target, ignore spread
		if (bFirstShotInaccurate or iShot ~= 1) then
			local x
			local y
			local z

			repeat
				x = gs.random:RandomFloat(-flSpreadBias, flSpreadBias) + gs.random:RandomFloat(flSpreadBias - 1, 1 - flSpreadBias)
				y = gs.random:RandomFloat(-flSpreadBias, flSpreadBias) + gs.random:RandomFloat(flSpreadBias - 1, 1 - flSpreadBias)

				if (bNegBias) then
					x = x < 0 and -(1 + x) or 1 - x
					y = y < 0 and -(1 + y) or 1 - y
				end

				z = x * x + y * y
			until (z <= 1)

			vShotDir = vDir + x * vSpreadRight + y * vSpreadUp
			vShotDir:Normalize()
		else
			vShotDir = vDir
		end
		
		local bHitGlass
		local vEnd = vSrc + vShotDir * flDistance
		local vNewSrc = vSrc
		local vFinalHit
		
		repeat
			local tr = bHullTrace and iShot % 2 == 0 and
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
			
			local vHitPos = tr.HitPos
			vFinalHit = vHitPos
			
			local bEndNotWater = bit.band(util.PointContents(vHitPos), MASK_WATER) == 0
			Splash(vHitPos, bStartedInWater, bEndNotWater, vSrc, bWeaponValid and pWeapon, bFirstTimePredicted, iAmmoMinSplash, iAmmoMaxSplash)
			
			if (not tr.Hit or tr.HitSky) then
				break // we didn't hit anything, stop tracing shoot
			end
			
			Damage(bDoDebugHit, bStartedWater, bEndNotWater, iFlags, iDamage, iPlayerDamage, iNPCDamage, iAmmoDamage, pAttacker, pInflictor, iAmmoDamageType,
				tr, bWeaponValid and pWeapon, vShotDir, flAmmoForce, flForce, flPhysPush, iAmmoType, vSrc, fCallback, bFirstTimePredicted, bDrop)
			
			// do damage, paint decals
			-- https://github.com/Facepunch/garrysmod-issues/issues/2741
			local pEntity = tr.Entity
			bHitGlass = --[[tr.MatType == MAT_GLASS]] pEntity:IsBreakable() and not pEntity:HasSpawnFlags(SF_BREAK_NO_BULLET_PENETRATION)
			
			// See if we hit glass
			// Query the func_breakable for whether it wants to allow for bullet penetration
			if (bHitGlass) then
				if (tEnts == nil) then
					tEnts = ents.GetAll()
					iEntsLen = #tEnts
				end
				
				local bReplace = false
				
				-- Trace for only the entity we hit
				for i = iEntsLen, 1, -1 do
					if (tEnts[i] == pEntity) then
						tEnts[i] = tEnts[iEntsLen]
						tEnts[iEntsLen] = nil
						bReplace = true
						
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
				
				// bullet did penetrate object, exit Decal
				Impact(bWeaponValid and pWeapon, iAmmoDamageType, bFirstTimePredicted, vSrc, tr)
				
				vNewSrc = tr.HitPos
				
				if (bShowPenetration) then
					debugoverlay.Line(vHitPos, vNewSrc, DEBUG_LENGTH, color_altdebug)
				end
				
				if (bDoDebugHit) then
					debugoverlay.Box(vNewSrc, vector_debug_min, vector_debug_max, DEBUG_LENGTH, color_altdebug)
				end
				
				-- Should never be false
				if (bReplace) then
					tEnts[iEntsLen] = pEntity
				end
			end
		until (not bHitGlass)
		
		Tracer(bDebugShoot, vSrc, vFinalHit, bFirstTimePredicted, iTracerFreq, bWeaponValid and pWeapon, self, iAmmoTracerType, sTracerName)
	end
	
	if (bIsPlayer) then
		self:LagCompensation(false)
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

function PLAYER:FireCSSBullets(tInfo)
	if (hook.Run("EntityFireBullets", self, tInfo) == false) then
		return
	end
	
	local bIsPlayer = self:IsPlayer()
	
	if (bIsPlayer) then
		self:LagCompensation(true)
	end
	
	local pWeapon = self:GetActiveWeapon()
	local bWeaponValid = pWeapon:IsValid()
	
	-- FireCSSBullets info
	local sAmmoType
	local iAmmoType
	
	if (tInfo.AmmoType == nil) then
		sAmmoType = ""
		iAmmoType = -1
	elseif (isstring(tInfo.AmmoType)) then
		sAmmoType = tInfo.AmmoType
		iAmmoType = game.GetAmmoID(sAmmoType)
	else
		iAmmoType = tInfo.AmmoType
		sAmmoType = game.GetAmmoName(iAmmoType) or ""
	end
	
	local pAttacker = tInfo.Attacker and tInfo.Attacker:IsValid() and tInfo.Attacker or self
	local fCallback = tInfo.Callback
	local iDamage = tInfo.Damage or 0
	local flDecayRate = tInfo.DecayRate or 1/500
	local vDir = tInfo.Dir and tInfo.Dir:GetNormal() or self:GetAimVector()
	local flDistance = tInfo.Distance or MAX_TRACE_LENGTH
	local flExitMaxDistance = tInfo.ExitMaxDistance or 128
	local flExitStepSize = tInfo.ExitStepSize or 24
	
	local bFilterIsFunction
	local iFilterEnd
	local Filter = tInfo.Filter
	
	-- Yes, this is dirty
	-- But this prevents tables from being created when it's not necessary
	-- Also supports functional filters
	if (isentity(Filter)) then
		iFilterEnd = -1
		bFilterIsFunction = false
	elseif (istable(Filter)) then
		-- Length of the table will be found if penetration happens
		--iFilterEnd = #Filter
		bFilterIsFunction = false
	elseif (isfunction(Filter)) then
		bFilterIsFunction = true
	else
		Filter = self
		iFilterEnd = -1
		bFilterIsFunction = false
	end
	
	local iFlags = tInfo.Flags or 0
	local flForce = tInfo.Force or 1
	--local flHitboxTolerance = tInfo.HitboxTolerance or 40
	local bHullTrace = tInfo.HullTrace or false
	local pInflictor = tInfo.Inflictor and tInfo.Inflictor:IsValid() and tInfo.Inflictor or bWeaponValid and pWeapon or self
	local iMask = tInfo.Mask or MASK_HITBOX
	local iNPCDamage = tInfo.NPCDamage or 0
	local iNum = tInfo.Num or 1
	local iPenetration = tInfo.Penetration or 0
	local iPlayerDamage = tInfo.PlayerDamage or 0
	local flRangeModifier = tInfo.RangeModifier or 1
	local vSrc = tInfo.Src or self:GetShootPos()
	local iTracerFreq = tInfo.Tracer or 1
	local sTracerName = tInfo.TracerName or "Tracer"
	
	-- Ammo
	local iAmmoFlags = game.GetAmmoFlags(sAmmoType)
	local flAmmoForce = game.GetAmmoForce(sAmmoType)
	local iAmmoDamageType = game.GetAmmoDamageType(sAmmoType)
	local iAmmoMinSplash = game.GetAmmoMinSplash(sAmmoType)
	local iAmmoMaxSplash = game.GetAmmoMaxSplash(sAmmoType)
	local iAmmoNPCDamage = game.GetAmmoNPCDamage(sAmmoType)
	local iAmmoPlayerDamage = game.GetAmmoPlayerDamage(sAmmoType)
	local iAmmoTracerType = game.GetAmmoTracerType(sAmmoType)
	
	local flPenetrationDistance = game.GetAmmoKey(sAmmoType, "penetrationdistance", 0)
	local flPenetrationPower = game.GetAmmoKey(sAmmoType, "penetrationpower", 0)
	
	-- Loop values
	local bDrop = bit.band(iAmmoFlags, AMMO_FORCE_DROP_IF_CARRIED) ~= 0
	local bDebugShoot = ai_debug_shoot_positions:GetBool()
	local bFirstShotInaccurate = bit.band(iFlags, FIRE_BULLETS_FIRST_SHOT_ACCURATE) == 0
	local flPhysPush = phys_pushscale:GetFloat()
	local bShowPenetration = sv_showpenetration:GetBool()
	local bStartedInWater = bit.band(util.PointContents(vSrc), MASK_WATER) ~= 0
	local bFirstTimePredicted = IsFirstTimePredicted()
	local flSpreadBias, vShootRight, vShootUp, vFireBulletMin, vFireBulletMax, tEnts, iEntsLen
	
	// Wrap it for network traffic so it's the same between client and server
	local iSeed = self:GetMD5Seed() % 0x100
	
	-- Don't calculate stuff we won't end up using
	if (bFirstShotInaccurate or iNum ~= 1) then
		local vSpread = tInfo.Spread or vector_origin
		flSpreadBias = tInfo.SpreadBias or 0.5
		vShootRight = vDir:Right()
		vShootRight:Mul(vSpread[1])
		vShootUp = vDir:Up()
		vShootUp:Mul(vSpread[2])
		
		if (bHullTrace and iNum ~= 1) then
			local flHullSize = tInfo.HullSize
			vFireBulletMax = flHullSize and Vector(flHullSize, flHullSize, flHullSize) or Vector(3, 3, 3)
			vFireBulletMin = -vFireBulletMax
		end
	end
	
	local bDoDebugHit
	
	do
		//Adrian: visualize server/client player positions
		//This is used to show where the lag compesator thinks the player should be at.
		local iHitNum = sv_showplayerhitboxes:GetInt()
		
		if (iHitNum > 0) then
			local pLagPlayer = Player(iHitNum)
			
			if (pLagPlayer:IsValid()) then
				pLagPlayer:DrawHitBoxes(DEBUG_LENGTH)
			end
		end
		
		iHitNum = sv_showimpacts:GetInt()
		bDoDebugHit = iHitNum == 1 or (CLIENT and iHitNum == 2) or (SERVER and iHitNum == 3)
	end
	
	for iShot = 1, iNum do
		local vShotDir
		iSeed = iSeed + 1 // use new seed for next bullet
		gs.random:SetSeed(iSeed) // init random system with this seed
		
		-- Loop values
		local flCurrentDamage = iDamage	// damage of the bullet at it's current trajectory
		local flCurrentPlayerDamage = iPlayerDamage
		local flCurrentNPCDamage = iNPCDamage
		local flCurrentDistance = 0	// distance that the bullet has traveled so far
		local vNewSrc = vSrc
		local vFinalHit
		
		// add the spray 
		if (bFirstShotInaccurate or iShot ~= 1) then
			vShotDir = vDir + vShootRight * (gs.random:RandomFloat(-flSpreadBias, flSpreadBias) + gs.random:RandomFloat(-flSpreadBias, flSpreadBias))
			+ vShootUp * (gs.random:RandomFloat(-flSpreadBias, flSpreadBias) + gs.random:RandomFloat(-flSpreadBias, flSpreadBias))
			vShotDir:Normalize()
		else
			vShotDir = vDir
		end
		
		local vEnd = vNewSrc + vShotDir * flDistance
		
		repeat
			local tr = bHullTrace and iShot % 2 == 0 and
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
			
			// Check for player hitboxes extending outside their collision bounds
			--util.ClipTraceToPlayers(tr, vNewSrc, vEnd + vShotDir * flHitboxTolerance, Filter, iMask)
			
			local vHitPos = tr.HitPos
			vFinalHit = vHitPos
			
			local bEndNotWater = bit.band(util.PointContents(vHitPos), MASK_WATER) == 0
			Splash(vHitPos, bStartedInWater, bEndNotWater, vSrc, bWeaponValid and pWeapon, bFirstTimePredicted, iAmmoMinSplash, iAmmoMaxSplash)
			
			if (not tr.Hit or tr.HitSky) then
				break // we didn't hit anything, stop tracing shoot
			end
			
			/************* MATERIAL DETECTION ***********/
			-- https://github.com/Facepunch/garrysmod-requests/issues/923
			local iEnterMaterial = tr.MatType
			
			-- https://github.com/Facepunch/garrysmod-requests/issues/787
			// since some railings in de_inferno are CONTENTS_GRATE but CHAR_TEX_CONCRETE, we'll trust the
			// CONTENTS_GRATE and use a high damage modifier.
			// If we're a concrete grate (TOOLS/TOOLSINVISIBLE texture) allow more penetrating power.
			local bHitGrate = iEnterMaterial == MAT_GRATE or bit.band(util.PointContents(vHitPos), CONTENTS_GRATE) ~= 0
			
			// calculate the damage based on the distance the bullet travelled.
			flCurrentDistance = flCurrentDistance + tr.Fraction * flDistance
			local flDecay = flRangeModifier ^ (flCurrentDistance * flDecayRate)
			flCurrentDamage = flCurrentDamage * flDecay
			flCurrentPlayerDamage = flCurrentPlayerDamage * flDecay
			flCurrentNPCDamage = flCurrentNPCDamage * flDecay
			
			Damage(bDoDebugHit, bStartedWater, bEndNotWater, iFlags, flCurrentDamage, flCurrentPlayerDamage, flCurrentNPCDamage, bIsPlayer and iAmmoPlayerDamage or iAmmoNPCDamage, pAttacker,
				pInflictor, iAmmoDamageType, tr, bWeaponValid and pWeapon, vShotDir, flAmmoForce, flForce, flPhysPush, iAmmoType, vSrc, fCallback, bFirstTimePredicted, bDrop)
			
			// check if we reach penetration distance, no more penetrations after that
			if (flCurrentDistance > flPenetrationDistance and iPenetration > 0) then
				iPenetration = 0
			end
			
			// check if bullet can penetrate another entity
			// If we hit a grate with iPenetration == 0, stop on the next thing we hit
			if (iPenetration == 0 and not bHitGrate or iPenetration < 0) then
				break
			end
			
			local pEntity = tr.Entity
			
			if (pEntity:IsBreakable() and pEntity:HasSpawnFlags(SF_BREAK_NO_BULLET_PENETRATION)) then
				break // no, stop
			end
			
			if (tEnts == nil) then
				tEnts = ents.GetAll()
				iEntsLen = #tEnts
			end
			
			if (pEntity:IsWorld()) then
				local flExitDistance = 0
				
				local tr = tr
				local tTrace = {
					mask = iMask,
					filter = tEnts,
					output = tr
				}
				
				// try to penetrate object, maximum penetration is 128 inch
				while (flExitDistance < flExitMaxDistance) do
					flExitDistance = math.min(flExitMaxDistance, flExitDistance + flExitStepSize)
					
					local vHit = vHitPos + flExitDistance * vShotDir
					tTrace.start = vHit
					tTrace.endpos = vHit
					util.TraceLine(tTrace)
					
					if (not tr.Hit) then
						// found first free point
						goto PositionFound
					end
				end
				
				-- Nowhere to penetrate
				do break end
				
				::PositionFound::
				
				tTrace.endpos = vHitPos
				util.TraceLine(tTrace)
			else
				local bReplace = false
				
				-- Trace for only the entity we hit
				for i = iEntsLen, 1, -1 do
					if (tEnts[i] == pEntity) then
						tEnts[i] = tEnts[iEntsLen]
						tEnts[iEntsLen] = nil
						bReplace = true
						
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
				
				-- Should never be false
				if (bReplace) then
					tEnts[iEntsLen] = pEntity
				end
			end
			
			vNewSrc = tr.HitPos
			vEnd = vNewSrc + vShotDir * flDistance
			
			if (bShowPenetration) then
				debugoverlay.Line(vHitPos, vNewSrc, DEBUG_LENGTH, color_altdebug)
			end
			
			local iExitMaterial = tr.MatType
			local tMatParams = tMaterialParameters[iEnterMaterial]
			local flPenetrationModifier = bHitGrate and 1 or tMatParams and tMatParams.Penetration or 1
			local flDamageModifier = bHitGrate and 0.99 or tMatParams and tMatParams.Damage or 0.5
			local flTraceDistance = (vNewSrc - vHitPos):LengthSqr()
			
			// if enter & exit point is wood or metal we assume this is 
			// a hollow crate or barrel and give a penetration bonus
			if (bHitGrate and (iExitMaterial == MAT_GRATE or bit.band(util.PointContents(tr.HitPos), CONTENTS_GRATE) ~= 0) or iEnterMaterial == iExitMaterial and tDoublePenetration[iExitMaterial]) then
				flPenetrationModifier = flPenetrationModifier * 2	
			end

			local flPenetrationDistance = flPenetrationPower * flPenetrationModifier
			
			// check if bullet has enough power to penetrate this distance for this material
			if (flTraceDistance > flPenetrationDistance * flPenetrationDistance) then
				break // bullet hasn't enough power to penetrate this distance
			end
			
			if (bDoDebugHit) then
				debugoverlay.Box(tr.HitPos, vector_debug_min, vector_debug_max, DEBUG_LENGTH, color_altdebug)
			end
			
			// bullet did penetrate object, exit Decal
			Impact(bWeaponValid and pWeapon, iAmmoDamageType, bFirstTimePredicted, vSrc, tr)
			
			// penetration was successful
			flTraceDistance = math.sqrt(flTraceDistance)
			
			// setup new start end parameters for successive trace
			flPenetrationPower = flPenetrationPower - flTraceDistance / flPenetrationModifier
			flCurrentDistance = flCurrentDistance + flTraceDistance
			
			// reduce damage power each time we hit something other than a grate
			flCurrentDamage = flCurrentDamage * flDamageModifier
			flDistance = (flDistance - flCurrentDistance) * 0.5
			
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
		until (flCurrentDamage <= 0)
		
		Tracer(bDebugShoot, vSrc, vFinalHit, bFirstTimePredicted, iTracerFreq, bWeaponValid and pWeapon, self, iAmmoTracerType, sTracerName)
	end
	
	if (bIsPlayer) then
		self:LagCompensation(false)
	end
end

-- FireCSSBullets without penetration
function PLAYER:FireSDKBullets(tInfo)
	
end

function PLAYER:FireQuakeBullets(tInfo)
	if (hook.Run("EntityFireBullets", self, tInfo) == false) then
		return
	end
	
	local bIsPlayer = self:IsPlayer()
	
	if (bIsPlayer) then
		self:LagCompensation(true)
	end
	
	local pWeapon = self:GetActiveWeapon()
	local bWeaponValid = pWeapon:IsValid()
	
	-- FireBullets info
	local sAmmoType
	local iAmmoType
	
	if (tInfo.AmmoType == nil) then
		sAmmoType = ""
		iAmmoType = -1
	elseif (isstring(tInfo.AmmoType)) then
		sAmmoType = tInfo.AmmoType
		iAmmoType = game.GetAmmoID(sAmmoType)
	else
		iAmmoType = tInfo.AmmoType
		sAmmoType = game.GetAmmoName(iAmmoType) or ""
	end
	
	local pAttacker = tInfo.Attacker or self
	local fCallback = tInfo.Callback
	local iDamage = tInfo.Damage or 0
	local vDir = tInfo.Dir and tInfo.Dir:GetNormal() or self:GetAimVector()
	local flDistance = tInfo.Distance or MAX_TRACE_LENGTH
	local Filter = tInfo.Filter or self
	local iFlags = tInfo.Flags or 0
	local flForce = tInfo.Force or 1
	local bHullTrace = tInfo.HullTrace or false
	local pInflictor = tInfo.Inflictor and tInfo.Inflictor:IsValid() and tInfo.Inflictor or bWeaponValid and pWeapon or self
	local iMask = tInfo.Mask or MASK_SHOT
	local iNPCDamage = tInfo.NPCDamage or 0
	local iNum = tInfo.Num or 1
	local iPlayerDamage = tInfo.PlayerDamage or 0
	local vSrc = tInfo.Src or self:GetShootPos()
	local iTracerFreq = tInfo.Tracer or 1
	local sTracerName = tInfo.TracerName or "Tracer"
	
	-- Ammo
	local iAmmoFlags = game.GetAmmoFlags(sAmmoType)
	local flAmmoForce = game.GetAmmoForce(sAmmoType)
	local iAmmoDamageType = game.GetAmmoDamageType(sAmmoType)
	local iAmmoMinSplash = game.GetAmmoMinSplash(sAmmoType)
	local iAmmoMaxSplash = game.GetAmmoMaxSplash(sAmmoType)
	local iAmmoNPCDamage = game.GetAmmoNPCDamage(sAmmoType)
	local iAmmoPlayerDamage = game.GetAmmoPlayerDamage(sAmmoType)
	local iAmmoTracerType = game.GetAmmoTracerType(sAmmoType)
	
	if (bit.band(iAmmoFlags, AMMO_INTERPRET_PLRDAMAGE_AS_DAMAGE_TO_PLAYER) ~= 0) then
		if (iPlayerDamage == 0) then
			iPlayerDamage = iAmmoPlayerDamage
		end
		
		if (iNPCDamage == 0) then
			iNPCDamage = iAmmoNPCDamage
		end
	end
	
	local iAmmoDamage = bIsPlayer and iAmmoPlayerDamage or iAmmoNPCDamage
	
	-- Loop values
	local bDrop = bit.band(iAmmoFlags, AMMO_FORCE_DROP_IF_CARRIED) ~= 0
	local bDebugShoot = ai_debug_shoot_positions:GetBool()
	local bFirstShotInaccurate = bit.band(iFlags, FIRE_BULLETS_FIRST_SHOT_ACCURATE) == 0
	local flPhysPush = phys_pushscale:GetFloat()
	local bStartedInWater = bit.band(util.PointContents(vSrc), MASK_WATER) ~= 0
	local bFirstTimePredicted = IsFirstTimePredicted()
	local flSpreadBias, flFlatness, bNegBias, vFireBulletMax, vFireBulletMin, vSpreadRight, vSpreadUp, tEnts, iEntsLen
	local iSeed = self:GetMD5Seed() % 0x100 - 1
	
	-- Don't calculate stuff we won't end up using
	if (bFirstShotInaccurate or iNum ~= 1) then
		flSpreadBias = tInfo.SpreadBias or 1
		
		local vSpread = tInfo.Spread or vector_origin
		vSpreadRight = vSpread:Right()
		vSpreadRight:Mul(vSpread[1])
		vSpreadUp = vSpread:Up()
		vSpreadUp:Mul(vSpread[2])
		
		if (bHullTrace and iNum ~= 1) then
			local flHullSize = tInfo.HullSize
			vFireBulletMax = flHullSize and Vector(flHullSize, flHullSize, flHullSize) or Vector(3, 3, 3)
			vFireBulletMin = -vFireBulletMax
		end
	end
	
	local bDoDebugHit
	
	do
		//Adrian: visualize server/client player positions
		//This is used to show where the lag compesator thinks the player should be at.
		local iHitNum = sv_showplayerhitboxes:GetInt()
		
		if (iHitNum > 0) then
			local pLagPlayer = Player(iHitNum)
			
			if (pLagPlayer:IsValid()) then
				pLagPlayer:DrawHitBoxes(DEBUG_LENGTH)
			end
		end
		
		iHitNum = sv_showimpacts:GetInt()
		bDoDebugHit = iHitNum == 1 or (CLIENT and iHitNum == 2) or (SERVER and iHitNum == 3)
	end
	
	for iShot = 1, iNum do
		local vShotDir
		iSeed = iSeed + 1
		gs.random:SetSeed(iSeed)
		
		if (bFirstShotInaccurate or iShot ~= 1) then
			vShotDir = vDir + vShootRight * gs.random:RandomFloat(-flSpreadBias, flSpreadBias)
			+ vShootUp * gs.random:RandomFloat(-flSpreadBias, flSpreadBias)
			vShotDir:Normalize()
		else
			vShotDir = vDir
		end
		
		local tr = bHullTrace and iShot % 2 == 0 and
			// Half of the shotgun pellets are hulls that make it easier to hit targets with the shotgun.
			util.TraceHull({
				start = vSrc,
				endpos = vSrc + vShotDir * flDistance,
				mins = vFireBulletMin,
				maxs = vFireBulletMax,
				mask = iMask,
				filter = Filter
			})
		or
			util.TraceLine({
				start = vSrc,
				endpos = vSrc + vShotDir * flDistance,
				mask = iMask,
				filter = Filter
			})
		
		local vHitPos = tr.HitPos
		local bEndNotWater = bit.band(util.PointContents(vHitPos), MASK_WATER) == 0
		Splash(vHitPos, bStartedInWater, bEndNotWater, vSrc, bWeaponValid and pWeapon, bFirstTimePredicted, iAmmoMinSplash, iAmmoMaxSplash)
		
		if (tr.Hit and not tr.HitSky) then
			Damage(bDoDebugHit, bStartedWater, bEndNotWater, iFlags, iDamage, iPlayerDamage, iNPCDamage, iAmmoDamage, pAttacker, pInflictor, iAmmoDamageType,
				tr, bWeaponValid and pWeapon, vShotDir, flAmmoForce, flForce, flPhysPush, iAmmoType, vSrc, fCallback, bFirstTimePredicted, bDrop)
		end
		
		Tracer(bDebugShoot, vSrc, vHitPos, bFirstTimePredicted, iTracerFreq, bWeaponValid and pWeapon, self, iAmmoTracerType, sTracerName)
	end
	
	if (bIsPlayer) then
		self:LagCompensation(false)
	end
end

local fFrameCount = gs.IsType(FrameNumber, TYPE_FUNCTION) and FrameNumber or UnPredictedCurTime

function PLAYER:GetMD5Seed()
	local iFrameCount = fFrameCount()
	
	if (self.m_iMD5SeedSavedFrame ~= iFrameCount) then
		self.m_iMD5SeedSavedFrame = iFrameCount
		self.m_iMD5Seed = math.MD5Random(self:GetCurrentCommand():CommandNumber())
	end
	
	return self.m_iMD5Seed
end

GESTURE_SLOT_COUNT = 7

function PLAYER:AnimResetGestureSlots()
	for i = 0, GESTURE_SLOT_COUNT - 1 do
		self:AnimResetGestureSlot(i)
	end
end
