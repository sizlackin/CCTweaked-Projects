-- Explicitly clears ghost/reboot-restored task assignments.
-- Run on the MAIN controller only when turtles are visibly idle/stuck in a
-- checkpoint-restored state. This is intentionally a hard recovery.

if turtle then error("Run this on the main controller.",0) end
if not global or not global.taskManager or not global.turtles or not global.node then
  error("Actually Useful Turtles controller is not running.",0)
end

local cleared = {}
local affectedGroups = {}

for _,task in pairs(global.taskManager.tasks or {}) do
  local t = global.turtles[task.turtleId]
  local state = t and t.state
  local status = task.status

  if state and state.online
  and status ~= "completed" and status ~= "deleted"
  and status ~= "cancelled" then
    -- LABENHANCED_HARD_STALE_RESET
    -- The old utility required state.task == nil. A restored checkpoint itself
    -- populates state.task, which is exactly why those ghosts were never found.
    print("HARD CLEAR",state.label or task.turtleId,
      task.shortId or task.id,status)

    task:setStatus("cancelled")
    global.taskManager.cancelledTasks[task.id] = task
    if task.groupId then affectedGroups[task.groupId] = true end

    cleared[task.turtleId] = true
  end
end

for groupId in pairs(affectedGroups) do
  local group = global.taskManager.groups and global.taskManager.groups[groupId]
  if group then group:setStatus("cancelled") end
end

global.taskManager:save()

local count=0
for id in pairs(cleared) do
  count=count+1
  local t=global.turtles[id]
  if t and t.state then
    t.state.task=nil
    t.state.lastTask=nil
    t.state.assignment=nil
    t.state.progress=nil
  end
  global.node:send(id,{"FORCE_CLEAR_STALE_TASK",nil,true},false,false)
  sleep(0.15)
end

print("Hard-cleared",count,"turtle assignment(s).")
if count == 0 then
  print("No nonterminal online assignments found.")
else
  print("Affected turtles will reboot themselves clean.")
end
