-- Stops DTX-001 / computer ID 12 during the large tunnel remap.
-- Run on the MAIN controller.

if turtle then error("Run this on the main controller.",0) end
if not global or not global.node then
  error("Actually Useful Turtles controller is not running.",0)
end

global.node:send(12,{"STOP"},false,false)
print("STOP sent to DTX-001 (ID 12).")
