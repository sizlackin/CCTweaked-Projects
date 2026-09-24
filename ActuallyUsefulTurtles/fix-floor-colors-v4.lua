-- Floor-colors v4:
-- keeps ordinary tunnel air light-gray so tunnel shapes remain visible,
-- but highlights visually distinct floor materials such as Galena purple.
-- Run on the MAIN controller.

local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/450112f0d54c2f564e0851e67784c6903d052127/ActuallyUsefulTurtles/patches/classMapDisplay.lua"
local targets = {"gui/classMapDisplay.lua","runtime/classMapDisplay.lua"}

if turtle then error("Run this on the main controller.",0) end

local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()

if not data:find("LABENHANCED_FLOOR_COLORS_V4",1,true) then
  error("Downloaded map patch is missing floor-colors v4.",0)
end

for _,p in ipairs(targets) do
  local f=assert(fs.open(p,"w"))
  f.write(data)
  f.close()
  print("Patched "..p)
end

print("Floor-colors v4 installed.")
print("Reboot the main controller.")
