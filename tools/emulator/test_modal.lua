-- Reproduces the "not first" list corruption from opening/closing the new-group
-- dialog too quickly, and proves the guards fix it.
--
--   ./tools/emulate --test modal
--
-- List:remove deliberately leaves a removed node's _prev/_next intact (they are
-- cleared on add), so removing the same node twice corrupts the list: the second
-- remove sees stale pointers and dies with "not first". The dialog unlinks the
-- page's close button on open and relinks it on close, so anything that opens
-- twice, or closes twice, hit exactly that.

package.path = table.concat({
	"/emu/?.lua", "/src/patch/?.lua", "/src/tunnelnav/?.lua", "/src/general/?.lua",
	"/src/gui/?.lua", "/src/host/?.lua", "/src/storage/?.lua", package.path,
}, ";")

local log = fs.open("/test.log", "w")
local pass, fail = 0, 0
local function check(name, got, want)
	if got == want then
		pass = pass + 1
		log.writeLine(("PASS  %-52s %s"):format(name, tostring(got)))
	else
		fail = fail + 1
		log.writeLine(("FAIL  %-52s got %s want %s"):format(name, tostring(got), tostring(want)))
	end
	log.flush()
end

local fakes = require("fakes")
_G.global = fakes.buildGlobal()
_G.config = fakes.config

local Window = require("classWindow")
local TaskGroupSelector = require("classTaskGroupSelector")

-- how many times does a node appear in the window's object list?
local function occurrences(win, target)
	local n, node, guard = 0, win.objects.first, 0
	while node and guard < 10000 do
		if node == target then n = n + 1 end
		node = node._next
		guard = guard + 1
	end
	return n, guard
end

local page = Window:new(1, 1, 57, 38)
local btnClose = page.btnClose
check("close button starts in the list", (occurrences(page, btnClose)), 1)

-- open two dialogs back to back, as double-tapping "create +" used to
local a = TaskGroupSelector:new(1, 1, global.taskManager, false)
page:addObject(a)
a:centerIn(page)
check("after first open, close button unlinked", (occurrences(page, btnClose)), 0)

local b = TaskGroupSelector:new(1, 1, global.taskManager, false)
page:addObject(b)
b:centerIn(page)
check("second open does not unlink it again", (occurrences(page, btnClose)), 0)
check("only the first dialog owns the restore", b.closeOwner, nil)

-- close both, then close one again
local okA = pcall(function() a:close() end)
check("closing the owner succeeds", okA, true)
check("close button relinked exactly once", (occurrences(page, btnClose)), 1)

local okB = pcall(function() b:close() end)
check("closing the non-owner succeeds", okB, true)
check("still exactly one close button", (occurrences(page, btnClose)), 1)

local okA2 = pcall(function() a:close() end)
check("closing an already-closed dialog is a no-op", okA2, true)
check("list still holds one close button", (occurrences(page, btnClose)), 1)

-- the list must still be walkable: a corrupted one loops or dies
local _, walked = occurrences(page, btnClose)
check("object list is not cyclic", walked < 100, true)

local okRemove = pcall(function() page:removeObjectInternal(btnClose) end)
check("a normal remove still works afterwards", okRemove, true)

log.writeLine(("%d passed, %d failed"):format(pass, fail))
log.close()
os.shutdown()
