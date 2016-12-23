local VECTOR = FindMetaTable("Vector")

vector_normal = Vector(0, 0, 1)
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

function VECTOR:ImpulseAngle()
	return Angle(self.y, self.z, self.x)
end

function VECTOR:Right(vUp --[[= Vector(0, 0, 1)]])
	if (self.x == 0 and self.y == 0)then
		// pitch 90 degrees up/down from identity
		return Vector(0, -1, 0)
	else
		local vRet = self:Cross(vUp or vector_normal)
		vRet:Normalize()
		
		return vRet
	end
end

function VECTOR:Up(vUp --[[= Vector(0, 0, 1)]])
	if (self.x == 0 and self.y == 0)then
		return Vector(-self.z, 0, 0)
	else
		local vRet = self:Cross(vUp or vector_normal)
		vRet = vRet:Cross(self)
		vRet:Normalize()
		
		return vRet
	end
end

function VECTOR:GetTable()
	return {self.x, self.y, self.z}
end

function VectorFromTable(tbl)
	if (tbl.x) then
		return Vector(tbl.x, tbl.y or 0, tbl.z or 0)
	else
		return Vector(tbl[1] or 0, tbl[2] or 0, tbl[3] or 0)
	end
end

// Return true of the sphere might touch the box (the sphere is actually treated
// like a box itself, so this may return true if the sphere's bounding box touches
// a corner of the box but the sphere itself doesn't).
function VECTOR:QuickBoxSphereTest(flRadius, bbMin, bbMax)
	return self.x - flRadius < bbMax.x and self.x + flRadius > bbMin.x and
		self.y - flRadius < bbMax.y and self.y + flRadius > bbMin.y and
		self.z - flRadius < bbMax.z and self.z + flRadius > bbMin.z
end

function VECTOR:CalcDistanceToAABB(mins, maxs)
	return math.sqrt(self:CalcSqrDistanceToAABB(mins, maxs))
end

function VECTOR:GetNormalRadius()
	local x = self.x
	local y = self.y
	local z = self.z
	
	return math.sqrt(x * x + y * y + z * z)
end

function VECTOR:Lerp(vFrom, vTo)
	return Vector(Lerp(self.x, vFrom.x, vTo.x),
		Lerp(self.y, vFrom.y, vTo.y),
		Lerp(self.z, vFrom.z, vTo.z))
end

function VECTOR:GetClosestPoint(flMaxDist, vTarget)
	local vDelta = vTarget - vStart
	local flDistSqr = vDelta:LengthSqr()
	
	if (flDistSqr <= flMaxDist * flMaxDist) then
		return vTarget
	end
	
	return self + (vDelta / math.sqrt(flDistSqr)) * flMaxDist
end

function VECTOR:Interpolate(dest, frac)
	-- Cache values
	local x = self.x
	local y = self.y
	local z = self.z
	
	return Vector(x + frac * (dest.x - x),
		y + frac * (dest.y - y),
		z + frac * (dest.z - z))
end

function VECTOR:Yaw()
	local y = v.y
	local x = v.x
	
	if (y == 0 and x == 0) then
		return 0
	end
	
	local yaw = math.atan2(y, x)
	
	yaw = math.deg(yaw)
	
	if (yaw < 0) then
		yaw = yaw + 360
	end
	
	return yaw
end

function VECTOR:Pitch()
	if (v.y == 0 and v.x == 0) then
		if (v.z < 0) then
			return 180.0
		else
			return -180.0
		end
	end
	
	local dist = v:Length2D()
	local pitch = math.atan2(-v.z, dist)
	
	pitch = math.deg(pitch)
	
	return pitch
end

// snaps a vector to the nearest axis vector (if within epsilon)
function VECTOR:SnapDirectionToAxis(epsilon)
	local proj = 1 - epsilon
	-- x
	if (math.abs(self.x) > proj) then
		// snap to axis unit vector
		if (direction.x < 0) then
			direction.x = -1
		else
			direction.x = 1
		end
		
		direction.y = 0
		direction.z = 0
		return
	end
	-- y
	if (math.abs(self.y) > proj) then
		// snap to axis unit vector
		if (direction.y < 0) then
			direction.y = -1
		else
			direction.y = 1
		end
		
		direction.z = 0
		direction.x = 0
		return
	end
	-- z
	if (math.abs(self.z) > proj) then
		// snap to axis unit vector
		if (direction.z < 0) then
			direction.z = -1
		else
			direction.z = 1
		end
		
		direction.x = 0
		direction.y = 0
	end
end

function VECTOR:Transform(vmatIn)
	return Vector(self:Dot(vmatIn:GetRow(1)) + vmatIn:GetField(1, 4),
		self:Dot(vmatIn:GetRow(2)) + vmatIn:GetField(2, 4),
		self:Dot(vmatIn:GetRow(3)) + vmatIn:GetField(3, 4))
end
