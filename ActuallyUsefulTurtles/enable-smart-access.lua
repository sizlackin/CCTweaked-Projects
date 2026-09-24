-- Installs shared smart mine access for Actually Useful Turtles.
-- Run on the MAIN controller at the normal CraftOS > prompt.
-- 2-4 turtle jobs reuse existing tunnels as far as possible. Only one turtle
-- creates the shared 1-wide x 2-high access corridor and in-box access spine.

local files = {
  {
    url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classTaskGroup.lua",
    targets = {"host/classTaskGroup.lua", "runtime/classTaskGroup.lua"},
  },
  {
    url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classMiner.lua",
    targets = {"turtle/classMiner.lua"},
  },
}

if turtle then
  error("Run this on the main Actually Useful Turtles controller.",0)
end
if not fs.isDir("host") or not fs.isDir("turtle") then
  error("Could not find host/turtle source folders on this controller.",0)
end

local function download(url)
  local response,err = http.get(url)
  if not response then error("Download failed: "..tostring(err),0) end
  local code = response.getResponseCode()
  if code ~= 200 then
    response.close()
    error("Download failed: HTTP "..tostring(code),0)
  end
  local data = response.readAll()
  response.close()
  if not data or #data < 5000 then error("Downloaded patch looks incomplete.",0) end
  return data
end

for _,entry in ipairs(files) do
  local data = download(entry.url)
  for _,path in ipairs(entry.targets) do
    fs.makeDir(fs.getDir(path))
    local f = assert(fs.open(path,"w"))
    f.write(data)
    f.close()
    print("Patched "..path)
  end
end

print("Smart shared mine access installed (supports 2-4 turtles).")
print("Reboot controller, then reboot DTX-001 through DTX-004.")
