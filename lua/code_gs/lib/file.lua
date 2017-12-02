local FILE = FindMetaTable("File")

function FILE:ReadInt(iBits)
	local iCurPower = 2 ^ iBits
	local iReturn = 0
	
	for i = 1, iBits do
		iCurPower = iCurPower / 2
		local bBit = self:ReadBool()
		
		if (bBit) then
			iReturn = iReturn + iCurPower
		end
	end
	
	return iReturn
end

function FILE:ReadChar()
	return string.char(self:ReadByte())
end

function FILE:ReadString(iLen)
	local tChars = {}
	
	for i = 1, iLen do
		tChars[i] = self:ReadByte()
	end
	
	return string.char(unpack(tChars))
end
