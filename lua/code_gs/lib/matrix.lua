-- FIXME: Move over Vector and Angle methods
-- FIXME: Convert 3x4 matrix methods to 4x4

matrix_identity = Matrix()
matrix_zero = Matrix({{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}})

function MatrixZero()
	return Matrix({{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}})
end

function MatrixRand(minVal, maxVal)
	minVal = minVal or -1
	maxVal = maxVal or 1
	
	local tRand = {{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}
	
	for i = 1, 4 do
		for j = 1, 4 do
			tRand[i][j] = math.random(minVal, maxVal)
		end
	end
	
	return Matrix(tRand)
end

-- The Lua implementation of VMatricies only come in 4x4 varieties
-- So for 3x4 methods, we only touch the first three rows
function MatrixVector(xAxis, yAxis, zAxis, wAxis --[[= Vector(0,0,0)]], vOrigin --[[= Vector(0,0,0)]], flWOrigin --[[= 1]])
	if (vOrigin) then
		return Matrix({
			{xAxis[1], yAxis[1], zAxis[1], vOrigin[1]},
			{xAxis[2], yAxis[2], zAxis[2], vOrigin[2]},
			{xAxis[3], yAxis[3], zAxis[3], vOrigin[3]},
			wAxis and {wAxis[1], wAxis[2], wAxis[3], flWOrigin or 1} or {0, 0, 0, 1}
		})
	end
	
	return Matrix({
		{xAxis[1], yAxis[1], zAxis[1], 0},
		{xAxis[2], yAxis[2], zAxis[2], 0},
		{xAxis[3], yAxis[3], zAxis[3], 0},
		wAxis and {wAxis[1], wAxis[2], wAxis[3], flWOrigin or 1} or {0, 0, 0, 1}
	})
end

local MATRIX = FindMetaTable("VMatrix")

function MATRIX:ConcatTransforms(vmat)
	local in111 = self:GetField(1, 1)
	local in112 = self:GetField(1, 2)
	local in113 = self:GetField(1, 3)
	
	local in121 = self:GetField(2, 1)
	local in122 = self:GetField(2, 2)
	local in123 = self:GetField(2, 3)
	
	local in131 = self:GetField(3, 1)
	local in132 = self:GetField(3, 2)
	local in133 = self:GetField(3, 3)
	
	local in211 = vmat:GetField(1, 1)
	local in212 = vmat:GetField(1, 2)
	local in213 = vmat:GetField(1, 3)
	local in214 = vmat:GetField(1, 4)
	local in221 = vmat:GetField(2, 1)
	local in222 = vmat:GetField(2, 2)
	local in223 = vmat:GetField(2, 3)
	local in224 = vmat:GetField(2, 4)
	local in231 = vmat:GetField(3, 1)
	local in232 = vmat:GetField(3, 2)
	local in233 = vmat:GetField(3, 3)
	local in234 = vmat:GetField(3, 4)
	
	return Matrix({
		{in111 * in211 + in112 * in221 +
		in113 * in231,
		in111 * in212 + in112 * in222 +
		in113 * in232,
		in111 * in213 + in112 * in223 +
		in113 * in233,
		in111 * in214 + in112 * in224 +
		in113 * in234 + self:GetField(1, 4)},
		{in121 * in211 + in122 * in221 +
		in123 * in231,
		in121 * in212 + in122 * in222 +
		in123 * in232,
		in121 * in213 + in122 * in223 +
		in123 * in233,
		in121 * in214 + in122 * in224 +
		in123 * in234 + self:GetField(2, 4)},
		{in131 * in211 + in132 * in221 +
		in133 * in231,
		in131 * in212 + in132 * in222 +
		in133 * in232,
		in131 * in213 + in132 * in223 +
		in133 * in233,
		in131 * in214 + in132 * in224 +
		in133 * in234 + self:GetField(3, 4)},
		{0, 0, 0, 1}
	})
end

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
	local flNewDist = flDist * vNewNormal:Dot(vNewNormal) +
		vNewNormal[1] * self:GetField(1, 4) +
		vNewNormal[2] * self:GetField(2, 4) +
		vNewNormal[3] * self:GetField(3, 4)
	
	return vNewNormal, flNewDist
end

function MATRIX:ITransformPlane(vNormal, flDist)
	// The trick here is that Tn = translational component of transform,
	// but for an inverse transform, Tn = - R^-1 * T
	local vInvTranslation = self:GetColumnVector(4):IRotateMatrixInPlace(self)
	local vNewNormal = vNormal:GetIRotatedMatrix(self)
	local flNewDist= flDist * vNewNormal:Dot(vNewNormal) +
		vNewNormal[1] * vInvTranslation[1] +
		vNewNormal[2] * vInvTranslation[2] +
		vNewNormal[3] * vInvTranslation[3]
	
	return vNewNormal, flNewDist
end

function MATRIX:RowDotProduct(iRow, vIn)
	return self:GetRowVector(iRow):Dot(vIn)
end

function MATRIX:ColumnDotProduct(iColumn, vIn)
	return self:GetColumnVector(iColumn):Dot(vIn)
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
	self:SetField(2, iColumn, tbl[2])
	self:SetField(3, iColumn, tbl[3])
	
	if (tbl[4]) then
		self:SetField(4, iColumn, tbl[4])
	end
end

function MATRIX:SetColumnVector(iColumn, vec, w)
	self:SetField(1, iColumn, vec[1])
	self:SetField(2, iColumn, vec[2])
	self:SetField(3, iColumn, vec[3])
	
	if (w) then
		self:SetField(4, iColumn, w)
	end
end

function MATRIX:SetRow(iRow, tbl)
	self:SetField(iRow, 1, tbl[1])
	self:SetField(iRow, 2, tbl[2])
	self:SetField(iRow, 3, tbl[3])
	
	if (tbl[4]) then
		self:SetField(4, iColumn, tbl[4])
	end
end

function MATRIX:SetRowVector(iRow, vec, w)
	self:SetField(iRow, 1, vec[1])
	self:SetField(iRow, 2, vec[2])
	self:SetField(iRow, 3, vec[3])
	
	if (w) then
		self:SetField(iRow, 4, w)
	end
end

--[[local MATRIX = {}
MATRIX.__index = MATRIX
debug.getregistry().VMatrix = MATRIX

function Matrix(tbl)
	return setmetatable({m_tMatrix = tbl}, MATRIX)
end

function MATRIX:GetField(iRow, iColumn)
	return self.m_tMatrix[iRow][iColumn]
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
	self:SetField(1,1, vForward[1])
	self:SetField(2,1, vForward[2])
	self:SetField(3,1, vForward[3])
end

function MATRIX:SetLeft(vLeft)
	self:SetField(1,2, vLeft[1])
	self:SetField(2,2, vLeft[2])
	self:SetField(3,2, vLeft[3])
end

function MATRIX:SetUp(vRight)
	self:SetField(1,3, vRight[1])
	self:SetField(2,3, vRight[2])
	self:SetField(3,3, vRight[3])
end

function MATRIX:GetTranslation()
	return Vector(self:GetField(1,4), self:GetField(2,4), self:GetField(3,4))
end

function MATRIX:SetTranslation(vTrans)
	self:SetField(1,4, vTrans[1])
	self:SetField(2,4, vTrans[1])
	self:SetField(3,4, vTrans[1])
end]]
