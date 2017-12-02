local isstring = isstring
local isnumber = isnumber
local istable = istable
local isentity = isentity
local error = error
local getmetatable = getmetatable
local math_floor = math.floor
local debug_getinfo = debug.getinfo

local fOldType = type
local type = function(Val, ...)
	if (Val == NULL) then
		return "NULL"
	end
	
	return fOldType(Val, ...)
end

-- FIXME: Is 3 the right level?
-- FIXME: Refactor to use is* functions?

function assert_type(Val, sType, iArg --[[= nil]], iLevel --[[= 3]])
	if (not isstring(sType)) then
		error("bad argument #2 to 'assert_type' (string expected, got " .. type(sType) .. ")", 2)
	end
	
	if (not (iArg == nil or isnumber(iArg))) then
		error("bad argument #3 to 'assert_type' (number or nil expected, got " .. type(iArg) .. ")", 2)
	end
	
	if (not (iLevel == nil or isnumber(iLevel))) then
		error("bad argument #4 to 'assert_type' (number or nil expected, got " .. type(iLevel) .. ")", 2)
	end
	
	if (type(Val) ~= sType) then
		if (iLevel == nil) then
			iLevel = 3
		end
		
		local sName = debug_getinfo(iLevel - 1, "n").name
		
		error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
			.. " (" .. sType .. " expected, got " .. type(Val) .. ")", iLevel)
	end
end

function assert_types(Val, tTypes, iArg --[[= nil]], iLevel --[[= 3]])
	if (not istable(tTypes)) then
		error("bad argument #2 to 'assert_types' (table expected, got " .. type(tTypes) .. ")", 2)
	end
	
	if (not (iArg == nil or isnumber(iArg))) then
		error("bad argument #3 to 'assert_types' (number or nil expected, got " .. type(iArg) .. ")", 2)
	end
	
	if (not (iLevel == nil or isnumber(iLevel))) then
		error("bad argument #4 to 'assert_types' (number or nil expected, got " .. type(iLevel) .. ")", 2)
	end
	
	local iLen = #tTypes
	
	if (iLen == 0) then
		error("bad argument #2 to 'assert_types' (got empty table)")
	end
	
	local sType = type(Val)
	
	for i = 1, iLen do
		local sTestType = tTypes[i]
		
		if (not isstring(sTestType)) then
			error("bad argument #2 'assert_types' (string value expected, got " .. type(sTestType) .. " at index " .. i .. ")")
		end
		
		if (sType == sTestType) then
			return
		end
	end
	
	local sAcceptedTypes
	
	if (iLen == 1) then
		sAcceptedTypes = tTypes[1]
	elseif (iLen == 2) then
		sAcceptedTypes = tTypes[1] .. " or " .. tTypes[2]
	else
		sAcceptedTypes = ""
		
		for i = 1, iLen - 1 do
			sAcceptedTypes = sAcceptedTypes .. tTypes[i] .. ", "
		end
		
		sAcceptedTypes = sAcceptedTypes .. "or " .. tTypes[iLen]
	end
	
	if (iLevel == nil) then
		iLevel = 3
	end
	
	local sName = debug_getinfo(iLevel - 1, "n").name
	
	error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
		.. " (" .. sAcceptedTypes .. " expected, got " .. sType .. ")", iLevel)
end

function assert_meta(Val, tMeta, iArg --[[= nil]], iLevel --[[= 3]])
	if (not istable(tMeta)) then
		error("bad argument #2 to 'assert_meta' (table expected, got " .. type(tMeta) .. ")", 2)
	end
	
	if (not (iArg == nil or isnumber(iArg))) then
		error("bad argument #3 to 'assert_meta' (number or nil expected, got " .. type(iArg) .. ")", 2)
	end
	
	if (not (iLevel == nil or isnumber(iLevel))) then
		error("bad argument #4 to 'assert_meta' (number or nil expected, got " .. type(iLevel) .. ")", 2)
	end
	
	if (getmetatable(Val) ~= tMeta) then
		if (iLevel == nil) then
			iLevel = 3
		end
		
		local sName = debug_getinfo(iLevel - 1, "n").name
		local tTestMeta = getmetatable(Val)
		
		error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
			.. " (" .. (tMeta.MetaName or tostring(tMeta)) .. " expected, got " .. (tTestMeta == nil and type(Val) or tTestMeta.MetaName) .. ")", iLevel)
	end
end

function assert_metas(Val, tMetas, iArg --[[= nil]], iLevel --[[= 3]])
	if (not istable(tMetas)) then
		error("bad argument #2 to 'assert_metas' (table expected, got " .. type(tTypes) .. ")", 2)
	end
	
	if (not (iArg == nil or isnumber(iArg))) then
		error("bad argument #3 to 'assert_metas' (number or nil expected, got " .. type(iArg) .. ")", 2)
	end
	
	if (not (iLevel == nil or isnumber(iLevel))) then
		error("bad argument #4 to 'assert_metas' (number or nil expected, got " .. type(iLevel) .. ")", 2)
	end
	
	local iLen = #tMetas
	
	if (iLen == 0) then
		error("bad argument #2 to 'assert_metas' (got empty table)")
	end
	
	local tMeta = getmetatable(Val)
	
	for i = 1, iLen do
		local tTestType = tMetas[i]
		
		if (not istable(tTestType)) then
			error("bad argument #2 'assert_metas' (table value expected, got " .. type(sTestType) .. " at index " .. i .. ")")
		end
		
		if (tMeta == tTestType) then
			return
		end
	end
	
	local sAcceptedTypes
	
	if (iLen == 1) then
		sAcceptedTypes = tMetas[1].MetaName or tostring(tMetas[1])
	elseif (iLen == 2) then
		sAcceptedTypes = (tMetas[1].MetaName or tostring(tMetas[1])) .. " or " .. (tMetas[2].MetaName or tostring(tMetas[2]))
	else
		sAcceptedTypes = ""
		
		for i = 1, iLen - 1 do
			sAcceptedTypes = sAcceptedTypes .. (tMetas[i].MetaName or tostring(tMetas[i])) .. ", "
		end
		
		sAcceptedTypes = sAcceptedTypes .. "or " .. (tMetas[iLen].MetaName or tostring(tMetas[iLen]))
	end
	
	if (iLevel == nil) then
		iLevel = 3
	end
	
	local sName = debug_getinfo(iLevel - 1, "n").name
	
	error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
		.. " (" .. sAcceptedTypes .. " expected, got " .. (tMeta == nil and type(Val) or tMeta.MetaName) .. ")", iLevel)
end

function assert_integer(num, iArg --[[= nil]], iLevel --[[= 3]])
	if (not isnumber(num)) then
		error("bad argument #1 to 'assert_integer' (number expected, got " .. type(Val) .. ")", 2)
	end
	
	if (not (iArg == nil or isnumber(iArg))) then
		error("bad argument #2 to 'assert_integer' (number or nil expected, got " .. type(iArg) .. ")", 2)
	end
	
	if (not (iLevel == nil or isnumber(iLevel))) then
		error("bad argument #3 to 'assert_integer' (number or nil expected, got " .. type(iLevel) .. ")", 2)
	end
	
	if (num ~= math_floor(num)) then
		if (iLevel == nil) then
			iLevel = 3
		end
		
		local sName = debug_getinfo(iLevel - 1, "n").name
		
		error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
			.. " (number has no integer representation)", iLevel)
	end
end

function assert_notnil(Val, iArg --[[= nil]], iLevel --[[= 3]])
	if (not (iArg == nil or isnumber(iArg))) then
		error("bad argument #2 to 'assert_notnil' (number or nil expected, got " .. type(iArg) .. ")", 2)
	end
	
	if (not (iLevel == nil or isnumber(iLevel))) then
		error("bad argument #3 to 'assert_notnil' (number or nil expected, got " .. type(iLevel) .. ")", 2)
	end
	
	if (Val == nil) then
		if (iLevel == nil) then
			iLevel = 3
		end
		
		local sName = debug_getinfo(iLevel - 1, "n").name
		
		error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
			.. " (any but nil expected, got nil)", iLevel)
	end
end

function assert_entity(Val, iArg --[[= nil]], iLevel --[[= 3]])
	if (not (iArg == nil or isnumber(iArg))) then
		error("bad argument #2 to 'assert_entity' (number or nil expected, got " .. type(iArg) .. ")", 2)
	end
	
	if (not (iLevel == nil or isnumber(iLevel))) then
		error("bad argument #3 to 'assert_entity' (number or nil expected, got " .. type(iLevel) .. ")", 2)
	end
	
	if (not isentity(Val)) then
		if (iLevel == nil) then
			iLevel = 3
		end
		
		local sName = debug_getinfo(iLevel - 1, "n").name
		
		error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
			.. " (Entity expected, got " .. type(Val) .. ")", iLevel)
	end
end

function assert_entityvalid(Val, iArg --[[= nil]], iLevel --[[= 3]])
	if (not (iArg == nil or isnumber(iArg))) then
		error("bad argument #2 to 'assert_entityvalid' (number or nil expected, got " .. type(iArg) .. ")", 2)
	end
	
	if (not (iLevel == nil or isnumber(iLevel))) then
		error("bad argument #3 to 'assert_entityvalid' (number or nil expected, got " .. type(iLevel) .. ")", 2)
	end
	
	if (not isentity(Val)) then
		if (iLevel == nil) then
			iLevel = 3
		end
		
		local sName = debug_getinfo(iLevel - 1, "n").name
		
		error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
			.. " (Entity expected, got " .. type(Val) .. ")", iLevel)
	end
	
	if (not (Val:IsValid() or Val:IsWorld())) then
		if (iLevel == nil) then
			iLevel = 3
		end
		
		local sName = debug_getinfo(iLevel - 1, "n").name
		
		error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
			.. " (tried to use an invalid entity)", iLevel)
	end
end

function assert_world(Val, iArg --[[= nil]], iLevel --[[= 3]])
	if (not (iArg == nil or isnumber(iArg))) then
		error("bad argument #2 to 'assert_player' (number or nil expected, got " .. type(iArg) .. ")", 2)
	end
	
	if (not (iLevel == nil or isnumber(iLevel))) then
		error("bad argument #3 to 'assert_player' (number or nil expected, got " .. type(iLevel) .. ")", 2)
	end
	
	if (not (isentity(Val) and Val:IsWorld())) then
		if (iLevel == nil) then
			iLevel = 3
		end
		
		local sName = debug_getinfo(iLevel - 1, "n").name
		
		error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
			.. " (World expected, got " .. type(Val) .. ")", iLevel)
	end
end

function assert_player(Val, iArg --[[= nil]], iLevel --[[= 3]])
	if (not (iArg == nil or isnumber(iArg))) then
		error("bad argument #2 to 'assert_player' (number or nil expected, got " .. type(iArg) .. ")", 2)
	end
	
	if (not (iLevel == nil or isnumber(iLevel))) then
		error("bad argument #3 to 'assert_player' (number or nil expected, got " .. type(iLevel) .. ")", 2)
	end
	
	if (not (isentity(Val) and Val:IsPlayer())) then
		if (iLevel == nil) then
			iLevel = 3
		end
		
		local sName = debug_getinfo(iLevel - 1, "n").name
		
		error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
			.. " (Player expected, got " .. type(Val) .. ")", iLevel)
	end
end

function assert_weapon(Val, iArg --[[= nil]], iLevel --[[= 3]])
	if (not (iArg == nil or isnumber(iArg))) then
		error("bad argument #2 to 'assert_weapon' (number or nil expected, got " .. type(iArg) .. ")", 2)
	end
	
	if (not (iLevel == nil or isnumber(iLevel))) then
		error("bad argument #3 to 'assert_weapon' (number or nil expected, got " .. type(iLevel) .. ")", 2)
	end
	
	if (not (isentity(Val) and Val:IsWeapon())) then
		if (iLevel == nil) then
			iLevel = 3
		end
		
		local sName = debug_getinfo(iLevel - 1, "n").name
		
		error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
			.. " (Weapon expected, got " .. type(Val) .. ")", iLevel)
	end
end

function assert_npc(Val, iArg --[[= nil]], iLevel --[[= 3]])
	if (not (iArg == nil or isnumber(iArg))) then
		error("bad argument #2 to 'assert_npc' (number or nil expected, got " .. type(iArg) .. ")", 2)
	end
	
	if (not (iLevel == nil or isnumber(iLevel))) then
		error("bad argument #3 to 'assert_npc' (number or nil expected, got " .. type(iLevel) .. ")", 2)
	end
	
	if (not (isentity(Val) and Val:IsNPC())) then
		if (iLevel == nil) then
			iLevel = 3
		end
		
		local sName = debug_getinfo(iLevel - 1, "n").name
		
		error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
			.. " (NPC expected, got " .. type(Val) .. ")", iLevel)
	end
end

function assert_vehicle(Val, iArg --[[= nil]], iLevel --[[= 3]])
	if (not (iArg == nil or isnumber(iArg))) then
		error("bad argument #2 to 'assert_vehicle' (number or nil expected, got " .. type(iArg) .. ")", 2)
	end
	
	if (not (iLevel == nil or isnumber(iLevel))) then
		error("bad argument #3 to 'assert_vehicle' (number or nil expected, got " .. type(iLevel) .. ")", 2)
	end
	
	if (not (isentity(Val) and Val:IsVehicle())) then
		if (iLevel == nil) then
			iLevel = 3
		end
		
		local sName = debug_getinfo(iLevel - 1, "n").name
		
		error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
			.. " (Vehicle expected, got " .. type(Val) .. ")", iLevel)
	end
end

function assert_ragdoll(Val, iArg --[[= nil]], iLevel --[[= 3]])
	if (not (iArg == nil or isnumber(iArg))) then
		error("bad argument #2 to 'assert_ragdoll' (number or nil expected, got " .. type(iArg) .. ")", 2)
	end
	
	if (not (iLevel == nil or isnumber(iLevel))) then
		error("bad argument #3 to 'assert_ragdoll' (number or nil expected, got " .. type(iLevel) .. ")", 2)
	end
	
	if (not (isentity(Val) and Val:IsRagdoll())) then
		if (iLevel == nil) then
			iLevel = 3
		end
		
		local sName = debug_getinfo(iLevel - 1, "n").name
		
		error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
			.. " (Ragdoll expected, got " .. type(Val) .. ")", iLevel)
	end
end

function assert_viewmodel(Val, iArg --[[= nil]], iLevel --[[= 3]])
	if (not (iArg == nil or isnumber(iArg))) then
		error("bad argument #2 to 'assert_viewmodel' (number or nil expected, got " .. type(iArg) .. ")", 2)
	end
	
	if (not (iLevel == nil or isnumber(iLevel))) then
		error("bad argument #3 to 'assert_viewmodel' (number or nil expected, got " .. type(iLevel) .. ")", 2)
	end
	
	if (not (isentity(Val) and Val:IsViewModel())) then
		if (iLevel == nil) then
			iLevel = 3
		end
		
		local sName = debug_getinfo(iLevel - 1, "n").name
		
		error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
			.. " (Viewmodel expected, got " .. type(Val) .. ")", iLevel)
	end
end

function assert_customarg(Val, sMessage --[[= nil]], iArg --[[= nil]], iLevel --[[= 3]])
	if (not (sMessage == nil or isstring(sMessage))) then
		error("bad argument #2 to 'assert_customarg' (string or nil expected, got " .. type(sMessage) .. ")", 2)
	end
	
	if (not (iArg == nil or isnumber(iArg))) then
		error("bad argument #3 to 'assert_customarg' (number or nil expected, got " .. type(iArg) .. ")", 2)
	end
	
	if (not (iLevel == nil or isnumber(iLevel))) then
		error("bad argument #4 to 'assert_customarg' (number or nil expected, got " .. type(iLevel) .. ")", 2)
	end
	
	if (not Val) then
		if (iLevel == nil) then
			iLevel = 3
		end
		
		local sName = debug_getinfo(iLevel - 1, "n").name
		
		error("bad argument " .. (iArg and "#" .. iArg or "") .. (sName == nil and "" or " to '" .. sName .. "'")
			.. (sMessage and " (" .. sMessage .. ")" or ""), iLevel)
	end
end
