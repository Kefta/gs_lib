function debugoverlay.BoxDirection(vOrigin, vMins, vMaxs, vOrientation, flDuration, col)
	// convert vForward vector to aOrientation
	debugoverlay.BoxAngles(vOrigin, vMins, vMaxs, Angle(0, util.VecToYaw(vOrientation), 0), flDuration, col)
end

function debugoverlay.EntityBounds(pEntity, flDuration, col)
	debugoverlay.BoxAngles(pEntity:GetPos(), pEntity:OBBMins(), pEntity:OBBMaxs(), pEntity:GetAngles(), flDuration, col)
end

function debugoverlay.EntityText(pEntity, iOffset, sText, flDuration, col)
	-- This actually calls a different overlay method
	-- But it is not exposed to the Lua state
	-- So this is the next best alternative
	debugoverlay.EntityTextAtPosition(pEntity:GetPos(), iOffset, sText, flDuration, col)
end

function debugoverlay.Cross3D(vPos, flSize, flDuration, col, bNoDepthTest --[[= false]])
	local vX = Vector(flSize, 0, 0)
	local vY = Vector(0, flSize, 0)
	local vZ = Vector(0, 0, flSize)
	
	debugoverlay.Line(vPos + vX, vPos - vX, flDuration, col, bNoDepthTest)
	debugoverlay.Line(vPos + vY, vPos - vY, flDuration, col, bNoDepthTest)
	debugoverlay.Line(vPos + vZ, vPos - vZ, flDuration, col, bNoDepthTest)
end

function debugoverlay.Cross3DHull(vPos, vMins, vMaxs, flDuration, col, bNoDepthTest)
	local vStart = vMins + vPos
	local vEnd = vMaxs + vPos
	local x = vMaxs[1] - vMins[1]
	local y = vMaxs[2] - vMins[2]
	
	debugoverlay.Line(vStart, vEnd, flDuration, col, bNoDepthTest)
	
	vStart[1] = vStart[1] + x
	vEnd[1] = vEnd[1] - x
	
	debugoverlay.Line(vStart, vEnd, flDuration, col, bNoDepthTest)
	
	vStart[2] = vStart[2] + y
	vEnd[2] = vEnd[2] - y
	
	debugoverlay.Line(vStart, vEnd, flDuration, col, bNoDepthTest)
	
	vStart[1] = vStart[1] - x
	vEnd[1] = vEnd[1] + x
	
	debugoverlay.Line(vStart, vEnd, flDuration, col, bNoDepthTest)
end

function debugoverlay.Cross3DOriented(vPos, aOrientation, flSize, flDuration, col, bNoDepthTest)
	local vForward = aOrientation:Forward() * flSize
	local vRight = aOrientation:Right() * flSize
	local vUp = aOrientation:Up() * flSize
	
	debugoverlay.Line(vPos + vRight, vPos - vRight, flDuration, col, bNoDepthTest)
	debugoverlay.Line(vPos + vForward, vPos - vForward, flDuration, col, bNoDepthTest)
	debugoverlay.Line(vPos + vUp, vPos - vUp, flDuration, col, bNoDepthTest)
end

function debugoverlay.Cross3DOrientedMatrix(vmat, flSize, flDuration, iCol, bNoDepthTest)
	local vForward = vmat:GetColumnVector(1) * flSize
	local vLeft = vmat:GetColumnVector(2) * flSize
	local vUp = vmat:GetColumnVector(3) * flSize
	local vPos = vmat:GetColumnVector(4) * flSize
	
	debugoverlay.Line(vPos + vLeft, vPos - vLeft, flDuration, Color(0, iCol, 0), bNoDepthTest)
	debugoverlay.Line(vPos + vForward, vPos - vForward, flDuration, Color(iCol, 0, 0), bNoDepthTest)
	debugoverlay.Line(vPos + vUp, vPos - vUp, flDuration, Color(0, 0, iCol), bNoDepthTest)
end

local vector_tick = Vector(0, 0, 8)

function debugoverlay.DrawTickMarkedLine(pPlayer, vStartPos, vEndPos, flTickDist, iTextDist, flDuration, col, bNoDepthTest)
	local vLineDir = vEndPos - vStartPos
	vLineDir:Normalize()
	local vSideDir
	
	if (SERVER) then
		local vBodyDir = pPlayer:GetAngles():Forward()
		vBodyDir[3] = 0
		vSideDir = vLineDir:Cross(4 * vBodyDir)
	else
		vSideDir = vLineDir:Cross(4 * pPlayer:LocalEyeAngles():Forward())
	end
	
	local vTickPos = vStartPos
	local iTickCount = 0
	local vTickMod = flTickDist * vLineDir
	
	// First draw the line
	debugoverlay.Line(vStartPos, vEndPos, flDuration, col, bNoDepthTest)
	
	// Now draw the ticks
	for i = 0, vLineDir/flTickDist do
		// Draw tick mark text
		if (iTickCount == iTextDist) then
			local vTickLeft = vTickPos - vSideDir
			debugoverlay.Line(vTickLeft, vTickPos + vSideDir, flDuration, color_black, bNoDepthTest)
			debugoverlay.Text(vTickLeft + vector_tick, tostring(i), flDuration, true)
			iTickCount = 0
		else
			// Draw tick mark
			debugoverlay.Line(vTickPos - vSideDir, vTickPos + vSideDir, flDuration, col, bNoDepthTest)
		end
		
		iTickCount = iTickCount + 1
		vTickPos = vTickPos + vTickMod
	end
end

local vector_6x_max = Vector(6, 0, 0)
local vector_6y_max = Vector(0, 6, 0)
local vector_6x_min = -vector_6x_max
local vector_6y_min = -vector_6y_max

function debugoverlay.DrawGroundCrossHairOverlay(pPlayer, col, bNoDepthTest)
	// Trace a line to where player is looking
	local vSource = pPlayer:EyePos()
	local tr = util.TraceLine({
		start = vSource,
		endpos = vSource + pPlayer:ActualEyeAngles():Forward() * 2048,
		mask = MASK_SOLID,
		filter = pPlayer
	})
	
	if (tr.Hit and vector_up:Dot(tr.HitNormal) > 0.5) then
		tr.HitPos[3] = tr.HitPos[3] + 1
		debugoverlay.Line(tr.HitPos + vector_6x_min, tr.HitPos + vector_6x_max, 0, col, bNoDepthTest)
		debugoverlay.Line(tr.HitPos + vector_6y_min, tr.HitPos + vector_6y_max, 0, col, bNoDepthTest)
	end
end

function debugoverlay.HorzArrow(vStartPos, vEndPos, flWidth, flDuration, col, bNoDepthTest)
	local vLineDir = vEndPos - vStartPos
	vLineDir:Normalize()
	
	local flRadius = flWidth / 2
	local vSideDir = vLineDir:Cross(vector_up)
	
	local v1 = vStartPos - vSideDir * flRadius
	local v2 = vEndPos - vLineDir * flWidth - vSideDir * flRadius
	local v3 = vEndPos - vLineDir * flWidth - vSideDir * flWidth
	--local v4 = vEndPos
	local v5 = vEndPos - vLineDir * flWidth + vSideDir * flWidth
	local v6 = vEndPos - vLineDir * flWidth + vSideDir * flRadius
	local v7 = vStartPos + vSideDir * flRadius
	
	// Outline the arrow
	debugoverlay.Line(v1, v2, col, flDuration, bNoDepthTest)
	debugoverlay.Line(v2, v3, col, flDuration, bNoDepthTest)
	debugoverlay.Line(v3, vEndPos, col, flDuration, bNoDepthTest)
	debugoverlay.Line(vEndPos, v5, col, flDuration, bNoDepthTest)
	debugoverlay.Line(v5, v6, col, flDuration, bNoDepthTest)
	debugoverlay.Line(v6, v7, col, flDuration, bNoDepthTest)
	
	if (col.a ~= 0) then
		// Fill us in with triangles
		debugoverlay.Triangle(v5, vEndPos, v3, col, flDuration, bNoDepthTest) // Tip
		debugoverlay.Triangle(v1, v7, v6, col, flDuration, bNoDepthTest) // Shaft
		debugoverlay.Triangle(v6, v2, v1, col, flDuration, bNoDepthTest)
		
		// And backfaces
		debugoverlay.Triangle(v3, vEndPos, v5, col, flDuration, bNoDepthTest) // Tip
		debugoverlay.Triangle(v6, v7, v1, col, flDuration, bNoDepthTest) // Shaft
		debugoverlay.Triangle(v1, v2, v6, col, flDuration, bNoDepthTest)
	end
end

function debugoverlay.YawArrow(vStartPos, yaw, flLength, flWidth, flDuration, col, bNoDepthTest)
	debugoverlay.HorzArrow(vStartPos, vStartPos + math.YawToVec(yaw) * flLength, flWidth, flDuration, col, bNoDepthTest)
end

function debugoverlay.VertArrow(vStartPos, vEndPos, flWidth, flDuration, col, bNoDepthTest)
	local vLineDir = vEndPos - vStartPos
	vLineDir:Normalize()
	local flRadius = flWidth / 2
	local vUp = vLineDir:Up()
	
	local v1 = vStartPos - vUp * flRadius
	local v2 = vEndPos - vLineDir * flWidth - vUp * flRadius
	local v3 = vEndPos - vLineDir * flWidth - vUp * flWidth
	--local v4 = vEndPos
	local v5 = vEndPos - vLineDir * flWidth + vUp * flWidth
	local v6 = vEndPos - vLineDir * flWidth + vUp * flRadius
	local v7 = vStartPos + vUp * flRadius
	
	debugoverlay.Line(v1, v2, col, flDuration, bNoDepthTest)
	debugoverlay.Line(v2, v3, col, flDuration, bNoDepthTest)
	debugoverlay.Line(v3, vEndPos, col, flDuration, bNoDepthTest)
	debugoverlay.Line(vEndPos, v5, col, flDuration, bNoDepthTest)
	debugoverlay.Line(v5, v6, col, flDuration, bNoDepthTest)
	debugoverlay.Line(v6, v7, col, flDuration, bNoDepthTest)
	
	if (col.a > 0) then
		debugoverlay.Triangle(v5, vEndPos, v3, col, flDuration, bNoDepthTest) // Tip
		debugoverlay.Triangle(v1, v7, v6, col, flDuration, bNoDepthTest) // Shaft
		debugoverlay.Triangle(v6, v2, v1, col, flDuration, bNoDepthTest)
		
		debugoverlay.Triangle(v3, vEndPos, v5, col, flDuration, bNoDepthTest) // Tip
		debugoverlay.Triangle(v6, v7, v1, col, flDuration, bNoDepthTest) // Shaft
		debugoverlay.Triangle(v1, v2, v6, col, flDuration, bNoDepthTest)
	end
end

function debugoverlay.CirclePlayer(pPlayer, vPos, flRadius, flDuration, col, bNoDepthTest)
	debugoverlay.CircleAngles(vPos, pPlayer:ActualEyeAngles():Forward():Angle(), flRadius, flDuration, col, bNoDepthTest)
end

function debugoverlay.CircleAngles(vPos, aOrientation, flRadius, flDuration, col, bNoDepthTest)
	// Setup our transform matrix
	local vmat = aOrientation:Matrix(vPos)
	
	// Default draws circle in the y/z plane
	debugoverlay.Circle(vPos, vmat:GetColumnVector(3), vmat:GetColumnVector(2), flDuration, col, bNoDepthTest)
end

function debugoverlay.Circle(vPos, vX, vY, flRadius, iSegments, flDuration, col, bNoDepthTest)
	if (iSegments == nil) then
		iSegments = 16
	end
	
	local flRadStep = 2*math.pi / iSegments

	// Find our first position
	// Retained for triangle fanning
	local vStart = vPos + vX * flRadius
	local vPos = vStart

	// Draw out each segment (fanning triangles if we have an alpha amount)
	for i = 1, iSegments do
		// Store off our last vPos
		local vLastPosition = vPos

		// Calculate the new one
		local flStep = flRadStep * i
		vPos = vPos + (vX * math.cos(flStep) * flRadius) + (vY * math.sin(flStep) * flRadius)
		
		// Draw the line
		debugoverlay.Line(vLastPosition, vPos, flDuration, col, bNoDepthTest)

		// If we have an alpha value, then draw the fan
		if (col.a ~= 0 and i ~= 1) then
			debugoverlay.Triangle(vStart, vLastPosition, vPos, flDuration, col, bNoDepthTest)
		end
	end
end

-- FIXME: This is overriding a default function
function debugoverlay.Sphere(vPos, aOrientation, flRadius, flDuration, col, bNoDepthTest)
	// Setup our transform matrix
	local vmat = aOrientation:Matrix(vPos)
	
	// Default draws circle in the y/x plane
	local vX = vmat:GetColumnVector(1)
	local vY = vmat:GetColumnVector(2)
	local vZ = vmat:GetColumnVector(3)
	debugoverlay.Circle(vPos, vX, vY, flRadius, flDuration, col, bNoDepthTest) // xy plane
	debugoverlay.Circle(vPos, vY, vZ, flRadius, flDuration, col, bNoDepthTest) // yz plane
	debugoverlay.Circle(vPos, vX, vZ, flRadius, flDuration, col, bNoDepthTest) // xz plane
end
