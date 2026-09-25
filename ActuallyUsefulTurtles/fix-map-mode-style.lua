-- Match select/cursor controls to MAP OPTIONS toggle styling.
if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("gui") then error("Run this on the main controller.",0) end
local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/f6381a025690ff5c92105c15c8a804123724b735/ActuallyUsefulTurtles/patches/classTaskGroupSelector.lua"
local r,e=http.get(url); if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode(); if code~=200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()
if not data:find("Match MAP OPTIONS",1,true) then error("Patch marker missing.",0) end
for _,target in ipairs({"gui/classTaskGroupSelector.lua","runtime/classTaskGroupSelector.lua"}) do local f=assert(fs.open(target,"w")); f.write(data); f.close(); print("Patched "..target) end
print("select/cursor now match MAP OPTIONS toggle style.")
print("Reboot the controller once.")
