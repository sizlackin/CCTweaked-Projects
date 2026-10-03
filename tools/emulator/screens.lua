-- Screen builders for the emulator harness.
--
-- Each builder returns a root object to hand to Monitor:addObject. They use the
-- real UI classes from the repo, so what you see is what the controller draws.

local screens = {}

-- Full controller display. Highest fidelity, but needs the most fake state -
-- it constructs the map, storage and turtle views too.
function screens.full(global, say)
	local HostDisplay = require("classHostDisplay")
	local w, h = term.getSize()
	say("building HostDisplay %dx%d", w, h)
	local hd = HostDisplay:new(1, 1, w, h)
	hd:displayGroups()
	return hd
end

-- The Groups page on its own. Builds the same winGroups the controller builds,
-- then drives it with the controller's own methods, so refreshGroupsHeader and
-- TaskGroupControl are the real code under test.
function screens.groups(global, say)
	local BasicWindow = require("classBasicWindow")
	local HostDisplay = require("classHostDisplay")
	local Window = require("classWindow")
	local Box = require("classBox")
	local Label = require("classLabel")
	local Button = require("classButton")

	local w, h = term.getSize()
	-- Callable from a logic test, which has no log to write to.
	say = say or function() end
	say("building groups page %dx%d", w, h)

	-- A HostDisplay-shaped host without running its full initialize(): we want
	-- the real refreshGroupsHeader/updateGroups, not the map and storage views.
	local host = BasicWindow:new(1, 1, w, h)
	HostDisplay.__index = HostDisplay
	setmetatable(host, HostDisplay)
	host.taskManager = global.taskManager
	host.turtles = global.turtles
	host.mapDisplay = nil

	local win = Window:new(1, 1, w, h)
	host.winGroups = win

	win.boxHeader = Box:new(1, 1, w, 1, colors.gray)
	win.lblName = Label:new("TASK GROUPS", 2, 1, colors.white, colors.gray)
	win.lblSummary = Label:new("", 14, 1, colors.white, colors.gray)
	win.lblAdd = Label:new("create", 14, 1, colors.lightGray, colors.gray)
	win.btnAdd = Button:new("+", 21, 1, 3, 1, colors.green)
	win.btnAdd:setTextColor(colors.black)
	win.taskGroupControls = {}
	win.groupCt = 0

	win:addObject(win.boxHeader)
	win:addObject(win.lblName)
	win:addObject(win.lblSummary)
	win:addObject(win.lblAdd)
	win:addObject(win.btnAdd)

	-- LABENHANCED_GROUPS_MASTERDETAIL
	-- Build the rail and the pane through HostDisplay itself. The preview then
	-- exercises the real construction, the real sort order and the real
	-- selection logic rather than a copy of them that can rot.
	host:buildGroupsChrome(win)

	win.visible = true
	win.__host = host          -- so a modal preview can drive header focus
	host:layoutGroupsPage()
	host:updateGroups()
	host:refreshGroupsHeader()

	-- Being added to the monitor cascades setVisible over every child, which
	-- re-shows the rail scrollbar this page may have decided to hide. Settle it
	-- again once attached - the real controller gets this for free because
	-- displayGroups runs updateGroups after addObject.
	win.__afterAdd = function() host:updateGroups() end

	local rowIds = {}
	for id in pairs(win.taskGroupControls) do rowIds[#rowIds + 1] = id end
	table.sort(rowIds)
	for _, id in ipairs(rowIds) do
		local row = win.taskGroupControls[id]
		say("rail %s status=%s y=%d w=%d sel=%s", id, row.taskGroup:getStatus(),
			row.y, row.width, tostring(row.selected))
	end
	say("pane: group=%s x=%d w=%d h=%d",
		tostring(win.pane.taskGroup and win.pane.taskGroup.id),
		win.pane.x, win.pane.width, win.pane.height)
	say("header: plate=%d btnAdd.x=%d lblAdd=%q lblSummary=%q btnClose.x=%s innerWin=%d",
		win.boxHeader.width, win.btnAdd.x, win.lblAdd:getText(),
		win.lblSummary:getText(), tostring(win.btnClose and win.btnClose.x),
		win.innerWin and win.innerWin:getWidth() or -1)

	return win
end

-- The "new group" panel, as HostDisplay:addGroup builds it: a Window filling
-- the Groups page. `stage` picks how far through the flow to render.
function screens.newgroup(global, say)
	local TaskGroupSelector = require("classTaskGroupSelector")

	-- Render the real Groups page behind the dialog. The panel is judged against
	-- what actually sits under it - the group rows and their gray plates - not a
	-- blank window.
	local page = screens.groups(global, say)

	local sel = TaskGroupSelector:new(1, 1, global.taskManager, false)
	sel:setHostDisplay(page.__host)   -- lets centerIn/close dim the page header
	page:addObject(sel)
	sel:centerIn(page)
	page.__host:refreshGroupsHeader()

	local stage = global.__stage or "area"
	if stage ~= "empty" then
		sel.positions = {
			{ x = -91, y = -59, z = 692 },
			{ x = -127, y = -59, z = 671 },
		}
	end
	if stage == "empty" then sel.taskName = nil end

	sel:refresh()

	-- stage "menu": open the task dropdown so its state can be checked
	if stage == "menu" then
		sel:selectTask()
		say("menu open: caret=%q stacked=%s",
			sel.btnTaskCaret:getText(), tostring(sel.choiceSelector ~= nil))
		-- clicking again must close it, not stack a second one
		sel:selectTask()
		say("after 2nd click: caret=%q open=%s",
			sel.btnTaskCaret:getText(), tostring(sel.choiceSelector ~= nil))
		sel:selectTask()
		say("after 3rd click: caret=%q open=%s",
			sel.btnTaskCaret:getText(), tostring(sel.choiceSelector ~= nil))
		say("menu has close button: %s",
			tostring(sel.choiceSelector and sel.choiceSelector.btnClose
				and sel.choiceSelector.btnClose.visible))
	end

	local function span(b) return b and (b.x .. "-" .. (b.x + b.width - 1)) or "?" end
	say("cols | selectArea %s | top %s | bottom %s | split %s",
		span(sel.btnSelectArea), span(sel.btnFromTop),
		span(sel.btnToBottom), span(sel.btnSplitArea))
	say("cols | taskField %s | caret %s | minus %s | plus %s",
		span(sel.btnSelectTask), span(sel.btnTaskCaret),
		span(sel.btnDecreaseSize), span(sel.btnIncreaseSize))
	say("newgroup stage=%s w=%d h=%d divider=%s action=%s",
		stage, sel.width, sel.height, tostring(sel.dividerRow), tostring(sel.actionRow))
	return page
end

-- Map view with two group outlines, to check the id labels.
function screens.map(global, say)
	local MapDisplay = require("classMapDisplay")
	local fakes = require("fakes")

	local w, h = term.getSize()
	local md = MapDisplay:new(1, 1, w, h)
	md:setMap(fakes.buildMap())
	md:setMid(0, -59, 0)

	-- two ACTIVE groups: both green by status, so only the label tells them apart
	md.areas = {
		{ start = {x=-20,y=-59,z=-16}, finish = {x=-4,y=-59,z=-2},
		  color = colors.green, groupId = "89d9bc" },
		{ start = {x=6,y=-59,z=4}, finish = {x=22,y=-59,z=18},
		  color = colors.green, groupId = "3587aa" },
	}
	say("map: %d outlines, both green - labels must disambiguate", #md.areas)

	return md
end

-- Interactive WorldEdit-style selection preview. The fake mine deliberately
-- uses four-block row spacing while touch coordinates normally advance three
-- blocks per character row, making the formerly unreachable tunnel pixels easy
-- to exercise. It uses the real TaskGroupSelector overlay and fine controls;
-- later map clicks move POS2 exactly like the live group selector.
function screens.selection(global, say)
	local MapDisplay = require("classMapDisplay")
	local TaskGroupSelector = require("classTaskGroupSelector")
	local fakes = require("fakes")
	local w,h = term.getSize()
	local md = MapDisplay:new(1,1,w,h)
	md:setMap(fakes.buildMap())
	md:setMid(0,-59,0)

	local selector = setmetatable({
		mapDisplay = md,
		positions = {
			vector.new(-20,-59,-8),
			vector.new(20,-59,8),
		},
		selectionMode = true,
		cursorMode = false,
		refresh = function() end,
		redraw = function() end,
		closeMap = function() end,
	}, { __index = TaskGroupSelector })

	md.onPositionSelected = function(_,x,y,z) selector:onAreaSelected(x,y,z) end
	selector:showModeControls()
	selector:updateAreaPreview()
	md:selectPosition(true)
	md.__selector = selector -- keep the preview controller reachable for its callbacks
	say("selection preview: map clicks move POS2; X-/X+/Z-/Z+ nudge it one block")
	return md
end

-- Group > details, as HostDisplay:openGroupDetails builds it.
function screens.details(global, say)
	local GroupDetails = require("classTaskGroupDetails")
	local fakes = require("fakes")
	global.map = global.map or fakes.buildMap()   -- the mini-map reads global.map
	local w, h = term.getSize()

	local groups = global.taskManager:getGroups()
	local ids = {}
	for id in pairs(groups) do ids[#ids+1] = id end
	table.sort(ids)
	-- A status-named scenario picks that group while retaining the default fake
	-- dataset. This exercises terminal control reflow and status-coloured chrome.
	local group = groups[ids[#ids]]
	local requestedStatus = global.__stage or ""
	if requestedStatus == "completed" or requestedStatus == "cancelled" then
		for _, id in ipairs(ids) do
			if groups[id]:getStatus() == requestedStatus then
				group = groups[id]
				break
			end
		end
	end

	local d = GroupDetails:new(1, 1, group)
	d:setSize(w, h)
	if d.onResize then d:onResize() end
	d:refresh()   -- otherwise the render shows initialize()'s placeholder values
	-- and again once attached, because addObject re-shows every hidden child
	d.__afterAdd = function() d:refresh() end
	say("details: group %s status=%s size=%dx%d", tostring(group.id),
		group:getStatus(), d.width, d.height)
	if d.winMap then
		say("minimap: x %d..%d of %d, y %d..%d", d.winMap.x,
			d.winMap.x + d.winMap.width - 1, d.width, d.winMap.y,
			d.winMap.y + d.winMap.height - 1)
	end
	return d
end

function screens.names()
	local n = {}
	for k in pairs(screens) do
		if k ~= "names" then n[#n + 1] = k end
	end
	table.sort(n)
	return n
end

return screens
