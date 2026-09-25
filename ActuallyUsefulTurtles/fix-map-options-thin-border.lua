-- Restore the original thin MAP OPTIONS frame while removing the two stray left-edge pixels.
-- Run on the MAIN CONTROLLER.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("gui") then error("Run this on the main controller.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/5124b2139a08c37ccfce584b3ef4e0dfb3a7387a/ActuallyUsefulTurtles/patches/classMapDisplay.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()
if not data:find("MAP OPTIONS",1,true) then error("Patch marker missing.",0) end
for _,target in ipairs({"gui/classMapDisplay.lua","runtime/classMapDisplay.lua"}) do
  local f=assert(fs.open(target,"w")); f.write(data); f.close(); print("Patched "..target)
end
print("Thin MAP OPTIONS frame restored; stray left corner pixels removed.")
print("Reboot the controller once.")
