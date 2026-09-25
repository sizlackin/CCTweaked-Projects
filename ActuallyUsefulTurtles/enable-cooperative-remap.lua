-- Enables cooperative multi-turtle tunnel remapping.
-- The controller atomically reserves unmapped frontiers so DTX turtles do not
-- duplicate scans. Known roads are fast-travel only.
-- Run on the MAIN controller.

if turtle then error("Run this on the main controller.",0) end

local files = {
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/b06454712209f1284dd7040602dd0b1b3280260e/ActuallyUsefulTurtles/tunnelnav/classTunnelMap.lua",
    marker="LABENHANCED_MULTI_MAPPER_CLAIMS",
    targets={"general/classTunnelMap.lua","runtime/classTunnelMap.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/429cd4296a00b5e804328344985984ed1526c516/ActuallyUsefulTurtles/patches/host-main.lua",
    marker="LABENHANCED_MULTI_MAPPER_CLAIMS",
    targets={"host/main.lua","runtime/main.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/f973cdf91b337231b8b9c9d2c2a3dae4333def25/ActuallyUsefulTurtles/tunnelnav/classTunnelNavigator.lua",
    marker="LABENHANCED_MULTI_MAPPER_CLAIMS",
    targets={"turtle/classTunnelNavigator.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/f240140e06b3bd541bb53181c4e3266243f2a90c/ActuallyUsefulTurtles/patches/classMiner.lua",
    marker="LABENHANCED_TORCH_REROUTE",
    targets={"turtle/classMiner.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/7b92c1d00c8773e76904daccf2defc3477bee622/ActuallyUsefulTurtles/tunnelnav/classTunnelMapper.lua",
    marker="LABENHANCED_MULTI_MAPPER_CLAIMS",
    targets={"turtle/classTunnelMapper.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/a002774f9464b8a972500ef29282be560d9702f9/ActuallyUsefulTurtles/patches/turtle-receive.lua",
    marker="LABENHANCED_STOP_LATCH_FIX",
    targets={"turtle/receive.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/start-tunnel-remap-all.lua",
    marker="COOPERATIVE TUNNEL REMAP",
    targets={"start-tunnel-remap-all"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/stop-tunnel-remap-all.lua",
    marker="STOP sent to",
    targets={"stop-tunnel-remap-all"},
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

print("Cooperative remap installed.")
print("Reboot controller, then reboot DTX-001 through DTX-004.")
print("Start with: start-tunnel-remap-all")
print("Stop all mappers with: stop-tunnel-remap-all")
