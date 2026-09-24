-- Removes the MARK REFILLED map feature while preserving other map patches
-- such as floor colors and turtle/home/chunk-circle display.
-- Run on the MAIN controller.

if turtle then error("Run this on the main controller.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/3d77617e9b6da1a63093dcb9d710a52dcbd61d73/ActuallyUsefulTurtles/patches/classMapDisplay.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()

if not data:find("LABENHANCED_MARK_REFILLED_REMOVED",1,true) then
  error("Downloaded map patch is missing the removal marker.",0)
end

for _,target in ipairs({"gui/classMapDisplay.lua","runtime/classMapDisplay.lua"}) do
  fs.makeDir(fs.getDir(target))
  local f=assert(fs.open(target,"w"))
  f.write(data)
  f.close()
  print("Patched "..target)
end

print("MARK REFILLED removed.")
print("Reboot the main controller.")
