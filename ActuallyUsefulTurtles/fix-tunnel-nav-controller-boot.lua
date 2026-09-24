-- Repairs a controller which booted into global.storage == nil after
-- installing shared tunnel navigation. Run from a normal shell on MAIN host.

if turtle then error("Run this on the main controller.",0) end

local files = {
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
	local r,e=http.get(url)
	if not r then error("Download failed: "..tostring(e),0) end
	local code=r.getResponseCode()
	if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
	local data=r.readAll(); r.close()
	return data
end

for _,entry in ipairs(files) do
	local data=fetch(entry.url)
	if not data:find(entry.marker,1,true) then
		error("Repair file missing marker: "..entry.marker,0)
	end
	for _,target in ipairs(entry.targets) do
		fs.makeDir(fs.getDir(target))
		local f=assert(fs.open(target,"w"))
		f.write(data); f.close()
		print("Repaired "..target)
	end
end

print("Controller boot repair installed.")
print("Rebooting...")
sleep(1)
os.reboot()
