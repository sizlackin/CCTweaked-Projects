
local function biosWithoutRednet()
	-- run the shell without rednet
	
	os.unloadAPI("rednet") -- optional
	
	local ok, err = pcall(
		function()
			local sShell
			if term.isColour() and settings.get("bios.use_multishell") then
				sShell = "rom/programs/advanced/multishell.lua"
			else
				sShell = "rom/programs/shell.lua"
			end
			os.run({}, sShell)
			os.run({}, "rom/programs/shutdown.lua")
		end
	)
	-- [...]error handling shutdown etc. see bios.lua
	
	-- If the shell errored, let the user read it.
	term.redirect(term.native())
	if not ok then
		printError(err)
		pcall(function()
			term.setCursorBlink(false)
			print("Press any key to continue")
			os.pullEvent("key")
		end)
	end

	-- End
	os.shutdown()

end

if rednet then

	setfenv(biosWithoutRednet, _G)

	-- trigger pullEventRaw in rednet.run to fail
	-- ignore the error and go to os.reboot
	local originalError = _G.error
	local originalShutdown = _G.os.shutdown
	local originalPullEventRaw = _G.os.pullEventRaw

	_G.error = function() end
	_G.os.pullEventRaw = nil
	_G.os.shutdown = function()
		-- intercept shutdown and restore functions
		_G.error = originalError
		_G.os.pullEventRaw = originalPullEventRaw
		_G.os.shutdown = originalShutdown
		-- start the shell again, without rednet
		return biosWithoutRednet()
	end
end