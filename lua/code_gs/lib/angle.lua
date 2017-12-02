local ANGLE = FindMetaTable("Angle")

function AngleRand(flMin --[[-90 pitch, -180 yaw/roll]], flMax --[[= 90 pitch, 180 yaw/roll]])
	return Angle(math.Rand(flMin or -90, flMax or 90),
		math.Rand(flMin or -180, flMax or 180),
		math.Rand(flMin or -180, flMax or 180))
end

function ANGLE:ClipPunchAngleOffset(aPunch, aClip)
	local aFinal = self + aPunch
	local fp = aFinal[1]
	local fy = aFinal[2]
	local fr = aFinal[3]
	local cp = aClip[1]
	local cy = aClip[2]
	local cr = aClip[3]
	
	if (fp > cp) then
		fp = cp
	elseif (fp < -cp) then
		fp = -cp
	end
	
	self[1] = fp - aPunch[1]
	
	if (fy > cy) then
		fy = cy
	elseif (fy < -cy) then
		fy = -cy
	end
	
	self[2] = fy - aPunch[2]
	
	if (fr > cr) then
		fr = cr
	elseif (fr < -cr) then
		fr = -cr
	end
	
	self[3] = fr - aPunch[3]
end

function ANGLE:NormalizeInPlace()
	if (self == angle_zero) then
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

function ANGLE:Matrix(vPos --[[= Vector(0, 0, 0)]])
	local pitch = math.rad(self[1])
	local yaw = math.rad(self[2])
	local roll = math.rad(self[3])
	
	local sp = math.sin(pitch)
	local cp = math.cos(pitch)
	local sy = math.sin(yaw)
	local cy = math.cos(yaw)
	local sr = math.sin(roll)
	local cr = math.cos(roll)
	
	local srcy = sr * cy
	local srsy = sr * sy
	local crcy = cr * cy
	local crsy = cr * sy
	
	local t1, t2, t3
	
	if (vPos == nil) then
		t1, t2, t3 = 0, 0, 0
	else
		t1, t2, t3 = vPos[1], vPos[2], vPos[3]
	end
	
	return Matrix({{cp * cy, sp * srcy - crsy, sp * crcy + srsy, t1},
	{cp * sy, sp * srsy + crcy, sp * crsy - srcy, t2},
	{-sp, sr * cp, cr * cp, t3},
	{0, 0, 0, 1}})
end

function ANGLE:IsEqualTol(ang, flTol --[[= 0]])
	if (flTol == nil) then
		return self == ang
	end
	
	return math.EqualWithTolerance(self[1], ang[1], tol)
		and math.EqualWithTolerance(self[2], ang[2], tol)
		and math.EqualWithTolerance(self[3], ang[3], tol)
end

function ANGLE:ToTable()
	return {self[1], self[2], self[3]}
end

-- FIXME: Check this
function ANGLE:Impulse()
	return Vector(self[3], self[1], self[2])
end

function ANGLE:Length()
	return math.sqrt(self:LengthSqr())
end

function ANGLE:LengthSqr()
	local p = self[1]
	local y = self[2]
	local r = self[3]
	
	return p * p + y * y + r * r
end

function ANGLE:Add(ang)
	self[1] = self[1] + ang[1]
	self[2] = self[2] + ang[2]
	self[3] = self[3] + ang[3]
end

function ANGLE:Sub(ang)
	self[1] = self[1] - ang[1]
	self[2] = self[2] - ang[2]
	self[3] = self[3] - ang[3]
end

function ANGLE:Mul(flMultiplier)
	self[1] = self[1] * flMultiplier
	self[2] = self[2] * flMultiplier
	self[3] = self[3] * flMultiplier
end
