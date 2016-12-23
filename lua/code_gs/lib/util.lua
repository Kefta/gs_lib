DEBUG_LENGTH = 3

COORD_EXTENT = 2 * 16384
// Maximum traceable distance (assumes cubic world and trace from one corner to opposite)
// COORD_EXTENT * sqrt(3)
MAX_TRACE_LENGTH = math.sqrt(3) * COORD_EXTENT

SNDLVL_NONE = 0
SNDLVL_20dB = 20 // rustling leaves
SNDLVL_25dB = 25 // whispering
SNDLVL_30dB = 30 // library
SNDLVL_35dB = 35
SNDLVL_40dB = 40
SNDLVL_45dB = 45 // refrigerator
SNDLVL_50dB = 50 // 3.9 // average home
SNDLVL_55dB = 55 // 3.0
SNDLVL_IDLE = 60 // 2.0	
SNDLVL_60dB = 60 // 2.0 // normal conversation, clothes dryer
SNDLVL_65dB = 65 // 1.5 // washing machine, dishwasher
SNDLVL_STATIC = 66 // 1.25
SNDLVL_70dB = 70 // 1.0 // car, vacuum cleaner, mixer, electric sewing machine
SNDLVL_NORM = 75
SNDLVL_75dB = 75 // 0.8 // busy traffic
SNDLVL_80dB = 80 // 0.7 // mini-bike, alarm clock, noisy restaurant, office tabulator, outboard motor, passing snowmobile
SNDLVL_TALKING = 80 // 0.7
SNDLVL_85dB = 85 // 0.6 // average factory, electric shaver
SNDLVL_90dB = 90 // 0.5 // screaming child, passing motorcycle, convertible ride on frw
SNDLVL_95dB = 95
SNDLVL_100dB = 100 // 0.4 // subway train, diesel truck, woodworking shop, pneumatic drill, boiler shop, jackhammer
SNDLVL_105dB = 105 // helicopter, power mower
SNDLVL_110dB = 110 // snowmobile drvrs seat, inboard motorboat, sandblasting
SNDLVL_120dB = 120 // auto horn, propeller aircraft
SNDLVL_130dB = 130 // air raid siren
SNDLVL_GUNFIRE = 140 // 0.27 // THRESHOLD OF PAIN, gunshot, jet engine
SNDLVL_140dB = 140 // 0.2
SNDLVL_150dB = 150 // 0.2
SNDLVL_180dB = 180 // rocket launching

// -----------------------------------------
//	Vector cones
// -----------------------------------------
// VECTOR_CONE_PRECALCULATED - this resolves to vec3_origin, but adds some
// context indicating that the person writing the code is not allowing
// FireBullets() to modify the direction of the shot because the shot direction
// being passed into the function has already been modified by another piece of
// code and should be fired as specified. See GetActualShotTrajectory(). 

// NOTE: The way these are calculated is that each component == sin (degrees/2)
--VECTOR_CONE_PRECALCULATED = vec3_origin
VECTOR_CONE_1DEGREES = Vector(0.00873, 0.00873, 0.00873)
VECTOR_CONE_2DEGREES = Vector(0.01745, 0.01745, 0.01745)
VECTOR_CONE_3DEGREES = Vector(0.02618, 0.02618, 0.02618)
VECTOR_CONE_4DEGREES = Vector(0.03490, 0.03490, 0.03490)
VECTOR_CONE_5DEGREES = Vector(0.04362, 0.04362, 0.04362)
VECTOR_CONE_6DEGREES = Vector(0.05234, 0.05234, 0.05234)
VECTOR_CONE_7DEGREES = Vector(0.06105, 0.06105, 0.06105)
VECTOR_CONE_8DEGREES = Vector(0.06976, 0.06976, 0.06976)
VECTOR_CONE_9DEGREES = Vector(0.07846, 0.07846, 0.07846)
VECTOR_CONE_10DEGREES = Vector(0.08716, 0.08716, 0.08716)
VECTOR_CONE_15DEGREES = Vector(0.13053, 0.13053, 0.13053)
VECTOR_CONE_20DEGREES = Vector(0.17365, 0.17365, 0.17365)

function util.ClearTrace()
	return {
		Entity = NULL,
		Fraction = 1,
		FractionLeftSolid = 0,
		Hit = false,
		HitBox = 0,
		HitGroup = 0,
		HitNoDraw = false,
		HitNonWorld = false,
		HitNormal = Vector(0, 0, 0),
		HitPos = Vector(0, 0, 0),
		HitSky = false,
		HitTexture = "**empty**",
		HitWorld = false,
		MatType = 0,
		Normal = Vector(0, 0, 0),
		PhysicsBone = 0,
		StartPos = Vector(0, 0, 0),
		SurfaceProps = 0,
		StartSolid = false,
		AllSolid = false
	}
end

function util.TracePlayerBBox(tbl, pPlayer)
	tbl.mins, tbl.maxs = pPlayer:Crouching() and pPlayer:GetHullDuck() or pPlayer:GetHull()
	tbl.filter = tbl.filter or pPlayer
	
	return util.TraceRay(tbl)
end

function util.TracePlayerBBoxForGround(tbl, tr)
	tbl.output = nil
	local flFraction = tr.Fraction
	local vEndPos = tr.HitPos
	local vOldMaxs = tbl.maxs
	
	// Check the -x, -y quadrant
	local flTemp = vOldMaxs.x
	local Temp2 = vOldMaxs.y
	tbl.maxs = Vector(flTemp > 0 and 0 or flTemp, Temp2 > 0 and 0 or Temp2, vOldMaxs.z)
	local trTemp = util.TraceRay(tbl)

	if (trTemp.HitNormal >= 0.7 and trTemp.Entity ~= NULL) then
		trTemp.Fraction = flFraction
		trTemp.HitPos = vEndPos
		table.CopyFromTo(trTemp, tr)
		
		return tr
	end
	
	-- Re-use vector
	local Temp2 = tbl.maxs
	local vOldMins = tbl.mins
	flTemp = vOldMins.x
	Temp2.x = flTemp < 0 and 0 or flTemp
	flTemp = vOldMins.y
	Temp2.y = flTemp < 0 and 0 or flTemp
	Temp2.z = vOldMins.z
	tbl.mins = Temp2
	tbl.maxs = vOldMaxs
	tbl.output = trTemp
	util.TraceRay(tbl)

	if (trTemp.HitNormal >= 0.7 and trTemp.Entity ~= NULL) then
		trTemp.Fraction = flFraction
		trTemp.HitPos = vEndPos
		table.CopyFromTo(trTemp, tr)
		
		return tr
	end
	
	tbl.mins.x = vOldMins.x
	flTemp = vOldMaxs.x
	tbl.maxs = Vector(flTemp > 0 and 0 or flTemp, vOldMaxs.y, vOldMaxs.z)
	util.TraceRay(tbl)

	if (trTemp.HitNormal >= 0.7 and trTemp.Entity ~= NULL) then
		trTemp.Fraction = flFraction
		trTemp.HitPos = vEndPos
		table.CopyFromTo(trTemp, tr)
		
		return tr
	end
	
	flTemp = vOldMins.x
	mins.x = flTemp < 0 and 0 or flTemp
	mins.y = vOldMins.y
	maxs.x = vOldMaxs.x
	flTemp = vOldMaxs.y
	maxs.y = flTemp > 0 and 0 or flTemp
	util.TraceRay(tbl)
	
	if (trTemp.HitNormal >= 0.7 and trTemp.Entity ~= NULL) then
		trTemp.Fraction = flFraction
		trTemp.HitPos = vEndPos
		table.CopyFromTo(trTemp, tr)
	end
	
	return tr
end

--- Util
-- https://github.com/Facepunch/garrysmod-requests/issues/664
function util.ClipRayToEntity(tbl, pEnt)
	return util.TraceEntity(tbl, pEnt)
end

function util.ClipTraceToPlayers(tbl, tr, flMaxRange --[[= 60]])
	flMaxRange = (flMaxRange or 60) ^ 2
	tbl.output = nil
	local vAbsStart = tbl.start
	local vAbsEnd = tbl.endpos
	local Filter = tbl.filter
	local flSmallestFraction = tr.Fraction
	local tPlayers = player.GetAll()
	local trOutput
	
	for i = 1, #tPlayers do
		local pPlayer = tPlayers[i]
		
		if (not pPlayer:Alive() or pPlayer:IsDormant()) then
			continue
		end
		
		-- Don't bother to trace if the player is in the filter
		if (isentity(Filter)) then
			if (Filter == pPlayer) then
				continue
			end
		elseif (istable(Filter)) then
			local bFound = false
			
			for i = 1, #Filter do
				if (Filter[i] == pPlayer) then
					bFound = true
					
					break
				end
			end
			
			if (bFound) then
				continue
			end
		end
		
		local flRange = pPlayer:WorldSpaceCenter():DistanceSqrToRay(vAbsStart, vAbsEnd)
		
		if (flRange < 0 or flRange > flMaxRange) then
			continue
		end
		
		local trTemp = util.ClipRayToEntity(tbl, pPlayer)
		local flFrac = trTemp.Fraction
		
		if (flFrac < flSmallestFraction) then
			// we shortened the ray - save off the trace
			trOutput = trTemp
			flSmallestFraction = flFrac
		end
	end
	
	if (trOutput) then
		table.CopyFromTo(trOutput, tr)
	end
	
	return tr
end

function util.TraceRay(tbl)
	if (tbl.mins) then
		return util.TraceHull(tbl)
	end
	
	return util.TraceLine(tbl)
end

--- CS:S/DoD:S melee
function util.FindHullIntersection(tbl, tr)
	local iDist = 1e12
	tbl.output = nil
	local vSrc = tbl.start
	local vHullEnd = vSrc + (tr.HitPos - vSrc) * 2
	tbl.endpos = vHullEnd
	local tBounds = {tbl.mins, tbl.maxs}
	local trTemp = util.TraceLine(tbl)
	
	if (trTemp.Fraction ~= 1) then
		table.CopyFromTo(trTemp, tr)
		
		return tr
	end
	
	local trOutput
	
	for i = 1, 2 do
		for j = 1, 2 do
			for k = 1, 2 do
				tbl.endpos = Vector(vHullEnd.x + tBounds[i].x, 
					vHullEnd.y + tBounds[j].y,
					vHullEnd.z + tBounds[k].z)
				
				local trTemp = util.TraceLine(tbl)
				
				if (trTemp.Fraction ~= 1) then
					local iHitDistSqr = (trTemp.HitPos - vSrc):LengthSqr()
					
					if (iHitDistSqr < iDist) then
						trOutput = trTemp
						iDist = iHitDistSqr
					end
				end
			end
		end
	end
	
	if (trOutput) then
		table.CopyFromTo(trOutput, tr)
	end
	
	return tr
end

local sCRC = "%i%i%s"

function util.SeedFileLineHash(iSeed, sName, iAdditionalSeed --[[= 0]])
	return tonumber(util.CRC(sCRC:format(iSeed, iAdditionalSeed or 0, sName)))
end
