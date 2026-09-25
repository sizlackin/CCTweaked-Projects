-- Restyles the map screen after cc-mek-scada: solid color-coded buttons
-- (cyan=pan, yellow=level, lime=zoom, red=close), gray plates behind the
-- Level/X/Z/zoom readouts, and a framed LAYERS panel of toggles.
-- Run on the MAIN CONTROLLER at the normal CraftOS > prompt.

local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classMapDisplay.lua"
local targets = {"gui/classMapDisplay.lua", "runtime/classMapDisplay.lua"}

if not fs.isDir("gui") then
  error("Run this on the main Actually Useful Turtles controller.", 0)
end

local response, err = http.get(url)
if not response then error("Download failed: " .. tostring(err), 0) end
local code = response.getResponseCode()
if code ~= 200 then
  response.close()
  error("Download failed: HTTP " .. tostring(code), 0)
end

local data = response.readAll()
response.close()
if not data or #data < 10000 then
  error("Downloaded map display patch looks incomplete.", 0)
end
if not data:find("LABENHANCED_MAP_UI_THEME", 1, true) then
  error("Downloaded map display patch is missing the theme marker.", 0)
end

for _, target in ipairs(targets) do
  fs.makeDir(fs.getDir(target))
  local f = assert(fs.open(target, "w"))
  f.write(data)
  f.close()
  print("Patched " .. target)
end

print("Map UI theme installed.")
print("Reboot the main controller.")
