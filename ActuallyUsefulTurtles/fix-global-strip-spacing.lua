-- Keep mineArea strip tunnels on one global 3-block lane grid.
-- Run on the MAIN controller.
--
-- Result:
--   * parallel mining tunnels are exactly 3 blocks center-to-center
--   * therefore exactly TWO solid blocks remain between parallel tunnels
--   * turtle assignment boundaries no longer reset spacing and create redundant
--     one-block gaps
--   * all turtles share the same global row phase across the whole selection
--   * each turtle still keeps its own non-overlapping work stripe
--   * row connector turns are derived from the actual stripe direction instead
--     of assuming the same left turn from every starting corner
--
-- Recreate an already-started mineArea group. Its old task assignments do not
-- contain the global lane coordinates.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("host") or not fs.isDir("turtle") then
  error("Could not find host/turtle source folders on this controller.",0)
end

local files = {
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/34bd434a90634808839a2ea8ce17b6ee5da01c42/ActuallyUsefulTurtles/patches/classTaskGroup.lua",
    marker="LABENHANCED_GLOBAL_STRIP_GRID",
    targets={"host/classTaskGroup.lua","runtime/classTaskGroup.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/dfe2a949d516dbf6487bdf90acc4b0959782e56e/ActuallyUsefulTurtles/patches/classMiner.lua",
    marker="LABENHANCED_GLOBAL_STRIP_GRID",
    targets={"turtle/classMiner.lua"},
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

print("Global strip spacing installed.")
print("Reboot controller and mining turtles.")
print("Cancel/recreate the mineArea group.")
print("No tunnel-map reset is required.")
