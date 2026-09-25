-- Make DESELECT clear the current selection and immediately re-arm POS1.
-- Run on the MAIN CONTROLLER.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("gui") then error("Run this on the main controller.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/827d8a53fd68272e83415b15630c0d296f6b57ef/ActuallyUsefulTurtles/patches/classTaskGroupSelector.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()
if not data:find("next right%-click is always POS1") then error("Patch marker missing.",0) end
for _,target in ipairs({"gui/classTaskGroupSelector.lua","runtime/classTaskGroupSelector.lua"}) do
  local f=assert(fs.open(target,"w")); f.write(data); f.close(); print("Patched "..target)
end
print("DESELECT now clears and immediately re-arms POS1.")
print("Reboot the controller once.")
