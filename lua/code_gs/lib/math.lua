FLT_EPSILON = 1.19209290e-07

if (not code_gs.random) then
	local Ret = code_gs.LoadAddon("minstd", false)
	
	if (not Ret) then
		error("[GS] minstd random failed to load!")
	end
	
	code_gs.random = unpack(Ret)
end
	
function code_gs.random:SharedRandomFloat(pPlayer, sName, flMin, flMax, iAdditionalSeed)
	self:SetSeed(util.SeedFileLineHash(pPlayer:GetMD5Seed() % 0x80000000, sName, iAdditionalSeed))
	
	return self:RandomFloat(flMin, flMax)
end

function code_gs.random:SharedRandomInt(pPlayer, sName, iMin, iMax, iAdditionalSeed)
	self:SetSeed(util.SeedFileLineHash(pPlayer:GetMD5Seed() % 0x80000000, sName, iAdditionalSeed))
	
	return self:RandomInt(iMin, iMax)
end

function code_gs.random:SharedRandomVector(pPlayer, sName, flMin, flMax, iAdditionalSeed)
	self:SetSeed(util.SeedFileLineHash(pPlayer:GetMD5Seed() % 0x80000000, sName, iAdditionalSeed))

	return Vector(self:RandomFloat(flMin, flMax), 
			self:RandomFloat(flMin, flMax), 
			self:RandomFloat(flMin, flMax))
end

function code_gs.random:SharedRandomAngle(pPlayer, sName, flMin, flMax, iAdditionalSeed)
	self:SetSeed(util.SeedFileLineHash(pPlayer:GetMD5Seed() % 0x80000000, sName, iAdditionalSeed))

	return Angle(self:RandomFloat(flMin, flMax), 
			self:RandomFloat(flMin, flMax), 
			self:RandomFloat(flMin, flMax))
end

function code_gs.random:SharedRandomColor(pPlayer, sName, flMin, flMax, iAdditionalSeed)
	self:SetSeed(util.SeedFileLineHash(pPlayer:GetMD5Seed() % 0x80000000, sName, iAdditionalSeed))
	
	return Color(self:RandomFloat(flMin, flMax), 
			self:RandomFloat(flMin, flMax), 
			self:RandomFloat(flMin, flMax))
end

local band = bit.band
local bnot = bit.bnot
local bor = bit.bor
local bxor = bit.bxor
local floor = math.floor

// The four core functions - F1 is optimized somewhat
// local function f1(x, y, z) bit.bor(bit.band(x, y), bit.band(bit.bnot(x), z)) end
// This is the central step in the MD5 algorithm.
local function Step1(w, x, y, z, flData, iStep)
	w = w + bxor(z, band(x, bxor(y, z))) + flData
	
	return bor((w * 2^iStep) % 0x100000000, floor(w % 0x100000000 / 2^(0x20 - iStep))) + x
end

local function Step2(w, x, y, z, flData, iStep)
	w = w + bxor(y, band(z, bxor(x, y))) + flData
	
	return bor((w * 2^iStep) % 0x100000000, floor(w % 0x100000000 / 2^(0x20 - iStep))) + x
end

local function Step3(w, x, y, z, flData, iStep)
	w = w + bxor(bxor(x, y), z) + flData
	
	return bor((w * 2^iStep) % 0x100000000, floor(w % 0x100000000 / 2^(0x20 - iStep))) + x
end

local function Step4(w, x, y, z, flData, iStep)
	w = w + bxor(y, bor(x, bnot(z))) + flData
	
	return bor((w * 2^iStep) % 0x100000000, floor(w % 0x100000000 / 2^(0x20 - iStep))) + x
end

function math.MD5Random(nSeed)
	-- https://github.com/Facepunch/garrysmod-issues/issues/2820
	local bEnabled = jit.status()
	
	if (bEnabled) then
		jit.off()
	end
	
	nSeed = nSeed % 0x100000000
	
	local a = Step1(0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, nSeed + 0xd76aa478, 7)
	local d = Step1(0x10325476, a, 0xefcdab89, 0x98badcfe, 0xe8c7b7d6, 12)
	local c = Step1(0x98badcfe, d, a, 0xefcdab89, 0x242070db, 17)
	local b = Step1(0xefcdab89, c, d, a, 0xc1bdceee, 22)
	a = Step1(a, b, c, d, 0xf57c0faf, 7)
	d = Step1(d, a, b, c, 0x4787c62a, 12)
	c = Step1(c, d, a, b, 0xa8304613, 17)
	b = Step1(b, c, d, a, 0xfd469501, 22)
	a = Step1(a, b, c, d, 0x698098d8, 7)
	d = Step1(d, a, b, c, 0x8b44f7af, 12)
	c = Step1(c, d, a, b, 0xffff5bb1, 17)
	b = Step1(b, c, d, a, 0x895cd7be, 22)
	a = Step1(a, b, c, d, 0x6b901122, 7)
	d = Step1(d, a, b, c, 0xfd987193, 12)
	c = Step1(c, d, a, b, 0xa67943ae, 17)
	b = Step1(b, c, d, a, 0x49b40821, 22)
	
	a = Step2(a, b, c, d, 0xf61e25e2, 5)
	d = Step2(d, a, b, c, 0xc040b340, 9)
	c = Step2(c, d, a, b, 0x265e5a51, 14)
	b = Step2(b, c, d, a, nSeed + 0xe9b6c7aa, 20)
	a = Step2(a, b, c, d, 0xd62f105d, 5)
	d = Step2(d, a, b, c, 0x02441453, 9)
	c = Step2(c, d, a, b, 0xd8a1e681, 14)
	b = Step2(b, c, d, a, 0xe7d3fbc8, 20)
	a = Step2(a, b, c, d, 0x21e1cde6, 5)
	d = Step2(d, a, b, c, 0xc33707f6, 9)
	c = Step2(c, d, a, b, 0xf4d50d87, 14)
	b = Step2(b, c, d, a, 0x455a14ed, 20)
	a = Step2(a, b, c, d, 0xa9e3e905, 5)
	d = Step2(d, a, b, c, 0xfcefa3f8, 9)
	c = Step2(c, d, a, b, 0x676f02d9, 14)
	b = Step2(b, c, d, a, 0x8d2a4c8a, 20)

	a = Step3(a, b, c, d, 0xfffa3942, 4)
	d = Step3(d, a, b, c, 0x8771f681, 11)
	c = Step3(c, d, a, b, 0x6d9d6122, 16)
	b = Step3(b, c, d, a, 0xfde5382c, 23)
	a = Step3(a, b, c, d, 0xa4beeac4, 4)
	d = Step3(d, a, b, c, 0x4bdecfa9, 11)
	c = Step3(c, d, a, b, 0xf6bb4b60, 16)
	b = Step3(b, c, d, a, 0xbebfbc70, 23)
	a = Step3(a, b, c, d, 0x289b7ec6, 4)
	d = Step3(d, a, b, c, nSeed + 0xeaa127fa, 11)
	c = Step3(c, d, a, b, 0xd4ef3085, 16)
	b = Step3(b, c, d, a, 0x04881d05, 23)
	a = Step3(a, b, c, d, 0xd9d4d039, 4)
	d = Step3(d, a, b, c, 0xe6db99e5, 11)
	c = Step3(c, d, a, b, 0x1fa27cf8, 16)
	b = Step3(b, c, d, a, 0xc4ac5665, 23)
	
	a = Step4(a, b, c, d, nSeed + 0xf4292244, 6)
	d = Step4(d, a, b, c, 0x432aff97, 10)
	c = Step4(c, d, a, b, 0xab9423c7, 15)
	b = Step4(b, c, d, a, 0xfc93a039, 21)
	a = Step4(a, b, c, d, 0x655b59c3, 6)
	d = Step4(d, a, b, c, 0x8f0ccc92, 10)
	c = Step4(c, d, a, b, 0xffeff47d, 15)
	b = Step4(b, c, d, a, 0x85845e51, 21)
	a = Step4(a, b, c, d, 0x6fa87e4f, 6)
	d = Step4(d, a, b, c, 0xfe2ce6e0, 10)
	c = Step4(c, d, a, b, 0xa3014314, 15)
	b = Step4(b, c, d, a, 0x4e0811a1, 21)
	a = Step4(a, b, c, d, 0xf7537e82, 6)
	d = Step4(d, a, b, c, 0xbd3af235, 10)
	c = Step4(c, d, a, b, 0x2ad7d2bb, 15)
	b = (Step4(b, c, d, a, 0xeb86d391, 21) + 0xefcdab89) % 0x100000000
	
	c = (c + 0x98badcfe) % 0x100000000
	a = floor(b / 0x10000) % 0x100 + floor(b / 0x1000000) % 0x100 * 0x100 + c % 0x100 * 0x10000 + floor(c / 0x100) % 0x100 * 0x1000000
	
	if (bEnabled) then
		jit.on()
	end
	
	return a
end

function math.PoundsToKilograms(flPounds)
	return flPounds * 1/2.2046226218
end

function math.KilogramsToPounds(flKilos)
	return flKilos * 2.2046226218
end

function math.BulletImpulse(flGrains, flFtPerSec, flImpulse)
	return flFtPerSec * flGrains * 0.00077760497667185 * (flImpulse or 1)
end

function math.YawToVec(yaw)
	local ang = math.rad(yaw)
	
	return Vector(math.cos(ang), math.sin(ang), 0)
end

function math.IsPowerOfTwo(num)
	return bit.band(num, num - 1) == 0
end

function math.SmallestPowerOfTwoGreaterOrEqual(num)
	num = bit.bor(bit.rshift(num - 1, 1), num)
	num = bit.bor(bit.rshift(num, 2), num)
	num = bit.bor(bit.rshift(num, 4), num)
	num = bit.bor(bit.rshift(num, 8), num)
	num = bit.bor(bit.rshift(num, 16), num)
	
	return num + 1
end

function math.LargestPowerOfTwoLessThanOrEqual(num)
	if (num >= 0x80000000) then
		return 0x80000000
	end
	
	return math.rshift(math.SmallestPowerOfTwoGreaterOrEqual(num + 1), 1)
end

function math.AngleMod(ang)
	return 360/65536 * bit.band(math.Truncate(ang * 65536/360), 65535)
end

function math.RemapClamped(val, A, B, C, D)
	if (A == B) then
		return val >= B and D or C
	end
	
	return C + (D - C) * math.Clamp((val - A) / (B - A), 0, 1)
end

function math.FLerp(f1, f2, i1, i2, x)
	return f1 + (f2 - f1) * (x - i1) / (i2 - i1)
end

function math.Sign(num)
	return num < 0 and -1 or 1
end

function math.EqualWithTolerance(val1, val2, tol)
	return math.abs(val1 - val2) <= tol
end

// halflife is time for value to reach 50%
// decayTo is factor the value should decay to in decayTime
local flLogHalf = math.log(0.5)

function math.ExpDecay(flDecayTo, flDecayTime, flRate)
	if (flRate) then
		return math.exp(math.log(flDecayTo) / flDecayTime * flRate)
	end
	
	-- flDecayTo = Half-life
	-- flDecayTime = Rate
	
	return math.exp(flLogHalf / flDecayTo * flDecayTime)
end

// Get the integrated distanced traveled
// decayTo is factor the value should decay to in decayTime
// dt is the time relative to the last velocity update
function math.ExpDecayIntegral(flDecayTo, flDecayTime, flRate)
	return (flDecayTo ^ (flRate / flDecayTime) * flDecayTime - flDecayTime) / math.log(flDecayTo)
end

// hermite basis function for smooth interpolation
// Similar to Gain() above, but very cheap to call
// value should be between 0 & 1 inclusive
function math.SimpleSpline(num)
	local flSqr = num * num
	
	// Nice little ease-in, ease-out spline-like curve
	return (3 * flSqr - 2 * flSqr * num)
end

// This version doesn't premultiply by 0.5f, so it's the area of the rectangle instead
function math.TriArea2DTimesTwo(vA, vB, vC)
	return (vB.x - vA.x) * (vC.y - vA.y) - (vB.y - vA.y) * (vC.x - vA.x)
end

function math.GetBarycentricCoords2D(vA, vB, vC, vpt)
	// Note, because to top and bottom are both x2, the issue washes out in the composite
	local invTriArea = 1 / math.TriArea2DTimesTwo(vA, vB, vC)
	
	// NOTE: We assume here that the lightmap coordinate vertices go counterclockwise.
	// If not, TriArea2D() is negated so this works out right.
	return {math.TriArea2DTimesTwo(vB, vC, vpt) * invTriArea,
		math.TriArea2DTimesTwo(vC, vA, vpt) * invTriArea,
		math.TriArea2DTimesTwo(vA, vB, vpt) * invTriArea}
end

// Return true of the boxes intersect (but not if they just touch).
function math.QuickBoxIntersectTest(vBox1Min, vBox1Max, vBox2Min, vBox2Max)
	return self.x - flRadius < bbMax.x and self.x + flRadius > bbMin.x and
		self.y - flRadius < bbMax.y and self.y + flRadius > bbMin.y and
		self.z - flRadius < bbMax.z and self.z + flRadius > bbMin.z
end
