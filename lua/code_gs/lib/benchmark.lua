local SysTime = SysTime
local next = next
local jit_status = jit.status
local jit_off = jit.off
local jit_on = jit.on

function gs.Benchmark(tFuncs, iIterations, bNoJIT --[[= false]])
	local bEnable = bNoJIT == true and jit_status()
	
	if (bEnable) then
		jit_off()
	end
	
	-- Move scope as far up as possible
	local tRet = {}
	local SysTime = SysTime
	
	for Name, func in next, tFuncs do
		local iIterations = iIterations
		local flStart = SysTime()
		
		for i = 1, iIterations do
			func()
		end
		
		tRet[Name] = SysTime() - flStart
	end
	
	if (bEnable) then
		jit_on()
	end
	
	return tRet
end
