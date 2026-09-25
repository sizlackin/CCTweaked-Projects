-- Fixes a DTX turtle which was previously STOPped and then gets skipped
-- or immediately aborts when start-tunnel-remap-all is run.
-- Run on the MAIN controller.

if turtle then error("Run this on the main controller.",0) end

local files = {
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/8e93e5fad24e08f799b513700b4ab1adf747560c/ActuallyUsefulTurtles/patches/turtle-receive.lua",
    marker="LABENHANCED_STALE_CHECKPOINT_RECOVERY",
    targets={"turtle/receive.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/start-tunnel-remap-all.lua",
    marker="recovering stale STOP",
    targets={"start-tunnel-remap-all"},
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

print("Cooperative remap STOP-latch fix installed.")
print("Reboot all four DTX turtles so receive.lua updates.")
print("Then run start-tunnel-remap-all again.")
