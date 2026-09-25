-- Fix WorldEdit-style selection outlines glitching over tunnel colors.
-- Run on the MAIN controller.
--
-- The live red selection outline is composited after PixelDrawer terrain
-- rendering, so tunnel/floor colors can no longer quantize pieces of it away.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("gui") then error("Could not find gui source folder.",0) end

local files = {
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/b7828cfe6aeb019650aa29e2a971bb2f95b826ca/ActuallyUsefulTurtles/patches/classMapDisplay.lua",
    marker="LABENHANCED_PRECISE_SELECTION_OUTLINE",
    targets={"gui/classMapDisplay.lua","runtime/classMapDisplay.lua"},
  },
  {
    url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/4c49e6f2b06b7d182e0792157cd28d64c311ba67/ActuallyUsefulTurtles/patches/classTaskGroupSelector.lua",
    marker="selectionOutline = true",
    targets={"gui/classTaskGroupSelector.lua","runtime/classTaskGroupSelector.lua"},
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

print("Precise selection overlay installed.")
print("Reboot the controller once.")
