-- Proves the master/detail Groups page: the rail selects, the pane follows,
-- the options popup stays on screen from its new anchor, and an empty group
-- list renders a placeholder instead of erroring.
--
--   ./tools/emulate --test groups_select

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
local screens = require("screens")

local W, H = 57, 38

-- ---------------------------------------------------------------------------
-- Populated page
-- ---------------------------------------------------------------------------

_G.global = fakes.buildGlobal(nil, "default")
_G.config = fakes.config

local win = screens.groups(_G.global)
local pane = win.pane
local rows = win.taskGroupControls

check("pane exists", pane ~= nil, true)
check("rail window exists", win.railWin ~= nil, true)

-- Selection defaults to the first group so the pane is never blank with
-- groups present.
check("pane starts on the first sorted group",
	pane.taskGroup and pane.taskGroup.id, "28c2f0")

-- Every rail row is one line tall and they stack with no gaps, which is the
-- whole point of the rail: 35 rows of list instead of 5 cards.
local ys = {}
for _, row in pairs(rows) do
	check("rail row " .. tostring(row.taskGroup.id) .. " is one row tall", row.height, 1)
	ys[#ys + 1] = row.y
end
table.sort(ys)
local contiguous = true
for i = 2, #ys do
	if ys[i] ~= ys[i - 1] + 1 then contiguous = false end
end
check("rail rows stack contiguously", contiguous, true)

-- Rail rows must not spill into the detail pane.
local widthOk = true
for _, row in pairs(rows) do
	if row.x + row.width - 1 >= pane.x then widthOk = false end
end
check("no rail row overlaps the pane", widthOk, true)

-- Clicking a row drives the pane.
rows["89d9bc"]:select()
check("selecting a row swaps the pane", pane.taskGroup.id, "89d9bc")
check("selected row knows it is selected", rows["89d9bc"].selected, true)
check("previous row is deselected", rows["28c2f0"].selected, false)

-- The pane reads the group it was given, not a stale copy.
check("pane shows the selected group's task", pane.lblTask:getText(), "mineArea")

-- The hazard this test exists for: openOptions used to anchor its popup to a
-- button on the row. The button now lives in the pane, so prove the popup
-- lands fully on screen from there.
local ox, oy = pane:optionsAnchor()
check("options popup starts on screen (x)", ox >= 1, true)
check("options popup ends on screen (x)", ox + pane.optionsWidth - 1 <= W, true)
check("options popup starts on screen (y)", oy >= 1, true)
check("options popup ends on screen (y)", oy + pane.optionsHeight - 1 <= H, true)

-- A cancelled group offers resume, which makes the popup taller; it must still
-- fit. This is the tallest the menu ever gets.
rows["536e11"]:select()
local _, oy2 = pane:optionsAnchor()
check("tallest popup still fits", oy2 + pane.optionsHeight - 1 <= H, true)

-- ---------------------------------------------------------------------------
-- Empty page
-- ---------------------------------------------------------------------------

_G.global = fakes.buildGlobal(nil, "empty")
local okEmpty, emptyWin = pcall(screens.groups, _G.global)
check("empty group list builds without error", okEmpty, true)
if okEmpty then
	check("empty pane holds no group", emptyWin.pane.taskGroup, nil)
	check("empty pane shows a placeholder",
		#emptyWin.pane.lblEmpty:getText() > 0, true)
	check("empty pane hides its controls", emptyWin.pane.btnMap.visible, false)
end

log.writeLine(("%d passed, %d failed"):format(pass, fail))
log.close()
os.shutdown()
