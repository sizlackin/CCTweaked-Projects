-- Floor-colors v3:
-- 1) reads the stored Y=-60 floor instead of ChunkyMap's bedrock sentinel
-- 2) colors Galena-family modded blocks purple.
-- Run on the MAIN controller.

local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/bfef6af7de12ada719bfb8b378786caf54791764/ActuallyUsefulTurtles/patches/classMapDisplay.lua"
local targets = {"gui/classMapDisplay.lua","runtime/classMapDisplay.lua"}

if turtle then error("Run this on the main controller.",0) end

local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()

if not data:find("LABENHANCED_FLOOR_COLORS_V3",1,true) then
  error("Downloaded map patch is missing floor-colors v3.",0)
end

for _,p in ipairs(targets) do
  local f=assert(fs.open(p,"w"))
  f.write(data)
  f.close()
  print("Patched "..p)
end

print("Floor-colors v3 installed.")
print("Reboot the main controller.")
