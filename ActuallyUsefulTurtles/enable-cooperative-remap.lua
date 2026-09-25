-- Enables cooperative multi-turtle tunnel remapping.
-- The controller atomically reserves unmapped frontiers so DTX turtles do not
-- duplicate scans. Known roads are fast-travel only.
-- Run on the MAIN controller.

if turtle then error("Run this on the main controller.",0) end

local files = {
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/e47abe6f0f9874bdc7dff230317b26c29407f898/ActuallyUsefulTurtles/tunnelnav/classTunnelMap.lua",
    marker="LABENHANCED_SMART_FRONTIER_SCORING",
    targets={"general/classTunnelMap.lua","runtime/classTunnelMap.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/f6c8fcfd78eef0e6e767cbc6d4ea02a7595f0897/ActuallyUsefulTurtles/patches/host-main.lua",
    marker="LABENHANCED_SMART_FRONTIER_SCORING",
    targets={"host/main.lua","runtime/main.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/a74cd095a52bd333af3c6830d150d26f61b42def/ActuallyUsefulTurtles/tunnelnav/classTunnelNavigator.lua",
    marker="LABENHANCED_SMART_FRONTIER_SCORING",
    targets={"turtle/classTunnelNavigator.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/eefc46141aafe68bab5369cb1252b3ad0a7b1ae9/ActuallyUsefulTurtles/patches/classMiner.lua",
    marker="LABENHANCED_TUNNEL_FLOOR_LOCK",
    targets={"turtle/classMiner.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/0b6febc65a7811c583f558f89cb85d762a4612c0/ActuallyUsefulTurtles/tunnelnav/classTunnelMapper.lua",
    marker="LABENHANCED_BRANCH_RESCUE",
    targets={"turtle/classTunnelMapper.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/1a5babe6cfeb3da6fae48fdee55d882b22e3a5a7/ActuallyUsefulTurtles/patches/turtle-receive.lua",
    marker="LABENHANCED_HARD_STALE_RESET",
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
