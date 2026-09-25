-- Prevents 1x2 access/mining tunnels from drifting upward when the
-- temporary upper-cell scan cannot return to the lower tunnel cell.
-- Run on MAIN controller.

if turtle then error("Run this on the main controller.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/eefc46141aafe68bab5369cb1252b3ad0a7b1ae9/ActuallyUsefulTurtles/patches/classMiner.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()

if not data:find("LABENHANCED_TUNNEL_FLOOR_LOCK",1,true) then
  error("Downloaded miner patch is missing the tunnel floor-lock marker.",0)
end

fs.makeDir("turtle")
local f=assert(fs.open("turtle/classMiner.lua","w"))
f.write(data)
f.close()

print("Tunnel floor-lock fix installed.")
print("Reboot DTX-001 through DTX-004.")
print("Cancel/delete the currently failed mining group and create a fresh one.")
print("No map reset is required.")
