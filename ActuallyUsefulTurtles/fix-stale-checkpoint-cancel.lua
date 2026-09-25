-- Fixes ghost Active tasks / unresponsive Cancel after checkpoint reboot.
-- Run on MAIN controller.

if turtle then error("Run this on the main controller.",0) end

local files = {
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/turtle-receive.lua",
    marker="LABENHANCED_STALE_CHECKPOINT_RECOVERY",
    targets={"turtle/receive.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classTaskGroup.lua",
    marker="LABENHANCED_STALE_CHECKPOINT_RECOVERY",
    targets={"host/classTaskGroup.lua","runtime/classTaskGroup.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/clear-stale-active-tasks.lua",
    marker="Cleared",
    targets={"clear-stale-active-tasks"},
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

print("Stale checkpoint cancel fix installed.")
print("Reboot controller, then reboot all DTX turtles once.")
print("If the controller still shows ghost Active tasks, run:")
print("clear-stale-active-tasks")
