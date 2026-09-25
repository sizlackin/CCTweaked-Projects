-- One-shot recovery for DTX-002/003/004 ghost checkpoint tasks.
-- IDs: 14, 15, 16. Run on MAIN controller.

if turtle then error("Run this on the main controller.",0) end
if not global or not global.taskManager or not global.node then
  error("Actually Useful Turtles controller is not running.",0)
end

local targets = {[14]=true,[15]=true,[16]=true}
local affectedGroups = {}
local clearedTasks = 0

-- Cancel controller-side task records first so they cannot be resurrected on
-- the next controller reboot.
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

for groupId in pairs(affectedGroups) do
  local group = global.taskManager.groups and global.taskManager.groups[groupId]
  if group then
    group:setStatus("cancelled")
    -- This broken mining group should be recreated fresh. Mark every remaining
    -- nonterminal assignment in it cancelled, including a clean leader record.
    for _,task in ipairs(group.tasks or {}) do
      local status = task.status
      if status ~= "completed" and status ~= "deleted"
      and status ~= "cancelled" then
        task:setStatus("cancelled")
        global.taskManager.cancelledTasks[task.id] = task
      end
    end
  end
end

global.taskManager:save()

-- Clear UI cache immediately; live streams will repopulate after reboot.
for id in pairs(targets) do
  local t = global.turtles and global.turtles[id]
  if t and t.state then
    t.state.task = nil
    t.state.lastTask = nil
    t.state.assignment = nil
    t.state.progress = nil
  end
end

print("Sending HARD checkpoint reset to DTX-002/003/004...")
for _,id in ipairs({14,15,16}) do
  global.node:send(id,{"FORCE_CLEAR_STALE_TASK",nil,true},false,false)
  sleep(0.15)
end

print("Controller records cleared:",clearedTasks)
print("DTX-002/003/004 will reboot themselves clean.")
print("Wait about 5-10 seconds; dashboard active count should fall to 0.")
print("Then delete/recreate the failed mining group before starting again.")
