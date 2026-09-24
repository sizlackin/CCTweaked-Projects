-- Fixes tunnel remap crash:
-- classTunnelMapper.lua: attempt to index local 'nav' (a nil value)
-- Run on the MAIN controller, then reboot DTX-001.

if turtle then error("Run this on the main controller.",0) end

local files = {
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classMiner.lua",
    marker="LABENHANCED_MAPPER_NAV_FIX",
    targets={"turtle/classMiner.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/tunnelnav/classTunnelMapper.lua",
    marker="LABENHANCED_MAPPER_NAV_FIX",
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

print("Mapper navigator fix installed.")
print("Reboot DTX-001, wait for it to reconnect, then rerun start-tunnel-remap-large.")
