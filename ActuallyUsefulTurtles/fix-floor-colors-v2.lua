-- Fixes the floor-colors map crash caused by a nil Y reference.
-- Run on the MAIN Actually Useful Turtles controller.

local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/de87fe4c862395e43c691eeee5dad1fccd75d0eb/ActuallyUsefulTurtles/patches/classMapDisplay.lua"
local targets = {
  "gui/classMapDisplay.lua",
  "runtime/classMapDisplay.lua",
}

if turtle then
  error("Run this on the main controller, not a turtle.", 0)
end

local r,e = http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code = r.getResponseCode()
if code ~= 200 then
  r.close()
  error("Download failed: HTTP "..tostring(code),0)
end

local data = r.readAll()
r.close()

if not data:find("LABENHANCED_FLOOR_COLORS_V2",1,true) then
  error("Downloaded map patch is missing the v2 floor-color fix.",0)
end

for _,p in ipairs(targets) do
  local f = assert(fs.open(p,"w"))
  f.write(data)
  f.close()
  print("Patched "..p)
end

print("Floor-colors v2 fix installed.")
print("Reboot the main controller.")
