if (code_gs) then return end -- No auto-refresh here

local tLang, tLoadedAddons = {}, {}
code_gs = {}

local developer = GetConVar("developer")

function code_gs.DevMsg(iLevel, ...)
	if (developer:GetInt() >= iLevel) then
		print(...)
	end
end

local sIncludeError = "[GS] %s failed to load: %s\n"
local sRequireError = "[GS] Module %q failed to load: %s\n"
local sLoadedAddon = "[GS] Loaded %q addon"
local sLoadedModule = "[GS] Loaded %q module"

function code_gs.SafeInclude(sPath, bNoError --[[= false]])
	local tArgs = {pcall(include, sPath)}
	
	if (tArgs[1]) then
		table.remove(tArgs, 1)
		
		return tArgs
	end
	
	if (not bNoError) then
		ErrorNoHalt(string.format(sIncludeError, sPath, tArgs[2]))
	end
	
	tArgs[1] = nil
	tArgs[2] = nil
	
	return tArgs -- Empty table
end

function code_gs.SafeRequire(sName, bNoError --[[= false]])
	local bLoaded, sErr = pcall(require, sName)
	
	if (bStatus) then
		return true
	end
	
	if (not bNoError) then
		ErrorNoHalt(string.format(sRequireError, sName, sErr))
	end
	
	return false
end

function code_gs.IncludeDirectory(sFolder, bRecursive)
	if (sFolder[#sFolder] ~= '/') then
		sFolder = sFolder .. '/'
	end
	
	local tFiles, tFolders = file.Find(sFolder .. "*", "LUA")
	
	for i = 1, #tFiles do
		if (tFiles[i]:sub(-4):lower() == ".lua") then
			code_gs.SafeInclude(sFolder .. tFiles[i])
		end
	end
	
	if (bRecursive) then
		for i = 1, #tFolders do
			code_gs.IncludeDirectory(sFolder .. tFolders[i], bRecursive)
		end
	end
end

if (SERVER) then
	function code_gs.AddCSDirectory(sFolder, bRecursive)
		if (sFolder[#sFolder] ~= '/') then
			sFolder = sFolder .. '/'
		end
		
		local tFiles, tFolders = file.Find(sFolder .. "*", "LUA")
		
		for i = 1, #tFiles do
			if (tFiles[i]:sub(-4):lower() == ".lua") then
				AddCSLuaFile(sFolder .. tFiles[i])
			end
		end
		
		if (bRecursive) then
			for i = 1, #tFolders do
				code_gs.AddCSDirectory(sFolder .. tFolders[i], bRecursive)
			end
		end
	end
end

local gmod_language = GetConVar("gmod_language")

function code_gs.LoadAddon(sName, bLoadLanguage)
	sName = sName:lower()
	
	-- Do not load this file again!
	if (sName == "gs") then
		return {}
	end
	
	local flTime = UnPredictedCurTime()
	
	-- Don't load the file more than once in autorun
	if (tLoadedAddons[sName] == flTime) then
		return {}
	end
	
	local sPath = "code_gs/" .. sName .. ".lua"
	local tRet = false
	
	-- Check the base folder for single addon files
	if (file.Exists(sPath, "LUA")) then
		-- Return includes from this file
		tRet = code_gs.SafeInclude(sPath)
		tLoadedAddons[sName] = flTime
		code_gs.DevMsg(1, string.format(sLoadedAddon, sName))
		
		if (SERVER) then
			AddCSLuaFile(sPath)
		end
	end
	
	sPath = "code_gs/" .. sName .. "/"
	local tFiles = file.Find(sPath .. "*.lua", "LUA")
	local iFileLen = #tFiles
	
	-- There was only the base file
	if (iFileLen ~= 0) then
		for i = 1, iFileLen do
			local sFile = sPath .. tFiles[i]:lower()
			code_gs.SafeInclude(sFile)
			
			if (SERVER) then
				AddCSLuaFile(sFile)
			end
		end
		
		tLoadedAddons[sName] = flTime
		
		if (not tRet) then
			tRet = {}
			code_gs.DevMsg(1, string.format(sLoadedAddon, sName))
		end
	end
	
	if (not bLoadLanguage) then
		return tRet
	end
	
	local sLangFormat = "code_gs/lang/" .. sName .. "_%s.lua"
	tFiles = file.Find(string.format(sLangFormat, '*'), "LUA")
	iFileLen = #tFiles
	
	-- Don't load just language files
	if (iFileLen == 0) then
		return tRet
	end
	
	if (SERVER) then
		for i = 1, iFileLen do
			AddCSLuaFile("code_gs/lang/" .. tFiles[i])
		end
	end
	
	local sDefaultPath = string.format(sLangFormat, "en")
	local sLangPath = string.format(sLangFormat, gmod_language:GetString():lower())
	
	-- English not found; select a new default
	if (not file.Exists(sDefaultPath, "LUA")) then
		sDefaultPath = string.format(sLangFormat, tFiles[1])
	end
	
	if (file.Exists(sLangPath, "LUA")) then
		local tTranslation = code_gs.SafeInclude(sLangPath)
		
		for key, str in pairs(code_gs.SafeInclude(sDefaultPath)) do
			tLang[sName .. key] = tTranslation[key] or str
		end
	else
		for key, str in pairs(code_gs.SafeInclude(sDefaultPath)) do
			tLang[sName .. key] = str
		end
	end
	
	cvars.AddChangeCallback("gmod_language", function(_, _, sNewLang)
		sNewLang = sPath .. sNewLang:lower() .. ".lua"
		
		if (file.Exists(sNewLang, "LUA")) then
			local tTranslation = code_gs.SafeInclude(sNewLang)
			
			-- Fill in any non-translated phrases with default ones
			for key, str in pairs(code_gs.SafeInclude(sDefaultPath)) do
				key = key:lower()
				tLang[sName .. key] = tTranslation[key] or str
			end
		else
			for key, str in pairs(code_gs.SafeInclude(sDefaultPath)) do
				tLang[sName .. key:lower()] = str
			end
		end
	end, "GS-" .. sName[1]:upper() .. string.sub(2, #sName))
	
	return tRet or {}
end

function code_gs.AddonLoaded(sName)
	return tLoadedAddons[sName:lower()] ~= nil
end

function code_gs.GetPhrase(sKey)
	return tLang[sKey] or ""
end
