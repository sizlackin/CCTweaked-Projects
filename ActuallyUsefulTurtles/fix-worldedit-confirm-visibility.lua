-- WorldEdit controls:
-- 0 positions: no buttons
-- POS1 only: DESELECT only
-- POS1 + POS2: DESELECT + CONFIRM
-- Run on the MAIN CONTROLLER.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("gui") then error("Run this on the main controller.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/2c98f53d6e8fbd836927c2d62dbff30a5cd1452b/ActuallyUsefulTurtles/patches/classTaskGroupSelector.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()
if not data:find("CONFIRM must not exist until POS2",1,true) then error("Patch marker missing.",0) end
for _,target in ipairs({"gui/classTaskGroupSelector.lua","runtime/classTaskGroupSelector.lua"}) do
  local f=assert(fs.open(target,"w")); f.write(data); f.close(); print("Patched "..target)
end
print("WorldEdit CONFIRM visibility fixed.")
print("Reboot the controller once.")
