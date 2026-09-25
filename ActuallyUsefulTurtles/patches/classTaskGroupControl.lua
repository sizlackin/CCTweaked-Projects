
local Button = require("classButton")
local Label = require("classLabel")
local BasicWindow = require("classBasicWindow")
local Box = require("classBox")
local TaskSelector = require("classTaskSelector")
local ChoiceSelector = require("classChoiceSelector")
local GroupDetails = require("classTaskGroupDetails")

local default = {
	colors = {
		background = colors.black,
		border = colors.gray,
		good = colors.green,
		okay = colors.orange,
		bad = colors.red,
		neutral = colors.white,
		-- LABENHANCED_GROUPS_HMI
		-- Plates and captions follow the map screen: grouped values sit on a
		-- gray plate, captions are dimmed, values stay white.
		plate = colors.gray,
		caption = colors.lightGray,
		value = colors.white,
		divider = colors.gray,
		-- Controls need their own tier. Button defaults to colors.gray, the same
		-- gray as the plates, so map/opts/detail read as text on a slab instead
		-- of as controls. Lighter block + dark glyph, per the map screen.
		control = colors.lightGray,
		controlText = colors.black,
	},
	width = 50,
	height = 7,
}

-- LABENHANCED_GROUPS_HMI
-- Every column lives here so the drawn cells and the click areas of the
-- buttons cannot drift apart. Button x/width are deliberately unchanged from
-- the original layout: openOptions anchors its ChoiceSelector to btnOptions.
local layout = {
	stripX     = 1,  stripW = 2,   -- vertical status strip
	headerRow  = 2,
	dataTop    = 3,                -- data occupies rows 3..5
	dataRows   = 3,
	coordX     = 4,  coordW = 16,  -- X/Y/Z plate
	coordTop   = 2,  coordRows = 4, -- plate includes its FROM/TO caption row
	axisX      = 5,
	startEnd   = 12,               -- start value is right-aligned to here
	finishEnd  = 18,               -- finish value is right-aligned to here
	btnX       = 21, btnW  = 6,
	-- Row-header items sit right of the coordinate plate so the plate can own
	-- its caption row without colliding with the id and status.
	idX        = 21,
	lampX      = 26,
	statusX    = 28,
	infoX      = 29,               -- key/value block
	infoPad    = 1,
	dividerRow = 6,
	-- The close button overlays the inner window's last two columns (it sits at
	-- window column W-2 while the row is only W-1 wide). Reserve exactly those
	-- two so the row runs flush up to the X with no dead gap, same as the header.
	rightGutter = 2,
}

-- Compact, uppercase status wording. Denser than the raw enum without
-- inventing new states: the value still comes from group:getStatus().
local function statusText(status)
	if not status then return "UNKNOWN" end
	local text = tostring(status):upper():gsub("_", " ")
	text = text:gsub("^PARTIALLY ", "PART ")
	return text
end

-- Clip a value to the space its plate actually has. taskName is free text
-- from whoever created the group, so without this a long one runs off the
-- plate, past the row and over the scrollbar.
local function fitText(text, width)
	text = tostring(text)
	if width < 1 then return "" end
	if #text > width then return text:sub(1, width) end
	return text
end

local function padLeft(text, width)
	text = tostring(text)
	local pad = width - #text
	if pad > 0 then return string.rep(" ", pad) .. text end
	return text
end

local TaskGroupControl = BasicWindow:new()

function TaskGroupControl:new(x,y,taskGroup)
	local o = o or BasicWindow:new(x,y,default.width,default.height) or {}
	setmetatable(o,self)
	self.__index = self
	
	o:setBackgroundColor(default.colors.background)
	-- LABENHANCED_GROUPS_HMI
	-- Match the border to the background: BasicWindow:redraw draws a box whenever
	-- the two differ, which kept the old gray card outline around every row. The
	-- status strip and the divider carry that structure now.
	o:setBorderColor(default.colors.background)

	o.taskGroup = taskGroup or nil
	o.mapDisplay = nil -- needed to enable the map button
	o.hostDisplay = nil
	o:initialize()
	
	o:setTaskGroup(taskGroup)
	
	return o
end


function TaskGroupControl:setTaskGroup(taskGroup)
	if taskGroup then
		self.taskGroup = taskGroup
		local activeCount = self.taskGroup:getActiveTurtles()
		self.active = (activeCount ~= 0)
	
	else
		--pseudo data
		self.taskGroup = {}
		self.taskGroup.id = "no data"
		self.taskGroup.taskName = "no task"
		self.taskGroup.groupSize = 0
		self.taskGroup.started = os.epoch("ingame")
		self.active = false
	end
	if self.active then
		self.statusText = "active"
		self.statusColor = default.colors.good
	else
		self.statusText = "done"
		self.statusColor = default.colors.okay
	end
end


function TaskGroupControl:setHostDisplay(hostDisplay)
	self.hostDisplay = hostDisplay
	if self.hostDisplay then
		self.mapDisplay = self.hostDisplay:getMapDisplay()
	end
end

-- function TurtleControl:addTask()
	-- self.taskSelector = TaskSelector:new(self.x+19,self.y-1)
	-- self.taskSelector:setNode(self.node)
	-- self.taskSelector:setData(self.data)
	-- self.taskSelector:setHostDisplay(self.hostDisplay)
	-- self.parent:addObject(self.taskSelector)
	-- self.parent:redraw()
	-- return true
-- end

function TaskGroupControl:cancelTask()
	self.taskGroup:cancel()
	-- LABENHANCED_AREA_LIFECYCLE
	-- A cancelled group has no live outline. Drop it now rather than waiting
	-- for the next drawAreas sweep.
	if self.mapDisplay and self.taskGroup then
		self.mapDisplay:removeGroupArea(self.taskGroup.id)
	end
end

function TaskGroupControl:openMap()
	-- open map and set focus to middle of area
	if self.hostDisplay and self.mapDisplay then
		local start, finish, focus = self.taskGroup:getAreaDetails()
		if not start then return end
		-- LABENHANCED_AREA_LIFECYCLE
		-- Upsert one managed outline keyed by group id instead of pushing an
		-- untagged rectangle. An untagged entry can never be cleaned up, so
		-- reopening this row used to stack duplicates that outlived the group.
		self.mapDisplay:setGroupArea(self.taskGroup)
		self.mapDisplay:setMid(focus.x, focus.y, focus.z)
		self.hostDisplay:displayMap()
	end
end

function TaskGroupControl:openDetails()
	-- open a new window with more details and options for the turtle
	-- for fullscreen add to hostDisplay instead of parent
	self.hostDisplay:openGroupDetails(self.taskGroup)
	return true
end

function TaskGroupControl:openOptions()
	local choices = { "call home", "reboot" }
	if self.taskGroup:isResumable() then 
		table.insert(choices,1,"resume task")
	end
	local active = self.taskGroup:isActive()
	if active then 
		table.insert(choices, "cancel task")
	else
		table.insert(choices, "delete group")
	end
	
	local choiceSelector = ChoiceSelector:new(self.x + self.btnOptions.x - 1, self.y + self.btnOptions.y-5, 16, 6, choices)
	choiceSelector.onChoiceSelected = function(choice)
		if choice == "call home" then
			self:callHome()
		elseif choice == "reboot" then
			self.taskGroup:reboot()
		elseif choice == "resume task" then
			self.taskGroup:resume()
		elseif choice == "cancel task" then
			self.taskGroup:cancel()
		elseif choice == "delete group" then
			self:deleteGroup()
		end
	end
	
	self.parent:addObject(choiceSelector)
	self.parent:redraw()
	return true
end
function TaskGroupControl:callHome()
	self.taskGroup:addTaskToTurtles("returnHome",{})
end

function TaskGroupControl:onResize() -- super override
	BasicWindow.onResize(self) -- super

	-- LABENHANCED_GROUPS_HMI
	-- The right-hand plate is the only element that tracks the window width.
	if self.boxInfo then
		self.boxInfo:setWidth(
			math.max(1, self.width - layout.rightGutter - layout.infoX + 1))
	end
end

function TaskGroupControl:redraw() -- super override
	self:refresh()

	BasicWindow.redraw(self) -- super

	-- LABENHANCED_GROUPS_HMI
	-- Drawn after the children so it sits on top: a thin divider closing the
	-- row, and the uptime right-aligned to the trailing edge. A filled row is
	-- used for the divider rather than a box-drawing glyph so it renders the
	-- same on every CraftOS font.
	local c = default.colors
	local rightEdge = self.width - layout.rightGutter

	local span = math.max(0, rightEdge - layout.coordX + 1)
	if span > 0 then
		self:drawFilledBox(layout.coordX, layout.dividerRow, span, 1, c.divider)
	end

	local uptime = self.lblTime and self.lblTime:getText() or ""
	if #uptime > 0 then
		local ux = rightEdge - #uptime + 1
		-- Only draw the uptime when it clears the status text with a gap. The
		-- old guard only checked infoX, so at narrow widths a long status ran
		-- straight into it (PART RESUMED123:45.67).
		local statusEnd = layout.statusX - 1
		if self.lblStatus then
			statusEnd = layout.statusX + #self.lblStatus:getText() - 1
		end
		if ux > statusEnd + 1 then
			self:drawText(ux, layout.headerRow, uptime, c.caption, self.backgroundColor)
		end
	end
end

function TaskGroupControl:initialize()
	-- LABENHANCED_GROUPS_HMI
	-- Flat HMI row instead of a boxed card: a colored status strip on the left
	-- edge, one header line, and two gray data plates. Objects added earlier
	-- draw underneath, so every plate is registered before its labels.
	local c = default.colors
	local group = self.taskGroup
	local area = group:getArea() or { start = {x=0,y=0,z=0}, finish = {x=0,y=0,z=0} }

	-- left status strip, recolored per status in refresh()
	self.boxStrip = Box:new(layout.stripX, layout.headerRow, layout.stripW,
		layout.dataRows + 1, self.statusColor or c.neutral)
	self.boxStrip:setBorderColor(self.statusColor or c.neutral)

	-- plates behind the two data groups
	self.boxCoords = Box:new(layout.coordX, layout.coordTop, layout.coordW,
		layout.coordRows, c.plate)
	self.boxInfo = Box:new(layout.infoX, layout.dataTop,
		math.max(1, self.width - layout.rightGutter - layout.infoX + 1),
		layout.dataRows, c.plate)

	self:addObject(self.boxStrip)
	self:addObject(self.boxCoords)
	self:addObject(self.boxInfo)

	-- header line: id, status lamp + text, uptime
	self.lblId = Label:new(string.sub(tostring(group.id),1,4), layout.idX,
		layout.headerRow, c.value)
	self.boxLamp = Box:new(layout.lampX, layout.headerRow, 1, 1,
		self.statusColor or c.neutral)
	self.boxLamp:setBorderColor(self.statusColor or c.neutral)
	self.lblStatus = Label:new(statusText(group.status), layout.statusX,
		layout.headerRow, self.statusColor)
	-- Holds the uptime text only; redraw() paints it right-aligned, so it is
	-- deliberately not registered as a drawn child.
	self.lblTime = Label:new("00:00.00", layout.infoX, layout.headerRow, c.caption)

	self:addObject(self.lblId)
	self:addObject(self.boxLamp)
	self:addObject(self.lblStatus)

	-- Column captions, right-aligned to the same field edges as the values below
	-- so caption and number share a right margin. Without these the two number
	-- columns are unlabelled and you cannot tell the area's start from its end.
	self.lblFromCap = Label:new("FROM", layout.startEnd - 3, layout.coordTop,
		c.caption, c.plate)
	self.lblToCap = Label:new("TO", layout.finishEnd - 1, layout.coordTop,
		c.caption, c.plate)
	self:addObject(self.lblFromCap)
	self:addObject(self.lblToCap)

	-- coordinate plate: axis caption, start and finish right-aligned so the
	-- digits do not jump around as a group is edited
	self.lblXAxis = Label:new("X", layout.axisX, layout.dataTop,   c.caption, c.plate)
	self.lblYAxis = Label:new("Y", layout.axisX, layout.dataTop+1, c.caption, c.plate)
	self.lblZAxis = Label:new("Z", layout.axisX, layout.dataTop+2, c.caption, c.plate)

	self.lblXStart = Label:new(area.start.x, layout.axisX+2, layout.dataTop,   c.value, c.plate)
	self.lblYStart = Label:new(area.start.y, layout.axisX+2, layout.dataTop+1, c.value, c.plate)
	self.lblZStart = Label:new(area.start.z, layout.axisX+2, layout.dataTop+2, c.value, c.plate)

	self.lblXFinish = Label:new(area.finish.x, layout.startEnd+1, layout.dataTop,   c.value, c.plate)
	self.lblYFinish = Label:new(area.finish.y, layout.startEnd+1, layout.dataTop+1, c.value, c.plate)
	self.lblZFinish = Label:new(area.finish.z, layout.startEnd+1, layout.dataTop+2, c.value, c.plate)

	self:addObject(self.lblXAxis)
	self:addObject(self.lblYAxis)
	self:addObject(self.lblZAxis)
	self:addObject(self.lblXStart)
	self:addObject(self.lblYStart)
	self:addObject(self.lblZStart)
	self:addObject(self.lblXFinish)
	self:addObject(self.lblYFinish)
	self:addObject(self.lblZFinish)

	-- key/value block on the right plate
	local ix = layout.infoX + layout.infoPad
	self.lblTaskCap = Label:new("TASK", ix, layout.dataTop,   c.caption, c.plate)
	self.lblTurtCap = Label:new("TURT", ix, layout.dataTop+1, c.caption, c.plate)
	self.lblProgCap = Label:new("PROG", ix, layout.dataTop+2, c.caption, c.plate)

	self.lblTask = Label:new(group.taskName or "", ix+5, layout.dataTop, c.value, c.plate)
	self.lblActiveTurtles = Label:new("0/".. tostring(group.groupSize), ix+5,
		layout.dataTop+1, c.value, c.plate)
	self.lblProgress = Label:new("", ix+5, layout.dataTop+2, c.value, c.plate)

	self:addObject(self.lblTaskCap)
	self:addObject(self.lblTurtCap)
	self:addObject(self.lblProgCap)
	self:addObject(self.lblTask)
	self:addObject(self.lblActiveTurtles)
	self:addObject(self.lblProgress)

	-- controls, unchanged geometry
	self.btnMap = Button:new("map", layout.btnX, layout.dataTop, layout.btnW, 1, c.control)
	self.btnOptions = Button:new("opts", layout.btnX, layout.dataTop+1, layout.btnW, 1, c.control)
	self.btnDetails = Button:new("detail", layout.btnX, layout.dataTop+2, layout.btnW, 1, c.control)
	self.btnMap:setTextColor(c.controlText)
	self.btnOptions:setTextColor(c.controlText)
	self.btnDetails:setTextColor(c.controlText)

	self.btnMap.click = function() self:openMap() end
	self.btnOptions.click = function() return self:openOptions() end
	self.btnDetails.click = function() return self:openDetails() end

	self:addObject(self.btnMap)
	self:addObject(self.btnOptions)
	self:addObject(self.btnDetails)
end

function TaskGroupControl:refreshPos()

	local area = self.taskGroup:getArea() or { start = {x=0,y=0,z=0}, finish = {x=0,y=0,z=0} }
	local start, finish = area.start, area.finish

	-- LABENHANCED_GROUPS_HMI
	-- Right-align into fixed-width fields so the columns stay put.
	local startW = layout.startEnd - (layout.axisX + 2) + 1
	local finishW = layout.finishEnd - (layout.startEnd + 1) + 1

	self.lblXStart:setText(padLeft(start.x, startW))
	self.lblYStart:setText(padLeft(start.y, startW))
	self.lblZStart:setText(padLeft(start.z, startW))
	self.lblXFinish:setText(padLeft(finish.x, finishW))
	self.lblYFinish:setText(padLeft(finish.y, finishW))
	self.lblZFinish:setText(padLeft(finish.z, finishW))
end

function TaskGroupControl:infoValueWidth()
	-- from the value column to the inner edge of the right-hand plate
	local valueX = layout.infoX + layout.infoPad + 5
	return (self.width - layout.rightGutter) - valueX + 1
end

function TaskGroupControl:refresh()
	self:refreshPos()

	local group = self.taskGroup
	local valueW = self:infoValueWidth()
	self.lblTask:setText(fitText(group.taskName or "no task", valueW))

	local status = group:getStatus()
	local activeCount = group:getActiveTurtles()
	local active = group:isActive()

	-- LABENHANCED_GROUPS_HMI
	-- One status colour drives the strip, the lamp and the label, so the row
	-- reads at a glance. Colours still come from group:getStatusColor().
	local statusColor = group:getStatusColor()

	self.lblStatus:setText(statusText(status))
	self.lblStatus:setTextColor(statusColor)
	if self.boxStrip then
		self.boxStrip:setBackgroundColor(statusColor)
		self.boxStrip:setBorderColor(statusColor)
	end
	if self.boxLamp then
		self.boxLamp:setBackgroundColor(statusColor)
		self.boxLamp:setBorderColor(statusColor)
	end

	self.lblId:setText(string.sub(tostring(group.id),1,4))
	self.lblActiveTurtles:setText(
		fitText(activeCount.."/"..tostring(group.groupSize), valueW))
	self.lblProgress:setText(fitText(group:getProgressText(), valueW))

	self.lblTime:setText(group:getUptimeText())
end

function TaskGroupControl:deleteGroup()
	-- LABENHANCED_AREA_LIFECYCLE
	-- Capture the id and clear the outline before deleting, because the group
	-- may no longer be resolvable afterwards.
	local groupId = self.taskGroup and self.taskGroup.id
	if self.mapDisplay and groupId then
		self.mapDisplay:removeGroupArea(groupId)
	end
	if self.taskGroup then
		self.taskGroup:delete()
	end
	if self.hostDisplay then
		self.hostDisplay:deleteGroup(groupId)
	end
	return true
end

return TaskGroupControl