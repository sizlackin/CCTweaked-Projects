
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

local turtleListY = 15
local mapX = 37
function GroupDetails:onResize() -- super override
	Window.onResize(self) -- super
	
	print("turtlelist", self.turtleList.width, self.turtleList.height)
	self.winMap:setSize(self.width - mapX, math.min(10, self.height - 4))
	self.turtleList:setSize(self.width-2, self.height - turtleListY)
	self.winInfo:setSize(self.width - 2, self.turtleList.y - 2)
	print("onResize", self.width, self.height)
	print("turtlelist", self.turtleList.width, self.turtleList.height)
end

function GroupDetails:initializeMiniMap()
	-- TODO: for minimap but also whenever opening the map
	-- set the zoomlevel so the full area ( + home ) fit on the screen

	-- could also use main mapDisplay but this is cleaner
	self.winMap = MapDisplay:new(mapX, 2, self.width - mapX, math.min(10, self.height - 4))
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

	winInfo.lblId = Label:new("Group  " .. tostring(group.shortId or group.id or "????") .. " - " .. tostring(group.taskName or "no task"),3,1)
	-- row 1 - 16

	local x, y = 3,3
	local area = group:getArea() or { start = {x=0,y=0,z=0}, finish = {x=0,y=0,z=0} }
	winInfo.lblXStart = Label:new("X  " .. area.start.x,3,3)
	winInfo.lblYStart = Label:new("Y  " .. area.start.y,3,4)
	winInfo.lblZStart = Label:new("Z  " .. area.start.z,3,5)

	winInfo.lblXFinish = Label:new(area.finish.x,13,3)
	winInfo.lblYFinish = Label:new(area.finish.y,13,4)
	winInfo.lblZFinish = Label:new(area.finish.z,13,5)

	-- row 17 - 27

	local x, y = 3,9

	local x, y = 3 ,7
	winInfo.btnAddTask = Button:new("add task",x + 7,y,10,1, colors.purple)
	winInfo.btnCancelTask = Button:new("cancel",x + 18, y,6,1)
	winInfo.btnDeleteGroup = Button:new("delete",x,y,13,1)
	winInfo.btnOptions = Button:new("options", 21,4,6,1)
	-- row 28 - 

	winInfo.lblTask = Label:new(group.taskName,30,3)
	winInfo.lblProgress = Label:new("",30,5)
	winInfo.lblActiveTurtles = Label:new("0/".. tostring(group.groupSize or 0),41,4)
	winInfo.lblStatus = Label:new(group:getStatus(),30,4,group:getStatusColor())
	winInfo.lblTime = Label:new("00:00.00", 41,5)

	winInfo.btnCancelTask.click = function() self:cancelTask() end
	winInfo.btnDeleteGroup.click = function() return self:deleteGroup() end
	winInfo.btnOptions.click = function() return self:openOptions() end
	winInfo.btnAddTask.click = function() return self:addTask() end
	
	--winInfo.btnCallHome.click = function() self:callHome() end

	winInfo:addObject(winInfo.lblId)
	winInfo:addObject(winInfo.lblXStart)
	winInfo:addObject(winInfo.lblYStart)
	winInfo:addObject(winInfo.lblZStart)

	winInfo:addObject(winInfo.lblXFinish)
	winInfo:addObject(winInfo.lblYFinish)
	winInfo:addObject(winInfo.lblZFinish)

	winInfo:addObject(winInfo.lblTask)
	winInfo:addObject(winInfo.lblProgress)
	winInfo:addObject(winInfo.lblActiveTurtles)
	winInfo:addObject(winInfo.lblStatus)
	winInfo:addObject(winInfo.lblTime)

	-- TODO: popup window showing funciton args instead of fixed start, finish labels
	-- winInfo:addObject(winInfo.btnViewArgs) 

	winInfo:addObject(winInfo.btnAddTask)
	winInfo:addObject(winInfo.btnCancelTask)
	--winInfo:addObject(winInfo.btnCallHome)
	winInfo:addObject(winInfo.btnDeleteGroup)
	winInfo:addObject(winInfo.btnOptions)

	self:addObject(self.turtleList)
	self:addObject(winInfo)
	self:initializeMiniMap()
	
	winInfo.btnDeleteGroup.visible = false
	winInfo.btnCancelTask.visible = false

	--self:refresh()

end

function GroupDetails:refreshPos()

	local area = self.group:getArea() or { start = {x=0,y=0,z=0}, finish = {x=0,y=0,z=0} }
	local start, finish = area.start, area.finish
	local winInfo = self.winInfo

	winInfo.lblXStart:setText("X  " .. start.x)
	winInfo.lblYStart:setText("Y  " .. start.y)
	winInfo.lblZStart:setText("Z  " .. start.z)
	winInfo.lblXFinish:setText(finish.x)
	winInfo.lblYFinish:setText(finish.y)
	winInfo.lblZFinish:setText(finish.z)
end

function GroupDetails:refresh()
	self:refreshPos()
	local winInfo = self.winInfo

	local group = self.group
	winInfo.lblTask:setText(group.taskName or "no task")
	
	local status = group:getStatus()
	local activeCount = group:getActiveTurtles()
	local active = group:isActive()

	winInfo.lblStatus:setText(status)
	winInfo.lblStatus:setTextColor(group:getStatusColor())
	winInfo.lblActiveTurtles:setText(activeCount.."/"..group.groupSize)
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