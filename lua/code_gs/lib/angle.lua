local ANGLE = FindMetaTable("Angle")

function AngleRand(flMin, flMax)	
	return Angle(math.Rand(flMin or -90, flMax or 90),
		math.Rand(flMin or -180, flMax or 180),
		math.Rand(flMin or -180, flMax or 180))
end

function ANGLE:ClipPunchAngleOffset(aPunch, aClip)
	//Clip each component
	local aFinal = self + aPunch
	local fp = aFinal.p
	local fy = aFinal.y
	local fr = aFinal.r
	local cp = aClip.p
	local cy = aClip.y
	local cr = aClip.r
	
	if (fp > cp) then
		fp = cp
	elseif (fp < -cp) then
		fp = -cp
	end
	
	self.p = fp - aPunch.p
	
	if (fy > cy) then
		fy = cy
	elseif (fy < -cy) then
		fy = -cy
	end
	
	self.y = fy - aPunch.y
	
	if (fr > cr) then
		fr = cr
	elseif (fr < -cr) then
		fr = -cr
	end
	
	self.r = fr - aPunch.r
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

function ANGLE:Matrix(vPos)
	local yaw = math.rad(self.y)
	local pitch = math.rad(self.p)
	local roll = math.rad(self.r)
	local sy = math.sin(yaw)
	local cy = math.cos(yaw)
	local sp = math.sin(pitch)
	local cp = math.cos(pitch)
	local sr = math.sin(roll)
	local cr = math.cos(roll)
	local crcy = cr * cy
	local crsy = cr * sy
	local srcy = sr * cy
	local srsy = sr * sy
	
	return Matrix({{cp * cy, sp * srcy - crsy, sp * crcy + srsy, 0},
	{cp * sy, sp * srsy + crcy, sp * crsy - srcy, 0},
	{-sp, sr * cp, cr * cp, 0},
	{0, 0, 0, 0}})
end

function ANGLE:IsEqualTol(a, tol)
	if (not tol) then
		return self == v
	end
	
	return math.EqualWithTolerance(self.p, a.p, tol)
		and math.EqualWithTolerance(self.y, a.y, tol)
		and math.EqualWithTolerance(self.r, a.r, tol)
end

function ANGLE:Impulse()
	return Vector(self.r, self.p, self.y)
end

function ANGLE:Length()
	return math.sqrt(self:LengthSqr())
end

function ANGLE:LengthSqr()
	local p = self.p
	local y = self.y
	local r = self.r
	
	return p * p + y * y + r * r
end
