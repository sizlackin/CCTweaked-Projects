-- Experimental WorldEdit anchor style: small square glyph overlays.
-- Run on the MAIN CONTROLLER. Re-running the previous anchor visibility
-- installer restores the larger 2x3 markers.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("gui") then error("Run this on the main controller.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/e4602c0001af925741d754a22c3fc56e2d64d255/ActuallyUsefulTurtles/patches/classMapDisplay.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()
if not data:find("redrawSelectionAnchors",1,true) then error("Patch marker missing.",0) end

for _,target in ipairs({"gui/classMapDisplay.lua","runtime/classMapDisplay.lua"}) do
  fs.makeDir(fs.getDir(target))
  local f=assert(fs.open(target,"w"))
  f.write(data); f.close()
  print("Patched "..target)
end

print("Square WorldEdit anchor experiment installed.")
print("Reboot the controller once.")
