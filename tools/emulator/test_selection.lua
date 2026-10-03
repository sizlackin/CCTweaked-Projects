-- Proves that area-selection touches align only the axis established by a
-- tunnel crossing the character, while ordinary position selection and
-- ambiguous cells remain on the original coordinate grid.
--
--   ./tools/emulate --test selection

package.path = table.concat({
	"/emu/?.lua", "/src/patch/?.lua", "/src/tunnelnav/?.lua", "/src/general/?.lua",
	"/src/gui/?.lua", "/src/host/?.lua", "/src/storage/?.lua", package.path,
}, ";")

local log = fs.open("/test.log", "w")
local pass,fail = 0,0
local function check(name,got,want)
	if got == want then
		pass = pass + 1
		log.writeLine(("PASS  %-50s %s"):format(name,tostring(got)))
	else
		fail = fail + 1
		log.writeLine(("FAIL  %-50s got %s want %s"):format(name,tostring(got),tostring(want)))
	end
	log.flush()
end

local fakes = require("fakes")
_G.global = fakes.buildGlobal()
_G.config = fakes.config

local MapDisplay = require("classMapDisplay")
local TaskGroupSelector = require("classTaskGroupSelector")

local open = {}
local function key(x,z) return x .. ":" .. z end
local map = {
	getBlockId = function(_,x,y,z) return open[key(x,z)] and 0 or 1 end,
}
local function clear() open = {} end
local function tunnel(x,z) open[key(x,z)] = true end

-- With this centre and 10x8 map, mapX/mapZ are both zero. Character (3,2)
-- contains X=4,5 and Z=3,4,5 at 1:1.
local md = MapDisplay:new(1,1,10,8,map)
md:setMid(10,-59,12)

local rawX,rawZ = md:positionForCell(3,2,false)
check("ordinary click keeps the old X coordinate",rawX,4)
check("ordinary click keeps the old Z coordinate",rawZ,3)

clear()
for x=2,7 do tunnel(x,5) end
local x,z = md:positionForCell(3,2,true)
check("horizontal tunnel selects its hidden third row",z,5)
check("horizontal tunnel leaves X untouched",x,4)

clear()
for zz=1,7 do tunnel(5,zz) end
x,z = md:positionForCell(3,2,true)
check("vertical tunnel selects its hidden second column",x,5)
check("vertical tunnel leaves Z untouched",z,3)

clear()
for xx=2,5 do tunnel(xx,5) end
x,z = md:positionForCell(3,2,true)
check("horizontal endpoint supplies exact X",x,5)
check("horizontal endpoint supplies exact Z",z,5)

clear()
for zz=1,4 do tunnel(5,zz) end
x,z = md:positionForCell(3,2,true)
check("vertical endpoint supplies exact X",x,5)
check("vertical endpoint supplies exact Z",z,4)

clear()
for xx=2,7 do tunnel(xx,4) end
for zz=1,7 do tunnel(5,zz) end
x,z = md:positionForCell(3,2,true)
check("junction wins over a straight tunnel pixel X",x,5)
check("junction wins over a straight tunnel pixel Z",z,4)

clear()
x,z = md:positionForCell(3,2,true)
check("solid cell falls back to original X",x,4)
check("solid cell falls back to original Z",z,3)

-- A horizontal run and a separate vertical run can both occupy one 2x3
-- character without meeting. There is no honest way to infer which was hit.
clear()
for xx=2,4 do tunnel(xx,5) end
for zz=2,4 do tunnel(5,zz) end
x,z = md:positionForCell(3,2,true)
check("unrelated runs do not pull X",x,4)
check("unrelated runs do not pull Z",z,3)

-- At 1:2 the same character holds sampled X=8,10 and Z=6,8,10. Snapping
-- still chooses only a pixel that is actually visible on the zoomed map.
md.zoomLevel = 2
md:setMid(20,-59,24)
clear()
for xx=4,14 do tunnel(xx,10) end
x,z = md:positionForCell(3,2,true)
check("integer zoom selects a visible tunnel sample X",x,8)
check("integer zoom selects a visible tunnel sample Z",z,10)

md:selectPosition(true)
check("area selection arms axis alignment",md.selectionAlignToTunnel,true)
md:selectPosition()
check("ordinary selection disables axis alignment",md.selectionAlignToTunnel,false)

-- Fine controls always move one real block and follow the WorldEdit rule:
-- edit POS1 until POS2 exists, then leave POS1 locked and edit POS2.
local selector = setmetatable({
	selectionMode = true,
	positions = { {x=10,y=-59,z=20} },
	refresh = function() end,
	updateAreaPreview = function() end,
}, { __index = TaskGroupSelector })
selector:nudgeAreaPosition(-1,0)
check("X- nudges POS1 by one block",selector.positions[1].x,9)
selector:nudgeAreaPosition(0,1)
check("Z+ nudges POS1 by one block",selector.positions[1].z,21)

selector.positions[2] = {x=30,y=-59,z=40}
selector:nudgeAreaPosition(1,0)
selector:nudgeAreaPosition(0,-1)
check("fine controls lock POS1 after POS2 exists",selector.positions[1].x,9)
check("X+ nudges POS2 by one block",selector.positions[2].x,31)
check("Z- nudges POS2 by one block",selector.positions[2].z,39)

log.writeLine(("%d passed, %d failed"):format(pass,fail))
log.close()
os.shutdown()
