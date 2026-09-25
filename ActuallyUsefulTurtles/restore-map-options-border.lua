-- Restore the original thin/subpixel map-options border.
-- Keeps the MAP OPTIONS title.
-- Run on the MAIN CONTROLLER.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("gui") then error("Run this on the main controller.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/173adad876c2b1f2ade547720a20f442491963a6/ActuallyUsefulTurtles/patches/classMapDisplay.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()
if not data:find("original 1%-subpixel ring") then error("Patch marker missing.",0) end
for _,target in ipairs({"gui/classMapDisplay.lua","runtime/classMapDisplay.lua"}) do
  local f=assert(fs.open(target,"w")); f.write(data); f.close(); print("Patched "..target)
end
print("Original MAP OPTIONS border restored.")
print("Reboot the controller once.")
