-- Installs the LabEnhanced Philolite tunnel-repair patch.
-- Run on the MAIN controller at the normal CraftOS > prompt.
-- The patched miner also preserves the existing clean-return, lava,
-- 2-high tunnel, coordinated mining, and Sophisticated Storage changes.

local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classMiner.lua"

if turtle then
    error("Run this installer on the main Actually Useful Turtles controller.", 0)
end

if not fs.isDir("turtle") then
    error("Could not find the controller's turtle source folder.", 0)
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
    error("Downloaded classMiner patch looks incomplete.", 0)
end

local target = "turtle/classMiner.lua"
local f = assert(fs.open(target, "w"))
f.write(data)
f.close()

print("Philolite tunnel repair installed.")
print("Reboot the controller, then reboot DTX-001 and DTX-002.")
