-- Adds the MARK REFILLED map tool to Actually Useful Turtles.
-- Run on the MAIN CONTROLLER at the normal CraftOS > prompt.

local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classMapDisplay.lua"
local targets = {"gui/classMapDisplay.lua", "runtime/classMapDisplay.lua"}

if not fs.isDir("gui") then
  error("Run this on the main Actually Useful Turtles controller.", 0)
end

local response, err = http.get(url)
if not response then error("Download failed: " .. tostring(err), 0) end
if response.getResponseCode() ~= 200 then
  local code = response.getResponseCode()
  response.close()
  error("Download failed: HTTP " .. tostring(code), 0)
end

local data = response.readAll()
response.close()
if not data or #data < 10000 then
  error("Downloaded classMapDisplay patch looks incomplete.", 0)
end

for _,path in ipairs(targets) do
  fs.makeDir(fs.getDir(path))
  local f = assert(fs.open(path,"w"))
  f.write(data)
  f.close()
  print("Patched " .. path)
end

print("MARK REFILLED installed.")
print("Reboot the main controller.")
