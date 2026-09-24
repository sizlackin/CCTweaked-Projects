-- Makes the shared tunnel mapper travel smoothly through already-known roads.
-- It only inspects/rescans when entering genuinely new/frontier territory.
-- Run on the MAIN controller, then reboot DTX-001.

if turtle then error("Run this on the main controller.",0) end

local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/5b9d5cacad1915bd84da0e226490583ba4b7021d/ActuallyUsefulTurtles/tunnelnav/classTunnelMapper.lua"
local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()

if not data:find("LABENHANCED_MAPPER_FAST_TRAVEL",1,true) then
  error("Downloaded mapper is missing fast-travel fix.",0)
end

local target="turtle/classTunnelMapper.lua"
fs.makeDir(fs.getDir(target))
local f=assert(fs.open(target,"w"))
f.write(data); f.close()

print("Mapper fast-travel fix installed.")
print("Reboot DTX-001, then rerun start-tunnel-remap-large.")
