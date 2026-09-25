-- Measures how far the red selection outline can sit from the blocks that are
-- actually mined, at each zoom level.
--
--   ./tools/emulate --test outline
--
-- transformSubPos maps a block to the PIXEL containing it:
--     x = floor((pos.x - mapX) / zoomLevel) + 1
-- At 1:1 that is exact. Zoomed out, one pixel covers zoomLevel blocks, so the
-- outline pixel for the boundary block also covers blocks outside the
-- selection - which reads as "the outline isn't dug".

package.path = table.concat({
	"/src/patch/?.lua", "/src/tunnelnav/?.lua", "/src/general/?.lua",
	"/src/gui/?.lua", "/src/host/?.lua", "/src/storage/?.lua", package.path,
}, ";")

local log = fs.open("/test.log", "w")
local function say(s) log.writeLine(s); log.flush() end

-- the transform under test, lifted verbatim from MapDisplay:transformSubPos
local function transformSubPos(pos, mapX, mapZ, zoomLevel)
	local varX = pos.x - mapX
	local varZ = pos.z - mapZ
	return math.floor(varX / zoomLevel) + 1, math.floor(varZ / zoomLevel) + 1
end

-- which blocks does a given pixel column cover?
local function blocksInPixel(px, mapX, zoomLevel)
	local first = (px - 1) * zoomLevel + mapX
	return first, first + zoomLevel - 1
end

-- the fix under test, lifted verbatim from MapDisplay:insidePixelRange
local function insidePixelRange(a, b, origin, zoom)
	local lo, hi = math.min(a, b), math.max(a, b)
	local first = math.ceil((lo - origin) / zoom) + 1
	local last = math.floor((hi - origin + 1) / zoom)
	if first > last then
		first = math.floor((lo - origin) / zoom) + 1
		last = math.floor((hi - origin) / zoom) + 1
	end
	return first, last
end

local mapX, mapZ = 0, 0
local selStart, selFinish = { x = 10, z = 0 }, { x = 37, z = 0 }

say(("selection blocks x=%d..%d  (%d wide)")
	:format(selStart.x, selFinish.x, selFinish.x - selStart.x + 1))
say("")
say("zoom | outline px | those px cover blocks | overshoot beyond selection")
say("-----+------------+-----------------------+---------------------------")

local worst = 0
for _, zoom in ipairs({ 1, 2, 3, 4, 8 }) do
	local sx = transformSubPos(selStart, mapX, mapZ, zoom)
	local ex = transformSubPos(selFinish, mapX, mapZ, zoom)
	local loFirst = blocksInPixel(sx, mapX, zoom)
	local _, hiLast = blocksInPixel(ex, mapX, zoom)

	local before = selStart.x - loFirst      -- blocks drawn left of the selection
	local after = hiLast - selFinish.x       -- blocks drawn right of it
	local over = math.max(before, after)
	if over > worst then worst = over end

	say(("1:%-2d | %3d..%-3d   | %4d..%-4d            | %d before, %d after")
		:format(zoom, sx, ex, loFirst, hiLast, before, after))
end

say("")
if worst == 0 then
	say("RESULT: outline always exact")
else
	say(("RESULT: outline can cover up to %d blocks that are never mined"):format(worst))
	say("        exact only at 1:1; error grows with zoom-out")
end

say("")
say("AFTER FIX - outline uses only pixels wholly inside the selection")
say("zoom | outline px | those px cover blocks | outside selection?")
say("-----+------------+-----------------------+-------------------")
local bad = 0
for _, zoom in ipairs({ 1, 2, 3, 4, 8 }) do
	local sx, ex = insidePixelRange(selStart.x, selFinish.x, mapX, zoom)
	local loFirst = blocksInPixel(sx, mapX, zoom)
	local _, hiLast = blocksInPixel(ex, mapX, zoom)
	local outside = (loFirst < selStart.x) or (hiLast > selFinish.x)
	if outside then bad = bad + 1 end
	say(("1:%-2d | %3d..%-3d   | %4d..%-4d            | %s")
		:format(zoom, sx, ex, loFirst, hiLast, outside and "YES - BUG" or "no"))
end
say("")
if bad == 0 then
	say("RESULT: every block under the outline is inside the mined selection")
else
	say(("RESULT: %d zoom levels still paint unmined blocks"):format(bad))
end
log.close()
os.shutdown()
