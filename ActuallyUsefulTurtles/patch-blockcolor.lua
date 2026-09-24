-- Installs the fully patched Actually Useful Turtles blockColor.lua.
-- Run on the HOST/controller computer.

local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/blockColor.lua"
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

if not data:find("LABENHANCED_BLOCKCOLOR_YIELD",1,true) then
  error("Downloaded blockColor patch is missing the watchdog fix.",0)
end

for _,path in ipairs(targets) do
  fs.makeDir(fs.getDir(path))
  local f = assert(fs.open(path,"w"))
  f.write(data)
  f.close()
  print("Patched "..path)
end

print("blockColor watchdog fix installed.")
print("Reboot the controller, then reboot the turtles.")
