local Button = require("classButton")
local Label = require("classLabel")
local Window = require("classWindow")
local Frame = require("classFrame")
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
	height = 7,

	yLevel =  {
		top = 60,
		bottom = -58,
	},
	slowstartDelay = 0.05,
}

local TaskGroupSelector = Window:new()

function TaskGroupSelector:new(x,y, taskManager, slowStart)
	local o = o or Window:new(x,y,width or default.width ,height or default.height ) or {}
	setmetatable(o, self)
	self.__index = self
	
	o:setBackgroundColor(default.colors.background)
	o:setBorderColor(default.colors.border)
	
	o.mapDisplay = nil
	o.positions = {}
	o.selectionPreview = nil
	o.btnConfirmArea = nil
	o.btnReselectArea = nil
	o.taskGroup = nil
	o.taskManager = taskManager
	o.slowStart = slowStart
	
	o.taskName = "mineArea"
	
	o:initialize()
	return o
end

function TaskGroupSelector:onResize() -- super overwrite
	Window.onResize(self) -- super
	self.frm:setWidth(self.width)
	self.frm:setHeight(self.height)
end
function TaskGroupSelector:initialize()
	
	self.taskGroup = self.taskManager:createGroup()
	
	self.frm = Frame:new("new group - "..string.sub(self.taskGroup.id,1,4), 1,1,self.width,self.height,default.borderColor)
	
	local sx, sy = 41, 3
	self.lblGroupSizeTxt = Label:new("group size", sx, sy)
	self.btnDecreaseSize = Button:new("-",sx+2,sy+2,1,1)
	self.lblGroupSize = Label:new(self.taskGroup.groupSize,sx+4,sy+2)
	self.btnIncreaseSize = Button:new("+",sx+7,sy+2,1,1)
	
	self.btnIncreaseSize.click = function() self:changeGroupSize(1) end
	self.btnDecreaseSize.click = function() self:changeGroupSize(-1) end
	
	sx, sy = 25, 3
	self.btnSelectTask = Button:new("select task", sx,sy+3,13,1)
	self.lblTask = Label:new(self.taskName, sx, sy+1)
	self.btnSelectTask.click = function() return self:selectTask() end

	self.btnSelectArea = Button:new("select area", 6,3,14,1)
	self.btnSelectArea.click = function() self:selectArea() end
	
	
	self.lblAreaStart = Label:new("start  ",3,13)
	self.lblAreaEnd = Label:new("end    ", 3, 14)

	sx, sy = 3, 5
	self.lblXStart = Label:new("X   " .. "-",sx,sy)
	self.lblYStart = Label:new("Y   " .. "-",sx,sy+1)
	self.lblZStart = Label:new("Z   " .. "-",sx,sy+2)
	
	self.lblXFinish = Label:new("-",sx+12,sy)
	self.lblYFinish = Label:new("-",sx+12,sy+1)
	self.lblZFinish = Label:new("-",sx+12,sy+2)
	
	
	self.btnFromTop = Button:new("top",sx+3,sy+4,6,1 )
	self.btnToBottom = Button:new("bottom", sx+11,sy+4,6,1)
	self.btnFromTop.click = function() self:setFromTop() end
	self.btnToBottom.click = function() self:setToBottom() end
	
	self.btnSplitArea = Button:new("split area", 3,19,14)
	self.btnSplitArea.click = function() self:splitArea() end
	
	self.btnStartTasks = Button:new("start", 42,9,8,1)
	self.btnStartTasks.click = function() self:startTasks() end
	self.btnStartTasks:setEnabled(false)
	
	--self:removeObject(self.btnClose)
	self:addObject(self.frm)
	--self:addObject(self.btnClose)
	
	
	self:addObject(self.lblXStart)
	self:addObject(self.lblYStart)
	self:addObject(self.lblZStart)
	self:addObject(self.lblXFinish)
	self:addObject(self.lblYFinish)
	self:addObject(self.lblZFinish)
	
	self:addObject(self.lblGroupSizeTxt)
	self:addObject(self.lblGroupSize)
	--self:addObject(self.lblAreaStart)
	--self:addObject(self.lblAreaEnd)

	self:addObject(self.btnSelectTask)
	self:addObject(self.lblTask)
	
	self:addObject(self.btnIncreaseSize)
	self:addObject(self.btnDecreaseSize)
	self:addObject(self.btnSelectArea)
	self:addObject(self.btnSplitArea) -- testing
	self:addObject(self.btnStartTasks)
	self:addObject(self.btnFromTop)
	self:addObject(self.btnToBottom)
end

function TaskGroupSelector:getTaskGroup()
	return self.taskGroup
end

function TaskGroupSelector:changeGroupSize(increment)
	self.taskGroup:setGroupSize(self.taskGroup.groupSize+increment)
	--self.taskGroup:forceGroupSize(self.taskGroup.groupSize+increment)
	self:refresh()
	self.lblGroupSize:redraw()
end

function TaskGroupSelector:refreshPos()
	if self.positions and self.positions[1] then
		--self.lblAreaStart:setText("start  "..self.positions[1].x.." "..self.positions[1].y.." "..self.positions[1].z )
		self.lblXStart:setText("X   " .. self.positions[1].x)
		self.lblYStart:setText("Y   " .. self.positions[1].y)
		self.lblZStart:setText("Z   " .. self.positions[1].z)
	else
		self.lblXStart:setText("X   -")
		self.lblYStart:setText("Y   -")
		self.lblZStart:setText("Z   -")
	end
	if self.positions and self.positions[2] then
		self.lblAreaEnd:setText("end    "..self.positions[2].x.." "..self.positions[2].y.." "..self.positions[2].z )
		self.lblXFinish:setText(self.positions[2].x)
		self.lblYFinish:setText(self.positions[2].y)
		self.lblZFinish:setText(self.positions[2].z)
	else
		self.lblXFinish:setText("-")
		self.lblYFinish:setText("-")
		self.lblZFinish:setText("-")
	end
end
function TaskGroupSelector:refresh()
	self.lblGroupSize:setText(self.taskGroup.groupSize)
	self:refreshPos()
	if self.positions and #self.positions == 2 and self.taskName then
		self.btnStartTasks:setEnabled(true)
	else
		self.btnStartTasks:setEnabled(false)
	end
end

function TaskGroupSelector:redraw() -- super override
	self:refresh()
	
	Window.redraw(self) -- super
	
	for i=3,9 do
		self:setCursorPos(23,i)
		self:blit("|",colors.toBlit(colors.lightGray),colors.toBlit(self.backgroundColor))
	end
	for i=3,9 do
		self:setCursorPos(39,i)
		self:blit("|",colors.toBlit(colors.lightGray),colors.toBlit(self.backgroundColor))
	end
end

function TaskGroupSelector:splitArea()
	if #self.positions == 2 then
		self.taskGroup:setFunction(self.taskName)
		self.taskGroup:setArea(self.positions[1], self.positions[2])
		self.taskGroup:splitArea()
	end
end

function TaskGroupSelector:setFromTop()
	if self.positions and self.positions[1] then
		self.positions[1].y = default.yLevel.top
		self:refresh()
	end
	
end
function TaskGroupSelector:setToBottom()
	if self.positions and self.positions[2] then
		self.positions[2].y = default.yLevel.bottom
		self:refresh()
	end
end



function TaskGroupSelector:startTasks()
	self:clearAreaPreview()
	self.taskGroup:setFunction(self.taskName)
	self:splitArea()
	self.taskGroup:start()

	self:close()
end

function TaskGroupSelector:close()
	self:clearAreaPreview()
	return Window.close(self)
end



function TaskGroupSelector:setHostDisplay(hostDisplay)
	self.hostDisplay = hostDisplay
	if self.hostDisplay then
		self.mapDisplay = self.hostDisplay:getMapDisplay()
	end
end
function TaskGroupSelector:openMap()
	if self.hostDisplay and self.mapDisplay then
		self.hostDisplay:displayMap()
	end
end
function TaskGroupSelector:closeMap()
	if self.hostDisplay and self.mapDisplay then
		self.hostDisplay:closeMap()
	end
end


function TaskGroupSelector:selectPosition()
	self.position = nil
	self.mapDisplay.onPositionSelected = function(objRef,x,y,z) self:onPositionSelected(x,y,z) end
	self.mapDisplay:selectPosition()
	self:openMap()
end

function TaskGroupSelector:clearAreaPreview()
	local mapDisplay = self.mapDisplay

	if mapDisplay and mapDisplay.areas then
		for i = #mapDisplay.areas, 1, -1 do
			local area = mapDisplay.areas[i]
			if area == self.selectionPreview or area.areaPreviewOwner == self then
				table.remove(mapDisplay.areas, i)
			end
		end
	end
	self.selectionPreview = nil

	-- Remove every preview control owned by this selector. Scanning the map's
	-- object list also cleans up safely if a previous preview was interrupted.
	if mapDisplay and mapDisplay.objects then
		local object = mapDisplay.objects.first
		while object do
			local nextObject = object._next
			if object == self.btnConfirmArea
			or object == self.btnReselectArea
			or object.areaPreviewOwner == self then
				mapDisplay:removeObject(object)
			end
			object = nextObject
		end
	end
	self.btnConfirmArea = nil
	self.btnReselectArea = nil

	-- Area outlines are drawn into the map's cached pixel frame. Force the next
	-- redraw to rebuild that frame so a removed green outline cannot linger.
	if mapDisplay then
		mapDisplay.fullRedraw = true
	end
end

function TaskGroupSelector:showAreaPreview()
	if not self.mapDisplay or #self.positions ~= 2 then return end

	self:clearAreaPreview()

	local a, b = self.positions[1], self.positions[2]
	local previewStart = vector.new(
		math.min(a.x, b.x),
		math.min(a.y, b.y),
		math.min(a.z, b.z)
	)
	local previewFinish = vector.new(
		math.max(a.x, b.x),
		math.max(a.y, b.y),
		math.max(a.z, b.z)
	)

	self.selectionPreview = {
		start = previewStart,
		finish = previewFinish,
		color = colors.green,
		areaPreviewOwner = self,
	}
	table.insert(self.mapDisplay.areas, self.selectionPreview)

	-- Keep the map open so the selected rectangle can be reviewed. Centre both
	-- actions in the top bar between the up arrow and the close button.
	local reselectWidth = 10
	local confirmWidth = 10
	local buttonGap = 1
	local controlsWidth = reselectWidth + buttonGap + confirmWidth
	local controlsLeft = self.mapDisplay.btnUp.x + self.mapDisplay.btnUp.width
	local controlsRight = self.mapDisplay.btnClose.x - 1
	local availableWidth = controlsRight - controlsLeft + 1
	local reselectX = controlsLeft + math.floor((availableWidth - controlsWidth) / 2)
	local confirmX = reselectX + reselectWidth + buttonGap
	local controlsY = 2

	self.btnReselectArea = Button:new(
		"RESELECT",
		reselectX,
		controlsY,
		reselectWidth,
		1,
		colors.orange
	)
	self.btnReselectArea.areaPreviewOwner = self
	self.btnReselectArea.click = function()
		self:reselectArea()
		return true
	end

	self.btnConfirmArea = Button:new(
		"CONFIRM",
		confirmX,
		controlsY,
		confirmWidth,
		1,
		colors.green
	)
	self.btnConfirmArea.areaPreviewOwner = self
	self.btnConfirmArea.click = function()
		self:confirmAreaSelection()
		return true
	end

	self.mapDisplay:addObject(self.btnReselectArea)
	self.mapDisplay:addObject(self.btnConfirmArea)
	self.mapDisplay:redraw()
end

function TaskGroupSelector:reselectArea()
	self:clearAreaPreview()
	self.positions = {}
	self:refresh()
	self.mapDisplay.onPositionSelected = function(objRef,x,y,z) self:onAreaSelected(x,y,z) end
	self.mapDisplay:selectPosition()
	self.mapDisplay:redraw()
end

function TaskGroupSelector:confirmAreaSelection()
	if #self.positions ~= 2 then return end
	self:clearAreaPreview()
	self:closeMap()
	self:refresh()
	self:redraw()
end

function TaskGroupSelector:selectArea()
	self:clearAreaPreview()
	self.positions = {}
	self.mapDisplay.onPositionSelected = function(objRef,x,y,z) self:onAreaSelected(x,y,z) end
	self.mapDisplay:selectPosition()
	self:openMap()
end

function TaskGroupSelector:onAreaSelected(x, y, z)
	print("selected position", #self.positions, x,y,z)
	if x and z then
		if #self.positions < 2 then
			if y == nil then
				if #self.positions == 0 then
					-- default top level
					y = default.yLevel.top					
				else
					-- default end level
					y = default.yLevel.bottom
				end
			end
			table.insert(self.positions,vector.new(x,y,z))

			if #self.positions == 1 then
				-- start selection for second position
				self.mapDisplay.onPositionSelected = function(objRef,x,y,z) self:onAreaSelected(x,y,z) end
				self.mapDisplay:selectPosition()
			end
		end
	else
		-- cancel position selection
	end
	
	if #self.positions == 2 then
		-- Area selected: keep the map open, draw a green preview, and
		-- require explicit confirmation before returning to group setup.
		self:showAreaPreview()
	end
end

function TaskGroupSelector:onPositionSelected(x,y,z)
	if x and z then
		if y == nil then y = default.yLevel.top end
		self.node:send(self.data.id, {"DO",self.taskName,{x,y,z}})
	else
		-- cancel position selection
	end
	
	self:close()
	self:closeMap()
end
	
function TaskGroupSelector:selectTask()
	local choices = {"mineArea", "excavateArea"}
	
	self.choiceSelector = ChoiceSelector:new(self.btnSelectTask.x,self.btnSelectTask.y-4,16,6,choices)
	self.choiceSelector.onChoiceSelected = function(choice) 
		self.taskName = choice
		self.lblTask:setText(self.taskName)
		self:refresh()
		self:redraw()
	end
	self.parent:addObject(self.choiceSelector)
	self.parent:redraw()
	return true -- noBlink
end


return TaskGroupSelector
