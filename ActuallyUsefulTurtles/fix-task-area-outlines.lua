-- Removes task-area outlines when groups complete, are cancelled, or deleted.
-- Also prevents duplicate outlines when a group is opened repeatedly.
-- Run on MAIN controller.

if turtle then error("Run this on the main controller.",0) end

local files = {
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/74586ccc672020276811f677aabe3f4e3cce1365/ActuallyUsefulTurtles/patches/classMapDisplay.lua",
    marker="LABENHANCED_AREA_LIFECYCLE",
    targets={"gui/classMapDisplay.lua","runtime/classMapDisplay.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/c9c98abf9ee91b2ef4f7931665fd05858ebda950/ActuallyUsefulTurtles/patches/classTaskGroupDetails.lua",
    marker="LABENHANCED_AREA_LIFECYCLE",
    targets={"gui/classTaskGroupDetails.lua","runtime/classTaskGroupDetails.lua"},
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

print("Task area lifecycle fix installed.")
print("Reboot the controller once to clear old untagged outlines.")
print("Future completed/cancelled/deleted groups remove their outline automatically.")
