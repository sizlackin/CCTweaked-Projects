-- Repairs the shared tunnel mapper/navigation stack:
-- * fixes reserved-keyword syntax in classTunnelMap
-- * revalidates stale BLOCKED edges from old torch scans
-- * bypasses vanilla/modded torches without breaking them
-- * retries transient controller-link failures
-- * removes the arbitrary 32-failure mapper abort
-- * refreshes known routes while mapping
-- Run on the MAIN controller.

if turtle then error("Run this on the main controller.",0) end

local files = {
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/75b62d6ce1695cf646367da8de428d4205b7f2cd/ActuallyUsefulTurtles/tunnelnav/classTunnelMap.lua",
    marker="blockedUntil",
    targets={"general/classTunnelMap.lua","runtime/classTunnelMap.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/8da94efead9dc9c4dd956b4d5cb291b2cbf39ace/ActuallyUsefulTurtles/tunnelnav/classTunnelNavigator.lua",
    marker="LABENHANCED_TORCH_BYPASS_V2",
    targets={"turtle/classTunnelNavigator.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/f677c763003753fb830262c62065a0d3106bd0c7/ActuallyUsefulTurtles/tunnelnav/classTunnelMapper.lua",
    marker="MAPPING STOP REASON",
    targets={"turtle/classTunnelMapper.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/ea3b1e6c34f0a7c5c7dbe99fe6401e1d230d6169/ActuallyUsefulTurtles/patches/classMiner.lua",
    marker="blockedUntil=opts.blockedUntil",
    targets={"turtle/classMiner.lua"},
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

print("Large mapper stability fix installed.")
print("Reboot the controller, then reboot DTX-001.")
print("Then refresh/run start-tunnel-remap-large.")
