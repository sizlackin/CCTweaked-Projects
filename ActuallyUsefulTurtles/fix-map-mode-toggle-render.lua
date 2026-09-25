-- Fix select/cursor mode toggles to exactly match MAP OPTIONS lamp geometry.
if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("gui") then error("Run this on the main controller.",0) end
local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/76991cbc93a9e74b53b6f2e5cf79ebca3752d7f3/ActuallyUsefulTurtles/patches/classTaskGroupSelector.lua"
local r,e=http.get(url); if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode(); if code~=200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()
if not data:find("exact same 2-character SCADA lamp",1,true) then error("Patch marker missing.",0) end
for _,target in ipairs({"gui/classTaskGroupSelector.lua","runtime/classTaskGroupSelector.lua"}) do
 local f=assert(fs.open(target,"w")); f.write(data); f.close(); print("Patched "..target)
end
print("select/cursor toggle rendering corrected.")
print("Reboot the controller once.")
