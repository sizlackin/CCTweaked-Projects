-- Enables cooperative multi-turtle tunnel remapping.
-- The controller atomically reserves unmapped frontiers so DTX turtles do not
-- duplicate scans. Known roads are fast-travel only.
-- Run on the MAIN controller.

if turtle then error("Run this on the main controller.",0) end

local files = {
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/699e11283b6eeb18e0a5984096964cc3c5ba9e93/ActuallyUsefulTurtles/tunnelnav/classTunnelMap.lua",
    marker="LABENHANCED_MULTI_MAPPER_CLAIMS",
    targets={"general/classTunnelMap.lua","runtime/classTunnelMap.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/429cd4296a00b5e804328344985984ed1526c516/ActuallyUsefulTurtles/patches/host-main.lua",
    marker="LABENHANCED_MULTI_MAPPER_CLAIMS",
    targets={"host/main.lua","runtime/main.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/da657c4ce1cc6efd94baa725972b7e095e04ace4/ActuallyUsefulTurtles/tunnelnav/classTunnelNavigator.lua",
    marker="LABENHANCED_MULTI_MAPPER_CLAIMS",
    targets={"turtle/classTunnelNavigator.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/ffe35ca50e3997684008176c0db1ea5031ceb95a/ActuallyUsefulTurtles/tunnelnav/classTunnelMapper.lua",
    marker="LABENHANCED_MULTI_MAPPER_CLAIMS",
    targets={"turtle/classTunnelMapper.lua"},
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
