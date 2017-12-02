-- Unique meta-tables for each
setmetatable(FindMetaTable("Weapon"), {__index = FindMetaTable("Entity")})
setmetatable(FindMetaTable("NPC"), {__index = FindMetaTable("Entity")})
setmetatable(FindMetaTable("Vehicle"), {__index = FindMetaTable("Entity")})

function isnan(Val)
	return isnumber(Val) and Val ~= Val
end

do
	local CONVAR = FindMetaTable("ConVar")

	function isconvar(Val)
		return getmetatable(Val) == CONVAR
	end
end

do
	local MATERIAL = FindMetaTable("IMaterial")

	function ismaterial(Val)
		return getmetatable(Val) == MATERIAL
	end
end

do
	local TEXTURE = FindMetaTable("ITexture")

	function istexture(Val)
		return getmetatable(Val) == TEXTURE
	end
end

function istablenometa(Val)
	return istable(Val) and getmetatable(Val) == nil
end
