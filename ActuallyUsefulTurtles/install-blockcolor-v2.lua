-- blockColor watchdog fix v2.
-- Run on the MAIN Actually Useful Turtles controller.
-- Uses a commit-pinned patched source to avoid stale raw.githubusercontent caching.

local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/4f1b12f4048581731deb6081048151c3a522ff66/ActuallyUsefulTurtles/patches/blockColor.lua"
local targets = {
  "general/blockColor.lua",
  "runtime/blockColor.lua",
}

if turtle then
  error("Run this on the main controller, not a turtle.",0)
end

local response,err = http.get(url)
if not response then error("Download failed: "..tostring(err),0) end
local code = response.getResponseCode()
if code ~= 200 then
  response.close()
  error("Download failed: HTTP "..tostring(code),0)
end

local data = response.readAll()
response.close()

if not data:find("LABENHANCED_BLOCKCOLOR_FIX",1,true)
or not data:find("LABENHANCED_BLOCKCOLOR_YIELD",1,true) then
  error("Downloaded blockColor v2 did not contain both watchdog markers.",0)
end

for _,target in ipairs(targets) do
  fs.makeDir(fs.getDir(target))
  local f = assert(fs.open(target,"w"))
  f.write(data)
  f.close()
  print("Patched "..target)
end

print("blockColor v2 installed successfully.")
print("Reboot controller, then reboot DTX-003 and DTX-004.")
