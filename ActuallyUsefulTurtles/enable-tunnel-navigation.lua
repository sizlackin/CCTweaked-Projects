-- Installs the controller-authoritative shared tunnel navigation system.
-- Run on the MAIN Actually Useful Turtles controller.

if turtle then error("Run this on the main controller, not a turtle.",0) end

local files = {
	{
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/b06454712209f1284dd7040602dd0b1b3280260e/ActuallyUsefulTurtles/tunnelnav/classTunnelMap.lua",
		marker="LABENHANCED_TORCH_REROUTE",
		targets={"general/classTunnelMap.lua","runtime/classTunnelMap.lua"},
	},
	{
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/da657c4ce1cc6efd94baa725972b7e095e04ace4/ActuallyUsefulTurtles/tunnelnav/classTunnelNavigator.lua",
		marker="LABENHANCED_MULTI_MAPPER_CLAIMS",
		targets={"turtle/classTunnelNavigator.lua"},
	},
	{
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/4e19fb91120b1dc27b89066148a0933bf67900fe/ActuallyUsefulTurtles/tunnelnav/classTunnelMapper.lua",
		marker="LABENHANCED_TORCH_REROUTE",
		targets={"turtle/classTunnelMapper.lua"},
	},
	{
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/f240140e06b3bd541bb53181c4e3266243f2a90c/ActuallyUsefulTurtles/patches/classMiner.lua",
		marker="LABENHANCED_TORCH_REROUTE",
		targets={"turtle/classMiner.lua"},
	},
	{
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/e3a26a5d8ba32c3934eb1cb5e2c43758462c7a05/ActuallyUsefulTurtles/patches/turtle-send.lua",
		marker="LABENHANCED_TUNNEL_NAV",
		targets={"turtle/send.lua"},
	},
	{
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/a002774f9464b8a972500ef29282be560d9702f9/ActuallyUsefulTurtles/patches/turtle-receive.lua",
		marker="LABENHANCED_STOP_LATCH_FIX",
		targets={"turtle/receive.lua"},
	},
	{
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/01e579503fcf8de0ec32b58643ad869a4ef4c42a/ActuallyUsefulTurtles/patches/host-global.lua",
		marker="LABENHANCED_TUNNEL_NAV",
		targets={"host/global.lua","runtime/global.lua"},
	},
	{
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/5d009612a02e18abc7f36086be57673367d07129/ActuallyUsefulTurtles/patches/host-initialize.lua",
		marker="LABENHANCED_TUNNEL_NAV_BOOTSAFE",
		targets={"host/initialize.lua","runtime/initialize.lua"},
	},
	{
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/429cd4296a00b5e804328344985984ed1526c516/ActuallyUsefulTurtles/patches/host-main.lua",
		marker="LABENHANCED_TUNNEL_NAV_BOOTSAFE",
		targets={"host/main.lua","runtime/main.lua"},
	},
	{
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/c6e0e9b372c849334e7b2bef8c7d9e5d145c8782/ActuallyUsefulTurtles/patches/host-receive.lua",
		marker="LABENHANCED_TUNNEL_NAV_BOOTSAFE",
		targets={"host/receive.lua","runtime/receive.lua"},
	},
	{
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/host-startup.lua",
		marker="LABENHANCED_TUNNEL_NAV_BOOTSAFE",
		targets={"host/startup.lua","runtime/startup.lua","startup.lua"},
	},
}

local function fetch(url)
	local r,e = http.get(url)
	if not r then error("Download failed: "..tostring(e),0) end
	local code = r.getResponseCode()
	if code ~= 200 then r.close(); error("Download failed: HTTP "..tostring(code),0) end
	local data = r.readAll()
	r.close()
	return data
end

for _,entry in ipairs(files) do
	local data = fetch(entry.url)
	if not data:find(entry.marker,1,true) then
		error("Downloaded patch missing marker: "..entry.marker,0)
	end
	for _,target in ipairs(entry.targets) do
		fs.makeDir(fs.getDir(target))
		local f = assert(fs.open(target,"w"))
		f.write(data)
		f.close()
		print("Patched "..target)
	end
end

print("Shared tunnel navigation installed.")
print("Controller boot guards + torch bypass included.")
print("Reboot controller, then reboot every turtle.")
print("Run start-tunnel-remap-large to build/continue the road graph.")
