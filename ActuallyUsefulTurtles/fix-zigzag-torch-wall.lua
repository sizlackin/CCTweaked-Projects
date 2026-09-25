-- Keep mineArea torches on one ABSOLUTE physical wall across zigzag rows.
-- Run on the MAIN controller.
--
-- Why:
-- stripMine reverses direction every row. "Left relative to travel" therefore
-- flips physical walls and can make neighboring torch niches face each other,
-- chewing through both blocks of the intended 2-block divider.
--
-- New behavior:
--   * the wall physically left of the FIRST mining row becomes the torch wall
--   * when the turtle reverses direction, it automatically uses its RIGHT side
--     relative to travel so the same physical wall is still used
--   * the 2-block divider between parallel tunnels stays intact
--   * existing saved stripMine checkpoints are compatible

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("turtle") then error("Could not find turtle source folder.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/9a3b959108397815907400f51485e092cf121685/ActuallyUsefulTurtles/patches/classMiner.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll()
r.close()

if not data:find("LABENHANCED_FIXED_TORCH_WALL",1,true) then
  error("Patch marker missing.",0)
end

local f=assert(fs.open("turtle/classMiner.lua","w"))
f.write(data)
f.close()

print("Fixed-wall zigzag torch layout installed.")
print("Reboot mining turtles to load it.")
print("Existing mineArea checkpoints can resume.")
print("No tunnel-map reset is required.")
