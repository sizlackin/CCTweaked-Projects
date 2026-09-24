-- Fixes the empty Turtles screen on the Actually Useful Turtles host.
-- Run this on the MAIN CONTROLLER.
local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classTurtleList.lua"
local targets = {"gui/classTurtleList.lua", "runtime/classTurtleList.lua"}

if not fs.isDir("gui") then error("Run this on the main controller.", 0) end
local response, err = http.get(url)
if not response then error("Download failed: " .. tostring(err), 0) end
if response.getResponseCode() ~= 200 then
  local code = response.getResponseCode()
  response.close()
  error("Download failed: HTTP " .. tostring(code), 0)
end
local data = response.readAll()
response.close()

for _, target in ipairs(targets) do
  fs.makeDir(fs.getDir(target))
  local f = assert(fs.open(target, "w"))
  f.write(data)
  f.close()
  print("Patched " .. target)
end

print("Reboot the main controller, then open Turtles again.")
