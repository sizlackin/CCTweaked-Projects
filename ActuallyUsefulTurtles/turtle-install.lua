-- Clean turtle installer for Actually Useful Turtles.
-- Run on a brand-new mining turtle with a wireless/ender modem.
local raw = "https://raw.githubusercontent.com/helpmyRF24isntworking/computercraft/main/"
local patchedMiner = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classMiner.lua"
local files = {
  "general/blockColor.lua",
  "general/blockTranslation.lua",
  "general/bluenet.lua",
  "general/classBluenetNode.lua",
  "general/classBreadthFirstSearch.lua",
  "general/classChunkyMap.lua",
  "general/classHeap.lua",
  "general/classList.lua",
  "general/classLogger.lua",
  "general/classNetworkNode.lua",
  "general/classPathFinder.lua",
  "general/classQueue.lua",
  "general/classSimpleVector.lua",
  "general/classStateMap.lua",
  "general/config.lua",
  "general/killRednet.lua",
  "general/metadata.json",
  "general/utils.lua",
  "general/utilsSerialize.lua",
  "storage/classItemStorage.lua",
  "storage/classRemoteStorage.lua",
  "turtle/classCheckPointer.lua",
  "turtle/classMiner.lua",
  "turtle/classMinerTaskAssignment.lua",
  "turtle/classTaskQueue.lua",
  "turtle/classTurtleStorage.lua",
  "turtle/extTreeMining.lua",
  "turtle/extTurtleStorage.lua",
  "turtle/global.lua",
  "turtle/initialize.lua",
  "turtle/main.lua",
  "turtle/receive.lua",
  "turtle/send.lua",
  "turtle/startup.lua",
  "turtle/update.lua",
}
if not turtle then error("Run this on a turtle, not the controller.", 0) end
if fs.exists("startup.lua") then
  error("This turtle already has startup.lua. Stop: this installer is for new turtles only.", 0)
end
fs.makeDir("runtime")
print("Installing " .. #files .. " source files...")
local function fetch(path)
  local lastError
  for attempt = 1, 3 do
    local response, err = http.get(path == "turtle/classMiner.lua" and patchedMiner or (raw .. path))
    if response then
      if response.getResponseCode() == 200 then
        local data = response.readAll()
        response.close()
        return data
      end
      lastError = "HTTP " .. tostring(response.getResponseCode())
      response.close()
    else
      lastError = tostring(err)
    end
    sleep(2)
  end
  error("Download failed: " .. path .. " (" .. tostring(lastError) .. "). Run turtle-install again to retry.", 0)
end
for i, path in ipairs(files) do
  local dest = "runtime/" .. fs.getName(path)
  if path == "turtle/startup.lua" then
    -- Write startup LAST so a failed install never creates a boot loop.
  else
    local data = fetch(path)
    local temp = dest .. ".download"
    local output = assert(fs.open(temp, "w"))
    output.write(data)
    output.close()
    if fs.exists(dest) then fs.delete(dest) end
    fs.move(temp, dest)
  end
  if i % 10 == 0 then print(i .. "/" .. #files .. " files processed") end
end
-- Fix blockColor watchdog timeout before first boot.
do
  local target = "runtime/blockColor.lua"
  local f = assert(fs.open(target, "r"))
  local data = f.readAll()
  f.close()

  local old = "local dist = deltaEFromRGB(r, g, b, cr, cg, cb)"
  local new = "local dist = deltaE(r, g, b, cr, cg, cb) -- LABENHANCED_BLOCKCOLOR_FIX"
  local s, e = data:find(old, 1, true)
  if s then data = data:sub(1, s - 1) .. new .. data:sub(e + 1) end

  local old2 = "nameToBlit[name] = blitTab[best]\\n\\t\\tidToBlit[nameToId[name]] = blitTab[best]"
  local new2 = "nameToBlit[name] = blitTab[best]\\n\\t\\tlocal id = nameToId[name]\\n\\t\\tif id then idToBlit[id] = blitTab[best] end\\n\\t\\tsleep(0)"
  local s2, e2 = data:find(old2, 1, true)
  if s2 then data = data:sub(1, s2 - 1) .. new2 .. data:sub(e2 + 1) end

  local out = assert(fs.open(target, "w"))
  out.write(data)
  out.close()
end

-- Startup includes host synchronization, which updates all files as needed.
local startupData = fetch("turtle/startup.lua")
local output = assert(fs.open("startup.lua", "w"))
output.write(startupData)
output.close()
print("Turtle software installed. Leave host online, then reboot.")
