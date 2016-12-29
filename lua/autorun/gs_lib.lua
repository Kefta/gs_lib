include("code_gs/gs.lua")
AddCSLuaFile("code_gs/gs.lua")

if (not code_gs.LoadAddon("lib", false)) then
	error("[GS] Lib failed to load!")
end
