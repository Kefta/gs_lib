include("code_gs/gs.lua")

if (not code_gs.LoadAddon("code_gs/lib", "gslib")) then
	error("[GS] GSLib failed to load!")
end
