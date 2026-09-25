-- Fixes shared mine access false-failure and follower route spam.
-- Root cause: sharedAccess positions arrive over rednet as plain tables, so
-- vector/table identity comparisons report false even at identical coordinates.
-- Run on the MAIN controller.

if turtle then error("Run this on the main controller.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/eefc46141aafe68bab5369cb1252b3ad0a7b1ae9/ActuallyUsefulTurtles/patches/classMiner.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()

if not data:find("LABENHANCED_SHARED_ACCESS_POS_FIX",1,true) then
  error("Downloaded miner patch is missing the shared-access fix marker.",0)
end

fs.makeDir("turtle")
local f=assert(fs.open("turtle/classMiner.lua","w"))
f.write(data)
f.close()

print("Shared mine access fix installed.")
print("Reboot DTX-001 through DTX-004.")
print("Cancel/recreate the currently failed mining group before retrying.")
print("No map reset is required.")
