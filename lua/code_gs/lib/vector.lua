local VECTOR = FindMetaTable("Vector")

--vector_origin = Vector()
vector_forward = Vector(1, 0, 0)
vector_backward = Vector(-1, 0, 0)
vector_left = Vector(0, 1, 0)
vector_right = Vector(0, -1, 0)
--vector_up = Vector(0, 0, 1)
vector_down = Vector(0, 0, -1)
vector_normal = Vector(1, 1, 1)

vector_debug_max = Vector(2, 2, 2)
vector_debug_min = -vector_debug_max

function VectorRand(flMin, flMax)
	if (not flMin) then
		flMin = -1
	end
	
	if (not flMax) then
		flMax = 1
	end
	
	return Vector(math.Rand(flMin, flMax),
		math.Rand(flMin, flMax),
		math.Rand(flMin, flMax))
end

function VECTOR:NormalizeInPlace()
	if (self == vector_origin) then
		return 0
	end
	
	local x = self[1]
	local y = self[2]
	local z = self[3]
	local flRadius = math.sqrt(x*x + y*y + z*z)
	self[1] = x / flRadius
	self[2] = y / flRadius
	self[3] = z / flRadius
	
	return flRadius
end

function VECTOR:DistanceSqrToRay(vStart, vEnd)
	local vTo = self - vStart
	local vDir = vEnd - vStart
	local flLength = vDir:NormalizeInPlace()
	local flRange = (vDir):Dot(vTo)
	
	if (flRange < 0.0) then
		// off start point
		return -vTo:LengthSqr(), flRange, vStart
	end
	
	if (flRange > flLength) then
		// off end point
		return -(self - vEnd):LengthSqr(), flRange, vEnd
	end
	
	// within ray bounds
	local vOnRay = vStart + flRange * vDir
	
	return (self - vOnRay):LengthSqr(), flRange, vOnRay
end

function VECTOR:DistanceToRay(vStart, vEnd)
	local vTo = self - vStart
	local vDir = vEnd - vStart
	local flLength = vDir:NormalizeInPlace()
	local flRange = (vDir):Dot(vTo)
	
	if (flRange < 0.0) then
		// off start point
		return -vTo:Length(), flRange, vStart
	end
	
	if (flRange > flLength) then
		// off end point
		return -(self - vEnd):Length(), flRange, vEnd
	end
	
	// within ray bounds
	local vOnRay = vStart + flRange * vDir
	
	return (self - vOnRay):Length(), flRange, vOnRay
end

-- FIXME
function VECTOR:ImpulseAngle()
	return Angle(self[2], self[3], self[1])
end

function VECTOR:Right(vUp --[[= Vector(0, 0, 1)]])
	if (self[1] == 0 and self[2] == 0)then
		// pitch 90 degrees up/down from identity
		return Vector(0, -1, 0)
	end
	
	if (vUp == nil) then
		vUp = vector_up
	end
	
	local vRet = self:Cross(vUp)
	vRet:Normalize()
	
	return vRet
end

function VECTOR:Up(vUp --[[= Vector(0, 0, 1)]])
	if (self[1] == 0 and self[2] == 0)then
		return Vector(-self[3], 0, 0)
	end
	
	if (vUp == nil) then
		vUp = vector_up
	end
	
	local vRet = self:Cross(vUp)
	vRet = vRet:Cross(self)
	vRet:Normalize()
	
	return vRet
end

function VECTOR:ToTable()
	return {self[1], self[2], self[3]}
end

// Return true of the sphere might touch the box (the sphere is actually treated
// like a box itself, so this may return true if the sphere's bounding box touches
// a corner of the box but the sphere itself doesn't).
function VECTOR:QuickBoxSphereTest(flRadius, vBBMin, vBBMax)
	return self[1] - flRadius < vBBMax[1] and self[1] + flRadius > vBBMin[1] and
		self[2] - flRadius < vBBMax[2] and self[2] + flRadius > vBBMin[2] and
		self[3] - flRadius < vBBMax[3] and self[3] + flRadius > vBBMin[3]
end

function VECTOR:CalcDistanceToAABB(vMins, vMaxs)
	return math.sqrt(self:CalcSqrDistanceToAABB(vMins, vMaxs))
end

function VECTOR:CalcSqrDistanceToAABB(vMins, vMaxs)
	local flDistSqr = 0
	local p1 = self[1]
	local p2 = vMins[1]
	
	if (p1 < p2) then
		local flDelta = p2 - p1
		flDistSqr = flDelta * flDelta
	else
		local p2 = vMaxs[1]
		
		if (p1 > p2) then
			local flDelta = p1 - p2
			flDistSqr = flDelta * flDelta
		end
	end
	
	p1 = self[2]
	p2 = vMins[2]
	
	if (p1 < p2) then
		local flDelta = p2 - p1
		flDistSqr = flDistSqr + flDelta * flDelta
	else
		local p2 = vMaxs[2]
		
		if (p1 > p2) then
			local flDelta = p1 - p2
			flDistSqr = flDistSqr + flDelta * flDelta
		end
	end
	
	p1 = self[3]
	p2 = vMins[3]
	
	if (p1 < p2) then
		local flDelta = p2 - p1
		flDistSqr = flDistSqr + flDelta * flDelta
	else
		local p2 = vMaxs[3]
		
		if (p1 > p2) then
			local flDelta = p1 - p2
			flDistSqr = flDistSqr + flDelta * flDelta
		end
	end
	
	return flDistSqr
end

function VECTOR:CalcClosestPointOnAABB(vMins, vMaxs)
	return Vector(math.Clamp(self[1], vMins[1], vMaxs[1]),
		math.Clamp(self[2], vMins[2], vMaxs[2]),
		math.Clamp(self[3], vMins[3], vMaxs[3]))
end

function VECTOR:GetNormalRadius()
	local x = self[1]
	local y = self[2]
	local z = self[3]
	
	return math.sqrt(x * x + y * y + z * z)
end

function VECTOR:Lerp(vFrom, vTo)
	return Vector(Lerp(self[1], vFrom[1], vTo[1]),
		Lerp(self[2], vFrom[2], vTo[2]),
		Lerp(self[3], vFrom[3], vTo[3]))
end

function VECTOR:GetClosestPoint(flMaxDist, vTarget)
	local vDelta = vTarget - vStart
	local flDistSqr = vDelta:LengthSqr()
	
	if (flDistSqr <= flMaxDist * flMaxDist) then
		return vTarget
	end
	
	return self + (vDelta / math.sqrt(flDistSqr)) * flMaxDist
end

function VECTOR:Interpolate(vDest, flFrac)
	-- Cache values
	local x = self[1]
	local y = self[2]
	local z = self[3]
	
	return Vector(x + flFrac * (vDest[1] - x),
		y + flFrac * (vDest[2] - y),
		z + flFrac * (vDest[3] - z))
end

function VECTOR:Yaw()
	local y = self[2]
	local x = self[1]
	
	if (y == 0 and x == 0) then
		return 0
	end
	
	return math.deg(math.atan2(y, x))
end

function VECTOR:Pitch()
	if (self[2] == 0 and self[1] == 0) then
		if (self[3] < 0) then
			return 180
		end
		
		return -180
	end
	
	return math.deg(math.atan2(-self[3], self:Length2D()))
end

-- FIXME
--[[// snaps a vector to the nearest axis vector (if within epsilon)
function VECTOR:SnapDirectionToAxis(epsilon)
	local proj = 1 - epsilon
	-- x
	if (math.abs(self[1]) > proj) then
		// snap to axis unit vector
		if (direction[1] < 0) then
			direction[1] = -1
		else
			direction[1] = 1
		end
		
		direction[2] = 0
		direction[3] = 0
		return
	end
	-- y
	if (math.abs(self[2]) > proj) then
		// snap to axis unit vector
		if (direction[2] < 0) then
			direction[2] = -1
		else
			direction[2] = 1
		end
		
		direction[3] = 0
		direction[1] = 0
		return
	end
	-- z
	if (math.abs(self[3]) > proj) then
		// snap to axis unit vector
		if (direction[3] < 0) then
			direction[3] = -1
		else
			direction[3] = 1
		end
		
		direction[1] = 0
		direction[2] = 0
	end
end]]

function VECTOR:Transform(vmat)
	return Vector(self:Dot(vmat:GetRowVector(1)) + vmat:GetField(1, 4),
		self:Dot(vmat:GetRowVector(2)) + vmat:GetField(2, 4),
		self:Dot(vmat:GetRowVector(3)) + vmat:GetField(3, 4))
end

// assuming the matrix is orthonormal, transform in1 by the transpose (also the inverse in this case) of in2.
function VECTOR:ITransform(vmat)
	local x = self[1] - vmat:GetField(1, 4)
	local y = self[2] - vmat:GetField(2, 4)
	local z = self[3] - vmat:GetField(3, 4)
	
	return Vector(x * vmat:GetField(1, 1) + y * vmat:GetField(2, 1) + z * vmat:GetField(3, 1),
		x * vmat:GetField(1, 2) + y * vmat:GetField(2, 2) + z * vmat:GetField(3, 2),
		x * vmat:GetField(1, 3) + y * vmat:GetField(2, 3) + z * vmat:GetField(3, 3))
end

function VECTOR:GetTranslationMatrix(w --[[= 1]])
	return Matrix({
		{1, 0, 0, self[1]},
		{0, 1, 0, self[2]},
		{0, 0, 1, self[3]},
		{0, 0, 0, w or 1}
	})
end

function VECTOR:GetScaledMatrix(w --[[= 1]]) -- Quaternion substitute
	return Matrix({
		{self[1], 0, 0, 0},
		{0, self[2], 0, 0},
		{0, 0, self[3], 0},
		{0, 0, 0, w or 1}
	})
end

function VECTOR:GetReflectionMatrix(vec) -- Plane substitute
	local x = vec[1]
	local y = vec[2]
	local z = vec[3]
	local xy = x * y
	local yz = y * z
	local zx = z * x
	
	local mReflect = Matrix({
		{-2 * x * x + 1, -2 * xy, -2 * zx, 0},
		{-2 * xy, -2 * y * y + 1, -2 * yz, 0},
		{-2 * zx, -2 * yz, -2 * z * z + 1, 0},
		{0, 0, 0, 1}
	})
	
	local mBack = Matrix()
	mBack:SetTranslation(-self)
	
	local mForward = Matrix()
	mForward:SetTranslation(self)
	
	// (multiplied in reverse order, so it translates to the origin point,
	// reflects, and translates back).
	return mForward * mReflect * mBack
end

function VECTOR:GetProjectionMatrix(PN, PD) -- Plane substitute
	local x = PN[1]
	local y = PN[2]
	local z = PN[3]
	local x1 = self[1]
	local y1 = self[2]
	local z1 = self[3]
	local dot = x*x1 + y*y1 + z*z1 - PD
	
	return Matrix({
		{dot - x1 * x, -x1 * y, x1 * z, -x1 * -PD},
		{-y1 * x, dot - y1 * y, -y1 * z, -y1 * -PD},
		{-z1 * x, -z1 * y, dot - z1 * z, -z1 * -PD},
		{-x, -y, -z, dot + PD}
	})
end

function VECTOR:GetAxisRotMatrix(fRadians)
	fRadians = math.rad(fRadians)
	
	local x = self[1]
	local y = self[2]
	local z = self[3]
	local s = math.sin(fRadians)
	local c = math.cos(fRadians)
	local t = 1 - c
	local tx = t * x
	local ty = t * y
	local tz = t * z
	local sx = s * x
	local sy = s * y
	local sz = s * z
	
	return Matrix({
		{tx*x+c, tx*y-sz, tx*z+sy, 0},
		{tx*y+sz, ty*y+c, ty*z-sx, 0},
		{tx*z-sy, ty*z+sx, tz*z+c, 0},
		{0, 0, 0, 1}
	})
end
