local Monitor = require("classMonitor")
local Button = require("classButton")
local GPU = require("classGPU")
local Box = require("classBox")
local ToggleButton = require("classToggleButton")
local Frame = require("classFrame")
local Label = require("classLabel")
--require("classBluenetNode")
--require("classNetworkNode")
local CheckBox = require("classCheckBox")
local Window = require("classWindow")
local BasicWindow = require("classBasicWindow")
local MapDisplay = require("classMapDisplay")
local TaskGroupSelector = require("classTaskGroupSelector")
local TaskGroupControl = require("classTaskGroupControl")
local TaskGroupPane = require("classTaskGroupPane")
local StorageDisplay = require("classStorageDisplay")
local ScrollBar = require("classScrollBar")
local TurtleList = require("classTurtleList")
local GroupDetails = require("classTaskGroupDetails")
local TurtleDetails = require("classTurtleDetails")

local default = {
	colors = {
		background = colors.black,
	},
}

-- LABENHANCED_GROUPS_MASTERDETAIL
-- Geometry of the Groups page, in one place so the rail, the divider rule and
-- the detail pane cannot drift apart. Only the pane's width tracks the window;
-- the rail is fixed, because a wider rail buys nothing once the id and the
-- abbreviated status fit.
local groupsLayout = {
	top         = 3,
	railW       = 15,
	ruleX       = 16,
	paneX       = 17,
	-- The page's close button overlays the last columns of row 1. Keep the pane
	-- clear of them so a wide readout never runs under the X.
	rightGutter = 3,
	minPaneW    = 20,
}

local global = global

local HostDisplay = BasicWindow:new()

function HostDisplay:new(x,y,width,height)
	local o = o or BasicWindow:new(x,y,width,height)
	setmetatable(o,self)
	self.__index = self
	
	o.backgroundColor = default.colors.background
	o.doSlowReboot = false
	o.doSlowStart = true

	o:initialize()
	
	return o
end

function HostDisplay:loadGlobals()
	if global then
		self.node = global.node
		self.map = global.map
		self.turtles = global.turtles
		self.pos = global.pos
		self.taskGroups = global.taskGroups
		self.alerts = global.alerts
		self.storage = global.storage
		self.taskManager = global.taskManager
	else
		print("GLOBALS NOT AVAILABLE")
	end
end

function HostDisplay:initialize()
	self:loadGlobals()
	
	-- init main window
	self.winMain = Window:new(1,1)
	self:addObject(self.winMain)
	self.winMain:fillParent()
	self.winMain:removeCloseButton()
	
	-- add main window objects
	--self.winMain.btnGlobalRebootSlow = Button:new("REBOOT SLW", self:getWidth()-9,10,11,3)
	--self.winMain.btnGlobalShutdown = Button:new("SHUTDOWN", self:getWidth()-9,13,11,3,colors.pink)
	
	--self.winMain.btnGlobalRebootSlow.click = function() return self:globalReboot(true) end
	--self.winMain.btnGlobalShutdown.click = function() return self:globalShutdown() end
	
	self.winMain.lblHeading = Label:new("Turtle Manager",2,1)
	local sx, sy = 10,2
	self.winMain.btnReboot = Button:new("REBOOT", self:getWidth()-8,sy,8,3,colors.blue)
	self.winMain.btnTerminate = Button:new("STOP", self:getWidth()-17,sy,8,3,colors.red)
	
	self.winMain.btnMap = Button:new("MAP", sx-8, sy, 7, 3)
	self.winMain.mp1 = Label:new("\155\156\136", sx, sy, colors.blue, colors.green)
	self.winMain.mp2 = Label:new("\137", sx+3, sy, colors.yellow, colors.blue)
	self.winMain.mp3 = Label:new("\155\156", sx, sy+1, colors.green, colors.blue)
	self.winMain.mp4 = Label:new("\148", sx+2, sy+1, colors.yellow, colors.blue)
	self.winMain.mp5 = Label:new("\159", sx+3, sy+1, colors.green, colors.blue)
	self.winMain.mp6 = Label:new("\154\158\141\151", sx, sy+2, colors.green, colors.blue)
	self.winMain.btnGroups = Button:new("Groups", sx+6, sy, 10, 3)
	self.winMain.btnStorage = Button:new("Storage", sx+17, sy, 10, 3)
	
	local sx, sy = 2, sy+4
	self.winMain.btnTurtles = Button:new("Turtles", sx, sy, 10, 3)
	self.winMain.lblRow1 = Label:new(   "      |        |        |", sx+12, sy)
	self.winMain.lblRow2 = Label:new(   "      |        |        |", sx+12, sy+1)
	self.winMain.lblTotalHd = Label:new(" total", sx+11, sy)
	self.winMain.lblTotal =   Label:new("     0", sx+11, sy+1)
	self.winMain.lblOnlineHd = Label:new(		 "online", sx+20, sy)
	self.winMain.lblOnline =   Label:new(         "     0", sx+20, sy+1)
	self.winMain.lblActiveHd = Label:new(				  "active", sx+29, sy)
	self.winMain.lblActive =   Label:new(				  "    0", sx+29, sy+1)
	self.winMain.lblAlertsHd = Label:new(				  " alerts", sx+38, sy)
	self.winMain.lblAlerts =   Label:new(				  "      0", sx+38, sy+1)

	self.winMain.btnGlobalReboot = Button:new("reboot", sx+11, sy+2, 7, 1)
	self.winMain.btnHome = Button:new("home", sx+20, sy+2, 7, 1)
	self.winMain.btnCancel = Button:new("cancel", sx+29, sy+2, 7, 1)
	self.winMain.lblTimeVal = Label:new("00:00:00", self:getWidth()-8, sy+2)


	local sx, sy = 2, sy + 12
	self.winMain.btnDumpItems = Button:new("dump", sx, sy+0, 7, 1)
	self.winMain.btnRefuel = Button:new("refuel", sx, sy+1, 7, 1)

	self.winMain.btnMap.click = function() return self:displayMap() end
	self.winMain.btnTurtles.click = function() return self:displayTurtles() end
	self.winMain.btnGroups.click = function() return self:displayGroups() end
	self.winMain.btnReboot.click = function() self:reboot() end
	self.winMain.btnTerminate.click = function() return self:terminate() end
	self.winMain.btnGlobalReboot.click = function() return self:globalReboot(self.doSlowReboot) end
	self.winMain.btnCancel.click = function() return self:globalCancelTask() end
	self.winMain.btnHome.click = function() return self:globalCallHome() end
	self.winMain.btnDumpItems.click = function() return self:globalDumpItems() end
	self.winMain.btnRefuel.click = function() return self:globalGetFuel() end
	self.winMain.btnStorage.click = function() return self:displayStorage() end



	--self.winMain:addObject(self.winMain.lblHeading)
	self.winMain:addObject(self.winMain.btnReboot)
	self.winMain:addObject(self.winMain.btnTerminate)
	self.winMain:addObject(self.winMain.btnMap)
	self.winMain:addObject(self.winMain.mp1)
	self.winMain:addObject(self.winMain.mp2)
	self.winMain:addObject(self.winMain.mp3)
	self.winMain:addObject(self.winMain.mp4)
	self.winMain:addObject(self.winMain.mp5)
	self.winMain:addObject(self.winMain.mp6)
	self.winMain:addObject(self.winMain.btnGroups)
	self.winMain:addObject(self.winMain.btnStorage)
	self.winMain:addObject(self.winMain.btnTurtles)
	self.winMain:addObject(self.winMain.lblRow1)
	self.winMain:addObject(self.winMain.lblRow2)
	self.winMain:addObject(self.winMain.lblTotalHd)
	self.winMain:addObject(self.winMain.lblTotal)
	self.winMain:addObject(self.winMain.lblOnlineHd)
	self.winMain:addObject(self.winMain.lblOnline)
	self.winMain:addObject(self.winMain.lblActiveHd)
	self.winMain:addObject(self.winMain.lblActive)
	self.winMain:addObject(self.winMain.lblAlertsHd)
	self.winMain:addObject(self.winMain.lblAlerts)
	self.winMain:addObject(self.winMain.btnGlobalReboot)
	self.winMain:addObject(self.winMain.btnHome)
	self.winMain:addObject(self.winMain.btnCancel)
	self.winMain:addObject(self.winMain.lblTimeVal)

	self.winMain:addObject(self.winMain.btnDumpItems)
	self.winMain:addObject(self.winMain.btnRefuel)


	--self.winMain:addObject(self.winMain.btnGlobalRebootSlow)
	--self.winMain:addObject(self.winMain.btnGlobalShutdown)
	
	self.winData = BasicWindow:new(2,11,self:getWidth()-2,6)
	self.winMain:addObject(self.winData)

	self.winData.frm = Frame:new("general", 1, 1, 55, 6)
	self.winData:addObject(self.winData.frm)
	self.winData.frm:setWidth(self.winData:getWidth())

	
	self.winData.btnPrintStatus = CheckBox:new(3,2, "print status", global.printStatus)
	self.winData.btnPrintMainTime = CheckBox:new(3,3, "print main", global.printMainTime)
	self.winData.btnPrintEvents = CheckBox:new(3,4, "print events", global.printEvents)
	self.winData.btnPrintDisplayTime = CheckBox:new(3,5, "print display", global.printDisplayTime)
	self.winData.btnPrintSend = CheckBox:new(25,2, "print send", global.printSend)
	self.winData.btnPrintSendTime = CheckBox:new(25,3, "print send time", global.printSendTime)
	self.winData.chkSlowReboot = CheckBox:new(25,4, "slow reboot", self.doSlowReboot)
	self.winData.chkSlowStart = CheckBox:new(25,5, "slow task start", self.doSlowStart)

	self.winData.btnPrintStatus.click = function()
		global.printStatus = self.winData.btnPrintStatus.active
	end
	self.winData.btnPrintEvents.click = function()
		global.printEvents = self.winData.btnPrintEvents.active
	end
	self.winData.btnPrintDisplayTime.click = function()
		global.printDisplayTime = self.winData.btnPrintDisplayTime.active
	end
	self.winData.btnPrintSend.click = function()
		global.printSend = self.winData.btnPrintSend.active
	end
	self.winData.btnPrintMainTime.click = function()
		global.printMainTime = self.winData.btnPrintMainTime.active
	end
	self.winData.btnPrintSendTime.click = function()
		global.printSendTime = self.winData.btnPrintSendTime.active
	end
	self.winData.chkSlowReboot.click = function()
		self.doSlowReboot = self.winData.chkSlowReboot.active
	end
	self.winData.chkSlowStart.click = function()
		self.doSlowStart = self.winData.chkSlowStart.active
	end

	self.winData:addObject(self.winData.btnPrintStatus)
	self.winData:addObject(self.winData.btnPrintEvents)
	self.winData:addObject(self.winData.btnPrintSend)
	self.winData:addObject(self.winData.btnPrintMainTime)
	self.winData:addObject(self.winData.btnPrintDisplayTime)
	self.winData:addObject(self.winData.btnPrintSendTime)
	self.winData:addObject(self.winData.chkSlowReboot)
	self.winData:addObject(self.winData.chkSlowStart)
	-- settings subwindow for main display
	self.winSettings = BasicWindow:new(12,18,30,1)
	self.winMain:addObject(self.winSettings)

	self.winSettings.lblMsgDelay = Label:new("message interval", 1,1)
	self.winSettings.btnDecreaseDelay = Button:new("-",21,1,1,1)
	self.winSettings.lblMsgDelayVal = Label:new(string.format("%.2f",global.minMessageDelay),23,1)
	self.winSettings.btnIncreaseDelay = Button:new("+",28,1,1,1)
	
	self.winSettings.changeMsgDelay = function(increment)
		global.minMessageDelay = global.minMessageDelay + increment
		if global.minMessageDelay < 0 then global.minMessageDelay = 0 end
		self.winSettings.lblMsgDelayVal:setText(string.format("%.2f",global.minMessageDelay))
		self.winSettings.lblMsgDelayVal:redraw()
	end
	self.winSettings.btnIncreaseDelay.click = function() self.winSettings.changeMsgDelay(0.05) end
	self.winSettings.btnDecreaseDelay.click = function() self.winSettings.changeMsgDelay(-0.05) end

	self.winSettings.lblMsgCount = Label:new("messages:",1,2)
	self.winSettings.lblMsgCountVal = Label:new("0",12,2)

	self.winSettings:addObject(self.winSettings.lblMsgDelay)
	self.winSettings:addObject(self.winSettings.btnDecreaseDelay)
	self.winSettings:addObject(self.winSettings.lblMsgDelayVal)
	self.winSettings:addObject(self.winSettings.btnIncreaseDelay)
	self.winSettings:addObject(self.winSettings.lblMsgCount)
	self.winSettings:addObject(self.winSettings.lblMsgCountVal)
	
	-- init hidden windows
	self.storageDisplay = StorageDisplay:new(1,1,self:getWidth(),self:getHeight(),self.storage)
	self.storageDisplay:setHostDisplay(self)

	--self.winMap = Window:new()
	self.mapDisplay = MapDisplay:new(4,4,32,16)
	--self.winMap:setInnerWindow(self.mapDisplay)
	self.winMap = self.mapDisplay
	self.winTurtles = TurtleList:new(1,1,self:getWidth(),self:getHeight(), self.turtles)
	self.winGroups = Window:new()
	
	-- add map window data
	self.mapDisplay:setMap(self.map)
	self.mapDisplay:setMid(self.pos.x,self.pos.y,self.pos.z)
	
	
	-- init groups window
	-- LABENHANCED_GROUPS_HMI
	-- Header strip: a full-width plate carrying the page title on the left and
	-- glanceable counts on the right, with create as a solid control. The plate
	-- is registered first so the labels and the button draw over it.
	-- LABENHANCED_GROUPS_HMI
	-- Deliberately stays gray. The modal already signals focus by carrying
	-- brighter chrome than anything it covers; dimming the page as well is
	-- redundant, and a lightGray bar here became the loudest thing on screen,
	-- competing with the status lamps that should be carrying the eye.
	self.winGroups.boxHeader = Box:new(1,1,self:getWidth(),1,colors.gray)
	self.winGroups.lblName = Label:new("TASK GROUPS",2,1,colors.white,colors.gray)
	self.winGroups.lblSummary = Label:new("",14,1,colors.white,colors.gray)
	-- Caption plus glyph control, the same pairing the map screen uses for its
	-- level and zoom spinners: a dimmed caption naming the action and a solid
	-- button carrying the glyph. Green reads as create against the red close.
	self.winGroups.lblAdd = Label:new("create",14,1,colors.lightGray,colors.gray)
	self.winGroups.btnAdd = Button:new("+",21,1,3,1,colors.green)
	self.winGroups.btnAdd:setTextColor(colors.black)
	self.winGroups.taskGroupControls = {}
	self.winGroups.groupCt = 0

	self.winGroups.btnAdd.click = function() return self:addGroup() end

	self.winGroups:addObject(self.winGroups.boxHeader)
	self.winGroups:addObject(self.winGroups.lblName)
	self.winGroups:addObject(self.winGroups.lblSummary)
	self.winGroups:addObject(self.winGroups.lblAdd)
	self.winGroups:addObject(self.winGroups.btnAdd)

	self:buildGroupsChrome(self.winGroups)
	-- initial redraw
	-- self:redraw()


end 

function HostDisplay:refreshRedraw()
	-- self.mapDisplay:checkUpdates() -- now part of refreshRedraw party
	-- self.winMap:redraw()
	-- self:updateTurtles()  -- winTurtles is not also part of the party

	self.storageDisplay:checkUpdates()
	self:updateGroups()
	self:updateTime()

	local winTop = self:getTopWindow()
	if winTop ~= self.winMain 
	and winTop ~= self.storageDisplay 
	and winTop ~= self.winGroups then
		winTop:refreshRedraw()
	end
end

function HostDisplay:getTopWindow()
	local winTop = self.objects.first
	local o = winTop
	while o do
		if o.visible then
			winTop = o
			break
		end
		o = o._next
	end
	return winTop
end

function HostDisplay:redraw()
	-- only redraw the top window and set the rest invisible
	-- get first visible window
	local winTop = self:getTopWindow()
	
	-- set other windows invisible
	local o = winTop._next
	while o do
		if o.setVisible then
			o:setVisible(false)
		else
			o.visible = false
		end
		o = o._next
	end
	
	-- make sure the window is set to visible
	if winTop.setVisible then
		winTop:setVisible(true)
	else
		winTop.visible = true
	end
	winTop:redraw()
end
function HostDisplay:updateTime()

	local winMain = self.winMain
	local lbl = winMain.lblTimeVal
	local time = os.epoch("ingame") / 1000
	local timeTable = os.date("*t", time)
	local txt = string.format("%02d:%02d:%02d",timeTable.hour,timeTable.min,timeTable.sec)
	lbl:setText(txt)
	lbl:redraw()

	local activeCount = 0
	local onlineCount = 0
	local totalCount = 0
	for id,turtle in pairs(self.turtles) do
		totalCount = totalCount + 1
		if turtle.state.online then
			onlineCount = onlineCount + 1
			if turtle.state.task then
				activeCount = activeCount + 1
			end
		end
	end

	local activeColor = (activeCount == totalCount and colors.green)
			or (activeCount == 0 and colors.orange)
			or colors.white
	local txt = tostring(activeCount)
	local len = string.len(txt)
	local txt = string.format("%s%s",string.rep(" ", 6-len),txt)
	winMain.lblActiveHd:setTextColor(activeColor)
	winMain.lblActive:setText(txt)
	winMain.lblActive:setTextColor( activeColor )
	
	local onlineColor = (onlineCount == totalCount and colors.green)
			or (onlineCount == 0 and colors.red)
			or colors.orange
	local txt = tostring(onlineCount)
	local len = string.len(txt)
	local txt = string.format("%s%s",string.rep(" ", 6-len),txt)
	winMain.lblOnlineHd:setTextColor(onlineColor)
	winMain.lblOnline:setText(txt)
	winMain.lblOnline:setTextColor( onlineColor )
	
	local txt = tostring(totalCount)
	local len = string.len(txt)
	local txt = string.format("%s%s",string.rep(" ", 6-len),txt)
	winMain.lblTotal:setText(txt)

	local openAlertCount = #self.alerts.open
	local handledAlertCount = #self.alerts.handled
	local alertColor = (openAlertCount == 0 and colors.white)
			or colors.red
	local txt = tostring(openAlertCount .. "(" .. handledAlertCount .. ")")
	local len = string.len(txt)
	local txt = string.format("%s%s",string.rep(" ", 7-len),txt)
	winMain.lblAlertsHd:setTextColor(alertColor)
	winMain.lblAlerts:setText(txt)
	winMain.lblAlerts:setTextColor(alertColor)

	-- not sure if this is clean like this...
	local winSettings = self.winSettings
	winSettings.lblMsgCountVal:setText(global.messageCount or "0")
	winSettings.lblMsgCountVal:redraw()

	winMain.lblActiveHd:redraw()
	winMain.lblActive:redraw()	
	winMain.lblOnlineHd:redraw()
	winMain.lblOnline:redraw()
	winMain.lblTotal:redraw()
	winMain.lblAlertsHd:redraw()
	winMain.lblAlerts:redraw()
end
function HostDisplay:getMapDisplay()
	return self.mapDisplay
end
function HostDisplay:displayMap()

	self:addObject(self.winMap)
	--self:addObject(self.mapDisplay)
	self.winMap:setPos(1,1)
	self.winMap:showControls()
	self.winMap:fillParent()
	
	self:redraw()
	return true
end
function HostDisplay:closeMap()
	self.winMap:close()
end

function HostDisplay:openTurtleDetails(turt)
	local detailsWindow = TurtleDetails:new(1, 1, turt, self.node)
	detailsWindow:setHostDisplay(self)
	self:addObject(detailsWindow)
	detailsWindow:fillParent()
	self:redraw()
	return true
end

function HostDisplay:openGroupDetails(group)
	local detailsWindow = GroupDetails:new(1, 1, group)
	detailsWindow:setHostDisplay(self)
	self:addObject(detailsWindow)
	detailsWindow:fillParent()
	-- Adding a window makes every child visible, and fillParent establishes its
	-- final width. Settle status-dependent visibility, packed controls and padded
	-- coordinate fields now so the first frame is already the final layout.
	detailsWindow:refresh()
	self:redraw()
	return true
end

function HostDisplay:displayStorage()
	self:addObject(self.storageDisplay)
	self.storageDisplay:fillParent()
	self.storageDisplay:refresh()
	self:redraw()
	return true
end
function HostDisplay:displayTurtles()
	self:addObject(self.winTurtles)
	self.winTurtles:fillParent()
	self:refreshRedraw()
	return true
end

function HostDisplay:deleteTurtle(id)
	if self.turtles[id] then
		-- delete from global list
		self.turtles[id] = nil
	end
end

-- task groups
function HostDisplay:displayGroups()
	self:addObject(self.winGroups)
	self.winGroups:fillParent()
	-- LABENHANCED_GROUPS_MASTERDETAIL
	-- Rail rows keep their fixed width now; it is the pane that tracks the
	-- page, and it can only be sized once fillParent has settled this window.
	self:layoutGroupsPage()
	self:updateGroups()
	self:redraw()
	return true
end
function HostDisplay:addGroup()
	-- LABENHANCED_NEWGROUP_HMI
	-- One dialog at a time. Pressing create twice in quick succession used to
	-- build a second selector over the first; both then unlinked the same page
	-- close button and the object list corrupted.
	local existing = self.winGroups.groupSelector
	if existing and not existing.closed then
		return true
	end

	self.winGroups.groupSelector = TaskGroupSelector:new(1,1,self.taskManager, self.doSlowStart)
	self.winGroups.groupSelector:setHostDisplay(self)
	self.winGroups:addObject(self.winGroups.groupSelector)
	-- LABENHANCED_NEWGROUP_HMI: a centred panel, not a full-page form
	self.winGroups.groupSelector:centerIn(self.winGroups)
	-- centerIn removes the page X. Reflow the title row before this redraw so
	-- create/+ occupies that newly available slot on the very first frame.
	self:refreshGroupsHeader()
	self:redraw()
	return true
end

-- LABENHANCED_GROUPS_MASTERDETAIL
-- Builds the master/detail furniture onto a Groups window: a scrolling rail of
-- one-line groups, a divider rule, and the detail pane. Shared with the
-- emulator harness so a preview exercises the real construction rather than a
-- copy that can rot.
function HostDisplay:buildGroupsChrome(win)
	win.railWin = Window:new(1, groupsLayout.top, groupsLayout.railW, 1)
	win.railWin:removeCloseButton()
	win.railWin:setBackgroundColor(colors.black)
	win.railWin:setBorderColor(colors.black)
	-- The rail owns the scrollbar, not the page: scrolling a long group list
	-- must not drag the detail pane off the top of the screen with it.
	win.railWin:addScrollbar(true)
	win:addObject(win.railWin)

	win.boxRailRule = Box:new(groupsLayout.ruleX, groupsLayout.top, 1, 1,
		colors.gray)
	win:addObject(win.boxRailRule)

	win.pane = TaskGroupPane:new(groupsLayout.paneX, groupsLayout.top,
		groupsLayout.minPaneW, 1)
	win.pane:setHostDisplay(self)
	win:addObject(win.pane)

	win.selectedId = nil
	return win
end

-- Sizes the rail, the rule and the pane to the page. Called whenever the page
-- is shown or resized; the heights are only knowable once fillParent has run.
function HostDisplay:layoutGroupsPage()
	local win = self.winGroups
	if not (win and win.railWin) then return end

	local width = (win.getWidth and win:getWidth()) or self:getWidth()
	local height = (win.getHeight and win:getHeight()) or self:getHeight()
	local bodyH = math.max(1, height - groupsLayout.top + 1)

	win.railWin:setSize(groupsLayout.railW, bodyH)
	-- Box has no setSize, only the two setters.
	win.boxRailRule:setWidth(1)
	win.boxRailRule:setHeight(bodyH)
	win.pane:setSize(
		math.max(groupsLayout.minPaneW,
			width - groupsLayout.rightGutter - groupsLayout.paneX + 1),
		bodyH)
end

-- Ids of the groups the rail shows, in a stable order. pairs() order is
-- arbitrary, so without this the rail reshuffles itself every rebuild.
function HostDisplay:sortedGroupIds()
	local ids = {}
	for id, group in pairs(self.taskManager:getGroups()) do
		if group.status ~= "new" then ids[#ids + 1] = id end
	end
	table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
	return ids
end

-- Drives the pane from the rail. Passing nil clears the selection, which is
-- what a delete leaves behind.
function HostDisplay:selectGroup(id)
	local win = self.winGroups
	if not win then return end

	local group = id and self.taskManager:getGroups()[id] or nil
	if id and not group then id = nil end

	win.selectedId = id
	for cid, control in pairs(win.taskGroupControls) do
		control:setSelected(cid == id)
	end
	if win.pane then win.pane:setGroup(group) end
	return true
end

function HostDisplay:refreshGroupsHeader()
	-- LABENHANCED_GROUPS_HMI
	-- Keep the header plate spanning the window and show how many groups exist
	-- and how many are running, so the page answers "is anything working?"
	-- without opening a group.
	local win = self.winGroups
	if not win or not win.boxHeader then return end

	-- The scrollbar narrows innerWin by one column, but its track starts below
	-- the three-row close-button slot. Row 1 can therefore use the full outer
	-- width whenever the X is suppressed by the new-group modal. When the X is
	-- present, clip against its real position instead of reserving guessed space.
	local inner = win.innerWin
	local width = (win.getWidth and win:getWidth())
		or (inner and inner.getWidth and inner:getWidth())
		or self:getWidth()

	local titleEnd = 13
	local usable = width
	if win.btnClose and win.btnClose.visible then
		local originX = (inner and inner.x or 1) - (inner and inner.scrollX or 0)
		usable = math.min(usable, win.btnClose.x - 1 - originX)
	end
	usable = math.max(titleEnd, usable)

	win.boxHeader:setWidth(usable)
	win.boxHeader:setBorderColor(colors.gray)

	local total, active = 0, 0
	for _,group in pairs(self.taskManager:getGroups()) do
		if group.status ~= "new" then
			total = total + 1
			if group:isActive() then active = active + 1 end
		end
	end

	-- Right to left: the + control sits flush against the close button, its
	-- caption one space to its left, then the counts. Each element drops out
	-- rather than collide once the window is too narrow to hold it.
	local btnW = win.btnAdd.width or 3
	local btnX = math.max(titleEnd, usable - btnW + 1)
	win.btnAdd:setPos(btnX, 1)

	local caption = "create"
	local cx = btnX - #caption - 1
	if cx >= titleEnd then
		win.lblAdd:setText(caption)
		win.lblAdd:setPos(cx, 1)
	else
		win.lblAdd:setText("")
		cx = btnX
	end

	local summary = string.format("%d GRP  %d ACT", total, active)
	local sx = cx - #summary - 2
	if sx >= titleEnd then
		win.lblSummary:setText(summary)
		win.lblSummary:setPos(sx, 1)
	else
		win.lblSummary:setText("")
	end
end

function HostDisplay:updateGroups()
	if self.winGroups.visible then
		-- LABENHANCED_GROUPS_MASTERDETAIL
		-- Rows are one line each and live in the rail, and their y comes from
		-- the sorted position rather than creation order, so inserting a group
		-- no longer leaves the list in whatever order pairs() happened to hand
		-- back.
		local taskControls = self.winGroups.taskGroupControls
		local groups = self.taskManager:getGroups()
		local ids = self:sortedGroupIds()

		for index, id in ipairs(ids) do
			local control = taskControls[id]
			if not control then
				control = TaskGroupControl:new(1, index, groups[id])
				taskControls[id] = control
				self.winGroups.railWin:addObject(control)
				control:setHostDisplay(self)
			end
			control:setTaskGroup(groups[id])
			control:setPos(1, index)
		end
		self.winGroups.groupCt = #ids

		-- The rail only needs a scrollbar when the list outruns it. Showing one
		-- for four groups puts a full-height track down the middle of the page.
		local rail = self.winGroups.railWin
		if rail and rail.scrollBar then
			local rows = (rail.innerWin and rail.innerWin:getHeight())
				or rail:getHeight()
			rail.scrollBar.visible = (#ids > rows)
		end

		-- A group can vanish underneath us (deleted elsewhere, or cancelled into
		-- a status the rail does not list).
		for id, control in pairs(taskControls) do
			if not groups[id] or groups[id].status == "new" then
				self.winGroups.railWin:removeObject(control)
				taskControls[id] = nil
			end
		end

		-- Keep a selection whenever there is anything to select, so the pane is
		-- never blank beside a populated rail.
		local selected = self.winGroups.selectedId
		if not selected or not taskControls[selected] then
			self:selectGroup(ids[1])
		end

		self:refreshGroupsHeader()
		self.winGroups:redraw()
	end
end
function HostDisplay:deleteGroup(id)
	-- delete all group controls and rebuild them
	for _,groupControl in pairs(self.winGroups.taskGroupControls) do
		self.winGroups.railWin:removeObject(groupControl)
	end
	self.winGroups.taskGroupControls = {}
	self.winGroups.groupCt = 0
	-- The pane was showing the group that just went away.
	self:selectGroup(nil)
end

function HostDisplay:globalReboot(slow)
	if self.node then
		if slow then 
		for id,turtle in pairs(self.turtles) do
			self.node:send(id, {"REBOOT"},false,false)
			sleep(0.15)
		end
		else
			self.node:broadcast({"REBOOT"},true)
		end
	end
	--self:reboot()
end

function HostDisplay:globalCancelTask()
	-- cancel all running tasks of the turtles
	if self.node then
		for id,turtle in pairs(self.turtles) do
			self.node:send(id, {"STOP"}, false, false)
		end
	end
end
function HostDisplay:globalCallHome()
	-- cancel all running tasks of the turtles
	if self.node then
		for id,turtle in pairs(self.turtles) do
			self.node:send(id, {"DO", "returnHome"}, false, false)
		end
	end
end
function HostDisplay:globalDumpItems(dropAll)
	-- cancel all running tasks of the turtles
	if self.node then
		for id,turtle in pairs(self.turtles) do
			self.node:send(id, {"DO", "dumpBadItems", {dropAll}}, false, false)
		end
	end
end
function HostDisplay:globalGetFuel()
	-- cancel all running tasks of the turtles
	if self.node then
		for id,turtle in pairs(self.turtles) do
			self.node:send(id, {"DO", "getFuel"}, false, false)
			--self.node:send(id, {"DO", "returnHome"}, false, false)
		end
	end
end


function HostDisplay:globalShutdown()
	if self.node then
		self.node:broadcast({"SHUTDOWN"},true)
	end
	--self:reboot()
end

function HostDisplay:reboot()
	self:clear()
    self:setCursorPos(math.floor((self:getWidth()-10)/2),math.floor(self:getHeight()/2))
    self:write("REBOOTING")
	self:update()
	global.beforeTerminate()
	-- self.node:broadcast({"REBOOT"},true)
    os.reboot()
end

function HostDisplay:terminate()
	global.running = false
	self:clear()
	self:setCursorPos(math.floor((self:getWidth()-10)/2),math.floor(self:getHeight()/2))
	self:write("TERMINATED")
	self:update()
	global.beforeTerminate()
	print("TERMINATED")
	return true
end

return HostDisplay
