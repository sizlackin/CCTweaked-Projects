-- Keep automatic mineArea torches on the LEFT wall only.
-- Run on the MAIN controller.
--
-- This replaces the previous left/right alternation. Every torch is placed on
-- the left wall relative to the turtle's current mining direction.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("turtle") then error("Could not find turtle source folder.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/33f29b5c970ccbef6d22d775e531609e3da88b59/ActuallyUsefulTurtles/patches/classMiner.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll()
r.close()

if not data:find("LABENHANCED_LEFT_WALL_TORCHES",1,true) then
  error("Patch marker missing.",0)
end

local f=assert(fs.open("turtle/classMiner.lua","w"))
f.write(data)
f.close()

print("Left-wall torch layout installed.")
print("Reboot mining turtles before the next mineArea task.")
