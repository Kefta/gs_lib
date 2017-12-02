do return end

--[[function util.PrecacheQuakeModel(sModel)
	local File = file.Open(sPath, "rb", "LUA")
	
	if (not File) then
		MsgN("couldn't precache " .. sPath .. "; doesn't exist!")
		
		return
	end
	
	local iSignature = File:ReadInt(32)
	
	-- IDPO
	if (iSignature ~= 0x4944504f) then
		MsgN
	
	local tSignature = tPrecacheFuncs[iSignature]
	
	if (tSignature == nil) then
		ErrorNoHalt("invalid model type, signature 0x" .. bit.tohex(iSignature))
	else
		local iVersion = tSignature[1](File)
		local fData = tSignature[2][iVersion]
		
		if (fData == nil) then
			ErrorNoHalt("invalid version " .. iVersion .. ", signature 0x" .. bit.tohex(iSignature))
		else
			tData[sPath] = fData(File)
		end
	end
	
	File:Close()
	else
		MsgN("couldn't precache " .. sPath .. "; doesn't exist!")
	end
end]]
