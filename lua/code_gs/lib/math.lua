local band = bit.band
local bnot = bit.bnot
local bor = bit.bor
local bxor = bit.bxor
local rshift = bit.rshift
local floor = math.floor
local log = math.log
local sin = math.sin
local cos = math.cos
local rad = math.rad
local abs = math.abs
local exp = math.exp

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

function math.MD5Random(iSeed)
	gs.CheckType(iSeed, 1, TYPE_NUMBER)
	
	-- FIXME: Add paragraph
	-- https://github.com/Facepunch/garrysmod-issues/issues/2820
	local bEnabled = jit.status()
	
	if (bEnabled) then
		jit.off()
	end
	
	iSeed = iSeed % 0x100000000
	
	local a = Step1(0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, iSeed + 0xd76aa478, 7)
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
	b = Step2(b, c, d, a, iSeed + 0xe9b6c7aa, 20)
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
	d = Step3(d, a, b, c, iSeed + 0xeaa127fa, 11)
	c = Step3(c, d, a, b, 0xd4ef3085, 16)
	b = Step3(b, c, d, a, 0x04881d05, 23)
	a = Step3(a, b, c, d, 0xd9d4d039, 4)
	d = Step3(d, a, b, c, 0xe6db99e5, 11)
	c = Step3(c, d, a, b, 0x1fa27cf8, 16)
	b = Step3(b, c, d, a, 0xc4ac5665, 23)
	
	a = Step4(a, b, c, d, iSeed + 0xf4292244, 6)
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

local tNilNumberType = {TYPE_NIL, TYPE_NUMBER}

function math.ApproxInvSqrt(num, iIterations --[[= 1]])
	gs.CheckType(num, 1, TYPE_NUMBER)
	
	if (gs.CheckType(iIterations, 2, tNilNumberType) == TYPE_NIL) then
		iIterations = 1
	end
	
	-- FIXME: Add explanation
	local x2 = num * 0.5
	num = 0x5f3759df - rshift(x2, 1)
	
	for i = 1, iIterations do
		num = num * (1.5 - x2 * num * num)
	end
	
	return num
end

-- https://www.ngs.noaa.gov/PUBS_LIB/FedRegister/FRdoc59-5442.pdf
function math.PoundsToKilograms(flPounds)
	return flPounds * 0.4535924277
end

function math.KilogramsToPounds(flKilos)
	return flKilos * 2.2046226218488
end

-- 1 grain = exactly 64.79891 milligrams
-- 0.00006479891 kilo
-- 12 inches = 1 ft
-- 12 * 0.00006479891 = 0.00077758692
-- Returns kg*in/s
function math.GrainFeetForce(flGrains, flFtPerSec, flExaggeration --[[= 1]])
	return flGrains * flFtPerSec * 0.00077758692 * (flExaggeration or 1)
end

function math.YawToVec(yaw)
	local ang = rad(yaw)
	
	return Vector(cos(ang), sin(ang))
end

function math.IsPowerOfTwo(num)
	return band(num, num - 1) == 0
end

function math.BitCount(iNum)
	assert_type(iNum, "number", 1)
	assert_integer(iNum, 1)
	
	-- Don't do log(0)
	if (iNum == 0) then
		return 0
	end
	
	assert_customarg(iNum > 0, "number is not positive")
	
	return floor(log(iNum, 2)) + 1
end

-- FIXME: Fix these!
--[[function math.SmallestPowerOfTwoGreaterOrEqual(num)
	num = bor(rshift(num - 1, 1), num)
	num = bor(rshift(num, 2), num)
	num = bor(rshift(num, 4), num)
	num = bor(rshift(num, 8), num)
	num = bor(rshift(num, 16), num)
	
	return num + 1
end

function math.LargestPowerOfTwoLessThanOrEqual(num)
	return rshift(math.SmallestPowerOfTwoGreaterOrEqual(num + 1), 1)
end]]

local iMod = 360/65536
local iInverseMod = 65536/360

function math.AngleMod(ang)
	return iMod * band(math.Truncate(ang * iInverseMod), 65535)
end

function math.RemapClamped(val, A, B, C, D)
	if (A == B) then
		return val < B and C or D
	end
	
	local flVal = (val - A) / (B - A)
	
	return C + (D - C) * (flVal < 0 and 0 or flVal > 1 and 1 or flVal)
end

function math.FLerp(f1, f2, i1, i2, x)
	return f1 + (f2 - f1) * (x - i1) / (i2 - i1)
end

function math.Sign(num)
	return num < 0 and -1 or 1
end

function math.EqualWithTolerance(val1, val2, tol)
	return abs(val1 - val2) <= tol
end

// halflife is time for value to reach 50%
// flDecayTo is factor the value should decay to in flDecayTime
local flLogHalf = log(0.5)

function math.ExpDecay(flDecayTo, flDecayTime, flRate --[[= 1]])
	if (flRate == nil) then
		-- flDecayTo = Half-life
		-- flDecayTime = Rate
		return exp(flLogHalf / flDecayTo * flDecayTime)
	end
	
	return exp(log(flDecayTo) / flDecayTime * flRate)
end

// Get the integrated distanced traveled
// flDecayTo is factor the value should decay to in flDecayTime
// dt is the time relative to the last velocity update
function math.ExpDecayIntegral(flDecayTo, flDecayTime, flRate)
	return (flDecayTo ^ (flRate / flDecayTime) * flDecayTime - flDecayTime) / log(flDecayTo)
end

// hermite basis function for smooth interpolation
// value should be between 0 & 1 inclusive
function math.SimpleSpline(num)
	local flSqr = num * num
	
	// Nice little ease-in, ease-out spline-like curve
	return (3 * flSqr - 2 * flSqr * num)
end

function math.SimpleSplineRemapVal(num, A, B, C, D)
	if (A == B) then
		return num < B and C or D
	end
	
	local flVal = (num - A) / (B - A)
	
	return C + (D - C) * math.SimpleSpline(flVal)
end

function math.SimpleSplineRemapValClamped(num, A, B, C, D)
	if (A == B) then
		return num < B and C or D
	end
	
	local flVal = (num - A) / (B - A)
	
	return C + (D - C) * math.SimpleSpline(flVal < 0 and 0 or flVal > 1 and 1 or flVal)
end

function math.RectArea2D(vA, vB, vC)
	return (vB[1] - vA[1]) * (vC[2] - vA[2]) - (vB[2] - vA[2]) * (vC[1] - vA[1])
end

function math.GetBarycentricCoords2D(vA, vB, vC, vPoint)
	local flInvTriArea = 1 / math.RectArea2D(vA, vB, vC)
	
	return Vector(math.RectArea2D(vB, vC, vPoint) * flInvTriArea,
		math.RectArea2D(vC, vA, vPoint) * flInvTriArea,
		math.RectArea2D(vA, vB, vPoint) * flInvTriArea)
end

function math.SignedToUnsigned(num, iBits --[[= 32]])
	return num % 2 ^ (iBits or 32)
end

function math.UnsignedToSigned(num, iBits --[[= 32]])
	if (iBits == nil) then
		iBits = 32
	end
	
	local iPow = 2 ^ iBits
	num = num % iPow
	
	if (num < iPow / 2) then
		return num
	end
	
	return num - iPow
end

local tStringTranslate = {
	[0] = "0", "1", "2", "3", "4", "5", "6",
	"7", "8", "9", "a", "b", "c", "d", "e", 
	"f", "g", "h", "i", "j", "k", "l", "m",
	"n", "o", "p", "q", "r", "s", "t", "u", 
	"v", "w", "x", "y", "z"
}

local iMaxBase = #tStringTranslate + 1
local tStringTranslateCaps = {}

for i = 0, iMaxBase - 1 do
	tStringTranslateCaps[i] = tStringTranslate[i]:upper()
end

local sBaseError = "number between 2 and " .. iMaxBase .. " expected, got "

function math.ToBaseString(num, iBase, bCaps --[[= false]])
	-- Make sure we're dealing with positive integers
	assert_integer(num, 1)
	assert_customarg(num >= 0, "number is not positive", 1)
	assert_integer(num, 2)
	
	-- Don't allow for an infinite loop or out-of-range table accesses
	assert_customarg(iBase >= 2 and iBase <= iMaxBase, sBaseError .. iBase, 2)
	
	local iPower = 1
	local iTestBase = iBase
	
	while (iTestBase < num) do
		iPower = iPower + 1
		iTestBase = iTestBase * iBase
	end
	
	local sRet = ""
	local tbl = bCaps and tStringTranslateCaps or tStringTranslate
	
	for i = iPower, 1, -1 do
		iTestBase = iTestBase / iBase
		
		local iDiv = floor(num / iTestBase)
		num = num - iDiv * iTestBase
		sRet = sRet .. tbl[iPow]
	end
	
	return sRet
end
