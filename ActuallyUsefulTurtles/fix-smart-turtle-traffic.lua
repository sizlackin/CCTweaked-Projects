-- Adds traffic-aware cooperative mapping.
-- A mapper briefly yields to another turtle, then temporarily avoids that edge
-- and asks the controller for the nearest reachable unclaimed frontier.
-- Run on the MAIN controller.

if turtle then error("Run this on the main controller.",0) end

local files = {
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/b06454712209f1284dd7040602dd0b1b3280260e/ActuallyUsefulTurtles/tunnelnav/classTunnelMap.lua",
    marker="LABENHANCED_TORCH_REROUTE",
    targets={"general/classTunnelMap.lua","runtime/classTunnelMap.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/eefc46141aafe68bab5369cb1252b3ad0a7b1ae9/ActuallyUsefulTurtles/patches/classMiner.lua",
    marker="LABENHANCED_TUNNEL_FLOOR_LOCK",
    targets={"turtle/classMiner.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/f973cdf91b337231b8b9c9d2c2a3dae4333def25/ActuallyUsefulTurtles/tunnelnav/classTunnelNavigator.lua",
    marker="LABENHANCED_SMART_TRAFFIC",
    targets={"turtle/classTunnelNavigator.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/7b92c1d00c8773e76904daccf2defc3477bee622/ActuallyUsefulTurtles/tunnelnav/classTunnelMapper.lua",
    marker="LABENHANCED_SMART_TRAFFIC",
    targets={"turtle/classTunnelMapper.lua"},
  },
}

local function fetch(url)
  local r,e=http.get(url)
  if not r then error("Download failed: "..tostring(e),0) end
  local code=r.getResponseCode()
  if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
  local data=r.readAll(); r.close()
  return data
end

for _,entry in ipairs(files) do
  local data=fetch(entry.url)
  if not data:find(entry.marker,1,true) then
    error("Patch marker missing: "..entry.marker,0)
  end
  for _,target in ipairs(entry.targets) do
    fs.makeDir(fs.getDir(target))
    local f=assert(fs.open(target,"w"))
    f.write(data); f.close()
    print("Patched "..target)
  end
end

print("Smart turtle traffic logic installed.")
print("Reboot controller, then reboot DTX-001 through DTX-004.")
print("Then run: start-tunnel-remap-all")
