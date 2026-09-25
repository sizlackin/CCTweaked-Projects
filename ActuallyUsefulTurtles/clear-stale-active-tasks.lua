-- Clears ghost "active" mining assignments after a checkpoint reboot.
-- Only touches ONLINE turtles which currently report no live task stack.
-- Run on the MAIN controller.

if turtle then error("Run this on the main controller.",0) end
if not global or not global.taskManager or not global.turtles then
  error("Actually Useful Turtles controller is not running.",0)
end

local cleared = {}
local groupsChanged = 0

for _,group in pairs(global.taskManager.groups or {}) do
  local changed = false
  for _,task in ipairs(group.tasks or {}) do
    local t = global.turtles[task.turtleId]
    local state = t and t.state
    local status = task.status

    if state and state.online and state.task == nil
    and status ~= "completed" and status ~= "deleted"
    and status ~= "cancelled" then
      print("CLEARING STALE",state.label or task.turtleId,
        "task",task.shortId or task.id)
      global.node:send(
        task.turtleId,
        {"FORCE_CLEAR_STALE_TASK",task.id},
        false,false
      )
      task:setStatus("cancelled")
      cleared[task.turtleId] = true
      changed = true
    end
  end

  if changed then
    group:setStatus("cancelled")
    groupsChanged = groupsChanged + 1
  end
end

if global.taskManager.save then global.taskManager:save() end

local count = 0
for _ in pairs(cleared) do count = count + 1 end
print("Cleared",count,"stale turtle assignment(s) in",
  groupsChanged,"group(s).")

if count > 0 then
  print("Rebooting cleared turtles so they start with no stale checkpoint...")
  sleep(0.5)
  for id in pairs(cleared) do
    global.node:send(id,{"REBOOT"},false,false)
    sleep(0.1)
  end
else
  print("No stale idle assignments found.")
end
