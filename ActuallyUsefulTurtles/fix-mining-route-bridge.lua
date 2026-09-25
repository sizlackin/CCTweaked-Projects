-- Fixes mining-area access when the logical TunnelMap does not yet contain
-- all physically-known tunnel roads, and treats other turtles as temporary traffic.
-- Run on the MAIN controller.

if turtle then error("Run this on the main controller.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/eefc46141aafe68bab5369cb1252b3ad0a7b1ae9/ActuallyUsefulTurtles/patches/classMiner.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()

if not data:find("LABENHANCED_MINING_ROUTE_BRIDGE",1,true) then
  error("Downloaded miner patch is missing the route-bridge marker.",0)
end

fs.makeDir("turtle")
local f=assert(fs.open("turtle/classMiner.lua","w"))
f.write(data)
f.close()

print("Mining route bridge installed.")
print("Reboot DTX-001 through DTX-004.")
print("No map reset is required.")
