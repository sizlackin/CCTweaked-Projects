-- Fix Select/Cursor custom toggle rendering.
if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("gui") then error("Run this on the main controller.",0) end
local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/d5f03f0191f9994e1139c1244f31619b8c13e7eb/ActuallyUsefulTurtles/patches/classTaskGroupSelector.lua"
local r,e=http.get(url); if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode(); if code~=200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()
if not data:find("guaranteed padding",1,true) then error("Patch marker missing.",0) end
for _,target in ipairs({"gui/classTaskGroupSelector.lua","runtime/classTaskGroupSelector.lua"}) do local f=assert(fs.open(target,"w")); f.write(data); f.close(); print("Patched "..target) end
print("Select/Cursor rendering fixed.")
print("Reboot the controller once.")
