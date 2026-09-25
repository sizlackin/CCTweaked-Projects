-- Add automatic tunnel torches for mineArea jobs.
-- Run on the MAIN controller.
--
-- Behavior:
--   * keeps at most one stack (64) of minecraft:torch when unloading
--   * places torches only on long mining rows, not short row connectors
--   * torches sit in a one-block recess beside the UPPER half of the 1x2 tunnel
--   * alternates left / right / left / right
--   * spacing is 11 forward blocks, keeping the lower tunnel floor above
--     vanilla hostile-mob spawn block-light 0 for this tunnel geometry
--
-- Plain CC:Tweaked does not expose the world's exact block-light value, so this
-- uses the deterministic vanilla torch-light falloff for the maintained 1x2 tunnel.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("turtle") then error("Could not find turtle source folder.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/1b61dfde5961e1480bf00840abbf59ddbf7c95db/ActuallyUsefulTurtles/patches/classMiner.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll()
r.close()

if not data:find("LABENHANCED_AUTO_TORCHES",1,true) then
  error("Patch marker missing.",0)
end

local f=assert(fs.open("turtle/classMiner.lua","w"))
f.write(data)
f.close()

print("Automatic tunnel torches installed.")
print("Give each mining turtle up to 64 minecraft:torch.")
print("Reboot mining turtles before the next mineArea task.")
print("No tunnel-map reset is required.")
