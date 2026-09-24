-- Starts a large non-destructive tunnel remap.
-- Run on the MAIN Actually Useful Turtles controller.
-- Uses the shared tunnel graph mapper for a mine-scale survey.
-- Prefers DTX-001 / computer ID 12.

if turtle then
  error("Run this on the main controller, not a turtle.", 0)
end

if not global or not global.node or not global.turtles then
  error("Actually Useful Turtles controller is not running.", 0)
end

local chosenId = nil

local preferred = global.turtles[12]
if preferred and preferred.state and preferred.state.online then
  chosenId = 12
else
  for id,t in pairs(global.turtles) do
    local state = t and t.state
    if state and state.online and state.label == "DTX-001" then
      chosenId = id
      break
    end
  end
end

if not chosenId then
  local ids = {}
  for id,t in pairs(global.turtles) do
    local state = t and t.state
    if state and state.online and not state.task then
      ids[#ids+1] = id
    end
  end
  table.sort(ids)
  chosenId = ids[1]
end

if not chosenId then
  error("No online idle turtle found. Turn on DTX-001 first.", 0)
end

local t = global.turtles[chosenId]
local state = t and t.state
if state and state.task then
  error("Turtle "..chosenId.." is busy with: "..tostring(state.task), 0)
end

print("Starting LARGE non-destructive tunnel remap on turtle "..chosenId)
print("Radius: 1024  Max cells: 50000")
print("NO BLOCKS WILL BE MINED")

global.node:send(chosenId, {"DO", "remapTunnels", {1024,50000}}, false, false)
print("Large remap command sent.")
