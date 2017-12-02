local pairs = pairs
local setmetatable = setmetatable

local math_floor = math.floor
local debug_getmetatable = debug.getmetatable

function table.ShallowCopy(tbl, bOutsideMeta --[[= true]])
	gs.CheckType(tbl, 1, TYPE_TABLE)
	
	if (gs.CheckType(bOutsideMeta, 2, {TYPE_BOOL, TYPE_NIL}) == TYPE_NIL) then
		bOutsideMeta = true
	end
	
	local tRet = {}
	
	for k, v in pairs(tbl) do
		tRet[k] = v
	end
	
	if (bOutsideMeta) then
		setmetatable(tRet, debug_getmetatable(tbl))
	end
	
	return tRet
end

local function InheritNoBaseClass(tTarget, tBase)
	-- Inherit tBase's metatable if tTarget doesn't have one
	-- Use debug_getmetatable since the __metatable key will be taken
	-- Care of in the loop
	if (debug_getmetatable(tTarget) == nil) then
		setmetatable(tTarget, debug_getmetatable(tBase))
	end
	
	for k, v in pairs(tBase) do
		local TargetVal = tTarget[k]
		
		if (TargetVal == nil) then
			tTarget[k] = v
		elseif (gs.IsType(TargetVal, TYPE_TABLE) and gs.IsType(v, TYPE_TABLE)) then
			InheritNoBaseClass(TargetVal, v)
		end
	end
end

local function InheritNoBaseClassCopy(tTarget, tBase)
	if (debug_getmetatable(tTarget) == nil) then
		setmetatable(tTarget, debug_getmetatable(tBase))
	end
	
	for k, v in pairs(tBase) do
		local TargetVal = tTarget[k]
		
		if (TargetVal == nil) then
			tTarget[gs.Copy(k)] = gs.Copy(v)
		elseif (gs.IsType(TargetVal, TYPE_TABLE) and gs.IsType(v, TYPE_TABLE)) then
			InheritNoBaseClassCopy(TargetVal, v)
		end
	end
end

-- FIXME: Rename?
function table.InheritNoBaseClass(tTarget, tBase, bCopyElements --[[= false]])
	gs.CheckType(tTarget, 1, TYPE_TABLE)
	gs.CheckType(tBase, 2, TYPE_TABLE)
	
	if (gs.CheckType(bCopyElements, 3, {TYPE_BOOL, TYPE_NIL}) == TYPE_NIL) then
		bCopyElements = false
	end
	
	if (bCopyElements) then
		InheritNoBaseClassCopy(tTarget, tBase)
	else
		InheritNoBaseClass(tTarget, tBase)
	end
end
