-- Center select/cursor controls vertically beside the 3-row yellow level button.
if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("gui") then error("Run this on the main controller.",0) end
local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/42b4424535afd05aadb5e2e510cb6e0106553cf7/ActuallyUsefulTurtles/patches/classTaskGroupSelector.lua"
local r,e=http.get(url); if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode(); if code~=200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()
if not data:find("Vertically center the two-row mode control",1,true) then error("Patch marker missing.",0) end
for _,target in ipairs({"gui/classTaskGroupSelector.lua","runtime/classTaskGroupSelector.lua"}) do
 local f=assert(fs.open(target,"w")); f.write(data); f.close(); print("Patched "..target)
end
print("select/cursor controls moved down one row.")
print("Reboot the controller once.")
