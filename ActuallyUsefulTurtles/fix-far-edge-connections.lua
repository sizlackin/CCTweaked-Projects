-- Fix mineArea far-edge connections and keep torches out of connector cells.
-- Run on the MAIN controller.
--
-- Fixes:
--   * each turtle now connects the FULL far edge of its assigned stripe, not
--     just from its first strip lane to its last strip lane
--   * adjacent turtle stripe connectors therefore meet into one continuous
--     far-side spine
--   * torch niches are never placed directly on row endpoints/shared spines
--   * first torch is placed two blocks into each row instead of at the entrance
--   * old endpoint torches encountered while building the 1x2 far spine are
--     cleared because the connector corridor takes priority
--
-- Existing mineArea checkpoints can continue with this patch.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("turtle") then error("Could not find turtle source folder.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/1eabba1d9272461d4fb0cdbd5e5f8a84a146b250/ActuallyUsefulTurtles/patches/classMiner.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll()
r.close()

if not data:find("LABENHANCED_COMPLETE_FAR_EDGE_SPINE",1,true)
or not data:find("LABENHANCED_CLEAR_TUNNEL_ENDS",1,true) then
  error("Patch marker missing.",0)
end

local f=assert(fs.open("turtle/classMiner.lua","w"))
f.write(data)
f.close()

print("Far-edge connector + clear-end torches installed.")
print("Reboot mining turtles to load it.")
print("Existing mineArea checkpoints can resume.")
print("No tunnel-map reset is required.")
