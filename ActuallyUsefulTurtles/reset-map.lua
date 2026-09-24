-- Clears ONLY Actually Useful Turtles map data.
-- Does not delete stations, tasks, labels, config, or turtle homes.

local isTurtle = turtle ~= nil
local targets = {
  "runtime/map/multichunks",
  "runtime/map/chunks",
  "runtime/map.txt",
}

print("Clearing Actually Useful Turtles map data...")
for _,path in ipairs(targets) do
  if fs.exists(path) then
    fs.delete(path)
    print("deleted "..path)
  end
end

-- Recreate the expected parent folder.
if not fs.exists("runtime/map") then fs.makeDir("runtime/map") end

if isTurtle then
  print("Map cleared. Shutting turtle down to keep it clean.")
  print("Turn it back on AFTER the controller map has been reset.")
  sleep(1)
  os.shutdown()
else
  print("Controller map cleared. Rebooting now.")
  sleep(1)
  os.reboot()
end
