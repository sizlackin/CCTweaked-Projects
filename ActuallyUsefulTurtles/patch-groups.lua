-- Fix Actually Useful Turtles Groups -> Create crash.
-- Run on the MAIN CONTROLLER at the normal CraftOS > prompt.
local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classTaskGroup.lua"
local targets = {"host/classTaskGroup.lua", "runtime/classTaskGroup.lua"}

if not fs.isDir("host") then error("Run this on the main controller.", 0) end

local response, err = http.get(url)
if not response then error("Download failed: " .. tostring(err), 0) end
if response.getResponseCode() ~= 200 then
  local code = response.getResponseCode()
  response.close()
  error("Download failed: HTTP " .. tostring(code), 0)
end
local data = response.readAll()
response.close()
if #data < 1000 then error("Downloaded patch looks incomplete.", 0) end

for _, target in ipairs(targets) do
  fs.makeDir(fs.getDir(target))
  local f = assert(fs.open(target, "w"))
  f.write(data)
  f.close()
  print("Patched " .. target)
end

print("Group creation fixed. Reboot the controller now.")
