-- Fix active task/group outlines glitching over tunnel/floor colors.
-- Run on the MAIN controller.
--
-- Active task outlines now use the same precise post-terrain compositor as the
-- WorldEdit-style live selection outline, so dense tunnel colors cannot break
-- or erase sections of the green/status-colored border.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("gui") then error("Could not find gui source folder.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/b23fa5fdd1def1b70fcfbc4296fe6dd46844b9b0/ActuallyUsefulTurtles/patches/classMapDisplay.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll()
r.close()

if not data:find("LABENHANCED_PRECISE_TASK_OUTLINE",1,true) then
  error("Patch marker missing.",0)
end

for _,target in ipairs({"gui/classMapDisplay.lua","runtime/classMapDisplay.lua"}) do
  local f=assert(fs.open(target,"w"))
  f.write(data)
  f.close()
  print("Patched "..target)
end

print("Precise active-task outline installed.")
print("Reboot the controller once.")
