-- Installs the controller-authoritative shared tunnel navigation system.
-- Run on the MAIN Actually Useful Turtles controller.

if turtle then error("Run this on the main controller, not a turtle.",0) end

local files = {{url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/20ad969bff6afc614564f64beaa8ec72100af600/ActuallyUsefulTurtles/tunnelnav/classTunnelMap.lua",marker="Controller is authoritative",targets={"general/classTunnelMap.lua","runtime/classTunnelMap.lua"}},{url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/20e196aa0f5f20708ba7dbed2863e1743d7ce5e0/ActuallyUsefulTurtles/tunnelnav/classTunnelNavigator.lua",marker="strict road-network navigator",targets={"turtle/classTunnelNavigator.lua"}},{url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/926719a596ca767a2db560859f28761d3ab4575a/ActuallyUsefulTurtles/tunnelnav/classTunnelMapper.lua",marker="non-destructive tunnel surveyor",targets={"turtle/classTunnelMapper.lua"}},{url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/fb6719dfa8b31ae44a3b780e59088d4948339cb4/ActuallyUsefulTurtles/patches/classMiner.lua",marker="LABENHANCED_TUNNEL_NAV",targets={"turtle/classMiner.lua"}},{url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/01e579503fcf8de0ec32b58643ad869a4ef4c42a/ActuallyUsefulTurtles/patches/host-global.lua",marker="LABENHANCED_TUNNEL_NAV",targets={"host/global.lua","runtime/global.lua"}},{url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/06cc038edf6098c695a58c715b11b09f6e00567c/ActuallyUsefulTurtles/patches/host-initialize.lua",marker="LABENHANCED_TUNNEL_NAV",targets={"host/initialize.lua","runtime/initialize.lua"}},{url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/0697e9bd343f2931676352de75d2c91401e717cf/ActuallyUsefulTurtles/patches/host-main.lua",marker="TUNNEL_ROUTE_REQUEST",targets={"host/main.lua","runtime/main.lua"}}}

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
print("Reboot controller, then reboot every turtle.")
print("Run the large mapper once to build the initial road graph.")
