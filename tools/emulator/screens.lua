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
	local TaskGroupControl = require("classTaskGroupControl")

	local w, h = term.getSize()
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
	win:addScrollbar(true)

	-- rows, ordered so the screenshot is stable between runs
	local ids = {}
	for id in pairs(global.taskManager:getGroups()) do ids[#ids + 1] = id end
	table.sort(ids)

	for _, id in ipairs(ids) do
		local group = global.taskManager:getGroups()[id]
		local row = TaskGroupControl:new(1, 3 + 6 * win.groupCt, group)
		win:addObject(row)
		row:fillWidth()
		row.hostDisplay = host
		row.mapDisplay = nil
		win.taskGroupControls[id] = row
		win.groupCt = win.groupCt + 1
		say("row %s status=%s width=%d", id, group:getStatus(), row.width)
	end

	win.visible = true
	host:refreshGroupsHeader()
	say("header: plate=%d btnAdd.x=%d lblAdd=%q lblSummary=%q btnClose.x=%s innerWin=%d",
		win.boxHeader.width, win.btnAdd.x, win.lblAdd:getText(),
		win.lblSummary:getText(), tostring(win.btnClose and win.btnClose.x),
		win.innerWin and win.innerWin:getWidth() or -1)

	return win
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
