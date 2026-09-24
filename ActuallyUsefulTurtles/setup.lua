-- Complete host installer for Actually Useful Turtles
-- Run this on a NEW control computer, NOT on a GPS computer or turtle.
local base = "https://raw.githubusercontent.com/helpmyRF24isntworking/computercraft/main/"
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
  "gui/classBasicWindow.lua",
  "gui/classBox.lua",
  "gui/classButton.lua",
  "gui/classCheckBox.lua",
  "gui/classChoiceSelector.lua",
  "gui/classFrame.lua",
  "gui/classGPU.lua",
  "gui/classHostDisplay.lua",
  "gui/classLabel.lua",
  "gui/classMapDisplay.lua",
  "gui/classMonitor.lua",
  "gui/classNumberInput.lua",
  "gui/classOptionSelector.lua",
  "gui/classPixelDrawer.lua",
  "gui/classScrollBar.lua",
  "gui/classStorageDisplay.lua",
  "gui/classStorageItemControl.lua",
  "gui/classTaskControl.lua",
  "gui/classTaskGroupControl.lua",
  "gui/classTaskGroupDetails.lua",
  "gui/classTaskGroupSelector.lua",
  "gui/classTaskList.lua",
  "gui/classTaskSelector.lua",
  "gui/classToggleButton.lua",
  "gui/classTurtleControl.lua",
  "gui/classTurtleDetails.lua",
  "gui/classTurtleList.lua",
  "gui/classWindow.lua",
  "host/classComplexTask.lua",
  "host/classLoadBalancer.lua",
  "host/classRecurringProject.lua",
  "host/classTaskAssignment.lua",
  "host/classTaskGroup.lua",
  "host/classTaskManager.lua",
  "host/display.lua",
  "host/global.lua",
  "host/hostTransfer.lua",
  "host/initialize.lua",
  "host/main.lua",
  "host/receive.lua",
  "host/send.lua",
  "host/startup.lua",
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

local function fetch(path)
  local url = base .. path
  for attempt = 1, 3 do
    local response, err = http.get(url)
    if response then
      local code = response.getResponseCode()
      if code == 200 then
        local contents = response.readAll()
        response.close()
        return contents
      end
      response.close()
      err = "HTTP " .. tostring(code)
    end
    print("Retry " .. attempt .. ": " .. path .. " (" .. tostring(err) .. ")")
    sleep(2)
  end
  error("Could not download " .. path .. "; run setup again to retry.", 0)
end

print("Installing Actually Useful Turtles host...")
print("GPS and modem must already be set up.")
for i, path in ipairs(files) do
  if not fs.exists(path) then
    local data = fetch(path)
    fs.makeDir(fs.getDir(path))
    local out = assert(fs.open(path, "w"))
    out.write(data)
    out.close()
  end
  if i % 10 == 0 or i == #files then
    print(i .. "/" .. #files .. " files ready")
  end
end

local mustExist = {
  "host/startup.lua", "general/utils.lua", "gui/classHostDisplay.lua",
  "host/classTaskManager.lua", "storage/classRemoteStorage.lua",
  "general/killRednet.lua", "host/hostTransfer.lua"
}
for _, path in ipairs(mustExist) do
  assert(fs.exists(path), "Missing: " .. path)
end
if fs.exists("startup.lua") then
  print("Existing startup.lua found; not overwriting it.")
  print("On a NEW computer, remove startup.lua manually and rerun setup.")
  return
end
fs.makeDir("runtime")
fs.copy("host/startup.lua", "startup.lua")
print("Install complete. Type: reboot")
