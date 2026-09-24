-- Enables coordinated two-turtle mining.
-- Run on the MAIN CONTROLLER, then run again on EACH TURTLE.
local hostUrl = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classTaskGroup.lua"
local minerUrl = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classMiner.lua"

local function fetch(url)
  local r, err = http.get(url)
  if not r then error("Download failed: " .. tostring(err), 0) end
  if r.getResponseCode() ~= 200 then
    local code = r.getResponseCode()
    r.close()
    error("Download failed: HTTP " .. tostring(code), 0)
  end
  local data = r.readAll()
  r.close()
  return data
end

local function writeFile(path, data)
  fs.makeDir(fs.getDir(path))
  local f = assert(fs.open(path, "w"))
  f.write(data)
  f.close()
  print("Patched " .. path)
end

if fs.isDir("host") then
  local data = fetch(hostUrl)
  writeFile("host/classTaskGroup.lua", data)
  writeFile("runtime/classTaskGroup.lua", data)
  print("Controller paired-mining patch installed.")
elseif turtle then
  local data = fetch(minerUrl)
  writeFile("runtime/classMiner.lua", data)
  if fs.isDir("turtle") then writeFile("turtle/classMiner.lua", data) end
  print("Turtle coordinated-path patch installed.")
else
  error("Run this on the main controller or a mining turtle.", 0)
end

print("Reboot this computer.")
