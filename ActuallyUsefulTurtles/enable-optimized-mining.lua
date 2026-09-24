-- Installs the optimized contained-mining build.
-- Run on the MAIN Actually Useful Turtles controller at the normal CraftOS > prompt.
-- This preserves fair exposed-ore mining, lava protection, Philolite repair,
-- 2-high tunnels, clean-return routing, coordinated mining and storage support.

local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classMiner.lua"

if turtle then
    error("Run this on the main Actually Useful Turtles controller.", 0)
end
if not fs.isDir("turtle") then
    error("Could not find the controller turtle source folder.", 0)
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

local f = assert(fs.open("turtle/classMiner.lua","w"))
f.write(data)
f.close()

print("Optimized contained mining installed.")
print("Reboot controller, then reboot DTX-001 and DTX-002.")
