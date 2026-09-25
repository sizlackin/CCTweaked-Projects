-- Fix WorldEdit selection controls visibility/state.
-- No positions: no DESELECT/CONFIRM.
-- POS1: DESELECT visible, CONFIRM disabled.
-- POS1+POS2: both visible, CONFIRM enabled.
-- DESELECT clears everything and immediately re-arms POS1 selection.
-- Run on the MAIN CONTROLLER.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("gui") then error("Run this on the main controller.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/e409dced7f9bc38ad4978f2498d45d2af1546d9d/ActuallyUsefulTurtles/patches/classTaskGroupSelector.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()
if not data:find("No selection yet",1,true) then error("Patch marker missing.",0) end
for _,target in ipairs({"gui/classTaskGroupSelector.lua","runtime/classTaskGroupSelector.lua"}) do
  local f=assert(fs.open(target,"w")); f.write(data); f.close(); print("Patched "..target)
end
print("WorldEdit selection controls fixed.")
print("Reboot the controller once.")
