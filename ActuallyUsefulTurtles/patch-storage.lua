-- Patches the controller's turtle source so all mining turtles recognize Sophisticated Storage chests.
-- Run this ON THE HOST/CONTROLLER computer.
local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classMiner.lua"
local target = "turtle/classMiner.lua"
if not fs.isDir("turtle") then
    error("No turtle source folder found. Run this on the mining controller.", 0)
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
if #data < 1000 then error("Downloaded patch looks incomplete.", 0) end
local temp = target .. ".download"
local f = assert(fs.open(temp, "w"))
f.write(data)
f.close()
if fs.exists(target) then fs.delete(target) end
fs.move(temp, target)
print("Patched turtle/classMiner.lua")
print("Sophisticated Storage chests are now valid unload/refuel inventories.")
print("They are also protected from turtle digging.")
print("Reboot any installed turtles so they sync the updated file.")
