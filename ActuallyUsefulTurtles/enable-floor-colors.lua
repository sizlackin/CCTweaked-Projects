-- Adds display-only floor colors to the Actually Useful Turtles map.
-- Open tunnel cells remain AIR for pathfinding; only their displayed color
-- comes from the inspected floor block beneath them.

local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classMapDisplay.lua"
local targets = {"gui/classMapDisplay.lua","runtime/classMapDisplay.lua"}

if turtle then error("Run this on the main controller.",0) end

local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
if r.getResponseCode() ~= 200 then local c=r.getResponseCode(); r.close(); error("HTTP "..c,0) end
local data=r.readAll(); r.close()
if not data:find("LABENHANCED_FLOOR_COLORS",1,true) then error("Floor-color patch missing.",0) end

for _,p in ipairs(targets) do
  local f=assert(fs.open(p,"w")); f.write(data); f.close()
  print("Patched "..p)
end
print("Floor colors installed. Reboot controller.")
