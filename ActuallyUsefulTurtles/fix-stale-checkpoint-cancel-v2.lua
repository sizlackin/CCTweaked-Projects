-- Hard stale-checkpoint recovery, fully commit-pinned to avoid raw.github
-- branch/CDN cache returning older patch files.
-- Run on MAIN controller.

if turtle then error("Run this on the main controller.",0) end

local files = {
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/1a5babe6cfeb3da6fae48fdee55d882b22e3a5a7/ActuallyUsefulTurtles/patches/turtle-receive.lua",
    marker="LABENHANCED_HARD_STALE_RESET",
    targets={"turtle/receive.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/89c65fcd6cd7e19f59c1e72fcbab3c909409007f/ActuallyUsefulTurtles/patches/classTaskGroup.lua",
    marker="LABENHANCED_HARD_STALE_RESET",
    targets={"host/classTaskGroup.lua","runtime/classTaskGroup.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/2f2e28af047f575abdfd40ee874be27538ed3231/ActuallyUsefulTurtles/clear-stale-active-tasks.lua",
    marker="LABENHANCED_HARD_STALE_RESET",
    targets={"clear-stale-active-tasks"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/52f866ec2165d60c867864aa3f2cb17001831eba/ActuallyUsefulTurtles/force-clear-dtx-234.lua",
    marker="HARD checkpoint reset",
    targets={"force-clear-dtx-234"},
  },
}

local function fetch(url)
  local r,e=http.get(url)
  if not r then error("Download failed: "..tostring(e),0) end
  local code=r.getResponseCode()
  if code ~= 200 then
    r.close()
    error("HTTP "..tostring(code),0)
  end
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

print("V2 hard checkpoint recovery installed.")
print("Reboot controller, then reboot DTX-002/003/004 once.")
print("After they reconnect, run: force-clear-dtx-234")
