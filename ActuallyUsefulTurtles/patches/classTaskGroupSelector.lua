local Button = require("classButton")
local Label = require("classLabel")
local Window = require("classWindow")
local Frame = require("classFrame")
local ChoiceSelector = require("classChoiceSelector")
local CheckBox = require("classCheckBox")

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
	o.selectionPos1Preview = nil
	o.selectionPos2Preview = nil
	o.selectionMode = false
	o.btnConfirmArea = nil
	o.btnReselectArea = nil
	o.btnSelectionMode = nil
	o.btnCursorMode = nil
	o.cursorMode = false
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

function TaskGroupSelector:clearSelectionOverlay()
	local mapDisplay = self.mapDisplay
	if mapDisplay and mapDisplay.areas then
		for i = #mapDisplay.areas, 1, -1 do
			local area = mapDisplay.areas[i]
			if area == self.selectionPreview
			or area == self.selectionPos1Preview
			or area == self.selectionPos2Preview
			or area.areaPreviewOwner == self then
				table.remove(mapDisplay.areas, i)
			end
		end
	end

	self.selectionPreview = nil
	self.selectionPos1Preview = nil
	self.selectionPos2Preview = nil

	if mapDisplay then mapDisplay.fullRedraw = true end
end

function TaskGroupSelector:clearAreaControls()
	local mapDisplay = self.mapDisplay
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
end

local function drawModeToggle(cb)
	if not (cb.parent and cb.visible) then return end

	-- Keep the SCADA lamp on BLACK, exactly like MAP OPTIONS. Putting the
	-- lamp's second teletext cell on the gray label plate was what made it
	-- look clipped/attached to the plate edge.
	local lampBg = colors.black
	local plate = colors.gray
	if cb.active then
		cb.parent:drawText(cb.x, cb.y, "\136", plate, cb.accentColor)
		cb.parent:drawText(cb.x + 1, cb.y, "\149", cb.accentColor, lampBg)
	else
		cb.parent:drawText(cb.x, cb.y, "\136", lampBg, plate)
		cb.parent:drawText(cb.x + 1, cb.y, "\149", plate, lampBg)
	end

	-- X/Z-style gray backing belongs only to the label. One trailing gray
	-- cell keeps the floating control from looking cramped.
	local labelPlateX = cb.x + 2
	local labelPlateWidth = #cb.labelText + 1
	cb.parent:drawFilledBox(labelPlateX, cb.y, labelPlateWidth, 1, plate)
	local textColor = cb.active and colors.white or colors.lightGray
	cb.parent:drawText(labelPlateX, cb.y, cb.labelText, textColor, plate)
end

function TaskGroupSelector:clearModeControls()
	if self.mapDisplay then
		if self.btnSelectionMode then self.mapDisplay:removeObject(self.btnSelectionMode) end
		if self.btnCursorMode then self.mapDisplay:removeObject(self.btnCursorMode) end
	end
	self.btnSelectionMode = nil
	self.btnCursorMode = nil
end

function TaskGroupSelector:setMapInteractionMode(cursorMode)
	self.cursorMode = cursorMode and true or false
	if self.btnSelectionMode then self.btnSelectionMode.active = not self.cursorMode end
	if self.btnCursorMode then self.btnCursorMode.active = self.cursorMode end
	if self.mapDisplay then
		if self.cursorMode then
			self.mapDisplay.doSelectPosition = false
		else
			self.mapDisplay.onPositionSelected = function(objRef,x,y,z) self:onAreaSelected(x,y,z) end
			self.mapDisplay:selectPosition()
		end
		self.mapDisplay:redraw()
	end
end

function TaskGroupSelector:showModeControls()
	if not self.mapDisplay or self.btnSelectionMode then return end

	-- One black-cell gap after the yellow level + control.
	local x = self.mapDisplay.btnLevelUp.x + self.mapDisplay.btnLevelUp.width + 1
	local width = 9

	-- Vertically center the two-row mode control beside the 3-row yellow level button.
	self.btnSelectionMode = CheckBox:new(x, 2, "select", not self.cursorMode, width, 1, colors.gray)
	self.btnSelectionMode.accentColor = colors.green
	self.btnSelectionMode.redraw = drawModeToggle
	self.btnSelectionMode.handleClick = function() self.btnSelectionMode.click() end
	self.btnSelectionMode.click = function()
		self:setMapInteractionMode(false)
		return true
	end

	self.btnCursorMode = CheckBox:new(x, 3, "cursor", self.cursorMode, width, 1, colors.gray)
	self.btnCursorMode.accentColor = colors.cyan
	self.btnCursorMode.redraw = drawModeToggle
	self.btnCursorMode.handleClick = function() self.btnCursorMode.click() end
	self.btnCursorMode.click = function()
		self:setMapInteractionMode(true)
		return true
	end

	self.mapDisplay:addObject(self.btnSelectionMode)
	self.mapDisplay:addObject(self.btnCursorMode)
end

function TaskGroupSelector:clearAreaPreview()
	-- LABENHANCED_WORLDEDIT_AREA_SELECT
	self.selectionMode = false
	self:clearModeControls()
	if self.mapDisplay then
		self.mapDisplay.doSelectPosition = false
	end
	self:clearSelectionOverlay()
	self:clearAreaControls()
	if self.mapDisplay then self.mapDisplay.fullRedraw = true end
end

function TaskGroupSelector:layoutAreaControls()
	if not self.mapDisplay then return nil end

	local deselectWidth = 10
	local confirmWidth = 10
	-- Mirror the outer gaps: DESELECT sits the same distance to the right of
	-- the blue UP control as CONFIRM sits to the left of the red X control.
	-- Any remaining space becomes the larger gap between the two buttons.
	local outerGap = 1
	local controlsLeft = self.mapDisplay.btnUp.x + self.mapDisplay.btnUp.width
	local controlsRight = self.mapDisplay.btnClose.x - 1
	local deselectX = controlsLeft + outerGap
	local confirmX = controlsRight - outerGap - confirmWidth + 1

	-- Narrow displays may not have enough room for the mirrored layout.
	if confirmX <= deselectX + deselectWidth then
		confirmX = deselectX + deselectWidth + 1
	end

	-- Raise both action buttons one row for cleaner alignment with the top controls.
	return deselectX, confirmX, 1
end

function TaskGroupSelector:showAreaControls()
	if not self.mapDisplay then return end

	local count = self.positions and #self.positions or 0
	if count == 0 then
		self:clearAreaControls()
		return
	end

	local deselectX, confirmX, controlsY = self:layoutAreaControls()
	if not deselectX then return end

	-- POS1 exists: DESELECT is the only action available.
	if not self.btnReselectArea then
		self.btnReselectArea = Button:new(
			"DESELECT",
			deselectX,
			controlsY,
			10,
			1,
			colors.red
		)
		self.btnReselectArea.areaPreviewOwner = self
		self.btnReselectArea.click = function()
			self:deselectArea()
			return true
		end
		self.mapDisplay:addObject(self.btnReselectArea)
	end
	self.btnReselectArea:setEnabled(self.selectionMode)

	-- CONFIRM must not exist until POS2 has actually been set.
	if count >= 2 then
		if not self.btnConfirmArea then
			self.btnConfirmArea = Button:new(
				"CONFIRM",
				confirmX,
				controlsY,
				10,
				1,
				colors.green
			)
			self.btnConfirmArea.areaPreviewOwner = self
			self.btnConfirmArea.click = function()
				self:confirmAreaSelection()
				return true
			end
			self.mapDisplay:addObject(self.btnConfirmArea)
		end
		self.btnConfirmArea:setEnabled(true)
	elseif self.btnConfirmArea then
		self.mapDisplay:removeObject(self.btnConfirmArea)
		self.btnConfirmArea = nil
	end
end

function TaskGroupSelector:updateAreaPreview()
	if not self.mapDisplay then return end

	-- Remove only the graphical overlay. Controls stay put while pos2 is moved.
	self:clearSelectionOverlay()

	local p1 = self.positions[1]
	local p2 = self.positions[2]

	-- Once both positions exist, draw the selected region in RED.
	if p1 and p2 then
		local previewStart = vector.new(
			math.min(p1.x, p2.x),
			math.min(p1.y, p2.y),
			math.min(p1.z, p2.z)
		)
		local previewFinish = vector.new(
			math.max(p1.x, p2.x),
			math.max(p1.y, p2.y),
			math.max(p1.z, p2.z)
		)

		self.selectionPreview = {
			start = previewStart,
			finish = previewFinish,
			color = colors.red,
			areaPreviewOwner = self,
		}
		table.insert(self.mapDisplay.areas, self.selectionPreview)
	end

	-- WorldEdit-style anchors: pos1 GREEN, pos2 MAGENTA.
	-- Insert these after the red outline so the anchor pixels remain visible.
	if p1 then
		self.selectionPos1Preview = {
			start = vector.new(p1.x,p1.y,p1.z),
			finish = vector.new(p1.x,p1.y,p1.z),
			color = colors.green,
			selectionAnchor = true,
			areaPreviewOwner = self,
		}
		table.insert(self.mapDisplay.areas, self.selectionPos1Preview)
	end

	if p2 then
		self.selectionPos2Preview = {
			start = vector.new(p2.x,p2.y,p2.z),
			finish = vector.new(p2.x,p2.y,p2.z),
			color = colors.magenta,
			selectionAnchor = true,
			areaPreviewOwner = self,
		}
		table.insert(self.mapDisplay.areas, self.selectionPos2Preview)
	end

	self:showAreaControls()
	self.mapDisplay.fullRedraw = true
	self.mapDisplay:redraw()
end

-- Compatibility name for any older call sites.
function TaskGroupSelector:showAreaPreview()
	self:updateAreaPreview()
end

function TaskGroupSelector:deselectArea()
	-- DESELECT clears the current WorldEdit selection and immediately starts
	-- a fresh selection. With no positions set, both action buttons disappear;
	-- the next right-click creates POS1 and brings DESELECT back.
	self.positions = {}
	self:clearSelectionOverlay()
	self:clearAreaControls()
	self.selectionMode = true
	self.cursorMode = false
	self:refresh()
	if self.mapDisplay then
		self.mapDisplay.fullRedraw = true
		self:setMapInteractionMode(false)
	end
end

function TaskGroupSelector:reselectArea()
	-- Legacy entry point: starting a fresh selection now means clearing both
	-- anchors and re-entering the persistent right-click selection mode.
	self:clearAreaPreview()
	self.positions = {}
	self.selectionMode = true
	self:refresh()
	self:showAreaControls()
	self.mapDisplay.onPositionSelected = function(objRef,x,y,z) self:onAreaSelected(x,y,z) end
	self.mapDisplay:selectPosition()
	self.mapDisplay:redraw()
end

function TaskGroupSelector:confirmAreaSelection()
	if #self.positions ~= 2 then return end
	self.selectionMode = false
	if self.mapDisplay then self.mapDisplay.doSelectPosition = false end
	self:clearAreaPreview()
	self:closeMap()
	self:refresh()
	self:redraw()
end

function TaskGroupSelector:selectArea()
	self:clearAreaPreview()
	self.positions = {}
	self.selectionMode = true
	self.cursorMode = false
	self.mapDisplay.onPositionSelected = function(objRef,x,y,z) self:onAreaSelected(x,y,z) end
	self.mapDisplay:selectPosition()
	self:openMap()
	self:showModeControls()
	self:setMapInteractionMode(false)
	-- DESELECT/CONFIRM stay hidden until their required positions exist.
	self.mapDisplay:redraw()
end

function TaskGroupSelector:onAreaSelected(x, y, z)
	if not self.selectionMode then return end
	print("selected position", #self.positions, x,y,z)

	if x and z then
		if y == nil then
			if #self.positions == 0 then
				y = default.yLevel.top
			else
				y = default.yLevel.bottom
			end
		end

		if #self.positions == 0 then
			-- First right-click: lock pos1 (GREEN).
			self.positions[1] = vector.new(x,y,z)
		elseif #self.positions == 1 then
			-- Second right-click: create pos2 (MAGENTA).
			self.positions[2] = vector.new(x,y,z)
		else
			-- Every later right-click moves ONLY pos2, WorldEdit-style.
			self.positions[2] = vector.new(x,y,z)
		end

		self:refresh()
		self:updateAreaPreview()

		-- Persistent edit mode: immediately arm the map for the next right-click.
		if self.selectionMode and not self.cursorMode then
			self.mapDisplay.onPositionSelected = function(objRef,sx,sy,sz)
				self:onAreaSelected(sx,sy,sz)
			end
			self.mapDisplay:selectPosition()
		end
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
