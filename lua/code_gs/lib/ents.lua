local rawget = rawget
local rawset = rawset
local CurTime = CurTime
local pairs = pairs
local setmetatable = setmetatable
local debug_setmetatable = debug_setmetatable

local ENTITY = FindMetaTable("Entity")
local tEntityTables = {}
-- FIXME: This needs to be implemented clientside!

local function EntityGetVar(pEntity, Key, Default --[[= nil]])
	local RetVal = rawget(tEntityTables[pEntity], Key)
	
	if (RetVal == nil) then
		return Default
	end
	
	return RetVal
end

local function EntitySetVar(pEntity, Key)
	rawset(tEntityTables[pEntity], Key)
end

-- FIXME
local function EntityGetTable(pEntity)
	return tEntityTables[pEntity]
end

function ents.SetupInheritance(pEntity, tMetaOverride --[[= nil]], tInitial --[[= setmetatable(pEntity:GetTable(), {__index = ENTITY})]])
	gs.CheckType(pEntity, 1, TYPE_ENTITY)
	gs.CheckValid(pEntity, 1)
	
	local bOverride = gs.CheckType(tMetaOverride, 2, {TYPE_TABLE, TYPE_NIL}) == TYPE_TABLE
	
	if (gs.CheckType(tInitial, 3, {TYPE_TABLE, TYPE_NIL}) == TYPE_NIL) then
		tInitial = setmetatable(pEntity:GetTable(), {__index = ENTITY})
	end
	
	tEntityTables[pEntity] = tInitial
	
	local tMeta = {
		__metatable = ENTITY,
		__index = tInitial,
		__newindex = tInitial,
		GetVar = EntityGetVar,
		SetVar = EntitySetVar,
		GetTable = EntityGetTable
	}
	
	if (bOverride) then
		for Key, Val in pairs(tMetaOverride) do
			tMeta[Key] = Val
		end
	end
	
	debug_setmetatable(pEntity, tMeta)
end
