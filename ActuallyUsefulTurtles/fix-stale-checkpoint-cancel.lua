-- Fixes ghost Active tasks / unresponsive Cancel after checkpoint reboot.
-- Run on MAIN controller.

if turtle then error("Run this on the main controller.",0) end

local files = {
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/turtle-receive.lua",
    marker="LABENHANCED_HARD_STALE_RESET",
    targets={"turtle/receive.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classTaskGroup.lua",
    marker="LABENHANCED_STALE_CHECKPOINT_RECOVERY",
    targets={"host/classTaskGroup.lua","runtime/classTaskGroup.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/clear-stale-active-tasks.lua",
    marker="LABENHANCED_HARD_STALE_RESET",
    targets={"clear-stale-active-tasks"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/force-clear-dtx-234.lua",
    marker="HARD checkpoint reset",
    targets={"force-clear-dtx-234"},
  },
}

local function fetch(url)
  local r,e=http.get(url)
  if not r then error("Download failed: "..tostring(e),0) end
  if r.getResponseCode() ~= 200 then
    local code=r.getResponseCode(); r.close()
    error("HTTP "..tostring(code),0)
  end
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

print("Hard checkpoint recovery installed.")
print("Reboot controller, then reboot DTX-002/003/004 once.")
print("After they reconnect, run:")
print("force-clear-dtx-234")
