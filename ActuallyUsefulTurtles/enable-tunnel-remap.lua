-- Installs non-destructive tunnel remapping for Actually Useful Turtles.
-- Run on the MAIN controller.

local files = {
  {
    url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classMiner.lua",
    targets = {"turtle/classMiner.lua"},
    marker = "LABENHANCED_TUNNEL_REMAP",
  },
  {
    url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classTaskGroupDetails.lua",
    targets = {"gui/classTaskGroupDetails.lua", "runtime/classTaskGroupDetails.lua"},
    marker = "LABENHANCED_TUNNEL_REMAP_UI",
  },
}

if turtle then error("Run this on the main controller.",0) end

for _,entry in ipairs(files) do
  local response,err = http.get(entry.url)
  if not response then error("Download failed: "..tostring(err),0) end
  local code = response.getResponseCode()
  if code ~= 200 then
    response.close()
    error("Download failed: HTTP "..tostring(code),0)
  end
  local data = response.readAll()
  response.close()
  if not data:find(entry.marker,1,true) then
    error("Downloaded patch is missing "..entry.marker,0)
  end

  for _,target in ipairs(entry.targets) do
    fs.makeDir(fs.getDir(target))
    local f = assert(fs.open(target,"w"))
    f.write(data)
    f.close()
    print("Patched "..target)
  end
end

print("Tunnel remap installed.")
print("Reboot controller. Turtles will receive the patched miner on their next boot.")
