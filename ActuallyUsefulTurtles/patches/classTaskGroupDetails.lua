local Box = require("classBox")

local Button = require("classButton")
local Label = require("classLabel")
local BasicWindow = require("classBasicWindow")
local Window = require("classWindow")
local Frame = require("classFrame")
local TaskSelector = require("classTaskSelector")
local TurtleList = require("classTurtleList")
local MapDisplay = require("classMapDisplay")
local ChoiceSelector = require("classChoiceSelector")

local default = {
	colors = {
		background = colors.black,
		border = colors.gray,
		good = colors.green,
		okay = colors.orange,
		bad = colors.red,
		neutral = colors.white,
	},
	width = 50,
	height = 20,
}

-- LABENHANCED_DETAILS_HMI
-- Same grammar as the Groups page and the new-group dialog: gray plates carry
-- grouped values, captions dim, values white, controls a lighter block with a
-- dark glyph. Additions only - no existing colour meaning is repurposed.
local ui = {
	plate   = colors.gray,
	caption = colors.lightGray,
	value   = colors.white,
	control = colors.lightGray,
	controlText = colors.black,
	header  = colors.lightGray,
	headerText = colors.black,
	headerDim = colors.gray,
	divider = colors.gray,
	danger  = colors.red,
	frame   = colors.gray,
}

-- Every row and column in one place so drawn cells and click targets cannot
-- drift apart. winInfo sits at self(2,2), so winInfo-local +1 = self-local.
local L = {
	headerRow  = 1,
	padX       = 2,
	capRow     = 3,
	areaX      = 2,  areaW = 24,
	areaTop    = 4,  areaRows = 4,      -- FROM/TO caption row + X/Y/Z
	axisX      = 4,
	fromEnd    = 15,
	toEnd      = 24,
	mapCapX    = 29,                    -- winInfo-local caption
	mapSelfX   = 30, mapSelfY = 5,      -- the MapDisplay lives on self
	mapW       = 24, mapH = 8,
	-- Readouts live LEFT of the map inset (which starts at winInfo x28), so they
	-- take two short rows rather than one wide one that would run under it.
	readRow    = 9,
	readRow2   = 10,
	-- Controls sit below the map frame's last row, not beside it.
	ctrlRow    = 13,
}

local function padLeft(text, width)
	text = tostring(text)
	local pad = width - #text
	if pad > 0 then return string.rep(" ", pad) .. text end
	return text
end

local function fitText(text, width)
	text = tostring(text)
	if width < 1 then return "" end
	if #text > width then return text:sub(1, width) end
	return text
end


local GroupDetails  = {}
setmetatable(GroupDetails, { __index = Window })
GroupDetails.__index = GroupDetails

function GroupDetails:new(x,y,group)
	local o = o or Window:new(x,y,default.width,default.height) or {}
	setmetatable(o,self)
	
	o:setBackgroundColor(default.colors.background)
	o:setBorderColor(default.colors.border)
	
	o.group = group or nil
	-- o.taskManager = taskManager or nil
	o.mapDisplay = nil -- needed to enable the map button
	o.hostDisplay = nil
	
	o:initialize()
	
	return o
end

function GroupDetails:setHostDisplay(hostDisplay)
	self.hostDisplay = hostDisplay
	if self.hostDisplay then
		-- only for showing fullscreen map?
		self.mapDisplay = self.hostDisplay:getMapDisplay()
	end
end

function GroupDetails:addTask()
	self.taskSelector = TaskSelector:new(self.x+19,self.y+2)
	self.taskSelector:setData(self.data)
	self.taskSelector:setHostDisplay(self.hostDisplay)
	self:addObject(self.taskSelector)
	self:redraw()
	return true
end

function GroupDetails:cancelTask()
	self.group:cancel()
	-- LABENHANCED_AREA_LIFECYCLE
	if self.mapDisplay and self.group then
		self.mapDisplay:removeGroupArea(self.group.id)
	end
end

function GroupDetails:openMap()
	if self.hostDisplay and self.mapDisplay then
		local start, finish, focus = self.group:getAreaDetails()
		if not start then return end
		-- LABENHANCED_AREA_LIFECYCLE
		-- Upsert one managed outline for this group; terminal groups have none.
		self.mapDisplay:setGroupArea(self.group)
		self.mapDisplay:setMid(focus.x, focus.y, focus.z)
		self.hostDisplay:displayMap()
	end
end

function GroupDetails:openOptions()
	local choices = { "call home", "remap tunnels", "reboot" }
	if self.group:isResumable() then 
		table.insert(choices,1,"resume task")
	end
	
	local choiceSelector = ChoiceSelector:new(self.x + self.winInfo.btnOptions.x - 1, self.y + self.winInfo.btnOptions.y-5, 16, 6, choices)
	choiceSelector.onChoiceSelected = function(choice)
		if choice == "call home" then
			self:callHome()
		elseif choice == "remap tunnels" then
			self:remapTunnels()
		elseif choice == "reboot" then
			self.group:reboot()
		elseif choice == "resume task" then
			self.group:resume()
		end
	end
	
	self:addObject(choiceSelector)
	self:redraw()
	return true
end

function GroupDetails:callHome()
	self.group:addTaskToTurtles("returnHome",{})
end

-- LABENHANCED_TUNNEL_REMAP_UI
-- Use one turtle only so scanners cannot collide. Lowest computer ID is
-- normally DTX-001 in this setup.
function GroupDetails:remapTunnels()
	local count, turtles = self.group:getAssignedTurtles()
	if not turtles or #turtles == 0 then
		print("NO TURTLES ASSIGNED TO THIS GROUP")
		return false
	end

	table.sort(turtles, function(a,b)
		return (a.state and a.state.id or math.huge) < (b.state and b.state.id or math.huge)
	end)

	local turt = turtles[1]
	local id = turt and turt.state and turt.state.id
	if not id then
		print("NO VALID TURTLE FOR REMAP")
		return false
	end

	local current = self.group.taskManager:getCurrentTurtleTask(id)
	if current and current.status == "running" then
		print("TURTLE", id, "IS BUSY - CALL HOME FIRST")
		return false
	end

	print("starting non-destructive tunnel remap on turtle", id)
	local task = self.group.taskManager:addTaskToTurtle(id, "remapTunnels", {256, 2500})
	return task ~= nil
end

-- LABENHANCED_DETAILS_HMI
-- 17, not 15: the control row sits on winInfo's last line, and at 15 it butted
-- straight against the turtle list's own heading with no separation.
local turtleListY = 17
local mapX = 37
function GroupDetails:onResize() -- super override
	Window.onResize(self) -- super
	self.turtleList:setSize(self.width-2, self.height - turtleListY)
	self.winInfo:setSize(self.width - 2, self.turtleList.y - 2)
	self:layoutPanel()
end

function GroupDetails:usableWidth()
	-- last column clear of the close button overlay, in winInfo-local terms
	local w = self.winInfo and self.winInfo:getWidth() or (self.width - 2)
	if self.btnClose and self.btnClose.visible then
		w = math.min(w, self.btnClose.x - 2)
	end
	return math.max(20, w)
end

function GroupDetails:layoutPanel()
	local usable = self:usableWidth()
	if self.winInfo and self.winInfo.boxHeader then
		self.winInfo.boxHeader:setWidth(usable)
	end
	if self.winInfo and self.winInfo.lblTime then
		local t = self.winInfo.lblTime:getText()
		self.winInfo.lblTime:setPos(math.max(20, usable - #t), L.headerRow)
	end
	self.usableWidthCache = usable
end

function GroupDetails:initializeMiniMap()
	-- LABENHANCED_DETAILS_HMI
	-- Inset and framed, clear of both the window border and the close button.
	-- It used to span to self.width, so it ran underneath the X and bled into
	-- the right-hand border.
	-- A thin frame one cell outside the viewport, so the map reads as a recessed
	-- panel rather than terrain floating on the window background.
	self.boxMapFrame = Box:new(L.mapSelfX - 1, L.mapSelfY - 1, L.mapW + 2, L.mapH + 2,
		colors.black)
	self.boxMapFrame:setBorderColor(ui.frame)
	self:addObject(self.boxMapFrame)

	self.winMap = MapDisplay:new(L.mapSelfX, L.mapSelfY, L.mapW, L.mapH)
	self.winMap:setMap(global.map)
	local start, finish, focus = self.group:getAreaDetails()
	if focus then
		self.winMap:setMid(focus.x, focus.y, focus.z)
		-- LABENHANCED_AREA_LIFECYCLE
		self.winMap:setGroupArea(self.group)
	end
	self.winMap:hideControls()
	self.winMap.handleClick = function(x,y) self:openMap() end
	self:addObject(self.winMap)
end


function GroupDetails:initialize()
	local group = self.group
	local ct, turtles = group:getAssignedTurtles()
	self.turtleList = TurtleList:new(2, turtleListY, self.width-2, self.height - turtleListY, turtles)
	self.turtleList:removeCloseButton()
	self.turtleList.filter.inactive = false

	self.winInfo = BasicWindow:new(2,2,self.width-2,self.turtleList.y - 2)
	local winInfo = self.winInfo
	local shortId = string.sub(tostring(group.shortId or group.id or "????"),1,4)

	-- ---- header strip: id, status lamp, status, uptime ---------------------
	winInfo.boxHeader = Box:new(1, L.headerRow, winInfo:getWidth(), 1, ui.header)
	winInfo:addObject(winInfo.boxHeader)
	winInfo.lblId = Label:new("GROUP " .. shortId, 2, L.headerRow, ui.headerText, ui.header)
	winInfo.boxLamp = Box:new(14, L.headerRow, 1, 1, group:getStatusColor())
	winInfo.boxLamp:setBorderColor(group:getStatusColor())
	winInfo.lblStatus = Label:new(group:getStatus(), 16, L.headerRow,
		group:getStatusColor(), ui.header)
	winInfo.lblTime = Label:new("00:00.00", 40, L.headerRow, ui.headerDim, ui.header)
	winInfo:addObject(winInfo.lblId)
	winInfo:addObject(winInfo.boxLamp)
	winInfo:addObject(winInfo.lblStatus)
	winInfo:addObject(winInfo.lblTime)

	-- ---- AREA plate ---------------------------------------------------------
	winInfo.lblAreaCap = Label:new("AREA", L.padX, L.capRow, ui.caption)
	winInfo:addObject(winInfo.lblAreaCap)
	winInfo.boxArea = Box:new(L.areaX, L.areaTop, L.areaW, L.areaRows, ui.plate)
	winInfo:addObject(winInfo.boxArea)
	winInfo.lblFromCap = Label:new("FROM", L.fromEnd - 3, L.areaTop, ui.caption, ui.plate)
	winInfo.lblToCap = Label:new("TO", L.toEnd - 1, L.areaTop, ui.caption, ui.plate)
	winInfo:addObject(winInfo.lblFromCap)
	winInfo:addObject(winInfo.lblToCap)

	local area = group:getArea() or { start = {x=0,y=0,z=0}, finish = {x=0,y=0,z=0} }
	local ay = L.areaTop + 1
	winInfo.lblXAxis = Label:new("X", L.axisX, ay,   ui.caption, ui.plate)
	winInfo.lblYAxis = Label:new("Y", L.axisX, ay+1, ui.caption, ui.plate)
	winInfo.lblZAxis = Label:new("Z", L.axisX, ay+2, ui.caption, ui.plate)
	winInfo.lblXStart = Label:new(area.start.x, L.axisX+2, ay,   ui.value, ui.plate)
	winInfo.lblYStart = Label:new(area.start.y, L.axisX+2, ay+1, ui.value, ui.plate)
	winInfo.lblZStart = Label:new(area.start.z, L.axisX+2, ay+2, ui.value, ui.plate)
	winInfo.lblXFinish = Label:new(area.finish.x, L.fromEnd+1, ay,   ui.value, ui.plate)
	winInfo.lblYFinish = Label:new(area.finish.y, L.fromEnd+1, ay+1, ui.value, ui.plate)
	winInfo.lblZFinish = Label:new(area.finish.z, L.fromEnd+1, ay+2, ui.value, ui.plate)
	for _,o in ipairs{winInfo.lblXAxis,winInfo.lblYAxis,winInfo.lblZAxis,
		winInfo.lblXStart,winInfo.lblYStart,winInfo.lblZStart,
		winInfo.lblXFinish,winInfo.lblYFinish,winInfo.lblZFinish} do winInfo:addObject(o) end

	-- ---- MAP caption (the display itself is added to self, above winInfo) ----
	winInfo.lblMapCap = Label:new("MAP", L.mapCapX, L.capRow, ui.caption)
	winInfo:addObject(winInfo.lblMapCap)

	-- ---- readouts -----------------------------------------------------------
	winInfo.lblTaskCap = Label:new("TASK", L.padX, L.readRow, ui.caption)
	winInfo.lblTask = Label:new(group.taskName or "", L.padX+5, L.readRow, ui.value)
	winInfo.lblTurtCap = Label:new("TURT", L.padX, L.readRow2, ui.caption)
	winInfo.lblActiveTurtles = Label:new("0/0", L.padX+5, L.readRow2, ui.value)
	winInfo.lblProgCap = Label:new("PROG", L.padX+12, L.readRow2, ui.caption)
	winInfo.lblProgress = Label:new("", L.padX+17, L.readRow2, ui.value)
	for _,o in ipairs{winInfo.lblTaskCap,winInfo.lblTask,winInfo.lblTurtCap,
		winInfo.lblActiveTurtles,winInfo.lblProgCap,winInfo.lblProgress} do
		winInfo:addObject(o)
	end

	-- ---- controls -----------------------------------------------------------
	winInfo.btnAddTask = Button:new("add task", L.padX, L.ctrlRow, 10, 1, ui.control)
	winInfo.btnCancelTask = Button:new("cancel", L.padX+11, L.ctrlRow, 8, 1, ui.control)
	winInfo.btnOptions = Button:new("options", L.padX+20, L.ctrlRow, 9, 1, ui.control)
	-- destructive, set apart from the operational controls
	winInfo.btnDeleteGroup = Button:new("delete", L.padX+32, L.ctrlRow, 8, 1, ui.danger)
	for _,b in ipairs{winInfo.btnAddTask,winInfo.btnCancelTask,winInfo.btnOptions} do
		b:setTextColor(ui.controlText)
		winInfo:addObject(b)
	end
	winInfo.btnDeleteGroup:setTextColor(ui.value)
	winInfo:addObject(winInfo.btnDeleteGroup)

	winInfo.btnAddTask.click = function() return self:addTask() end
	winInfo.btnCancelTask.click = function() self:cancelTask() end
	winInfo.btnDeleteGroup.click = function() return self:deleteGroup() end
	winInfo.btnOptions.click = function() return self:openOptions() end

	self:addObject(self.turtleList)
	self:addObject(winInfo)
	self:initializeMiniMap()

	winInfo.btnDeleteGroup.visible = false
	winInfo.btnCancelTask.visible = false
	self:layoutPanel()
end

function GroupDetails:refreshPos()
	-- right-aligned into fixed fields so digits do not shift about
	local area = self.group:getArea() or { start = {x=0,y=0,z=0}, finish = {x=0,y=0,z=0} }
	local s, f = area.start, area.finish
	local winInfo = self.winInfo
	local startW = L.fromEnd - (L.axisX + 2) + 1
	local finishW = L.toEnd - (L.fromEnd + 1) + 1

	winInfo.lblXStart:setText(padLeft(s.x, startW))
	winInfo.lblYStart:setText(padLeft(s.y, startW))
	winInfo.lblZStart:setText(padLeft(s.z, startW))
	winInfo.lblXFinish:setText(padLeft(f.x, finishW))
	winInfo.lblYFinish:setText(padLeft(f.y, finishW))
	winInfo.lblZFinish:setText(padLeft(f.z, finishW))
end

function GroupDetails:refresh()
	self:refreshPos()
	local winInfo = self.winInfo
	local group = self.group

	local status = group:getStatus()
	local statusColor = group:getStatusColor()
	local activeCount = group:getActiveTurtles()
	local active = group:isActive()

	-- LABENHANCED_DETAILS_HMI
	-- One status colour drives the lamp and the label together.
	winInfo.lblStatus:setText(tostring(status):upper():gsub("_"," "))
	winInfo.lblStatus:setTextColor(statusColor)
	if winInfo.boxLamp then
		winInfo.boxLamp:setBackgroundColor(statusColor)
		winInfo.boxLamp:setBorderColor(statusColor)
	end

	-- clipped to the space before the map inset, so a long task name cannot
	-- run underneath it
	winInfo.lblTask:setText(fitText(group.taskName or "no task", 19))
	winInfo.lblActiveTurtles:setText(activeCount.."/"..tostring(group.groupSize))
	winInfo.lblProgress:setText(group:getProgressText())
	winInfo.lblTime:setText(group:getUptimeText())

	winInfo.btnCancelTask:setEnabled(active)
	winInfo.btnCancelTask.visible = active
	winInfo.btnDeleteGroup.visible = not active

	-- Keep the mini-map lifecycle in sync too. Completion/cancellation
	-- removes its rectangle without requiring this details window to be reopened.
	if self.winMap then
		self.winMap:setGroupArea(group)
	end

	self:layoutPanel()
	self.turtleList:refresh()
	self.winMap:refresh()
end

function GroupDetails:deleteGroup()
	local groupId = self.group and self.group.id
	if self.mapDisplay and groupId then
		self.mapDisplay:removeGroupArea(groupId)
	end
	if self.winMap and groupId then
		self.winMap:removeGroupArea(groupId)
	end
	if self.group then 
		self.group:delete()
	end
	if self.hostDisplay then
		self.hostDisplay:deleteGroup(groupId)
	end
	return true
end

return GroupDetails