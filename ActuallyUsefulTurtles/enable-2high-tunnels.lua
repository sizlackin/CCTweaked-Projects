-- Makes Actually Useful Turtles mine 2-block-high horizontal tunnels.
-- Run on EACH TURTLE at the normal CraftOS > prompt.
local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classMiner.lua"
local targets = {"runtime/classMiner.lua", "turtle/classMiner.lua"}

local response, err = http.get(url)
if not response then error("Download failed: " .. tostring(err), 0) end
if response.getResponseCode() ~= 200 then
  local code = response.getResponseCode()
  response.close()
  error("Download failed: HTTP " .. tostring(code), 0)
end

local data = response.readAll()
response.close()
if #data < 5000 then error("Downloaded classMiner patch looks incomplete.", 0) end

for _, target in ipairs(targets) do
  fs.makeDir(fs.getDir(target))
  local f = assert(fs.open(target, "w"))
  f.write(data)
  f.close()
  print("Patched " .. target)
end

print("2-block-high tunnels enabled. Reboot this turtle.")
