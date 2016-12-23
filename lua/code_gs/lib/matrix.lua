local MATRIX = FindMetaTable("VMatrix")
local VECTOR = FindMetaTable("Vector")
local ANGLE = FindMetaTable("Angle")

function MATRIX:TransformPlane(vNormal, flDist)
	// What we want to do is the following:
	// 1) transform the normal into the new space.
	// 2) Determine a point on the old plane given by plane dist * plane normal
	// 3) Transform that point into the new space
	// 4) Plane dist = DotProduct(new normal, new point)

	// An optimized version, which works if the plane is orthogonal.
	// 1) Transform the normal into the new space
	// 2) Realize that transforming the old plane point into the new space
	// is given by [ d * n'x + Tx, d * n'y + Ty, d * n'z + Tz ]
	// where d = old plane dist, n' = transformed normal, Tn = translational component of transform
	// 3) Compute the new plane dist using the dot product of the normal result of #2

	// For a correct result, this should be an inverse-transpose matrix
	// but that only matters if there are nonuniform scale or skew factors in this matrix.
	local vNewNormal = vNormal:GetRotatedMatrix(self)
	local flNewDist= flDist * vNewNormal:Dot(vNewNormal) +
		vNewNormal.x * self:GetField(1, 4) +
		vNewNormal.y * self:GetField(2, 4) +
		vNewNormal.z * self:GetField(3, 4)
	
	return vNewNormal, flNewDist
end

function MATRIX:ITransformPlane(vNormal, flDist)
	// The trick here is that Tn = translational component of transform,
	// but for an inverse transform, Tn = - R^-1 * T
	local vInvTranslation = self:GetColumnVector(4):IRotateMatrixInPlace(self)
	local vNewNormal = vNormal:GetIRotatedMatrix(self)
	local flNewDist= flDist * vNewNormal:Dot(vNewNormal) +
		vNewNormal.x * vInvTranslation.x +
		vNewNormal.y * vInvTranslation.y +
		vNewNormal.z * vInvTranslation.z
	
	return vNewNormal, flNewDist
end

local tEmptyRow = {0, 0, 0, 0}

-- The Lua implementation of VMatricies only come in 4x4 varieties
-- So for 3x4 methods, we only touch the first three rows
function MatrixVector(xAxis, yAxis, zAxis, vOrigin)
	if (vOrigin) then
		return Matrix({
			{xAxis.x, yAxis.x, zAxis.x, vOrigin.x},
			{xAxis.y, yAxis.y, zAxis.y, vOrigin.y},
			{xAxis.z, yAxis.z, zAxis.z, vOrigin.z},
			tEmptyRow
		})
	else
		return Matrix({
			{xAxis.x, yAxis.x, zAxis.x, 0},
			{xAxis.y, yAxis.y, zAxis.y, 0},
			{xAxis.z, yAxis.z, zAxis.z, 0},
			tEmptyRow
		})
	end
end

function MatrixQuaternion(xAxis, yAxis, zAxis, vOrigin)
	if (vOrigin) then
		return Matrix({
			{xAxis.x, yAxis.x, zAxis.x, vOrigin.x},
			{xAxis.y, yAxis.y, zAxis.y, vOrigin.y},
			{xAxis.z, yAxis.z, zAxis.z, vOrigin.z},
			{xAxis.w, yAxis.w, zAxis.w, vOrigin.w}
		})
	else
		return Matrix({
			{xAxis.x, yAxis.x, zAxis.x, 0},
			{xAxis.y, yAxis.y, zAxis.y, 0},
			{xAxis.z, yAxis.z, zAxis.z, 0},
			{xAxis.w, yAxis.w, zAxis.w, 0}
		})
	end
end

function MatrixRand(minVal, maxVal)
	minVal = minVal or -1
	maxVal = maxVal or 1
	
	local tbl = {{}, {}, {}, {}}
	
	for i = 1, 4 do
		for j = 1, 4 do
			tbl[i][j] = math.random(minVal, maxVal)
		end
	end
	
	return Matrix(tbl)
end

function MatrixIdentity()
	return Matrix({
		{1.0, 0.0, 0.0, 0.0},
		{0.0, 1.0, 0.0, 0.0},
		{0.0, 0.0, 1.0, 0.0},
		{0.0, 0.0, 0.0, 1.0}})
end

function VECTOR:GetTranslationMatrix(w)
	return Matrix({
		{1.0, 0.0, 0.0, self.x},
		{0.0, 1.0, 0.0, self.y},
		{0.0, 0.0, 1.0, self.z},
		{0.0, 0.0, 0.0, w or 1.0}
	})
end

function VECTOR:GetScaledMatrix(w) -- Quaternion substitute
	return Matrix({
		{self.x, 0.0, 0.0, 0.0},
		{0.0, self.y, 0.0, 0.0},
		{0.0, 0.0, self.z, 0.0},
		{0.0, 0.0, 0.0, w or 1.0}
	})
end

function VECTOR:GetReflectionMatrix(N) -- Plane substitute
	local x = N.x
	local y = N.y
	local z = N.z
	
	local mReflect = Matrix({
		{-2.0*x*x + 1.0, -2.0*x*y, -2.0*x*z, 0.0},
		{-2.0*y*x, -2.0*y*y + 1.0,	-2.0*y*z, 0.0},
		{-2.0*z*x, -2.0*z*y, -2.0*z*z + 1.0, 0.0},
		{0.0, 0.0, 0.0, 1.0}
	})
	
	local mBack = MatrixIdentity()
	mBack:SetTranslation(-self)
	
	local mForward = MatrixIdentity()
	mForward:SetTranslation(self)
	
	// (multiplied in reverse order, so it translates to the origin point,
	// reflects, and translates back).
	return mForward * mReflect * mBack
end

function VECTOR:GetProjectionMatrix(PN, PD) -- Plane substitute
	local x = PN.x
	local y = PN.y
	local z = PN.z
	local x1 = self.x
	local y1 = self.y
	local z1 = self.z
	local dot = x*x1 + y*y1 + z*z1 - PD
	
	return Matrix({
		{
			dot - x1 * x,
			-x1 * y,
			-x1 * z,
			-x1 * -PD
		},
		{
			-y1 * x,
			dot - y1 * y,
			-y1 * z,
			-y1 * -PD
		},
		{
			-z1 * x,
			-z1 * y,
			dot - z1 * z,
			-z1 * -PD
		},
		{
			-x,
			-y,
			-z,
			dot + PD
		}
	})
end

function MATRIX:RowDotProduct(iRow, vIn)
	return self:GetRowVector(iRow):Dot(vIn)
end

function MATRIX:ColumnDotProduct(iColumn, vIn)
	return self:GetColumnVector(iColumn):Dot(vIn)
end

function VECTOR:GetAxisRotMatrix(fRadians)
	fRadians = math.rad(fRadians)
	
	local x = self.x
	local y = self.y
	local z = self.z
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

function ANGLE:GetMatrix()
end

function VECTOR:GetAngleMatrix(vAngles)
end

function VECTOR:GetTranslatedMatrix(w) -- 4DVector substitute
	return Matrix({
		{1.0, 0.0, 0.0, self.x},
		{0.0, 1.0, 0.0, self.y},
		{0.0, 0.0, 1.0, self.z},
		{0.0, 0.0, 0.0, w or 1.0}
	})
end

function MATRIX:GetColumn(iColumn)
	return {self:GetField(1, iColumn),
		self:GetField(2, iColumn),
		self:GetField(3, iColumn),
		self:GetField(4, iColumn)}
end

function MATRIX:GetColumnVector(iColumn)
	-- Fourth point lost precision
	return Vector(self:GetField(1, iColumn),
		self:GetField(2, iColumn),
		self:GetField(3, iColumn))
end

function MATRIX:GetRow(iRow)
	return {self:GetField(iRow, 1),
		self:GetField(iRow, 2),
		self:GetField(iRow, 3),
		self:GetField(iRow, 4)}
end

function MATRIX:GetRowVector(iRow)
	-- Fourth point lost precision
	return Vector(self:GetField(iRow, 1),
		self:GetField(iRow, 2),
		self:GetField(iRow, 3))
end

function MATRIX:SetColumn(iColumn, tbl)
	self:SetField(1, iColumn, tbl[1])
	self:GetField(2, iColumn, tbl[2])
	self:GetField(3, iColumn, tbl[3])
	self:GetField(4, iColumn, tbl[4] or 0)
end

function MATRIX:SetColumnVector(iColumn, vec)
	self:SetField(1, iColumn, vec.x)
	self:GetField(2, iColumn, vec.y)
	self:GetField(3, iColumn, vec.z)
end

function MATRIX:SetRow(iRow, tbl)
	self:SetField(iRow, 1, tbl[1])
	self:GetField(iRow, 2, tbl[2])
	self:GetField(iRow, 3, tbl[3])
	self:GetField(iRow, 4, tbl[4])
end

function MATRIX:SetRowVector(iRow, vec)
	self:SetField(iRow, 1, vec.x)
	self:GetField(iRow, 2, vec.y)
	self:GetField(iRow, 3, vec.z)
end

--[[local MATRIX = {}
MATRIX.__index = MATRIX
_R.VMatrix = MATRIX

function Matrix(tbl)
	return setmetatable(tbl, MATRIX)
end

function MATRIX:GetForward()
	return Vector(self:GetField(1,1), self:GetField(2,1), self:GetField(3,1))
end

function MATRIX:GetLeft()
	return Vector(self:GetField(1,2), self:GetField(2,2), self:GetField(3,2))
end

function MATRIX:GetUp()
	return Vector(self:GetField(1,3), self:GetField(2,3), self:GetField(3,3))
end

function MATRIX:SetForward(vForward)
	self:SetField(1,1, vForward.x)
	self:SetField(2,1, vForward.y)
	self:SetField(3,1, vForward.z)
end

function MATRIX:SetLeft(vLeft)
	self:SetField(1,2, vLeft.x)
	self:SetField(2,2, vLeft.y)
	self:SetField(3,2, vLeft.z)
end

function MATRIX:SetUp(vRight)
	self:SetField(1,3, vRight.x)
	self:SetField(2,3, vRight.y)
	self:SetField(3,3, vRight.z)
end

function MATRIX:GetTranslation()
	return Vector(self:GetField(1,4), self:GetField(2,4), self:GetField(3,4))
end

function MATRIX:SetTranslation(vTrans)
	self:SetField(1,4, vTrans.x)
	self:SetField(2,4, vTrans.x)
	self:SetField(3,4, vTrans.x)
end]]
