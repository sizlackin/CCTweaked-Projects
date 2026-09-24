-- Stops currently running direct mapper tasks on DTX turtles.
-- Run on the main controller.

if turtle then error("Run this on the main controller.",0) end
if not global or not global.node or not global.turtles then
	error("Actually Useful Turtles controller is not running.",0)
end

local count=0
for id,t in pairs(global.turtles) do
	local state=t and t.state
	local label=state and state.label or ""
	if state and state.online
	and type(label)=="string"
	and string.match(label,"^DTX%-") then
		global.node:send(id,{"STOP"},false,false)
		print("STOP sent to",label,"ID",id)
		count=count+1
	end
end
print("Stopped",count,"DTX turtle(s).")
