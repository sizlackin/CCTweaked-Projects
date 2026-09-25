-- Cooperative mining traffic + stripe-direction fix.
-- Run on the MAIN controller.
--
-- Fixes:
--   * each mineArea turtle stays on its assigned stripe long axis
--   * open-road navigation reroutes around turtle traffic
--   * 2-high tunnel headspace can be used as a temporary no-dig passing bay
--   * persistent turtle jams time out instead of pushing forever
--
-- After installing, reboot the mining turtles so they pull the new turtle code.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("turtle") then error("Could not find turtle source folder.",0) end

local files = {
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/41c99e7dfba745fe2a4687c21877ee7b03d4d4c6/ActuallyUsefulTurtles/patches/classMiner.lua",
    marker="LABENHANCED_COOP_STRIPE_ORIENTATION",
    targets={"turtle/classMiner.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/8b7cbb46481d918a79be04dc2331b229cea5b06b/ActuallyUsefulTurtles/tunnelnav/classTunnelNavigator.lua",
    marker="LABENHANCED_COOP_MINING_TRAFFIC",
    targets={"turtle/classTunnelNavigator.lua"},
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
    f.write(data)
    f.close()
    print("Patched "..target)
  end
end

print("Cooperative mining traffic fix installed.")
print("Reboot DTX-001 through DTX-004 before retrying the mining group.")
print("No map reset is required.")
