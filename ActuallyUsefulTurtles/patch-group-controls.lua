-- Fixes Task Group "opts" and "detail" freezes on the main controller.
-- Run at the normal CraftOS > prompt.
local files = {
  {
    url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classChoiceSelector.lua",
    targets = {"gui/classChoiceSelector.lua", "runtime/classChoiceSelector.lua"},
  },
  {
    url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classTaskGroupDetails.lua",
    targets = {"gui/classTaskGroupDetails.lua", "runtime/classTaskGroupDetails.lua"},
  },
}

if not fs.isDir("gui") then error("Run this on the main controller.", 0) end

for _, item in ipairs(files) do
  local response, err = http.get(item.url)
  if not response then error("Download failed: " .. tostring(err), 0) end
  if response.getResponseCode() ~= 200 then
    local code = response.getResponseCode()
    response.close()
    error("Download failed: HTTP " .. tostring(code), 0)
  end
  local data = response.readAll()
  response.close()
  if #data < 500 then error("Downloaded patch looks incomplete.", 0) end

  for _, target in ipairs(item.targets) do
    fs.makeDir(fs.getDir(target))
    local f = assert(fs.open(target, "w"))
    f.write(data)
    f.close()
    print("Patched " .. target)
  end
end

print("Group opts/detail fixes installed. Reboot the controller.")
