-- Installs the controller-authoritative shared tunnel navigation system.
-- Run on the MAIN Actually Useful Turtles controller.

if turtle then error("Run this on the main controller, not a turtle.",0) end

local files = {
	{
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/20ad969bff6afc614564f64beaa8ec72100af600/ActuallyUsefulTurtles/tunnelnav/classTunnelMap.lua",
		marker="Controller is authoritative",
		targets={"general/classTunnelMap.lua","runtime/classTunnelMap.lua"},
	},
	{
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/77fefe46e8fa5084f90d4c2ee52e54dc6e4cdd47/ActuallyUsefulTurtles/tunnelnav/classTunnelNavigator.lua",
		marker="LABENHANCED_TORCH_BYPASS",
		targets={"turtle/classTunnelNavigator.lua"},
	},
	{
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/ac30e839f5f13c30262780f61a8495d2c5cf769d/ActuallyUsefulTurtles/tunnelnav/classTunnelMapper.lua",
		marker="LABENHANCED_TORCH_BYPASS",
		targets={"turtle/classTunnelMapper.lua"},
	},
	{
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/fb6719dfa8b31ae44a3b780e59088d4948339cb4/ActuallyUsefulTurtles/patches/classMiner.lua",
		marker="LABENHANCED_TUNNEL_NAV",
		targets={"turtle/classMiner.lua"},
	},
	{
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/e3a26a5d8ba32c3934eb1cb5e2c43758462c7a05/ActuallyUsefulTurtles/patches/turtle-send.lua",
		marker="LABENHANCED_TUNNEL_NAV",
		targets={"turtle/send.lua"},
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
		url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/4f745b8ec079958229b79e6fd790d0854344330d/ActuallyUsefulTurtles/patches/host-main.lua",
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
