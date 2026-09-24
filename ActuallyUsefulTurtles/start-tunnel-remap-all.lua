-- Starts cooperative non-destructive tunnel mapping on all idle DTX turtles.
-- Frontier reservations on the controller prevent duplicate scanning.

if turtle then error("Run this on the main controller, not a turtle.",0) end
if not global or not global.node or not global.turtles then
	error("Actually Useful Turtles controller is not running.",0)
end

local candidates = {}
for id,t in pairs(global.turtles) do
	local state = t and t.state
	local label = state and state.label or ""
	if state and state.online
	and type(label) == "string"
	and string.match(label,"^DTX%-")
	and not state.task then
		candidates[#candidates+1] = {id=id,label=label}
	end
end

table.sort(candidates,function(a,b) return a.id < b.id end)

if #candidates == 0 then
	error("No online idle DTX turtles found.",0)
end

print("COOPERATIVE TUNNEL REMAP")
print("Radius: 2048 | Max new cells per turtle: 100000")
print("NO BLOCKS WILL BE MINED")
print("Frontiers are reserved so turtles do not duplicate scans.")

for _,entry in ipairs(candidates) do
	print("starting",entry.label,"ID",entry.id)
	global.node:send(
		entry.id,
		{"DO","remapTunnels",{2048,100000}},
		false,false
	)
	sleep(0)
end

print("Started",#candidates,"mapper turtle(s).")
