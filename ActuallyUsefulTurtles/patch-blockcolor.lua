-- Fixes CC:Tweaked "Too long without yielding" during turtle startup.
-- Run this ON THE HOST/CONTROLLER computer.
local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/blockColor.lua"
local target = "general/blockColor.lua"

if not fs.isDir("general") or not fs.isDir("turtle") then
    error("Run this on the mining controller/host.", 0)
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

-- Also refresh the host runtime copy.
fs.makeDir("runtime")
if fs.exists("runtime/blockColor.lua") then fs.delete("runtime/blockColor.lua") end
fs.copy(target, "runtime/blockColor.lua")

print("Patched blockColor.lua watchdog issue.")
print("Now reboot each turtle. It should sync the fixed file from the host.")
