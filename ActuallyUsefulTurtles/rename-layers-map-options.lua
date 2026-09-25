-- Rename the map LAYERS panel to MAP OPTIONS.
-- Run on the MAIN CONTROLLER.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("gui") then error("Run this on the main controller.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/e91b04d6145142ba18d416aff6824d0ce8ca5fed/ActuallyUsefulTurtles/patches/classMapDisplay.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()
if not data:find("MAP OPTIONS",1,true) then error("Patch marker missing.",0) end

for _,target in ipairs({"gui/classMapDisplay.lua","runtime/classMapDisplay.lua"}) do
  fs.makeDir(fs.getDir(target))
  local f=assert(fs.open(target,"w"))
  f.write(data); f.close()
  print("Patched "..target)
end

print("Renamed LAYERS to MAP OPTIONS.")
print("Reboot the controller once.")
