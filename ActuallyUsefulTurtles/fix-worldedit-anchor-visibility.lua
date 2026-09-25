-- Fix WorldEdit-style pos1/pos2 markers disappearing at some map quadrants/zooms.
-- Run on the MAIN CONTROLLER.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("gui") then error("Run this on the main controller.",0) end

local files = {
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/0542d947b4f10be21443077e1336f3fac6c8e7fe/ActuallyUsefulTurtles/patches/classMapDisplay.lua",
    marker="selectionAnchor",
    targets={"gui/classMapDisplay.lua","runtime/classMapDisplay.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/bda73b17999847ad5d7fb0a943b7ba36932faf56/ActuallyUsefulTurtles/patches/classTaskGroupSelector.lua",
    marker="selectionAnchor = true",
    targets={"gui/classTaskGroupSelector.lua","runtime/classTaskGroupSelector.lua"},
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

print("WorldEdit anchor visibility fix installed.")
print("Reboot the controller once.")
