-- WorldEdit-style area selector:
--   first map click  = pos1 (green)
--   second map click = pos2 (magenta) + red outline
--   later clicks     = move pos2 and redraw red outline
--   DESELECT         = leave edit mode but keep current selection
--   CONFIRM          = accept selection and return to group setup
-- Run on the MAIN CONTROLLER.

if turtle then error("Run this on the main controller.",0) end
if not fs.isDir("gui") then error("Run this on the main controller.",0) end

local url="https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/74395c21c7285a004abd3641cdef99b02a03b1d2/ActuallyUsefulTurtles/patches/classTaskGroupSelector.lua"
local targets={"gui/classTaskGroupSelector.lua","runtime/classTaskGroupSelector.lua"}

local r,e=http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code=r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data=r.readAll(); r.close()

if not data:find("LABENHANCED_WORLDEDIT_AREA_SELECT",1,true)
or not data:find('"DESELECT"',1,true)
or not data:find("colors.magenta",1,true)
or not data:find("colors.red",1,true) then
  error("Downloaded selector is missing the WorldEdit-style selection patch.",0)
end

for _,target in ipairs(targets) do
  fs.makeDir(fs.getDir(target))
  local f=assert(fs.open(target,"w"))
  f.write(data)
  f.close()
  print("Patched "..target)
end

print("WorldEdit-style area selection installed.")
print("Reboot the controller once.")
