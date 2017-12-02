local setmetatable = setmetatable
local debug_getmetatable = debug.getmetatable

local tNilBoolType = {TYPE_NIL, TYPE_BOOL}
local tNilIntType = {TYPE_NIL, gs.TYPE_INT}

array = {}

function array.ToHashTable(tbl, bMeta --[[= false]], iStart --[[= 1]], iEnd --[[= #tbl]])
	gs.CheckType(tbl, 1, TYPE_TABLE)
	
	if (gs.CheckType(bMeta, 2, tNilBoolType) == TYPE_NIL) then
		bMeta = false
	end
	
	if (gs.CheckType(iStart, 4, tNilIntType) == TYPE_NIL) then
		iStart = 1
	end
	
	if (gs.CheckType(iEnd, 5, tNilIntType) == TYPE_NIL) then
		iEnd = #tbl
	end
	
	local tRet = {}
	
	for i = iStart, iEnd do
		tRet[tbl[i]] = true
	end
	
	if (bMeta) then
		setmetatable(tRet, debug_getmetatable(tbl))
	end
	
	return tRet
end

function array.DeepCopy(tbl, bOutsideMeta --[[= true]], bInsideMeta --[[= true]], iStart --[[= 1]], iEnd --[[= #tbl]])
	gs.CheckType(tbl, 1, TYPE_TABLE)
	
	if (gs.CheckType(bOutsideMeta, 2, tNilBoolType) == TYPE_NIL) then
		bOutsideMeta = true
	end
	
	if (gs.CheckType(bInsideMeta, 3, tNilBoolType) == TYPE_NIL) then
		bInsideMeta = true
	end
	
	if (gs.CheckType(iStart, 4, tNilIntType) == TYPE_NIL) then
		iStart = 1
	end
	
	if (gs.CheckType(iEnd, 5, tNilIntType) == TYPE_NIL) then
		iEnd = #tbl
	end
	
	local tRet = {}
	
	for i = iStart, iEnd do
		tRet[i] = gs.Copy(tbl[i], bInsideMeta)
	end
	
	if (bOutsideMeta) then
		setmetatable(tRet, debug_getmetatable(tbl))
	end
	
	return tRet
end

function array.ShallowCopy(tbl, bOutsideMeta --[[= true]], iStart --[[= 1]], iEnd --[[= #tbl]])
	gs.CheckType(tbl, 1, TYPE_TABLE)
	
	if (gs.CheckType(bOutsideMeta, 2, tNilBoolType) == TYPE_NIL) then
		bOutsideMeta = true
	end
	
	if (gs.CheckType(iStart, 3, tNilIntType) == TYPE_NIL) then
		iStart = 1
	end
	
	if (gs.CheckType(iEnd, 4, tNilIntType) == TYPE_NIL) then
		iEnd = #tbl
	end
	
	local tRet = {}
	
	for i = iStart, iEnd do
		tRet[i] = tbl[i]
	end
	
	if (bOutsideMeta) then
		setmetatable(tRet, debug_getmetatable(tbl))
	end
	
	return tRet
end

/*local function MergeSort(tbl, tTemp, iLow, iHigh, bReverse)
	if (iLow < iHigh) then
		local iMiddle = math_floor(iLow + (iHigh - iLow) / 2)
		MergeSort(tbl, tTemp, iLow, iMiddle, bReverse)
		MergeSort(tbl, tTemp, iMiddle + 1, iHigh, bReverse)
		
		for i = iLow, iHigh do
			tTemp[i] = tbl[i]
		end
		
		local i = iLow
		local j = iMiddle + 1
		local k = iLow
		
		if (bReverse) then
			while (i <= iMiddle and j <= iHigh) do
				if (tTemp[i] > tTemp[j]) then
					tbl[k] = tTemp[i]
					i = i + 1
				else
					tbl[k] = tTemp[j]
					j = j + 1
				end
				
				k = k + 1
			end
		else
			while (i <= iMiddle and j <= iHigh) do
				if (tTemp[i] > tTemp[j]) then
					tbl[k] = tTemp[j]
					j = j + 1
				else
					tbl[k] = tTemp[i]
					i = i + 1
				end
				
				k = k + 1
			end
		end
		
		while (i <= iMiddle) do
			tbl[k] = tTemp[i]
			k = k + 1
			i = i + 1
		end
	end
end

function array.MergeSort(tbl, bReverse --[[= false]], iStart --[[= 1]], iEnd --[[= #tbl]])
	gs.CheckType(tbl, 1, TYPE_TABLE)
	
	if (gs.CheckType(bReverse, 2, tNilBoolType) == TYPE_NIL) then
		bReverse = false
	end
	
	if (gs.CheckType(iStart, 3, tNilIntType) == TYPE_NIL) then
		iStart = 1
	end
	
	if (gs.CheckType(iEnd, 4, tNilIntType) == TYPE_NIL) then
		iEnd = #tbl
	end
	
	MergeSort(tbl, {}, iStart, iEnd, bReverse)
	
	return tbl
end*/