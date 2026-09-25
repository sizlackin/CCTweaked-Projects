-- Connect the far ends of mineArea strip tunnels into one continuous 1x2 spine.
-- Run on the MAIN controller.
--
-- Each turtle connects only the far edge of its own assigned stripe.
-- Adjacent stripes meet naturally, producing one clean shared far-side spine.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("turtle") then error("Could not find turtle source folder.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/0d53bb3b882be3ea8b6a128dffd611119caecf33/ActuallyUsefulTurtles/patches/classMiner.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll()
r.close()

if not data:find("LABENHANCED_FAR_EDGE_SPINE",1,true) then
  error("Patch marker missing.",0)
end

local f=assert(fs.open("turtle/classMiner.lua","w"))
f.write(data)
f.close()

print("Far-edge mining spine installed.")
print("Reboot mining turtles before starting the next mineArea task.")
print("No tunnel-map reset is required.")
