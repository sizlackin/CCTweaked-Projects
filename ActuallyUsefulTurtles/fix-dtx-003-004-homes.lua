-- Corrects the saved home-station ownership for DTX-003 / DTX-004.
-- DTX-003 = computer ID 15 -> -89,-59,730
-- DTX-004 = computer ID 16 -> -89,-59,731
-- Run on the MAIN controller.

if turtle then error("Run this on the main controller.",0) end
if not global or not config or not config.stations or not config.stations.turtles then
  error("Actually Useful Turtles controller/stations are not loaded.",0)
end

local desired = {
  [15] = {x=-89,y=-59,z=730,label="DTX-003"},
  [16] = {x=-89,y=-59,z=731,label="DTX-004"},
}

local found = {}

-- Remove any stale/duplicate ownership for these two IDs first.
for _,s in pairs(config.stations.turtles) do
  if s.id == 15 or s.id == 16 then
    s.id = nil
    s.occupied = false
  end
end

-- Assign the exact intended stations.
for _,s in pairs(config.stations.turtles) do
  if s.pos then
    for id,d in pairs(desired) do
      if s.pos.x == d.x and s.pos.y == d.y and s.pos.z == d.z then
        s.id = id
        s.occupied = true
        found[id] = true
      end
    end
  end
end

for id,d in pairs(desired) do
  if not found[id] then
    error(("Missing turtle station for %s (ID %d) at %d %d %d")
      :format(d.label,id,d.x,d.y,d.z),0)
  end
end

global.saveStations()

print("HOME STATIONS FIXED:")
print("DTX-003 (15) -> -89 -59 730")
print("DTX-004 (16) -> -89 -59 731")
print("")
print("Rebooting DTX-003 and DTX-004 so they request the corrected homes...")

if global.node then
  global.node:send(15,{"REBOOT"},false,false)
  sleep(0.2)
  global.node:send(16,{"REBOOT"},false,false)
end

print("Done.")
print("If the two physical turtle blocks are still standing in each other's slots,")
print("pick them up and place DTX-003 at z=730 and DTX-004 at z=731.")
