-- Fix Task > Options > call home so it immediately pauses the active
-- assignment and sends the group's turtles home.
-- Run on the MAIN Actually Useful Turtles controller.

local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classTaskGroup.lua"
local targets = {
  "host/classTaskGroup.lua",
  "runtime/classTaskGroup.lua",
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

if not data:find("LABENHANCED_IMMEDIATE_GROUP_HOME",1,true) then
  error("Downloaded TaskGroup is missing the immediate-home fix.",0)
end
if not data:find("LABENHANCED_SHARED_MINE_ENTRANCE",1,true) then
  error("Downloaded TaskGroup is missing the smart-access patch.",0)
end

for _,target in ipairs(targets) do
  local f = assert(fs.open(target,"w"))
  f.write(data)
  f.close()
  print("Patched "..target)
end

print("Task group Home fix installed.")
print("Reboot the main controller. Turtle reboot is not required for this fix.")
