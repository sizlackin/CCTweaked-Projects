-- Compact map interaction controls to SELECT / CURSOR.
-- Run on the MAIN CONTROLLER.
if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("gui") then error("Run this on the main controller.",0) end
local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/ed2ed4cde5c74c0329fb636f0a3e17af84c41119/ActuallyUsefulTurtles/patches/classTaskGroupSelector.lua"
local r,e=http.get(url); if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode(); if code~=200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()
if not data:find('"SELECT"',1,true) or not data:find('"CURSOR"',1,true) then error("Patch marker missing.",0) end
for _,target in ipairs({"gui/classTaskGroupSelector.lua","runtime/classTaskGroupSelector.lua"}) do
 local f=assert(fs.open(target,"w")); f.write(data); f.close(); print("Patched "..target)
end
print("Map modes compacted to SELECT / CURSOR.")
print("Reboot the controller once.")
