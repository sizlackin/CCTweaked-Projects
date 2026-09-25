-- Fix sparse / prematurely-aborted strip-mining rows.
-- Run on the MAIN controller.
--
-- New mineArea jobs:
--   * keep efficient 3-block row spacing (each tunnel scans one block per side)
--   * use a final 2-block connector when needed to cover the far edge
--   * never command a 3-block row connector outside a turtle's assigned stripe
--   * preserve shared access, far-edge spine, traffic handling and auto torches
--
-- Recreate an already-started mineArea job to get the new row plan. Existing
-- checkpoint data does not contain the new per-row connector distances.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("turtle") then error("Could not find turtle source folder.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/d69b38cf89c9c301cff79581bc0ce1c050a5ffcd/ActuallyUsefulTurtles/patches/classMiner.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll()
r.close()

if not data:find("LABENHANCED_EFFICIENT_STRIP_ROWS",1,true) then
  error("Patch marker missing.",0)
end

local f=assert(fs.open("turtle/classMiner.lua","w"))
f.write(data)
f.close()

print("Efficient strip-row coverage installed.")
print("Reboot mining turtles.")
print("Recreate the mineArea task to use the new row plan.")
print("No tunnel-map reset is required.")
