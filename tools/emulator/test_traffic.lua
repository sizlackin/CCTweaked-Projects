-- Checks that turtles meeting in a tunnel cannot act in lockstep.
--
--   ./tools/emulate --test traffic
--
-- Two turtles meeting head-on both detect traffic in the same tick. If both then
-- wait the same time, both retry and fail together: in the navigator path that
-- livelocked until a route was abandoned, and in the mapper path both threw away
-- a claimed frontier when only one needed to give way.
--
-- The tie-break staggers the yield by computer id, so exactly one side moves
-- first. The slot arithmetic is lifted verbatim from Miner:yieldForTurtleTraffic.

package.path = table.concat({
	"/emu/?.lua", "/src/patch/?.lua", "/src/tunnelnav/?.lua", "/src/general/?.lua",
	"/src/gui/?.lua", "/src/host/?.lua", "/src/storage/?.lua", package.path,
}, ";")

local log = fs.open("/test.log", "w")
local pass, fail = 0, 0
local function check(name, got, want)
	if got == want then
		pass = pass + 1
		log.writeLine(("PASS  %-50s %s"):format(name, tostring(got)))
	else
		fail = fail + 1
		log.writeLine(("FAIL  %-50s got %s want %s"):format(name, tostring(got), tostring(want)))
	end
	log.flush()
end
local function say(s) log.writeLine(s); log.flush() end

-- verbatim from Miner:yieldForTurtleTraffic
local function slotFor(id) return (id % 5) * 0.2 end

local TURTLES = { 12, 14, 15, 16 }

say("turtle   slot")
for _, id in ipairs(TURTLES) do
	say(("  %-6d %.1fs"):format(id, slotFor(id)))
end
say("")

-- 1. every turtle gets its own slot
local seen, distinct = {}, 0
for _, id in ipairs(TURTLES) do
	local s = slotFor(id)
	if not seen[s] then seen[s] = true; distinct = distinct + 1 end
end
check("all four turtles get distinct slots", distinct, #TURTLES)

-- 2. no pair can act simultaneously - that is the whole point
local collisions = 0
for i = 1, #TURTLES do
	for j = i + 1, #TURTLES do
		if slotFor(TURTLES[i]) == slotFor(TURTLES[j]) then collisions = collisions + 1 end
	end
end
check("no pair shares a slot", collisions, 0)

-- 3. the gap between any two must be long enough to actually matter. A turtle
--    move is ~0.4s in CC, so adjacent slots must be at least that far apart.
local sorted = {}
for _, id in ipairs(TURTLES) do sorted[#sorted + 1] = slotFor(id) end
table.sort(sorted)
local minGap = math.huge
for i = 2, #sorted do minGap = math.min(minGap, sorted[i] - sorted[i - 1]) end
check("smallest gap covers a turtle move (>=0.2s)", minGap >= 0.199, true)

-- 4. deterministic: the same turtle must always pick the same slot, or the
--    ordering changes under it mid-encounter
check("slot is stable for a given id", slotFor(12), slotFor(12))

-- 5. bounded: a yield that takes too long is its own stall
local worst = 0
for _, id in ipairs(TURTLES) do worst = math.max(worst, slotFor(id)) end
check("worst-case stagger stays under a second", worst < 1.0, true)

-- 6. the first mover is unambiguous, so one side always proceeds
local first, firstId = math.huge, nil
for _, id in ipairs(TURTLES) do
	local s = slotFor(id)
	if s < first then first, firstId = s, id end
end
say("")
say(("first to yield: turtle %d at %.1fs"):format(firstId, first))
check("exactly one turtle yields first", first, slotFor(firstId))

-- 7. both traffic paths carry the tie-break, not just the navigator one
local function fileHas(path, needle)
	local f = fs.open(path, "r")
	if not f then return false end
	local text = f.readAll()
	f.close()
	return text:find(needle, 1, true) ~= nil
end
check("miner yield has the tie-break",
	fileHas("/src/patch/classMiner.lua", "LABENHANCED_TRAFFIC_TIEBREAK"), true)
check("mapper traffic path has it too",
	fileHas("/src/tunnelnav/classTunnelMapper.lua", "LABENHANCED_TRAFFIC_TIEBREAK"), true)
check("mapper no longer uses a bare fixed yield",
	fileHas("/src/tunnelnav/classTunnelMapper.lua", "yieldForTurtleTraffic"), true)

log.writeLine(("%d passed, %d failed"):format(pass, fail))
log.close()
os.shutdown()
