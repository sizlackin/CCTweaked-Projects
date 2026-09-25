-- One-shot recovery for DTX-002 / DTX-003 only.
-- IDs: 14 and 15. Leaves DTX-001 and DTX-004 untouched.
-- Run on the MAIN controller.

if turtle then error("Run this on the main controller.",0) end
if not global or not global.taskManager or not global.node then
  error("Actually Useful Turtles controller is not running.",0)
end

local targets = {[14]=true,[15]=true}
local affectedGroups = {}
local clearedTasks = 0

-- Clear only controller-side assignments belonging to DTX-002 / DTX-003.
for _,task in pairs(global.taskManager.tasks or {}) do
  if targets[task.turtleId] then
    local status = task.status
    if status ~= "completed" and status ~= "deleted"
    and status ~= "cancelled" then
      print("CONTROLLER CLEAR",task.turtleId,task.shortId or task.id,status)
      task:setStatus("cancelled")
      global.taskManager.cancelledTasks[task.id] = task
      if task.groupId then affectedGroups[task.groupId] = true end
      clearedTasks = clearedTasks + 1
    end
  end
end

-- The old mining group is no longer resumable as a coherent 4-turtle job once
-- two members are hard-reset, so mark the group itself cancelled. Do not alter
-- tasks belonging to DTX-001 or DTX-004.
for groupId in pairs(affectedGroups) do
  local group = global.taskManager.groups and global.taskManager.groups[groupId]
  if group then group:setStatus("cancelled") end
end

global.taskManager:save()

-- Clear dashboard cache for just 002/003 immediately.
for id in pairs(targets) do
  local t = global.turtles and global.turtles[id]
  if t and t.state then
    t.state.task = nil
    t.state.lastTask = nil
    t.state.assignment = nil
    t.state.progress = nil
  end
end

print("HARD RESET DTX-002 / DTX-003...")
for _,id in ipairs({14,15}) do
  global.node:send(id,{"FORCE_CLEAR_STALE_TASK",nil,true},false,false)
  sleep(0.2)
end

print("Controller records cleared:",clearedTasks)
print("DTX-001 and DTX-004 were not touched.")
print("DTX-002 and DTX-003 will reboot themselves clean.")
print("Wait 5-10 seconds, then verify both show 'saving 0 tasks'.")
