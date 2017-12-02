-- FIXME: Check for IsError?
local MATERIAL = FindMetaTable("IMaterial")

function MATERIAL:AlphaModulate(flAlpha)
	self:SetFloat("$alpha", flAlpha / 255)
end

function MATERIAL:ColorModulate(col)
	self:SetVector("$color", col:ToVector())
end

function MATERIAL:GetAlphaModulation()
	return self:GetFloat("$alpha")
end

function MATERIAL:GetColorModulation()
	return self:GetVector("$color"):ToColor() -- FIXME: Test if valid first?
end

function MATERIAL:GetMappingWidth()
	return self:GetTexture("$basetexture"):GetMappingWidth()
end

function MATERIAL:GetMappingHeight()
	return self:GetTexture("$basetexture"):GetMappingHeight()
end

-- Credits to Z0mb1n3: https://facepunch.com/showthread.php?t=1542841&p=51421705&viewfull=1#post51421705
local iOffset = 4 + 8 + 4 + 2 + 2 + 4

function MATERIAL:GetNumAnimationFrames()
	-- FIXME: Check for error texture?
	local File = file.Open("materials/" .. self:GetTexture("$basetexture"):GetName() .. ".vtf", "rb", "GAME")
	
	if (File) then
		File:Seek(iOffset)
		local iRet = math.SignedToUnsigned(File:ReadShort(), 16)
		File:Close()
		
		return iRet
	end
	
	return 0
end
		
