local Box = require("classBox")
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

-- LABENHANCED_NEWGROUP_HMI
-- Same visual grammar as the Groups page: gray plates carry grouped values,
-- captions are dimmed, values stay white, controls are a lighter block with a
-- dark glyph. Colours below are additions only - nothing existing is repurposed.
local ui = {
	plate   = colors.gray,
	caption = colors.lightGray,
	value   = colors.white,
	control = colors.lightGray,
	controlText = colors.black,
	divider = colors.gray,
	go      = colors.green,
	dead    = colors.gray,
	hint    = colors.lightGray,
	caret      = colors.lightGray, -- caret well at the end of a dropdown field
	caretGlyph = colors.black,
}

-- Every column and row in one place, so drawn cells and click areas cannot
-- drift apart. Rows counted from the top; the action bar is pinned to the
-- bottom and recomputed on resize.
local L = {
	headerRow   = 1,
	padX        = 3,
	areaCapRow  = 3,
	areaTop     = 4,   areaRows = 5,   -- caption row + X/Y/Z
	areaX       = 3,   areaW    = 30,
	axisX       = 5,
	fromEnd     = 17,                  -- FROM values right-aligned here
	toEnd       = 26,                  -- TO values right-aligned here
	areaBtnRow  = 10,
	taskCapRow  = 12,
	taskRow     = 13,
	caretW      = 3,   -- dropdown well at the right end of a field
	spinW       = 3,   -- - and + buttons of the turtle count spinner
	turtCapRow  = 15,
	turtRow     = 16,
	turtW       = 11,
}

local function padLeft(text, width)
	text = tostring(text)
	local pad = width - #text
	if pad > 0 then return string.rep(" ", pad) .. text end
	return text
end


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
	self:layoutPanel()
end
function TaskGroupSelector:usableWidth()
	-- The close button is an overlay on the inner window's right-hand columns;
	-- derive the last usable column from where it actually is.
	local inner = self.innerWin
	local width = (inner and inner.getWidth and inner:getWidth()) or self.width
	if self.btnClose and self.btnClose.visible then
		local originX = (inner and inner.x or 1) - (inner and inner.scrollX or 0)
		width = math.min(width, self.btnClose.x - 1 - originX)
	end
	return math.max(20, width)
end

-- LABENHANCED_NEWGROUP_HMI
-- Sized to its content and centred, rather than stretched over the whole page.
-- A full-screen form left ~18 dead rows between the last field and the action
-- bar; an HMI dialog is a panel, not a page.
TaskGroupSelector.panelWidth  = 44
TaskGroupSelector.panelHeight = 21

function TaskGroupSelector:centerIn(parent)
	local pw = parent and parent.getWidth and parent:getWidth() or self.width
	local ph = parent and parent.getHeight and parent:getHeight() or self.height
	local w = math.min(self.panelWidth, pw)
	local h = math.min(self.panelHeight, ph)
	self:setSize(w, h)
	self:setPos(math.max(1, math.floor((pw - w) / 2) + 1),
		math.max(1, math.floor((ph - h) / 2) + 1))

	-- LABENHANCED_NEWGROUP_HMI
	-- This is a modal panel, so the page behind it must not offer a close button
	-- of its own: two identical red X's two rows apart gave no clue which closed
	-- what. Unlink the page's button rather than just hiding it, because
	-- BasicWindow:setVisible cascades to every child and would switch a hidden
	-- one straight back on. Re-linked in close().
	if parent and parent.btnClose and parent.removeObjectInternal then
		self.closeOwner = parent
		parent:removeObjectInternal(parent.btnClose)
	end

	self:layoutPanel()
end

function TaskGroupSelector:layoutPanel()
	-- header plate stops short of the close button
	local usable = self:usableWidth()
	if self.boxHeader then self.boxHeader:setWidth(usable) end
	self:layoutAreaSize(usable)

	-- action bar pinned to the bottom edge
	local h = self.height
	-- Hint on its own row so a long one cannot collide with the buttons.
	self.hintRow = h - 3
	self.actionRow = h - 1
	if self.btnStartTasks then
		self.btnStartTasks:setPos(usable - self.btnStartTasks.width + 1, self.actionRow)
	end
	if self.lblHint then self.lblHint:setPos(L.padX, self.hintRow) end
end

function TaskGroupSelector:initialize()
	
	self.taskGroup = self.taskManager:createGroup()

	-- LABENHANCED_NEWGROUP_HMI
	-- The task field ends on the same column as the "top" button's right edge,
	-- derived from that button rather than hardcoded, so the caret keeps its
	-- alignment if the AREA button row is ever rearranged.
	self.btnTopX = L.padX + 15
	self.btnTopW = 5
	self.taskFieldW = (self.btnTopX + self.btnTopW - 1) - L.padX + 1

	self.spinMinusX = L.padX + L.turtW + 1
	self.spinPlusX = self.spinMinusX + L.spinW + 1


	-- LABENHANCED_NEWGROUP_HMI
	-- Header strip instead of a titled Frame. The Window already draws one
	-- border; a Frame inside it was a second box around the same panel.
	self.boxHeader = Box:new(1, L.headerRow, self.width, 1, ui.plate)
	self.lblTitle = Label:new("NEW GROUP", 2, L.headerRow, ui.value, ui.plate)
	-- LABENHANCED_NEWGROUP_HMI
	-- The header's right slot carries live state, as on the Groups page. A
	-- truncated internal id was nothing you could act on - and on cancel it is
	-- discarded and never seen again. The size of the selection is the number
	-- that actually decides whether this job is sane.
	self.lblAreaSize = Label:new("", 14, L.headerRow, ui.caption, ui.plate)
	self:addObject(self.boxHeader)
	self:addObject(self.lblTitle)
	self:addObject(self.lblAreaSize)

	-- ---- AREA -------------------------------------------------------------
	self.lblAreaCap = Label:new("AREA", L.padX, L.areaCapRow, ui.caption)
	self:addObject(self.lblAreaCap)

	self.boxArea = Box:new(L.areaX, L.areaTop, L.areaW, L.areaRows, ui.plate)
	self:addObject(self.boxArea)

	self.lblFromCap = Label:new("FROM", L.fromEnd - 3, L.areaTop, ui.caption, ui.plate)
	self.lblToCap   = Label:new("TO",   L.toEnd - 1,   L.areaTop, ui.caption, ui.plate)
	self:addObject(self.lblFromCap)
	self:addObject(self.lblToCap)

	local ay = L.areaTop + 1
	self.lblXAxis = Label:new("X", L.axisX, ay,   ui.caption, ui.plate)
	self.lblYAxis = Label:new("Y", L.axisX, ay+1, ui.caption, ui.plate)
	self.lblZAxis = Label:new("Z", L.axisX, ay+2, ui.caption, ui.plate)
	self.lblXStart = Label:new("-", L.axisX+2, ay,   ui.value, ui.plate)
	self.lblYStart = Label:new("-", L.axisX+2, ay+1, ui.value, ui.plate)
	self.lblZStart = Label:new("-", L.axisX+2, ay+2, ui.value, ui.plate)
	self.lblXFinish = Label:new("-", L.fromEnd+1, ay,   ui.value, ui.plate)
	self.lblYFinish = Label:new("-", L.fromEnd+1, ay+1, ui.value, ui.plate)
	self.lblZFinish = Label:new("-", L.fromEnd+1, ay+2, ui.value, ui.plate)
	for _,o in ipairs{self.lblXAxis,self.lblYAxis,self.lblZAxis,
		self.lblXStart,self.lblYStart,self.lblZStart,
		self.lblXFinish,self.lblYFinish,self.lblZFinish} do self:addObject(o) end

	self.btnSelectArea = Button:new("select area", L.padX, L.areaBtnRow, 14, 1, ui.control)
	self.btnFromTop    = Button:new("top",    self.btnTopX, L.areaBtnRow, self.btnTopW, 1, ui.control)
	self.btnToBottom   = Button:new("bottom", L.padX+21, L.areaBtnRow, 8, 1, ui.control)
	self.btnSplitArea  = Button:new("split",  L.padX+30, L.areaBtnRow, 7, 1, ui.control)
	for _,b in ipairs{self.btnSelectArea,self.btnFromTop,self.btnToBottom,self.btnSplitArea} do
		b:setTextColor(ui.controlText)
		self:addObject(b)
	end
	self.btnSelectArea.click = function() self:selectArea() end
	self.btnFromTop.click    = function() self:setFromTop() end
	self.btnToBottom.click   = function() self:setToBottom() end
	self.btnSplitArea.click  = function() self:splitArea() end

	-- ---- TASK -------------------------------------------------------------
	self.lblTaskCap = Label:new("TASK", L.padX, L.taskCapRow, ui.caption)
	self:addObject(self.lblTaskCap)
	-- The field itself is the control: the whole plate is clickable and carries a
	-- darkened caret well at its right end, instead of a separate "select task"
	-- button sitting beside a plate that looked like a read-only value.
	-- Its right edge sits under the spinner's "+" so the two align.
	self.btnSelectTask = Button:new("", L.padX, L.taskRow, self.taskFieldW, 1, ui.plate)
	self.btnSelectTask.click = function() return self:selectTask() end
	self:addObject(self.btnSelectTask)

	-- label drawn over the field (added later, so it paints on top)
	self.lblTask = Label:new(self.taskName, L.padX+2, L.taskRow, ui.value, ui.plate)
	self:addObject(self.lblTask)

	-- \31 is CraftOS's down triangle, the same glyph the scrollbar uses
	-- Flush with the plate's right edge. A DARKER well is not possible here: the
	-- only tone below the plate's gray is the panel background itself, so a black
	-- well merged into it and read as the plate stopping short with a triangle
	-- floating beside it. Lighter reads as a recess and matches every other
	-- control on the panel - light block, dark glyph.
	self.btnTaskCaret = Button:new("\31", L.padX + self.taskFieldW - L.caretW, L.taskRow,
		L.caretW, 1, ui.caret)
	self.btnTaskCaret:setTextColor(ui.caretGlyph)
	self.btnTaskCaret.click = function() return self:selectTask() end
	self:addObject(self.btnTaskCaret)

	-- ---- TURTLES ----------------------------------------------------------
	self.lblGroupSizeTxt = Label:new("TURTLES", L.padX, L.turtCapRow, ui.caption)
	self:addObject(self.lblGroupSizeTxt)
	self.boxTurt = Box:new(L.padX, L.turtRow, L.turtW, 1, ui.plate)
	self:addObject(self.boxTurt)
	self.lblGroupSize = Label:new(self.taskGroup.groupSize, L.padX+5, L.turtRow, ui.value, ui.plate)
	self:addObject(self.lblGroupSize)
	-- spinner, matching the map screen's zoom control
	self.btnDecreaseSize = Button:new("-", self.spinMinusX, L.turtRow, L.spinW, 1, ui.control)
	self.btnIncreaseSize = Button:new("+", self.spinPlusX, L.turtRow, L.spinW, 1, ui.control)
	for _,b in ipairs{self.btnDecreaseSize,self.btnIncreaseSize} do
		b:setTextColor(ui.controlText)
		self:addObject(b)
	end
	self.btnIncreaseSize.click = function() self:changeGroupSize(1) end
	self.btnDecreaseSize.click = function() self:changeGroupSize(-1) end

	-- ---- action bar -------------------------------------------------------
	self.lblHint = Label:new("", L.padX, 1, ui.hint)
	self:addObject(self.lblHint)
	-- LABENHANCED_NEWGROUP_HMI
	-- 13 wide, not 10: the commit action was the narrowest control on the panel,
	-- smaller than "select area" (14) and "select task" (13). 13 also centres a
	-- 5-character label exactly - Button splits the slack with floor(), so an
	-- even width left START one cell off-centre (2 left, 3 right).
	self.btnStartTasks = Button:new("START", 1, 1, 13, 1, ui.go)
	self.btnStartTasks:setTextColor(ui.controlText)
	self.btnStartTasks.disabledColor = ui.dead
	self.btnStartTasks.click = function() self:startTasks() end
	self.btnStartTasks:setEnabled(false)
	self:addObject(self.btnStartTasks)


	self:layoutPanel()
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
	-- Values right-aligned into fixed fields so digits do not jump as the
	-- selection is dragged around the map.
	local startW  = L.fromEnd - (L.axisX + 2) + 1
	local finishW = L.toEnd - (L.fromEnd + 1) + 1
	local p1 = self.positions and self.positions[1]
	local p2 = self.positions and self.positions[2]

	self.lblXStart:setText(padLeft(p1 and p1.x or "-", startW))
	self.lblYStart:setText(padLeft(p1 and p1.y or "-", startW))
	self.lblZStart:setText(padLeft(p1 and p1.z or "-", startW))
	self.lblXFinish:setText(padLeft(p2 and p2.x or "-", finishW))
	self.lblYFinish:setText(padLeft(p2 and p2.y or "-", finishW))
	self.lblZFinish:setText(padLeft(p2 and p2.z or "-", finishW))
end
function TaskGroupSelector:layoutAreaSize(usable)
	if not self.lblAreaSize then return end
	usable = usable or self:usableWidth()
	local text = self.lblAreaSize:getText()
	-- one column clear of the close button: red is visually heavy butted up
	self.lblAreaSize:setPos(math.max(13, usable - #text), L.headerRow)
end

function TaskGroupSelector:areaSizeText()
	local p1 = self.positions and self.positions[1]
	local p2 = self.positions and self.positions[2]
	if not (p1 and p2) then return "no area" end
	local dx = math.abs(p1.x - p2.x) + 1
	local dy = math.abs(p1.y - p2.y) + 1
	local dz = math.abs(p1.z - p2.z) + 1
	local dims = string.format("%dx%dx%d", dx, dy, dz)
	-- Block counts get astronomical for a sloppy selection; only add the total
	-- when it is short enough to be worth reading.
	local total = dx * dy * dz
	if total <= 9999999 then
		return dims .. "  " .. total .. " blk"
	end
	return dims
end

function TaskGroupSelector:refresh()
	self.lblGroupSize:setText(padLeft(self.taskGroup.groupSize, 2))
	self:refreshPos()
	self.lblAreaSize:setText(self:areaSizeText())
	self:layoutAreaSize()

	local hasArea = self.positions and #self.positions == 2
	local ready = hasArea and self.taskName ~= nil

	-- LABENHANCED_NEWGROUP_HMI
	-- Say what is still missing rather than leaving a dead button unexplained.
	if ready then
		self.lblHint:setText("ready to start")
		self.lblHint:setTextColor(ui.go)
	elseif not hasArea then
		self.lblHint:setText("select an area to continue")
		self.lblHint:setTextColor(ui.hint)
	else
		self.lblHint:setText("select a task to continue")
		self.lblHint:setTextColor(ui.hint)
	end

	self.btnStartTasks:setEnabled(ready)
	-- Box draws a border whenever borderColor differs from the background, and
	-- setEnabled only swaps the background - keep them in step.
	self.btnStartTasks:setBorderColor(self.btnStartTasks.backgroundColor)
end

function TaskGroupSelector:redraw() -- super override
	self:refresh()

	Window.redraw(self) -- super

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

	self.started = true   -- so close() does not delete the group it just started
	self:close()
end

function TaskGroupSelector:close()
	self:clearAreaPreview()
	self:discardDraftGroup()
	if self.closeOwner and self.closeOwner.addObjectInternal then
		self.closeOwner:addObjectInternal(self.closeOwner.btnClose)
		self.closeOwner = nil
	end
	return Window.close(self)
end

function TaskGroupSelector:discardDraftGroup()
	-- LABENHANCED_NEWGROUP_HMI
	-- initialize() calls taskManager:createGroup(), so merely opening this dialog
	-- registers a group. Nothing removed it again, so every cancelled draft was
	-- left in taskManager.groups forever - invisible, because the list filters
	-- status "new". Drop it unless the group was actually started.
	if self.started then return end
	local g = self.taskGroup
	if g and g.getStatus and g:getStatus() == "new" and g.delete then
		g:delete()
	end
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
			selectionOutline = true,
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
	
	-- LABENHANCED_NEWGROUP_HMI
	-- The menu is added to self.parent, so it must be positioned in PARENT
	-- coordinates. Using the field's local x/y only worked while this panel sat
	-- at 1,1; once it was centred the menu landed off the panel entirely.
	-- Hung directly under the field so it reads as that field's dropdown.
	self.choiceSelector = ChoiceSelector:new(
		self.x + self.btnSelectTask.x - 1,
		self.y + self.btnSelectTask.y,
		16, 6, choices)
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
