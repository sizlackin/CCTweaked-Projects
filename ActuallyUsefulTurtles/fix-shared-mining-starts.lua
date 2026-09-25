-- Shared mining start-path fix.
-- Run on the MAIN controller.
--
-- Mining behavior after this patch:
--   * one shared 1x2 access route/spine serves the whole mining group
--   * every turtle starts mining directly from its own corner on that spine
--   * no turtle drills a private connector/shortcut to its stripe start
--   * controller-known tunnel routes are travelled without re-publishing every
--     OPEN edge as though the route were being scanned again
--   * newly dug/bootstrap/passing-bay movement is still learned normally
--
-- Existing mining groups created before this patch contain midpoint access
-- entries. Cancel/recreate those groups after installation.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("host") or not fs.isDir("turtle") then
  error("Could not find host/turtle source folders on this controller.",0)
end

local files = {
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/8a6c645dbc65014e33d84c7bc48f31ed21245570/ActuallyUsefulTurtles/patches/classTaskGroup.lua",
    marker="LABENHANCED_SHARED_STRIPE_CORNERS",
    targets={"host/classTaskGroup.lua","runtime/classTaskGroup.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/c8a5fa85f169a4a559fcd215a95ec2208e948bce/ActuallyUsefulTurtles/patches/classMiner.lua",
    marker="LABENHANCED_NO_PRIVATE_STRIPE_CONNECTOR",
    targets={"turtle/classMiner.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/c0114a0130a1be3f20466881b6f08e92f598d873/ActuallyUsefulTurtles/tunnelnav/classTunnelNavigator.lua",
    marker="LABENHANCED_NO_ROUTE_RESCAN",
    targets={"turtle/classTunnelNavigator.lua"},
  },
}

local function fetch(url)
  local r,e=http.get(url)
  if not r then error("Download failed: "..tostring(e),0) end
  local code=r.getResponseCode()
  if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
  local data=r.readAll()
  r.close()
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

print("Shared mining starts fixed.")
print("Reboot the controller and mining turtles.")
print("Cancel/recreate any mining group made before this patch.")
print("No tunnel-map reset is required.")
