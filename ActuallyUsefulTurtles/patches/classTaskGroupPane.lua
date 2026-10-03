-- LABENHANCED_GROUPS_MASTERDETAIL
-- The detail half of the Groups page. The rail (classTaskGroupControl) is now
-- one line per group and carries no controls; everything you can read or do
-- about the selected group lives here.
--
-- Same grammar as the rest of the HMI: gray plates carry grouped values,
-- captions dim, values white, controls a lighter block with a dark glyph.
-- Status colour still comes from group:getStatusColor(), so the lamp on the
-- rail and the word here always agree.

local Box = require("classBox")
local Button = require("classButton")
local Label = require("classLabel")
local BasicWindow = require("classBasicWindow")
local ChoiceSelector = require("classChoiceSelector")

local default = {
	width = 38,
	height = 35,
	colors = {
		background = colors.black,
		plate = colors.gray,
		caption = colors.lightGray,
		value = colors.white,
		control = colors.lightGray,
		controlText = colors.black,
		divider = colors.gray,
		-- The unfilled part of the progress bar. Dark enough that a bar at 1%
		-- still reads as "a bar", not as a stray coloured cell.
		track = colors.gray,
		empty = colors.lightGray,
	},
}

-- Every row and column in one place so the drawn cells and the click targets
-- of the buttons cannot drift apart.
local L = {
	headerRow  = 1,
	dividerRow = 2,
	taskRow    = 4,
	turtRow    = 5,
	barRow     = 7,
	barX       = 2,
	plateTop   = 9,  plateRows = 4,
	labelX     = 2,
	ctrlRow    = 14,
	emptyRow   = 5,
}

local function fitText(text, width)
	text = tostring(text)
	if width < 1 then return "" end
	if #text > width then return text:sub(1, width) end
	return text
end

-- Compact, uppercase status wording, identical to the rail's long form.
local function statusText(status)
	if not status then return "UNKNOWN" end
	local text = tostring(status):upper():gsub("_", " ")
	text = text:gsub("^PARTIALLY ", "PART ")
	return text
end

local TaskGroupPane = BasicWindow:new()

function TaskGroupPane:new(x, y, width, height)
	local o = BasicWindow:new(x, y, width or default.width, height or default.height)
	setmetatable(o, self)
	self.__index = self

	o:setBackgroundColor(default.colors.background)
	o:setBorderColor(default.colors.background)

	o.taskGroup = nil
	o.hostDisplay = nil
	o.mapDisplay = nil
	-- The options popup's own size, kept here so the anchor can be checked
	-- without opening one.
	o.optionsWidth = 16
	o.optionsHeight = 6

	o:initialize()
	o:setGroup(nil)

	return o
end

function TaskGroupPane:initialize()
	local c = default.colors

	-- header: id left, status word right (painted in redraw, which knows the
	-- current colour and the current width)
	self.lblId = Label:new("", L.labelX, L.headerRow, c.value)
	self:addObject(self.lblId)

	-- key/value rows above the bar
	self.lblTaskCap = Label:new("TASK", L.labelX, L.taskRow, c.caption)
	self.lblTask = Label:new("", L.labelX + 6, L.taskRow, c.value)
	self.lblTurtCap = Label:new("TURT", L.labelX, L.turtRow, c.caption)
	self.lblTurtles = Label:new("", L.labelX + 6, L.turtRow, c.value)
	self.lblTimeCap = Label:new("TIME", L.labelX + 16, L.turtRow, c.caption)
	self.lblTime = Label:new("", L.labelX + 21, L.turtRow, c.value)
	self:addObject(self.lblTaskCap)
	self:addObject(self.lblTask)
	self:addObject(self.lblTurtCap)
	self:addObject(self.lblTurtles)
	self:addObject(self.lblTimeCap)
	self:addObject(self.lblTime)

	-- area plate. Registered before its labels so it draws underneath.
	self.boxArea = Box:new(1, L.plateTop, self.width, L.plateRows, c.plate)
	self:addObject(self.boxArea)

	self.lblXCap = Label:new("X", 1, L.plateTop, c.caption, c.plate)
	self.lblYCap = Label:new("Y", 1, L.plateTop, c.caption, c.plate)
	self.lblZCap = Label:new("Z", 1, L.plateTop, c.caption, c.plate)
	self:addObject(self.lblXCap)
	self:addObject(self.lblYCap)
	self:addObject(self.lblZCap)

	self.lblFromCap = Label:new("FROM", L.labelX, L.plateTop + 1, c.caption, c.plate)
	self.lblToCap   = Label:new("TO",   L.labelX, L.plateTop + 2, c.caption, c.plate)
	self.lblSizeCap = Label:new("SIZE", L.labelX, L.plateTop + 3, c.caption, c.plate)
	self:addObject(self.lblFromCap)
	self:addObject(self.lblToCap)
	self:addObject(self.lblSizeCap)

	self.coordLabels = {}
	for row = 1, 3 do
		self.coordLabels[row] = {}
		for col = 1, 3 do
			local lbl = Label:new("", 1, L.plateTop + row, c.value, c.plate)
			self.coordLabels[row][col] = lbl
			self:addObject(lbl)
		end
	end

	-- controls
	self.btnMap = Button:new("MAP", L.labelX, L.ctrlRow, 7, 1, c.control)
	self.btnOptions = Button:new("OPTS", L.labelX + 9, L.ctrlRow, 8, 1, c.control)
	self.btnDetails = Button:new("DETAIL", L.labelX + 19, L.ctrlRow, 10, 1, c.control)
	self.btnMap:setTextColor(c.controlText)
	self.btnOptions:setTextColor(c.controlText)
	self.btnDetails:setTextColor(c.controlText)

	self.btnMap.click = function() return self:openMap() end
	self.btnOptions.click = function() return self:openOptions() end
	self.btnDetails.click = function() return self:openDetails() end

	self:addObject(self.btnMap)
	self:addObject(self.btnOptions)
	self:addObject(self.btnDetails)

	-- empty state, shown instead of everything above when nothing is selected
	self.lblEmpty = Label:new("NO GROUP SELECTED", L.labelX, L.emptyRow, c.empty)
	self:addObject(self.lblEmpty)
end

-- Everything except the placeholder, so the two states can be swapped wholesale.
function TaskGroupPane:contentObjects()
	return {
		self.lblId, self.lblTaskCap, self.lblTask, self.lblTurtCap,
		self.lblTurtles, self.lblTimeCap, self.lblTime, self.boxArea,
		self.lblXCap, self.lblYCap, self.lblZCap, self.lblFromCap,
		self.lblToCap, self.lblSizeCap, self.btnMap, self.btnOptions,
		self.btnDetails,
		self.coordLabels[1][1], self.coordLabels[1][2], self.coordLabels[1][3],
		self.coordLabels[2][1], self.coordLabels[2][2], self.coordLabels[2][3],
		self.coordLabels[3][1], self.coordLabels[3][2], self.coordLabels[3][3],
	}
end

function TaskGroupPane:setGroup(group)
	self.taskGroup = group
	local has = (group ~= nil)
	-- Labels and Boxes carry a plain `visible` field - only BasicWindow has a
	-- setter, and it cascades, which is not what is wanted here.
	for _, obj in ipairs(self:contentObjects()) do
		obj.visible = has
	end
	self.lblEmpty.visible = not has
	if has then self:refresh() end
end

-- BasicWindow:setVisible cascades to every child, and addObject calls it, so
-- being shown wipes the content/placeholder split chosen above. Re-settle it
-- rather than leave the placeholder painted over a populated pane.
function TaskGroupPane:setVisible(isVisible) -- super override
	BasicWindow.setVisible(self, isVisible)
	if isVisible then self:setGroup(self.taskGroup) end
end

function TaskGroupPane:onResize() -- super override
	BasicWindow.onResize(self)
	if self.boxArea then self.boxArea:setWidth(self.width) end
end

-- The three coordinate columns are right-aligned to the pane's trailing edge
-- so they stay put when the pane is resized, and still fit a pocket computer.
function TaskGroupPane:columnEnds()
	return { self.width - 18, self.width - 10, self.width - 2 }
end

function TaskGroupPane:setHostDisplay(hostDisplay)
	self.hostDisplay = hostDisplay
	if self.hostDisplay and self.hostDisplay.getMapDisplay then
		self.mapDisplay = self.hostDisplay:getMapDisplay()
	end
end

function TaskGroupPane:refresh()
	local group = self.taskGroup
	if not group then return end

	self.lblId:setText("GROUP " .. string.sub(tostring(group.id), 1, 8))

	-- TASK has the whole row minus its caption; TURT and TIME share theirs.
	self.lblTask:setText(fitText(group.taskName or "no task",
		self.width - (L.labelX + 6)))
	self.lblTurtles:setText(
		tostring(group:getActiveTurtles()) .. "/" .. tostring(group.groupSize))
	self.lblTime:setText(group:getUptimeText() or "")

	local area = group:getArea()
	local rows
	if area then
		local s, f = area.start, area.finish
		rows = {
			{ s.x, s.y, s.z },
			{ f.x, f.y, f.z },
			{ math.abs(f.x - s.x) + 1, math.abs(f.y - s.y) + 1,
			  math.abs(f.z - s.z) + 1 },
		}
	else
		-- A group can genuinely have no area (returnHome, for one). Say so
		-- rather than printing zeroes that look like a real location.
		rows = { { "-", "-", "-" }, { "-", "-", "-" }, { "-", "-", "-" } }
	end

	local ends = self:columnEnds()
	self.lblXCap:setPos(ends[1], L.plateTop)
	self.lblYCap:setPos(ends[2], L.plateTop)
	self.lblZCap:setPos(ends[3], L.plateTop)

	for row = 1, 3 do
		for col = 1, 3 do
			local lbl = self.coordLabels[row][col]
			local text = tostring(rows[row][col])
			lbl:setText(text)
			lbl:setPos(ends[col] - #text + 1, L.plateTop + row)
		end
	end
end

function TaskGroupPane:redraw() -- super override
	self:refresh()

	BasicWindow.redraw(self) -- super

	local c = default.colors
	if not self.taskGroup then return end

	-- Drawn after the children so they sit on top.
	local group = self.taskGroup
	local statusColor = group:getStatusColor()

	-- status word, right-aligned against the header row
	local status = statusText(group:getStatus())
	local sx = self.width - #status
	if sx > L.labelX + #self.lblId:getText() then
		self:drawText(sx, L.headerRow, status, statusColor, self.backgroundColor)
	end

	-- header rule
	self:drawFilledBox(L.labelX, L.dividerRow, self.width - L.labelX, 1, c.divider)

	-- progress bar. An untrackable group gets an empty track and no number,
	-- which is honest: nothing reports progress for it.
	-- The bar yields the trailing columns to the percentage, so both track the
	-- pane's width instead of assuming a 57-column monitor.
	local pctEnd = self.width - 2
	local barW = math.max(1, pctEnd - 5 - L.barX)
	local progress = group:getProgress()
	self:drawFilledBox(L.barX, L.barRow, barW, 1, c.track)
	if progress then
		local clamped = math.max(0, math.min(1, progress))
		local filled = math.floor(barW * clamped + 0.5)
		-- Any nonzero progress must show at least one cell, or a long job looks
		-- like it never started.
		if filled < 1 and clamped > 0 then filled = 1 end
		if filled > 0 then
			self:drawFilledBox(L.barX, L.barRow, filled, 1, statusColor)
		end
		local pct = group:getProgressText()
		self:drawText(pctEnd - #pct + 1, L.barRow, pct, c.value,
			self.backgroundColor)
	else
		self:drawText(pctEnd - 2, L.barRow, "--%", c.caption,
			self.backgroundColor)
	end
end

-- Where the options popup should open, in parent coordinates. Exposed so the
-- emulator test can prove it lands on screen without opening one: the popup
-- used to be anchored to a button on the rail row, and that anchor moved here.
function TaskGroupPane:optionsAnchor()
	local x = self.x + self.btnOptions.x - 1
	local y = self.y + self.btnOptions.y - self.optionsHeight + 1
	return math.max(1, x), math.max(1, y)
end

function TaskGroupPane:openMap()
	if not (self.taskGroup and self.hostDisplay and self.mapDisplay) then return true end
	local _, _, focus = self.taskGroup:getAreaDetails()
	if not focus then return true end
	self.mapDisplay:setGroupArea(self.taskGroup)
	self.mapDisplay:setMid(focus.x, focus.y, focus.z)
	self.hostDisplay:displayMap()
	return true
end

function TaskGroupPane:openDetails()
	if not (self.taskGroup and self.hostDisplay) then return true end
	self.hostDisplay:openGroupDetails(self.taskGroup)
	return true
end

function TaskGroupPane:callHome()
	if self.taskGroup then self.taskGroup:addTaskToTurtles("returnHome", {}) end
end

function TaskGroupPane:deleteGroup()
	local groupId = self.taskGroup and self.taskGroup.id
	if self.mapDisplay and groupId then
		self.mapDisplay:removeGroupArea(groupId)
	end
	if self.taskGroup then self.taskGroup:delete() end
	if self.hostDisplay then self.hostDisplay:deleteGroup(groupId) end
	return true
end

function TaskGroupPane:cancelTask()
	if not self.taskGroup then return end
	self.taskGroup:cancel()
	if self.mapDisplay then
		self.mapDisplay:removeGroupArea(self.taskGroup.id)
	end
end

function TaskGroupPane:openOptions()
	local group = self.taskGroup
	if not group then return true end

	local choices = { "call home", "reboot" }
	if group:isResumable() then table.insert(choices, 1, "resume task") end
	if group:isActive() then
		table.insert(choices, "cancel task")
	else
		table.insert(choices, "delete group")
	end

	local x, y = self:optionsAnchor()
	local choiceSelector = ChoiceSelector:new(x, y, self.optionsWidth,
		self.optionsHeight, choices)
	choiceSelector.onChoiceSelected = function(choice)
		if choice == "call home" then
			self:callHome()
		elseif choice == "reboot" then
			group:reboot()
		elseif choice == "resume task" then
			group:resume()
		elseif choice == "cancel task" then
			self:cancelTask()
		elseif choice == "delete group" then
			self:deleteGroup()
		end
	end

	self.parent:addObject(choiceSelector)
	self.parent:redraw()
	return true
end

return TaskGroupPane
