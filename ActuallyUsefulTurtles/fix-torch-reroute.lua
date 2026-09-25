-- Fixes mapper loops on torches whose upper bypass is physically unusable.
-- The mapper tries the preserved upper bypass once, then records that route as
-- blocked and chooses another frontier instead of rediscovering it forever.
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
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/4e19fb91120b1dc27b89066148a0933bf67900fe/ActuallyUsefulTurtles/tunnelnav/classTunnelMapper.lua",
    marker="LABENHANCED_TORCH_REROUTE",
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

print("Torch reroute fix installed.")
print("Reboot controller, then reboot DTX-001 through DTX-004.")
print("An unbypassable torch will now print:")
print("TORCH BYPASS BLOCKED - REROUTING")
