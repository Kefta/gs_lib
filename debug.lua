-- Put in lua/autorun

local function TraceOverride(sFunc, tTraceKeys)
	sFunc = "Trace" .. sFunc
	local fOld = util[sFunc]
	local sError = "util." .. sFunc .. ": Foreign key \""
	
	util[sFunc] = function(tbl, ...)
		for sKey, Value in pairs(tbl) do
			if (tTraceKeys[k] == nil) then
				debug.Trace() -- FIXME
				print(sError .. sKey .. "\" with value \"" .. tostring(Value) .. "\"")
			end
		end
		
		fOld(tbl, ...)
	end
end

local tTraceKeys = {
	start = true,
	endpos = true,
	mask = true,
	filter = true,
	collisiongroup = true,
	ignoreworld = true,
	output = true
}

TraceOverride("Line", tTraceKeys)
TraceOverride("Entity", tTraceKeys)
TraceOverride("Hull", {
	start = true,
	endpos = true,
	mask = true,
	filter = true,
	collisiongroup = true,
	ignoreworld = true,
	output = true,
	mins = true,
	maxs = true
})

local MATERIAL = FindMetaTable("IMaterial")

local function MaterialOverride(sFunc)
	local sGet = "Get" .. sFunc
	sFunc = "Set" .. sFunc
	local fOld = MATERIAL[sFunc]
	local sError = "IMaterial." .. sFunc .. ": Failed to set key \""
	
	MATERIAL[sFunc] = function(self, sKey, Val, ...)
		fOld(self, sKey, Val, ...)
		local NewVal = MATERIAL[sGet](self, sKey)
		
		-- If the values aren't equal and aren't both nan
		if (not (Val == NewVal or isnan(Val) and isnan(NewVal))) then
			debug.Trace()
			print(sError .. sKey .. "\" to value \"" .. tostring(Val) .. "\", staying at \"" .. tostring(NewVal) .. "\"")
		end
	end
end

MaterialOverride("Int")
MaterialOverride("String")
MaterialOverride("Vector")
MaterialOverride("Float")
MaterialOverride("Matrix")

local fOld = MATERIAL.SetTexture
local sError = "IMaterial.SetTexture: Failed to set key \""

function MATERIAL:SetTexture(sKey, Val, ...)
	fOld(self, sKey, Val, ...)
	local tex = self:GetTexture(sKey)
	
	if (tex) then
		tex = tex:GetName()
		
		if (istexture(Val)) then
			Val = Val:GetName()
		end
		
		if (tex ~= Val) then
			debug.Trace()
			print(sError .. sKey .. "\" to value \"" .. Val .. "\", staying at \"" .. tex .. "\"")
		end
	elseif (tex ~= Val) then
		debug.Trace()
		print(sError .. sKey .. "\" to value \"" .. tostring(Val) .. "\", staying at \"" .. tostring(tex) .. "\"")
	end
end

local sError = "Entity.SetTexture: Failed to set key \""

FindMetaTable("Entity").SetSaveValue = function(self, sKey, Val, ...)
	local bSuccess = fOld(self, sKey, Val, ...)
	
	if (not bSuccess) then
		debug.Trace()
		local OrigVal = self:GetSaveValue(sKey)
		print(sError .. sKey .. "\" to value \"" .. tostring(Val) ..
			(OrigVal == nil and ", key doesn't exist on "
			or "\", staying at \"" .. tostring(OrigVal) .. "\" on ") .. tostring(self))
	end
end
