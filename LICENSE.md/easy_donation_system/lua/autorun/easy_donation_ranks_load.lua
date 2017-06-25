if SERVER then
	AddCSLuaFile("easy_donator_ranks/config.lua")
	AddCSLuaFile("easy_donator_ranks/cl_eds.lua")
	include("easy_donator_ranks/config.lua")
	include("easy_donator_ranks/sv_eds.lua")
else
	include("easy_donator_ranks/config.lua")
	include("easy_donator_ranks/cl_eds.lua")
end