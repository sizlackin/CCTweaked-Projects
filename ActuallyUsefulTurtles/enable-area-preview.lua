-- Adds WorldEdit-style persistent area selection to Groups > Create > Select area.
-- Run this on the MAIN CONTROLLER at the normal CraftOS > prompt.
local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/74395c21c7285a004abd3641cdef99b02a03b1d2/ActuallyUsefulTurtles/patches/classTaskGroupSelector.lua"
local targets = {"gui/classTaskGroupSelector.lua", "runtime/classTaskGroupSelector.lua"}

if not fs.isDir("gui") then error("Run this on the main controller.", 0) end

local r, err = http.get(url)
if not r then error("Download failed: " .. tostring(err), 0) end
if r.getResponseCode() ~= 200 then
  local code = r.getResponseCode()
  r.close()
  error("Download failed: HTTP " .. tostring(code), 0)
end

local data = r.readAll()
r.close()
if #data < 3000 then error("Downloaded patch looks incomplete.", 0) end
if not data:find("LABENHANCED_WORLDEDIT_AREA_SELECT", 1, true)
or not data:find('"DESELECT"', 1, true)
or not data:find('"CONFIRM"', 1, true) then
  error("Downloaded patch does not contain the WorldEdit-style area controls.", 0)
end

for _, path in ipairs(targets) do
  fs.makeDir(fs.getDir(path))
  local f = assert(fs.open(path, "w"))
  f.write(data)
  f.close()
  print("Patched " .. path)
end

print("WorldEdit-style area preview + DESELECT/CONFIRM controls enabled. Reboot the controller.")
