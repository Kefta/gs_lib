if (code_gs) then return end -- No auto-refresh here

AddCSLuaFile()

local tLang, tLoadedAddons = {}, { ["code_gs/load"] = true }
code_gs = {}

local developer = CreateConVar("gs_developer", "0", FCVAR_ARCHIVE, "Enables developer messaged for GS addons")

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
	
	return false
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

function code_gs.SafeCompile(sPath, bNoError --[[= false]])
	local bSuccess, Ret = pcall(CompileFile, sPath)
	
	if (bSuccess) then
		return Ret
	end
	
	if (not bNoError) then
		ErrorNoHalt(string.format(sIncludeError, sPath, Ret))
	end
	
	return false
end

local sAddonPath = debug.getinfo(1, "S").source

function code_gs.EnvironmentCompile(sPath, bNoError)
	if (sPath:sub(-4) == ".lua") then
		local func
		local iLevel = 2
		local sActualPath = debug.getinfo(iLevel, "S").source
		
		while (sActualPath == sAddonPath) do
			iLevel = iLevel + 1
			sActualPath = debug.getinfo(iLevel, "S").source
		end
		
		if (sPath:find('/', 1, true)) then -- Path specified
			func = code_gs.SafeCompile(sPath, bNoError)
		else -- include("shared.lua")
			local iEndPos = #sActualPath
			
			while (not (sActualPath[iEndPos] == '/' or iEndPos == 5)) do-- Find the file path
				iEndPos = iEndPos - 1
			end
			
			local iStart
			
			if (sActualPath:sub(1, 5) == "@lua/") then
				iStart = 5
			else
				local _
				_, iStart = sActualPath:find("/lua/", 3, true)
			end
			
			func = code_gs.SafeCompile(sActualPath:sub(iStart + 1, iEndPos) .. sPath, bNoError)
		end
		
		setfenv(func, getfenv(iLevel))
		
		return func
	end
	
	error("Non-lua file \"" .. sPath .. "\" cannot be compiled!")
end

function code_gs.EnvironmentInclude(sPath, bNoError)
	local func = code_gs.EnvironmentCompile(sPath, bNoError)
	
	if (func) then
		return func()
	end
end

function code_gs.EnvironmentAddCSLuaFile(sPath)
	if (sPath:sub(-4) == ".lua") then
		if (sPath:find('/', 1, true)) then -- Path specified
			AddCSLuaFile(sPath)
		else -- AddCSLuaFile("shared.lua")
			local iLevel = 2
			local sActualPath = debug.getinfo(iLevel, "S").source
			
			while (sActualPath == sAddonPath) do
				iLevel = iLevel + 1
				sActualPath = debug.getinfo(iLevel, "S").source
			end
			
			local iEndPos = #sActualPath
			assert(iEndPos > 5) -- Should never happen
			
			while (not (sActualPath[iEndPos] == '/' or iEndPos == 5)) do-- Find the file path
				iEndPos = iEndPos - 1
			end
			
			local _, iStart
			
			if (sActualPath:sub(1, 5) == "@lua/") then
				iStart = 5
			else
				_, iStart = sActualPath:find("/lua/", 3, true)
			end
			
			AddCSLuaFile(sActualPath:sub(iStart + 1, iEndPos) .. sPath)
		end
	else
		error("Non-lua file \"" .. sPath .. "\" cannot be AddCSLuaFile'd!")
	end
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

function code_gs.LoadAddon(sPath, sName, bLoadLang)
	if (sPath[#sPath] == '/') then
		sPath = sPath:sub(1, #sPath - 1)
	end
	
	if (sPath:lower() == "code_gs/load") then
		return
	end
	
	local tRet = false
	
	-- Check the base folder for single addon files
	if (file.Exists(sPath .. ".lua", "LUA")) then
		-- Return includes from this file
		tRet = code_gs.SafeInclude(sPath .. ".lua")
		
		if (SERVER) then
			AddCSLuaFile(sPath .. ".lua")
		end
	end
	
	local tFiles = file.Find(sPath .. "/*.lua", "LUA")
	
	for i = 1, #tFiles do
		local sFile = sPath .. "/" .. tFiles[i]:lower()
		tRet = code_gs.SafeInclude(sFile) ~= false or tRet
		
		if (SERVER) then
			AddCSLuaFile(sFile)
		end
	end
	
	if (bLoadLang) then
		tRet = code_gs.LoadTranslation(sPath .. "/lang/", sName) or tRet
	end
	
	tLoadedAddons[sName or sPath:lower()] = tRet ~= false
	
	return tRet
end

function code_gs.LoadTranslation(sPath, sPrefix, sDefaultLang --[[= "en"]])
	if (sPath[#sPath] ~= '/') then
		sPath = sPath .. '/'
	end
	
	local tFiles = file.Find(sPath .. "*.lua", "LUA")
	local iFileLen = #tFiles
	
	-- No languages
	if (iFileLen == 0) then
		return false
	end
	
	if (SERVER) then
		for i = 1, iFileLen do
			AddCSLuaFile(sPath .. tFiles[i])
		end
	end
	
	local sDefaultPath
	
	if (sDefaultLang) then
		if (file.Exists(sPath .. sDefaultLang, "LUA")) then
			sDefaultPath = sPath .. sDefaultLang
		else
			sDefaultPath = sPath .. "en.lua"
		end
	else
		sDefaultPath = sPath .. "en.lua"
	end
	
	local sLangPath = sPath .. gmod_language:GetString():sub(-2):lower() .. ".lua"
	local fLanguage
	
	for i = 1, iFileLen do
		-- English not found; select a new default
		if (not file.Exists(sDefaultPath, "LUA")) then
			sDefaultPath = sPath .. tFiles[i]
		end
		
		fLanguage = code_gs.SafeCompile(sDefaultPath)
		
		if (fLanguage) then
			break
		end
		
		if (i == iFileLen) then
			return false
		end
	end
	
	local tDefault = {}
	setfenv(fLanguage, tDefault)
	fLanguage()
	
	sPrefix = sPrefix and sPrefix .. "_" or ""
	
	if (file.Exists(sLangPath, "LUA")) then
		local fTranslation = code_gs.SafeCompile(sLangPath)
		
		if (not fTranslation) then
			for key, str in pairs(tDefault) do
				tLang[sPrefix .. key:lower()] = str
			end
			
			return true
		end
		
		local tTranslation = {}
		setfenv(fTranslation, tTranslation) 
		fTranslation()
		
		for key, str in pairs(tDefault) do
			key = key:lower()
			tLang[sPrefix .. key] = tTranslation[key] or str
		end
	else
		for key, str in pairs(tDefault) do
			tLang[sPrefix .. key:lower()] = str
		end
	end
	
	cvars.AddChangeCallback("gmod_language", function(_, _, sNewLang)
		sNewLang = sPath .. sNewLang:lower() .. ".lua"
		
		if (file.Exists(sNewLang, "LUA")) then
			local fTranslation = code_gs.SafeCompile(sNewLang)
			
			if (not fTranslation) then
				for key, str in pairs(tDefault) do
					tLang[sPrefix .. key:lower()] = str
				end
				
				return
			end
			
			local tTranslation = {}
			setfenv(fTranslation, tTranslation) 
			fTranslation()
			
			-- Fill in any non-translated phrases with default ones
			for key, str in pairs(tDefault) do
				key = key:lower()
				tLang[sName .. key] = tTranslation[key] or str
			end
		else
			for key, str in pairs(tDefault) do
				tLang[sName .. key:lower()] = str
			end
		end
	end, "GS-" .. sPath)
	
	return true
end

function code_gs.AddonLoaded(sName)
	return tLoadedAddons[sName:lower()] == true
end

function code_gs.GetPhrase(sKey)
	return tLang[sKey] or sKey
end
