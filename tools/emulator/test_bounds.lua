-- Proves the bounded-remap frontier selection behaves as intended.
--
--   ./tools/emulate --test bounds
--
-- The graph is a straight east-west corridor. A box covers only the eastern
-- end. Both ends have an unmapped side branch, so the only correct answer for a
-- bounded request is the branch inside the box - reached by walking through
-- corridor nodes that lie OUTSIDE it.
--
--     x=0 .. x=4  corridor        box = x 3..5
--     ^ start                     ^ in-box branch (north from x=4)
--     ^ out-of-box branch (north from x=0)

package.path = table.concat({
	"/src/patch/?.lua", "/src/tunnelnav/?.lua", "/src/general/?.lua",
	"/src/gui/?.lua", "/src/host/?.lua", "/src/storage/?.lua", package.path,
}, ";")

local TunnelMap = require("classTunnelMap")

local log = fs.open("/test.log", "w")
local pass, fail = 0, 0
local function check(name, got, want)
	if got == want then
		pass = pass + 1
		log.writeLine(("PASS  %-46s %s"):format(name, tostring(got)))
	else
		fail = fail + 1
		log.writeLine(("FAIL  %-46s got %s want %s"):format(name, tostring(got), tostring(want)))
	end
	log.flush()
end

local map = TunnelMap:new()
local function pos(x, y, z) return { x = x, y = y, z = z } end

-- corridor x=0..4 at y=0,z=0, open both ways
for x = 0, 4 do map:ensureNode(pos(x, 0, 0)) end
for x = 0, 3 do
	map:_applyOne(pos(x, 0, 0), "east", TunnelMap.STATE.OPEN)
	map:_applyOne(pos(x + 1, 0, 0), "west", TunnelMap.STATE.OPEN)
end

-- one unmapped branch at each end
map:_applyOne(pos(0, 0, 0), "north", TunnelMap.STATE.UNMAPPED)  -- outside the box
map:_applyOne(pos(4, 0, 0), "north", TunnelMap.STATE.UNMAPPED)  -- inside the box

local BOX = { minX = 3, maxX = 5, minY = -1, maxY = 1, minZ = -2, maxZ = 2 }

-- 1. unbounded: nearest frontier to the start is the one at its own feet
local f = map:findNearestFrontier(pos(0, 0, 0), { maxNodes = 500 })
check("unbounded picks nearest frontier", f and f.source.x, 0)

-- 2. bounded: must skip it and walk east to the in-box branch
f = map:findNearestFrontier(pos(0, 0, 0), { bounds = BOX, maxNodes = 500 })
check("bounded skips the out-of-box frontier", f and f.source.x, 4)
check("bounded target is inside the box", f and f.target.x, 4)
check("bounded reached it through outside nodes", f and f.path and #f.path > 0, true)

-- 3. a box containing no unmapped work reports none, rather than wandering
local EMPTY = { minX = 20, maxX = 25, minY = -1, maxY = 1, minZ = -1, maxZ = 1 }
local f2, reason = map:findNearestFrontier(pos(0, 0, 0), { bounds = EMPTY, maxNodes = 500 })
check("empty box yields no frontier", f2, nil)
check("empty box reason", reason, "no_frontier")

-- 4. radius mode still behaves as before
f = map:findNearestFrontier(pos(0, 0, 0), { origin = pos(0, 0, 0), radius = 2, maxNodes = 500 })
check("radius mode still finds the near frontier", f and f.source.x, 0)
f = map:findNearestFrontier(pos(4, 0, 0), { origin = pos(4, 0, 0), radius = 1, maxNodes = 500 })
check("radius mode still excludes distant work", f and f.source.x, 4)

log.writeLine(("%d passed, %d failed"):format(pass, fail))
log.close()
os.shutdown()
