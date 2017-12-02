-- No auto-refresh here
if (gs ~= nil) then return end

-- 0: No debugging
-- 1: Release-debugging - extra type and structure checks; code must pass error free on this level
-- 2: Development-debugging - strict type/object debugging
gs = {DEBUG = 2}

-- Global/library localisations
-- Type checking functions are used often in performance-variant environments
-- So they are optimised down to a fine level
local type = type
local error = error
local pcall = pcall
local print = print
local pairs = pairs
local unpack = unpack
local rawget = rawget
local TypeID = TypeID
local include = include
local require = require
local getfenv = getfenv
local setfenv = setfenv
local tostring = tostring
local ErrorNoHalt = ErrorNoHalt
local CompileFile = CompileFile
local AddCSLuaFile = AddCSLuaFile
local FindMetaTable = FindMetaTable

local file_Find = file.Find
local math_floor = math.floor
local string_sub = string.sub
local string_rep = string.rep
local string_find = string.find
local string_lower = string.lower
local string_upper = string.upper
local string_format = string.format
local debug_getinfo = debug.getinfo
local debug_getmetatable = debug.getmetatable
local debug_setmetatable = debug.setmetatable

local tTypeNilBool = {TYPE_NIL, TYPE_BOOL}
local tTypeNilString = {TYPE_NIL, TYPE_STRING}
local tTypeNilNumber = {TYPE_NIL, TYPE_NUMBER}
local iTypeNilNumber = #tTypeNilNumber
local tTypeNilFunction = {TYPE_NIL, TYPE_FUNCTION}
local tTypeNumberTable = {TYPE_NUMBER, TYPE_TABLE}
local tTypeNumberTable = #tTypeNumberTable

local tArgs45 = {4, 5}
local iArgs45 = #tArgs45

local fSetInt = function(num)
	return num == math_floor(num), "expected integer, got %s"
end

local fSetPositiveInt = function(num)
	return num > 0 and num == math_floor(num), "expected integer [1, inf), got %s"
end

local fSetNonNegInt = function(num)
	return num >= 0 and num == math_floor(num), "expected integer [0, inf), got %s"
end

-- https://github.com/Facepunch/garrysmod-requests/issues/1013
local sTypeNil = type(nil)
local sTypeBool = type(false)
local sTypeNumber = type(0)
local sTypeString = type("")
local sTypeTable = type({})
local fEmpty = function() end
local sTypeFunction = type(fEmpty)

local tTypeTranslation = {
	--[TYPE_INVALID] = "no value",
	[TYPE_NIL] = sTypeNil,
	[TYPE_BOOL] = sTypeBool,
	[TYPE_LIGHTUSERDATA] = "light userdata", -- Can't create light userdata
	[TYPE_NUMBER] = sTypeNumber,
	[TYPE_STRING] = sTypeString,
	[TYPE_TABLE] = sTypeTable,
	[TYPE_FUNCTION] = sTypeFunction,
	[TYPE_USERDATA] = type(newproxy()),
	[TYPE_THREAD] = type(coroutine.create(fEmpty))
}

-- Could do this automatically by scanning the registry for MetaID's and MetaName's
-- But this would add any custom tables people have added to the registry
-- It would also create unpredictable results with TYPE_ENTITY since it is the ID
-- For Entity, Player, NPC, Vehicle, Weapon, Nextbot, and CSEnt
-- Stick to only default TYPE_* enums
local function RegisterType(iEnum, sMeta)
	-- TYPE_PROJECTEDTEXTURE not in main branch yet
	if (iEnum ~= nil) then
		local tMeta = FindMetaTable(sMeta)
		
		-- Only insert in the correct realm
		if (tMeta ~= nil) then
			tTypeTranslation[iEnum] = tMeta.MetaName or sMeta
		end
	end
end

RegisterType(TYPE_ENTITY, "Entity")
RegisterType(TYPE_VECTOR, "Vector")
RegisterType(TYPE_ANGLE, "Angle")
RegisterType(TYPE_PHYSOBJ, "PhysObj")
RegisterType(TYPE_SAVE, "ISave")
RegisterType(TYPE_RESTORE, "IRestore")
RegisterType(TYPE_DAMAGEINFO, "CTakeDamageInfo")
RegisterType(TYPE_EFFECTDATA, "CEffectData")
RegisterType(TYPE_MOVEDATA, "CMoveData")
RegisterType(TYPE_RECIPIENTFILTER, "CRecipientFilter")
RegisterType(TYPE_USERCMD, "CUserCmd")
RegisterType(TYPE_MATERIAL, "IMaterial")
RegisterType(TYPE_PANEL, "Panel")
RegisterType(TYPE_PARTICLE, "CLuaParticle")
RegisterType(TYPE_PARTICLEEMITTER, "CLuaEmitter")
RegisterType(TYPE_TEXTURE, "ITexture")
RegisterType(TYPE_USERMSG, "bf_read")
RegisterType(TYPE_CONVAR, "ConVar")
RegisterType(TYPE_IMESH, "IMesh")
RegisterType(TYPE_MATRIX, "VMatrix")
RegisterType(TYPE_SOUND, "CSoundPatch")
RegisterType(TYPE_PIXELVISHANDLE, "pixelvis_handle_t")
RegisterType(TYPE_DLIGHT, "dlight_t")
RegisterType(TYPE_VIDEO, "IVideoWriter")
RegisterType(TYPE_FILE, "File")
RegisterType(TYPE_LOCOMOTION, "CLuaLocomotion")
RegisterType(TYPE_PATH, "PathFollower")
RegisterType(TYPE_NAVAREA, "CNavArea")
RegisterType(TYPE_SOUNDHANDLE, "IGModAudioChannel")
RegisterType(TYPE_NAVLADDER, "CNavLadder")
RegisterType(TYPE_PARTICLESYSTEM, "CNewParticleEffect")
RegisterType(TYPE_PROJECTEDTEXTURE, "ProjectedTexture")

-- HACK: TYPE_COLOR is a Lua-declared enum and isn't actually associated to a TypeID-identifiable type
local COLOR = FindMetaTable("Color")

local tCustomTypes = {
	[TYPE_COLOR] = {
		function(Val, nType)
			return nType == TYPE_TABLE and debug_getmetatable(Val) == COLOR
		end, "Color"
	}
}

local function table_NiceList_Format(tList, sSeparator, iStartPos, iEndPos, iSubLength, fFormat)
	if (iSubLength < 0) then
		return ""
	end
	
	if (iSubLength == 0) then
		return tostring(fFormat(tList[iStart]))
	end
	
	if (iSubLength == 1) then
		return string_format("%s %s %s", fFormat(tList[iStart]), sSeparator, fFormat(tList[iEnd]))
	end
	
	local sList = ""
	
	for i = iStart, iEnd - 1 do
		sList = string_format("%s %s, ", sList, fFormat(tList[i]))
	end
	
	return string_format("%s %s %s", sList, sSeparator, fFormat(tList[iEnd]))
end

local function table_NiceList(tList, sSeparator, fFormat, iStartPos, iEndPos, iSubLength)
	if (iSubLength < 0) then
		return ""
	end
	
	if (iSubLength == 0) then
		return tostring(tList[iStart])
	end
	
	if (iSubLength == 1) then
		return string_format("%s %s %s", tList[iStart], sSeparator, tList[iEnd])
	end
	
	local sList = ""
	
	for i = iStart, iEnd - 1 do
		sList = string_format("%s %s, ", sList, tList[i])
	end
	
	return string_format("%s %s %s", sList, sSeparator, tList[iEnd])
end

local function FormatArg(iArg)
	-- This is actually faster than a single concat
	-- JIT probably inlines a uint concatenation
	return string_format("#%u", iArg)
end

local function FormatArg_Method(iArg)
	iArg = iArg - 1
	
	if (iArg == 0) then
		return "self"
	end
	
	return FormatArg(iArg)
end

local function ArgError(iArg, sSubError, iLevel)
	iLevel = iLevel + 1
	local tInfo = debug_getinfo(iLevel, "n")
	local sPrefix
	
	if (tInfo == nil) then
		sPrefix = string_format("bad argument #%u", iArg)
	else
		if (tInfo.namewhat == "method") then
			iArg = iArg - 1
			
			if (iArg == 0) then
				sPrefix = string_format("calling '%s' on bad self", tInfo.name)
				
				-- goto solves so many inner-else/outer-else repetative branches
				goto SelfArg
			end
		end
		
		sPrefix = string_format("bad argument #%u to '%s'", iArg, tInfo.name or "?")
		
		::SelfArg::
	end
	
	-- Level 0 refers to the error call here
	-- Bump it up 1 since you want the error to target the function that ran the erroneous code
	-- While debug.getinfo targets the function that threw the error
	error(string_format("%s (%s)", sPrefix, sSubError), iLevel + 1)
end

local function ArgsError(tArgs, iLength, sSubError, iLevel)
	iLevel = iLevel + 1
	local tInfo = debug_getinfo(iLevel, "n")
	local sPrefix
	
	if (tInfo == nil) then
		sPrefix = string_format("bad arguments %s", table_NiceList_Format(tArgs, "and", 1, iLength, iLength - 1, FormatArg))
	else
		sPrefix = string_format("bad arguments %s to '%s'", table_NiceList_Format(tArgs, "and", 1, iLength, iLength - 1, tInfo.namewhat == "method" and FormatArg_Method or FormatArg), tInfo.name or "?")
	end
	
	error(string_format("%s (%s)", sPrefix, sSubError), iLevel + 1)
end

local sRet1CheckType = "bad return #1 in check " .. sTypeFunction .. " for type %s (" .. sTypeBool .. " expected, got %s)"
local sRet2CheckType = "bad return #2 in check " .. sTypeFunction .. " for type %s (" .. sTypeString .. " or " .. sTypeNil .. " expected, got %s)"

local function IsType(Val, nType, iErrorLevel, bDebug)
	if (tTypeTranslation[nType] == nil) then
		local tType = tCustomTypes[nType]
		local bRet, sError
		
		if (bDebug) then
			local bSuccess
			bSuccess, bRet, sError = pcall(tType[1], Val, TypeID(Val))
			
			if (not bSuccess) then
				error(string_format("bad check function of type %s (%s)", tType[2], bRet), iErrorLevel + 1)
			end
			
			local nCheckType = TypeID(bRet)
			
			if (nCheckType ~= TYPE_BOOL) then
				error(string_format(sRet1CheckType, tType[2], tTypeTranslation[nCheckType]), iErrorLevel + 1)
			end
			
			nCheckType = TypeID(sError)
			
			if (not (nCheckType == TYPE_NIL or nCheckType == TYPE_STRING)) then
				error(string_format(sRet2CheckType, tType[2], tTypeTranslation[nCheckType]), iErrorLevel + 1)
			end
		else
			bRet, sError = tType[1](Val, TypeID(Val))
		end
		
		if (bRet) then
			return true
		end
		
		return false, sError
	end
	
	return TypeID(Val) == nType
end

local function TypeName(nType)
	local sName = tTypeTranslation[nType]
	
	if (sName == nil) then
		return tCustomTypes[nType][2]
	end
	
	return sName
end

local function CheckType(Val, iArg, nType, iLevel, iErrorLevel, bDebug)	
	local bIsType, sError = IsType(Val, nType, iErrorLevel + 1, bDebug)
	
	if (not bIsType) then
		ArgError(iArg, sError or string_format("%s expected, got %s", TypeName(nType), type(Val)), iLevel + 1)
	end
end

local function IsTypes(Val, tTypes, iLength, iErrorLevel, bDebug)
	iErrorLevel = iErrorLevel + 1
	
	for i = 1, iLength do
		if (IsType(Val, tTypes[i], iErrorLevel, bDebug)) then
			return tTypes[i]
		end
	end
	
	return false
end

local function CheckTypes(Val, iArg, tTypes, iLength, iLevel, bDebug)
	local Ret = IsTypes(Val, tTypes, iLength, 2, bDebug)
	
	if (Ret == false) then
		ArgError(iArg, string_format("%s expected, got %s", table_NiceList_Format(tTypes, "or", 1, iLength, iLength - 1, TypeName), type(Val)), iLevel + 1)
	end
	
	return Ret
end

local function CheckMinLength(Val, iArg, iLength, iMinLength, iLevel)
	if (iLength < iMinLength) then
		ArgError(iArg, string_format("%s has length %u, expected at least %u", type(Val), iLength, iMinLength), iLevel + 1)
	end
end

local sNumberKey = sTypeNumber .. " key expected, got %s (%s)"
local sTableSequential = sTypeTable .. " is not sequential"
local sTableIndex = sTypeTable .. " has keys less than one"
local sNumberValue = sTypeNumber .. " value expected at key %u, got %s"

local function CheckFormattedTable(tbl, iArg, fLoopCheck)
	CheckType(tbl, iArg, TYPE_TABLE, 2, 2, true)
	
	local tEntries = {}
	local iNextIndex = 0
	
	for k, v in pairs(tbl) do
		iNextIndex = iNextIndex + 1
		
		if (iNextIndex ~= k) then
			if (not IsType(k, TYPE_NUMBER, 3, true)) then
				ArgError(iArg, string_format(sNumberKey, type(k), k), 2)
			end
			
			ArgError(iArg, k > 0 and sTableSequential or sTableIndex, 2)
		end
		
		if (not IsType(v, TYPE_NUMBER, 3, true)) then
			ArgError(iArg, string_format(sNumberValue, k, type(v)), 2)
		end
		
		fLoopCheck(k, v, iArg, 2)
		
		if (tEntries[v] == true) then
			ArgError(iArg, string_format("%g has duplicate entries in the table", v), 2)
		end
		
		tEntries[v] = true
	end
	
	CheckMinLength(tbl, iArg, iNextIndex, 2, 2)
	
	return iNextIndex
end

local function CheckTypeTable(k, v, iArg, iLevel)
	if (tTypeTranslation[v] == nil and tCustomTypes[v] == nil) then
		ArgError(iArg, v .. " at key " .. k .. " is not a registered type", iLevel + 1)
	end
end

local sRet1CheckSet = "bad return #1 - " .. sTypeBool .. " expected, got %s"
local sRet2CheckSet = "bad return #2 - " .. sTypeString .. " expected, got %s"

local function InSet(num, fSet, iErrorLevel, bDebug)
	local bRet, sError
	
	if (bDebug) then
		local bSuccess
		bSuccess, bRet, sError = pcall(fSet, num)
		
		if (not bSuccess) then
			ArgError(3, "function error - " .. bRet, iErrorLevel + 1)
		end
		
		local nCheckType = TypeID(bRet)
		
		if (nCheckType ~= TYPE_BOOL) then
			ArgError(3, string_format(sRet1CheckSet, tTypeTranslation[nCheckType]), iErrorLevel + 1)
		end
		
		nCheckType = TypeID(sError)
		
		if (nCheckType ~= TYPE_STRING) then
			ArgError(3, string_format(sRet2CheckSet, tTypeTranslation[nCheckType]), iErrorLevel + 1)
		end
	else
		bRet, sError = fSet(num)
	end
	
	if (bRet) then
		return true
	end
	
	return false, sError
end

local function CheckSet(num, iArg, fSet, iLevel, bDebug)
	local bInSet, sError = InSet(num, fSet, 2, bDebug)
	
	if (not bInSet) then
		ArgError(iArg, string_format(sError, num), iLevel + 1)
	end
end

local function CheckArgTable(k, v, iArg, iLevel)
	iLevel = iLevel + 1
	local bInSet, sError = InSet(v, fSetPositiveInt, iLevel, true)
	
	if (not bInSet) then
		ArgError(iArg, string_format(sError, v .. " at key " .. k), iLevel)
	end
end

-- iLevel refers to the stack level
-- 0 = The gs.* function call
-- 1 = The function that called gs.*
-- 2 = The function that called the function that called gs.*
-- 2 is default since it will be the majority case for checking argument types

function gs.ArgError(iArg, sSubError, iLevel --[[= 2]])
	if (gs.DEBUG >= 1) then
		CheckType(iArg, 1, TYPE_NUMBER, 1, 1, true)
		CheckSet(iArg, 1, fSetPositiveInt, 1, true)
		CheckType(sSubError, 2, TYPE_STRING, 1, 1, true)
		
		if (CheckTypes(iLevel, 3, tTypeNilNumber, iTypeNilNumber, 1, true) == TYPE_NIL) then
			iLevel = 2
		else
			CheckSet(iLevel, 3, fSetNonNegInt, 1, true)
		end
	elseif (iLevel == nil) then
		iLevel = 2
	end
	
	ArgError(iArg, sSubError, iLevel)
end

function gs.ArgsError(tArgs, sSubError, iLevel --[[= 2]])
	if (gs.DEBUG >= 1) then
		iLength = CheckFormattedTable(tArgs, 3, CheckArgTable)
		CheckType(sSubError, 2, TYPE_STRING, 1, 1, true)
		
		if (CheckTypes(iLevel, 3, tTypeNilNumber, iTypeNilNumber, 1, true) == TYPE_NIL) then
			iLevel = 2
		else
			CheckSet(iLevel, 3, fSetNonNegInt, 1, true)
		end
	else
		iLength = #tArgs
		
		if (iLevel == nil) then
			iLevel = 2
		end
	end
	
	ArgsError(tArgs, iLength, sSubError, iLevel)
end

-- https://github.com/Facepunch/garrysmod-requests/issues/1013
function gs.GetTypeName(nType)
	CheckType(nType, 1, TYPE_NUMBER, 1, 1, gs.DEBUG >= 1)
	
	local sName = tTypeTranslation[nType]
	
	if (sName == nil) then
		local tCustom = tCustomTypes[nType]
		
		if (tCustom == nil) then
			return nil
		end
		
		return tCustom[2]
	end
	
	return sName
end

function gs.IsType(Val, nType)
	local bDebug = gs.DEBUG >= 1
	
	if (bDebug) then
		CheckType(nType, 2, TYPE_NUMBER, 1, 1, true)
		CheckSet(nType, 2, fSetInt, 1, true)
	end
	
	return (IsType(Val, nType, 1, bDebug))
end

function gs.IsTypes(Val, tTypes)
	local bDebug = gs.DEBUG >= 1
	
	return IsTypes(Val, tTypes, bDebug and CheckFormattedTable(tTypes, 2, CheckTypeTable) or #tTypes, 1, bDebug)
end

function gs.CheckType(Val, iArg, nType, iLevel --[[= 2]])
	local bDebug = gs.DEBUG >= 1
	
	if (bDebug) then
		CheckType(iArg, 2, TYPE_NUMBER, 1, 1, true)
		CheckSet(iArg, 2, fSetPositiveInt, 1, true)
		CheckType(nType, 3, TYPE_NUMBER, 1, 1, true)
		CheckSet(nType, 3, fSetInt, 1, true)
		
		if (tTypeTranslation[nType] == nil and tCustomTypes[nType] == nil) then
			ArgError(3, nType .. " is not a registered type", 1)
		end
		
		if (CheckTypes(iLevel, 4, tTypeNilNumber, iTypeNilNumber, 1, true) == TYPE_NIL) then
			iLevel = 2
		else
			CheckSet(iLevel, 4, fSetNonNegInt, 1, true)
		end
	elseif (iLevel == nil) then
		iLevel = 2
	end
	
	CheckType(Val, iArg, nType, iLevel, 1, bDebug)
end

function gs.CheckValue(Val, iArg, iLevel --[[= 2]])
	if (gs.DEBUG >= 1) then
		CheckType(iArg, 2, TYPE_NUMBER, 1, 1, true)
		CheckSet(iArg, 2, fSetPositiveInt, 1, true)
		
		if (CheckTypes(iLevel, 3, tTypeNilNumber, iTypeNilNumber, 1, true) == TYPE_NIL) then
			iLevel = 2
		else
			CheckSet(iLevel, 3, fSetNonNegInt, 1, true)
		end
	elseif (iLevel == nil) then
		iLevel = 2
	end
	
	if (Val == nil) then
		ArgError(iArg, "value expected", iLevel)
	end
end

function gs.CheckTypes(Val, iArg, tTypes, iLevel --[[= 2]])
	local bDebug = gs.DEBUG >= 1
	local iLength
	
	if (bDebug) then
		CheckType(iArg, 2, TYPE_NUMBER, 1, 1, true)
		CheckSet(iArg, 2, fSetPositiveInt, 1, true)
		iLength = CheckFormattedTable(tTypes, 3, CheckTypeTable)
		
		if (CheckTypes(iLevel, 4, tTypeNilNumber, iTypeNilNumber, 1, true) == TYPE_NIL) then
			iLevel = 2
		else
			CheckSet(iLevel, 4, fSetNonNegInt, 1, true)
		end
	else
		iLength = #tTypes
		
		if (iLevel == nil) then
			iLevel = 2
		end
	end
	
	return CheckTypes(Val, iArg, tTypes, iLength, iLevel, bDebug)
end

function gs.CheckTypesAndSet(Val, iArg, tTypes, fSet, iLevel --[[= 2]])
	local bDebug = gs.DEBUG >= 1
	local iLength
	
	if (bDebug) then
		CheckType(iArg, 2, TYPE_NUMBER, 1, 1, true)
		CheckSet(iArg, 2, fSetPositiveInt, 1, true)
		
		-- FIXME: Slow..
		CheckFormattedTable(tTypes, 3, function(k, v, iArg, iLevel)
			CheckTypeTable(k, v, iArg, iLevel + 1)
			
			if (v == TYPE_NUMBER) then
				bNumber = true
			end
		end)
		
		if (not bNumber) then
			ArgError(3, "no TYPE_NUMBER value in table", 1)
		end
		
		CheckMinLength(tTypes, 3, iNextIndex, 2, 1)
		CheckType(fSet, 4, TYPE_FUNCTION, 1, 1, true)
		
		if (CheckTypes(iLevel, 5, tTypeNilNumber, iTypeNilNumber, 1, true) == TYPE_NIL) then
			iLevel = 2
		else
			CheckSet(iLevel, 5, fSetNonNegInt, 1, true)
		end
		
		iLength = iNextIndex
	else
		iLength = #tTypes
		
		if (iLevel == nil) then
			iLevel = 2
		end
	end
	
	local nType = CheckTypes(Val, iArg, tTypes, iLength, iLevel, bDebug)
	
	if (nType == TYPE_NUMBER) then
		CheckSet(nType, iArg, fSet, iLevel, bDebug)
	end
	
	return nType
end

function gs.CheckSet(num, iArg, fSet, iLevel --[[= 2]])
	local bDebug = gs.DEBUG >= 1
	
	if (bDebug) then
		CheckType(iArg, 2, TYPE_NUMBER, 1, 1, true)
		CheckSet(iArg, 2, fSetPositiveInt, 1, true)
		CheckType(fSet, 3, TYPE_FUNCTION, 1, 1, true)
		
		if (CheckTypes(iLevel, 4, tTypeNilNumber, iTypeNilNumber, 1, true) == TYPE_NIL) then
			iLevel = 2
		else
			CheckSet(iLevel, 4, fSetNonNegInt, 1, true)
		end
	elseif (iLevel == nil) then
		iLevel = 2
	end
	
	CheckType(num, iArg, TYPE_NUMBER, iLevel, 1, bDebug)
	CheckSet(num, iArg, fSet, iLevel, bDebug)
end

local sNilBoth = "expected one non-" .. sTypeNil

local function CheckLengthArgs(iArg, iMinLength --[[= nil]], iMaxLength --[[= nil]], iLevel --[[= 2]], bDebug)
	if (bDebug) then
		CheckType(iArg, 2, TYPE_NUMBER, 2, 2, true)
		CheckSet(iArg, 2, fSetPositiveInt, 2, true)
		
		local bCheckMin = false
		
		if (CheckTypes(iMinLength, 3, tTypeNilNumber, iTypeNilNumber, 2, true) == TYPE_NUMBER) then
			CheckSet(iMinLength, 3, fSetPositiveInt, 2, true)
			bCheckMin = true
		end
		
		if (CheckTypes(iMaxLength, 4, tTypeNilNumber, iTypeNilNumber, 2, true) == TYPE_NIL) then
			if (not bCheckMin) then
				ArgsError(tArgs45, iArgs45, sNilBoth, 2)
			end
		else
			CheckSet(iMaxLength, 4, fSetPositiveInt, 2, true)
		end
		
		if (CheckTypes(iLevel, 5, tTypeNilNumber, iTypeNilNumber, 2, true) == TYPE_NIL) then
			iLevel = 2
		else
			CheckSet(iLevel, 5, fSetNonNegInt, 2, true)
		end
	elseif (iLevel == nil) then
		iLevel = 2
	end
	
	return iLevel
end

local function CheckLength(Val, iArg, iMinLength --[[= nil]], iMaxLength --[[= nil]], iLevel, iLength)
	if (iMinLength ~= nil) then
		CheckMinLength(Val, iArg, iLength, iMinLength, iLevel + 1)
	end
	
	if (iMaxLength ~= nil and iLength > iMaxLength) then
		ArgError(iArg, type(Val) .. " has length " .. iLength .. ", expected at most " .. iMaxLength, iLevel + 1)
	end
end

local function Length(Val)
	return #Val
end

function gs.CheckLength(Val, iArg, iMinLength --[[= nil]], iMaxLength --[[= nil]], iLevel --[[= 2]])
	local bDebug = gs.DEBUG >= 1
	iLevel = CheckLengthArgs(iArg, iMinLength, iMaxLength, iLevel, bDebug)
	
	local iLength
	
	if (bDebug) then
		local bSuccess
		bSuccess, iLength = pcall(Length, Val)
		
		if (not bSuccess) then
			ArgError(1, "length operation not implemented for " .. type(Val), 1)
		end
	else
		iLength = #Val
	end
	
	CheckLength(Val, iArg, iMinLength, iMaxLength, iLevel, iLength)
	
	return iLength
end

local function TypeLengthFuncBuilder(sName, nType)
	gs["Check" .. sName .. "Length"] = function(Val, iArg, iMinLength --[[= nil]], iMaxLength --[[= nil]], iLevel --[[= 2]])
		local bDebug = gs.DEBUG >= 1
		iLevel = CheckLengthArgs(iArg, iMinLength, iMaxLength, iLevel, bDebug)
		CheckType(Val, iArg, nType, iLevel, 1, bDebug)
		
		local iLength = #Val
		CheckLength(Val, iArg, iMinLength, iMaxLength, iLevel, iLength)
		
		return iLength
	end
end

-- function gs.CheckStringLength(Val, iArg, iMinLength --[[= nil]], iMaxLength --[[= nil]], iLevel --[[= 2]])
TypeLengthFuncBuilder("String", TYPE_STRING)

-- function gs.CheckTableLength(Val, iArg, iMinLength --[[= nil]], iMaxLength --[[= nil]], iLevel --[[= 2]])
TypeLengthFuncBuilder("Table", TYPE_TABLE)

local function CheckValidArgs(Val, iArg, iLevel --[[= 2]], bDebug)
	if (bDebug) then
		CheckType(iArg, 2, TYPE_NUMBER, 2, 2, true)
		CheckSet(iArg, 2, fSetPositiveInt, 2, true)
		
		if (CheckTypes(iLevel, 3, tTypeNilNumber, iTypeNilNumber, 2, true) == TYPE_NIL) then
			iLevel = 2
		else
			CheckSet(iLevel, 3, fSetNonNegInt, 2, true)
		end
	elseif (iLevel == nil) then
		iLevel = 2
	end
	
	return iLevel
end

local function ValidError(Val, iArg, iLevel)
	ArgError(iArg, "expected valid " .. type(Val), iLevel + 1)
end

local function GetValid(Val)
	return Val.IsValid
end

local sBoolValid = " has IsValid method that doesn't return a " .. sTypeBool .. ", returns "

function gs.CheckValid(Val, iArg, iLevel --[[= 2]])
	local nDebug = gs.DEBUG
	local bDebug = nDebug >= 1
	iLevel = CheckValidArgs(Val, iArg, iLevel, bDebug)
	
	local bValid
	
	if (bDebug) then
		local bSuccess, fValid = pcall(GetValid, Val)
		
		if (not bSuccess) then
			ArgError(1, type(Val) .. " cannot be indexed", 1)
		end
		
		bSuccess, bValid = pcall(fValid, Val)
		
		if (not bSuccess) then
			ArgError(1, type(Val) .. " has bad IsValid method - " .. bValid, 1)
		end
		
		if (nDebug >= 2) then
			local nValidType = TypeID(bValid)
			
			if (nValidType ~= TYPE_BOOL) then
				ArgError(1, type(Val) .. sBoolValid .. tTypeTranslation[nValidType], 1)
			end
		end
	else
		bValid = Val:IsValid()
	end
	
	if (not bValid) then
		ValidError(Val, iArg, iLevel)
	end
end

local function TypeValidFuncBuilder(sName, nType)
	gs["Check" .. sName .. "Valid"] = function(Val, iArg, iLevel --[[= 2]])
		local bDebug = gs.DEBUG >= 1
		iLevel = CheckValidArgs(Val, iArg, iLevel, bDebug)
		CheckType(Val, iArg, nType, iLevel, 1, bDebug)
		
		if (not Val:IsValid()) then
			ValidError(Val, iArg, iLevel)
		end
	end
end

-- function gs.CheckEntityValid(Val, iArg, iLevel --[[= 2]])
TypeValidFuncBuilder("Entity", TYPE_ENTITY)

-- function gs.CheckPhysicsObjectValid(Val, iArg, iLevel --[[= 2]])
TypeValidFuncBuilder("PhysicsObject", TYPE_PHYSOBJ)

if (CLIENT) then
	-- function gs.CheckPanelValid(Val, iArg, iLevel --[[= 2]])
	TypeValidFuncBuilder("Panel", TYPE_PANEL)
end

-- Need to check two methods here
function gs.CheckVehicleValid(Val, iArg, iLevel --[[= 2]])
	local bDebug = gs.DEBUG >= 1
	iLevel = CheckValidArgs(Val, iArg, iLevel, bDebug)
	CheckType(Val, iArg, gs.TYPE_VEHICLE, iLevel, 1, bDebug)
	
	if (not (Val:IsValid() and Val:IsValidVehicle())) then
		ValidError(Val, iArg, iLevel)
	end
end

local gs_developer = CreateConVar("gs_developer", "0", FCVAR_ARCHIVE, "Enables developer messages for GS addons")

function gs.DevMsg(iLevel, First, ...)
	gs.CheckSet(iLevel, 1, fSetNonNegInt)
	
	if (iLevel == 0 or gs_developer:GetInt() >= iLevel) then
		print("[GS Dev] " .. tostring(First), ...)
	end
end

local function table_DeepCopy(tbl, fCopy)
	local tCopy = {}
	
	for k, v in pairs(tbl) do
		tCopy[fCopy(k)] = fCopy(v)
	end
	
	return tCopy
end

do
	-- Add copy-constructor support
	local fMatrix = Matrix

	function Matrix(Data)
		return fMatrix(gs.IsType(Data, TYPE_MATRIX) and {Data:GetRow(1), Data:GetRow(2), Data:GetRow(3), Data:GetRow(4)} or Data)
	end
end

local Angle = Angle
local Vector = Vector
local Matrix = Matrix

local function Copy(Val, fCopy)
	local nType = TypeID(Val)
	
	-- FIXME: Don't call __add
	--[[if (nType == TYPE_NUMBER) then
		return Val + 0
	end
	
	-- FIXME: Don't call concat
	if (nType == TYPE_STRING) then
		return Val .. ""
	end]]
	
	if (nType == TYPE_TABLE) then
		return table_DeepCopy(Val, fCopy)
	end
	
	if (nType == TYPE_BOOL) then
		if (Val) then
			return true
		end
		
		return false
	end
	
	if (nType == TYPE_FUNCTION) then
		-- LuaJIT tail-call optimises this layer out while still creating a new function object
		return function(...)
			return Val(...)
		end
	end
	
	if (nType == TYPE_VECTOR) then
		return Vector(Val)
	end
	
	if (nType == TYPE_ANGLE) then
		return Angle(Val)
	end
	
	if (nType == TYPE_MATRIX) then
		return Matrix(Val)
	end
	
	return Val
end

local function CopyWithMeta(Val)
	return debug_setmetatable(Copy(Val, CopyWithMeta), debug_getmetatable(Val))
end

function gs.Copy(Val)
	return Copy(Val, Copy)
end

function gs.CopyWithMeta(Val)
	return CopyWithMeta(Val)
end

local iTypeOffset = TYPE_COUNT

function gs.RegisterCustomType(sName, fCheck, sEnumPostfix --[[= sName]])
	local iLength = gs.CheckStringLength(sName, 1, 1)
	gs.CheckType(fCheck, 2, TYPE_FUNCTION)
	
	if (gs.CheckTypes(sEnumPostfix, 3, tTypeNilString) == TYPE_NIL) then
		sEnumPostfix = sName
	else
		iLength = gs.CheckLength(sEnumPostfix, 3, 1)
	end
	
	-- FIXME: Go through all string.sub instances and specify length where applicable
	for i = 1, iLength do
		if (string_sub(sEnumPostfix, i, i) == " ") then
			sEnumPostfix = string_sub(sEnumPostfix, 1, i - 1) .. "_" .. string_sub(sEnumPostfix, i + 1, iLength)
		end
	end
	
	local sEnum = "TYPE_" .. string_upper(sEnumPostfix)
	local iCurValue = gs[sEnum]
	
	if (iCurValue == nil) then
		iCurValue = iTypeOffset + 1
		
		-- HACK: TYPE_COLOR > TYPE_COUNT, can collide
		if (iCurValue == TYPE_COLOR) then
			iCurValue = iCurValue + 1
		end
		
		iTypeOffset = iCurValue
		gs[sEnum] = iCurValue
	end
	
	tCustomTypes[iCurValue] = {fCheck, sName}
end

gs.RegisterCustomType("callable", function(Val, nType)
	if (nType == TYPE_FUNCTION) then
		return true
	end
	
	local tMeta = debug_getmetatable(Val)
	
	return tMeta ~= nil and TypeID(rawget(tMeta, "__call")) == TYPE_FUNCTION
end)

-- Not entirely accurate, but the closest way
gs.RegisterCustomType("Player", function(Val, nType)
	return nType == TYPE_ENTITY and Val:IsPlayer()
end)

gs.RegisterCustomType("Weapon", function(Val, nType)
	return nType == TYPE_ENTITY and Val:IsWeapon()
end)

gs.RegisterCustomType("NPC", function(Val, nType)
	return nType == TYPE_ENTITY and Val:IsNPC()
end)

gs.RegisterCustomType("Vehicle", function(Val, nType)
	return nType == TYPE_ENTITY and Val:IsVehicle()
end)

if (SERVER) then
	local NEXTBOT = FindMetaTable("NextBot")
	
	gs.RegisterCustomType("NextBot", function(Val, nType)
		return nType == TYPE_ENTITY and debug_getmetatable(Val) == NEXTBOT
	end)
else
	local CSENT = FindMetaTable("CSEnt")
	
	gs.RegisterCustomType("CSEnt", function(Val, nType)
		return nType == TYPE_ENTITY and debug_getmetatable(Val) == CSENT
	end)
end

function gs.ErrorNoHaltStack(sMessage, iLevel --[[= 1]])
	gs.CheckType(sMessage, 1, TYPE_STRING)
	
	if (gs.CheckTypes(iLevel, 2, tTypeNilNumber) == TYPE_NIL) then
		iLevel = 1
	end
	
	iLevel = iLevel + 1
	
	local tBaseInfo = debug_getinfo(iLevel, "S")
	
	if (tBaseInfo ~= nil) then
		local sSource = tBaseInfo.source
		
		if (sSource ~= "[C]") then
			sMessage = sSource .. ":" .. tBaseInfo.lastlinedefined .. ": "
		end
	end
	
	sMessage = "[ERROR] " .. sMessage .. "\n"
	
	::StackLoop::
	
	local tInfo = debug_getinfo(iLevel, "nS")
	
	if (tInfo == nil) then
		ErrorNoHalt(sMessage)
	else
		iLevel = iLevel + 1
		sMessage = string_rep(" ", iLevel + 1) .. iLevel .. ". " .. tInfo.name .. " - " .. tInfo.short_src .. ":" .. tInfo.lastlinedefined .. "\n"
		
		goto StackLoop
	end
end

local function SafeInclude(sPath, bNoError, iErrorLevel)
	-- https://github.com/Facepunch/garrysmod-issues/issues/1976
	-- https://github.com/Facepunch/garrysmod-issues/issues/3112
	-- FIXME: Replace with CompileFile?
	do return true, include(sPath) end
	
	local tArgs = {pcall(include, sPath)}
	
	if (tArgs[1]) then
		-- FIXME: nil arguments?
		return unpack(tArgs)
	end
	
	if (not bNoError) then
		gs.ErrorNoHaltStack("\"" .. sPath .. "\" failed to load: " .. tArgs[2], iErrorLevel + 1)
	end
	
	return false, tArgs[2]
end

function gs.SafeInclude(sPath, bNoError --[[= false]])
	gs.CheckType(sPath, 1, TYPE_STRING)
	
	if (gs.CheckTypes(bNoError, 2, tTypeNilBool) == TYPE_NIL) then
		bNoError = false
	end
	
	return SafeInclude(sPath, bNoError, 2)
end

function gs.SafeRequire(sName, bNoError --[[= false]])
	gs.CheckType(sName, 1, TYPE_STRING)
	
	if (gs.CheckTypes(bNoError, 2, tTypeNilBool) == TYPE_NIL) then
		bNoError = false
	end
	
	-- https://github.com/Facepunch/garrysmod-issues/issues/3244
	local bLoaded, sError = pcall(require, sName)
	
	if (bLoaded) then
		return nil
	end
	
	if (not bNoError) then
		gs.ErrorNoHaltStack("Module \"" .. sName .. "\" failed to load: " .. sError, 2)
	end
	
	return sError
end

local function SafeCompile(sPath, bNoError, iErrorLevel)
	local bSuccess, Ret = pcall(CompileFile, sPath)
	
	if (bSuccess) then
		return Ret
	end
	
	if (not bNoError) then
		gs.ErrorNoHaltStack("\"" .. sPath .. "\" failed to load: " .. Ret, iErrorLevel + 1)
	end
	
	return false, Ret
end

-- FIXME: Check auto-refresh
function gs.SafeCompile(sPath, bNoError --[[= false]])
	gs.CheckType(sPath, 1, TYPE_STRING)
	
	if (gs.CheckTypes(bNoError, 2, tTypeNilBool) == TYPE_NIL) then
		bNoError = false
	end
	
	return SafeCompile(sPath, bNoError, 2)
end

local sAddonPath = debug_getinfo(1, "S").source
local sInvalidPath = "invalid path! This should never happen: "

function gs.EnvironmentCompile(sPath, bNoError --[[= false]])
	gs.CheckType(sPath, 1, TYPE_STRING)
	
	if (gs.CheckTypes(bNoError, 2, tTypeNilBool) == TYPE_NIL) then
		bNoError = false
	end
	
	-- FIXME: Apply to SafeCompile? Apply at all?
	if (string_sub(sPath, -4) ~= ".lua") then
		gs.ErrorNoHaltStack("non-lua file \"" .. sPath .. "\" cannot be compiled!", 2)
		
		return nil
	end
	
	-- FIXME: This is dumb
	local iLevel = 2
	local sActualPath = debug_getinfo(iLevel, "S").source
	
	while (sActualPath == sAddonPath) do
		iLevel = iLevel + 1
		sActualPath = debug_getinfo(iLevel, "S").source
	end
	
	local func
	
	if (string_find(sPath, "/", 1, true)) then -- Path specified
		func = SafeCompile(sPath, bNoError, 2)
	else -- include("shared.lua")
		local iEndPos = #sActualPath
		
		-- FIXME: Need level, and condense this into a local function
		if (iEndPos < 5) then
			gs.ErrorNoHaltStack(sInvalidPath .. sPath, 2)
			
			return nil
		end
		
		-- Find the file path
		while (not (string_sub(sActualPath, iEndPos, iEndPos) == "/" or iEndPos == 5)) do
			iEndPos = iEndPos - 1
		end
		
		local iStart
		
		if (string_sub(sActualPath, 1, 5) == "@lua/") then
			iStart = 5
		else
			local _
			_, iStart = string_find(sActualPath, "/lua/", 3, true)
			
			if (iStart == nil) then
				gs.ErrorNoHaltStack(sInvalidPath .. sPath)
				
				return nil
			end
		end
		
		func = SafeCompile(string_sub(sActualPath, iStart + 1, iEndPos) .. sPath, bNoError, 2)
	end
	
	if (func == nil) then
		return nil
	end
	
	setfenv(func, getfenv(iLevel))
	
	return func
end

function gs.EnvironmentAddCSLuaFile(sPath --[[= debug_getinfo(2, "S").source]])
	if (gs.CheckTypes(sPath, 1, tTypeNilString) == TYPE_NIL) then
		sPath = debug_getinfo(2, "S").source
	end
	
	if (string_sub(sPath, -4) ~= ".lua") then
		gs.ErrorNoHaltStack("Non-lua file \"" .. sPath .. "\" cannot be sent to the client!", 2)
		
		return
	end
	
	local iLevel = 2
	local sActualPath = debug_getinfo(iLevel, "S").source
	
	while (sActualPath == sAddonPath) do
		iLevel = iLevel + 1
		sActualPath = debug_getinfo(iLevel, "S").source
	end
	
	local func
	
	if (string_find(sPath, "/", 1, true)) then -- Path specified
		AddCSLuaFile(sPath)
	else -- AddCSLuaFile("shared.lua")
		local iEndPos = #sActualPath
		
		if (iEndPos < 5) then
			gs.ErrorNoHaltStack(sInvalidPath .. sPath)
			
			return
		end
		
		-- Find the file path
		while (not (string_sub(sActualPath, iEndPos, iEndPos) == "/" or iEndPos == 5)) do
			iEndPos = iEndPos - 1
		end
		
		local iStart
		
		if (string_sub(sActualPath, 1, 5) == "@lua/") then
			iStart = 5
		else
			local _
			_, iStart = string_find(sActualPath, "/lua/", 3, true)
			
			if (iStart == nil) then
				gs.ErrorNoHaltStack(sInvalidPath .. sPath)
				
				return
			end
		end
		
		AddCSLuaFile(string_sub(sActualPath, iStart + 1, iEndPos) .. sPath)
	end
end

function gs.EnvironmentInclude(sPath, bNoError --[[= false]])
	gs.CheckType(sPath, 1, TYPE_STRING)
	
	if (gs.CheckTypes(bNoError, 2, tTypeNilBool) == TYPE_NIL) then
		bNoError = false
	end
	
	local func = gs.EnvironmentCompile(sPath, bNoError)
	
	if (func ~= nil) then
		return func()
	end
	
	return nil
end

function gs.IncludeDirectory(sFolder, bRecursive --[[= false]])
	gs.CheckType(sFolder, 1, TYPE_STRING)
	
	if (gs.CheckTypes(bRecursive, 2, tTypeNilBool) == TYPE_NIL) then
		bRecursive = false
	end
	
	local iLength = #sFolder
	
	if (string_sub(sFolder, iLength, iLength) ~= "/") then
		sFolder = sFolder .. "/"
	end
	
	local tFiles, tFolders = file_Find(sFolder .. "*", "LUA")
	local bRet = false
	
	for i = 1, #tFiles do
		local sFile = tFiles[i]
		
		if (string_sub(sFile, -4) == ".lua") then
			local sRealm = string_sub(sFile, 1, 3)
			
			if (SERVER and sRealm == "sv_") then
				bRet = SafeInclude(sFolder .. sFile, false, 2) or bRet
			elseif (sRealm == "cl_") then
				if (SERVER) then
					AddCSLuaFile(sFolder .. sFile)
				else
					bRet = SafeInclude(sFolder .. sFile, false, 2) or bRet
				end
			else
				local sFile = sFolder .. sFile
				
				if (SERVER) then
					AddCSLuaFile(sFile)
				end
				
				bRet = SafeInclude(sFile, false, 2) or bRet
			end
		end
	end
	
	if (bRecursive) then
		for i = 1, #tFolders do
			bRet = gs.IncludeDirectory(sFolder .. tFolders[i], true) or bRet
		end
	end
	
	return bRet
end

-- From C#'s Path.GetInvalidPathChars()
local tUnsafeChars = {
	'"', '<', '>', '|', '\0', '\a', '\b', '\t', '\n', '\v', '\f', '\r',
	--[['\u0001', '\u0002', '\u0003', '\u0004', '\u0005', '\u0006',
	'\u000e', '\u000f', '\u0010', '\u0011', '\u0012', '\u0013',
	'\u0014', '\u0015', '\u0016', '\u0017', '\u0018', '\u0019',
	'\u001a', '\u001b', '\u001c', '\u001d', '\u001e', '\u001f']]
}

-- Convert to hash table
for i = 1, #tUnsafeChars do
	tUnsafeChars[tUnsafeChars[i]] = true
	tUnsafeChars[i] = nil
end

if (system.IsWindows()) then
	tUnsafeChars[':'] = true
	tUnsafeChars['*'] = true
	tUnsafeChars['?'] = true
end

function gs.IsFileSafe(sFile, bPath --[[= false]])
	gs.CheckType(sFile, 1, TYPE_STRING)
	
	if (gs.CheckTypes(bPath, 2, tTypeNilBool) == TYPE_NIL) then
		bPath = false
	end
	
	local iLength = #sFile
	
	if (iLength == 0) then
		return false
	end
	
	for i = 1, iLength do
		local sChar = string_sub(sFile, i, i)
		
		if (tUnsafeChars[sChar] == true or not bPath and (sChar == "/" or sChar == "\\")) then
			return false
		end
	end
	
	return true
end

local tLoadedAddons = {}
local sFileSafe = "path is not file safe"

function gs.LoadAddon(sPath)
	gs.CheckType(sPath, 1, TYPE_STRING)
	
	if (not gs.IsFileSafe(sPath, true)) then
		gs.ArgError(1, sFileSafe)
	end
	
	sPath = string_lower(sPath)
	local sPathSlash = sPath
	
	local iLength = #sPath
	
	if (string_sub(sPath, iLength, iLength) == "/") then
		sPath = string_sub(sPath, 1, iLength - 1)
	else
		sPathSlash = sPathSlash .. "/"
	end
	
	if (hook.Run("GS_LoadAddon", sPath) == true) then
		return false
	end
	
	local sFile = sPath .. ".lua"
	local bLoaded = false
	
	-- Check the base folder for single addon files
	if (file.Exists(sFile, "LUA")) then
		if (SERVER) then
			AddCSLuaFile(sFile)
		end
		
		if (not SafeInclude(sFile, false, 2)) then
			return false
		end
		
		bLoaded = true
	end
	
	if (SERVER) then
		local sRealmFile = "sv_" .. sFile
		
		if (file.Exists(sRealmFile, "LUA")) then
			if (not SafeInclude(sRealmFile, false, 2)) then
				return false
			end
			
			bLoaded = true
		end
	end
	
	local sRealmFile = "cl_" .. sFile
	
	if (file.Exists(sRealmFile, "LUA")) then
		if (SERVER) then
			AddCSLuaFile(sRealmFile)
		elseif (not SafeInclude(sRealmFile, false, 2)) then
			return false
		else
			bLoaded = true
		end
	end
	
	bLoaded = gs.IncludeDirectory(sPathSlash) or bLoaded
	
	if (gs.LoadTranslation(sPathSlash .. "lang/") or bLoaded) then
		tLoadedAddons[sPath] = true
		hook.Run("GS_LoadedAddon", sPath)
		
		gs.DevMsg(0, "Addon \"" .. sPath .. "\" loaded!")
		
		return true
	end
	
	return false
end

function gs.AddonLoaded(sPath)
	gs.CheckType(sPath, 1, TYPE_STRING)
	
	--[[if (not gs.IsFileSafe(sPath, true)) then
		gs.ArgError(1, sFileSafe)
	end]]
	
	local iLength = #sPath
	
	if (string_sub(sPath, iLength, iLength) == "/") then
		sPath = string_sub(sPath, 1, iLength - 1)
	end
	
	return tLoadedAddons[sPath] == true
end

local tLang = {}

local function LoadLangTable(tbl, sPrefix)
	for Key, Val in pairs(tbl) do
		if (TypeID(Key) == TYPE_STRING and TypeID(Val) == TYPE_STRING) then
			tLang[sPrefix .. string_lower(Key)] = Val
		end
	end
end

local function LoadLang(sLang, sPath, sDefaultLang, tDefault, sPrefix, iErrorLevel)
	LoadLangTable(tDefault, sPrefix) -- Fill with default strings
	
	if (sLang ~= sDefaultLang and gs.IsFileSafe(sLang, false)) then
		local sLangPath = sPath .. sLang .. ".lua"
	
		if (file.Exists(sLangPath, "LUA")) then
			local fTranslation = SafeCompile(sLangPath, false, iErrorLevel + 1)
			
			if (fTranslation ~= nil) then
				local tTranslation = {}
				setfenv(fTranslation, tTranslation) 
				fTranslation()
				
				LoadLangTable(tTranslation, sPrefix) -- Fill with translated strings
			end
		end
	end
end

local gmod_language = GetConVar("gmod_language")

function gs.LoadTranslation(sPath, sPrefix --[[= ""]], sDefaultLang --[[= "en"]])
	gs.CheckType(sPath, 1, TYPE_STRING)
	
	if (not gs.IsFileSafe(sPath, true)) then
		gs.ArgError(1, sFileSafe)
	end
	
	if (gs.CheckTypes(sPrefix, 2, tTypeNilString) == TYPE_NIL) then
		sPrefix = ""
	else
		sPrefix = string_lower(sPrefix) .. "_"
	end
	
	if (gs.CheckTypes(sDefaultLang, 3, tTypeNilString) == TYPE_NIL) then
		sDefaultLang = "en"
	else
		if (not gs.IsFileSafe(sDefaultLang, false)) then
			gs.ArgError(3, sFileSafe)
		end
		
		sDefaultLang = string_lower(sDefaultLang)
	end
	
	local iLength = #sPath
	
	if (string_sub(sPath, iLength, iLength) ~= "/") then
		sPath = sPath .. "/"
	end
	
	local tFiles = file_Find(sPath .. "*.lua", "LUA")
	local iFileLen = #tFiles
	
	-- No languages
	if (iFileLen == 0) then
		gs.DevMsg(0, "Translation \"" .. sPath .. "\" failed to loaded!")
		
		return false
	end
	
	if (SERVER) then
		for i = 1, iFileLen do
			AddCSLuaFile(sPath .. tFiles[i])
		end
	end
	
	local tDefault = {}
	local fLanguage = SafeCompile(sPath .. sDefaultLang .. ".lua", false, 2)
	
	if (fLanguage ~= nil) then
		setfenv(fLanguage, tDefault)
		fLanguage()
	end
	
	LoadLang(string_lower(gmod_language:GetString()), sPath, sDefaultLang, tDefault, sPrefix, 2)
	
	cvars.AddChangeCallback("gmod_language", function(_, _, sNewLang)
		-- FIXME: Refresh default?
		LoadLang(string_lower(sNewLang), sPath, sDefaultLang, tDefault, sPrefix, 1)
	end, "GS_" .. sPath) -- Check if this is removed first
	
	gs.DevMsg(0, "Translation \"" .. sPath .. "\" loaded!")
	
	return true
end

function gs.GetPhrase(sKey)
	gs.CheckType(sKey, 1, TYPE_STRING)
	
	return tLang[string_lower(sKey)] or sKey
end

function gs.LoadDependency(sPath, sSource, sDependency)
	gs.CheckType(sPath, 1, TYPE_STRING)
	
	if (not gs.IsFileSafe(sPath, true)) then
		gs.ArgError(1, sFileSafe)
	end
	
	gs.CheckType(sSource, 2, TYPE_STRING)
	gs.CheckType(sDependency, 3, TYPE_STRING)
	
	sPath = string_lower(sPath)
	local sPathSlash = sPath
	
	local iLength = #sPath
	
	if (string_sub(sPath, iLength, iLength) == "/") then
		sPath = string_sub(sPath, 1, iLength - 1)
	else
		sPathSlash = sPathSlash .. "/"
	end
	
	if (not (gs.AddonLoaded(sPath) or gs.LoadAddon(sPath))) then
		-- https://github.com/Facepunch/garrysmod-issues/issues/2113
		error("[GS] %s failed to load! Missing dependency %s (%s)", sSource, sDependency, sPath)
	end
end

local function fLoadPrint(sName)
	gs.DevMsg(0, string_format((gs.AddonLoaded(sName) or gs.LoadAddon(sName)) and "Addon \"%s\" loaded" or "Addon \"%s\" failed to load", sName))
end

hook.Add("Initialize", "gs_load", function()	
	hook.Run("GS_PreLoad")
	
	-- FIXME: Rework current folder structure
	local tFiles, tFolders = file_Find("code_gs/*", "LUA")
	
	for i = 1, #tFiles do
		local sFile = tFiles[i]
		
		if (string_sub(sFile, -4) == ".lua") then
			fLoadPrint("code_gs/" .. string_sub(sFile, 1, -5))
		end
	end
	
	for i = 1, #tFolders do
		fLoadPrint("code_gs/" .. tFolders[i])
	end
	
	hook.Run("GS_PostLoad")
end)

function table.NiceList(tList, sWord, iStartPos --[[= 1]], iEndPos --[[= #tList]], fFormat --[[= nil]])
	gs.CheckType(tList, 1, TYPE_TABLE)
	gs.CheckType(sWord, 2, TYPE_STRING)
	
	if (gs.CheckTypesAndSet(iStartPos, 3, tTypeNilNumber, fSetInt) == TYPE_NIL) then
		iStartPos = 1
	end
	
	if (gs.CheckTypesAndSet(iEndPos, 4, tTypeNilNumber, fSetInt) == TYPE_NIL) then
		iEndPos = #tList
	end
	
	if (gs.CheckTypes(fFormat, 5, tTypeNilFunction) == TYPE_NIL) then
		return table_NiceList(tList, sWord, iStartPos, iEndPos, iEndPos - iStartPos)
	end
	
	return table_NiceList_Format(tList, sWord, iStartPos, iEndPos, iEndPos - iStartPos, fFormat)
end

function table.DeepCopy(tbl, bOutsideMeta --[[= true]], bInsideMeta --[[= true]])
	gs.CheckType(tbl, 1, TYPE_TABLE)
	
	if (gs.CheckType(bOutsideMeta, 2, tTypeNilBool) == TYPE_NIL) then
		bOutsideMeta = true
	end
	
	if (gs.CheckType(bInsideMeta, 3, tTypeNilBool) == TYPE_NIL) then
		bInsideMeta = true
	end
	
	local tRet = table_DeepCopy(tbl, bInsideMeta and CopyWithMeta or Copy)
	
	if (bOutsideMeta) then
		setmetatable(tRet, debug_getmetatable(tbl))
	end
	
	return tRet
end
