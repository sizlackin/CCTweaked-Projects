-- LABENHANCED_GROUPS_MASTERDETAIL
-- One line in the Groups rail. This used to be a seven-row card carrying the
-- coordinates, the readouts and three buttons; all of that moved to
-- classTaskGroupPane, which shows whichever group the rail has selected.
--
-- What is left is deliberately tiny: a selection plate, a status lamp, the
-- short id and an abbreviated status. The lamp colour still comes from
-- group:getStatusColor(), so rail and pane always agree.

local Button = require("classButton")
local BasicWindow = require("classBasicWindow")

local default = {
	width = 14,
	height = 1,
	colors = {
		background = colors.black,
		selected = colors.gray,
		caption = colors.lightGray,
		value = colors.white,
		neutral = colors.white,
	},
}

local layout = {
	lampX   = 1,
	idX     = 3,
	idW     = 4,
	statusX = 8,
}

-- Four characters, because the rail is fourteen wide and the pane carries the
-- full word. Every status in statusToColor has an entry; anything unmapped
-- falls through to the first four characters of the raw status.
local abbrev = {
	new               = "NEW",
	started           = "RUN",
	resumed           = "RUN",
	partially_started = "PART",
	partially_resumed = "PART",
	completed         = "DONE",
	cancelled         = "CANC",
	error             = "ERR",
	deleted           = "DEL",
}

local function statusAbbrev(status)
	if not status then return "----" end
	return abbrev[status] or tostring(status):upper():sub(1, 4)
end

local TaskGroupControl = BasicWindow:new()

function TaskGroupControl:new(x, y, taskGroup)
	local o = BasicWindow:new(x, y, default.width, default.height)
	setmetatable(o, self)
	self.__index = self

	o:setBackgroundColor(default.colors.background)
	o:setBorderColor(default.colors.background)

	o.taskGroup = taskGroup
	o.selected = false
	o.hostDisplay = nil
	o.mapDisplay = nil

	o:initialize()

	return o
end

function TaskGroupControl:initialize()
	-- A full-width button is the click target: BasicWindow dispatches a click to
	-- whichever child covers the position, so the whole line selects, not just
	-- the text. It carries no caption - redraw paints the line on top of it.
	self.btnSelect = Button:new("", 1, 1, self.width, 1,
		default.colors.background)
	self.btnSelect.click = function()
		self:select()
		return true -- suppress the blink; selection is its own feedback
	end
	self:addObject(self.btnSelect)
end

function TaskGroupControl:setHostDisplay(hostDisplay)
	self.hostDisplay = hostDisplay
	if self.hostDisplay and self.hostDisplay.getMapDisplay then
		self.mapDisplay = self.hostDisplay:getMapDisplay()
	end
end

function TaskGroupControl:setTaskGroup(taskGroup)
	self.taskGroup = taskGroup
end

function TaskGroupControl:setSelected(selected)
	self.selected = selected and true or false
	local bg = self.selected and default.colors.selected
		or default.colors.background
	self:setBackgroundColor(bg)
	self:setBorderColor(bg)
	if self.btnSelect then
		self.btnSelect:setBackgroundColor(bg)
	end
end

function TaskGroupControl:select()
	if self.hostDisplay and self.hostDisplay.selectGroup then
		self.hostDisplay:selectGroup(self.taskGroup and self.taskGroup.id)
	else
		-- Standalone (tests, previews): still reflect the click.
		self:setSelected(true)
	end
	return true
end

function TaskGroupControl:onResize() -- super override
	BasicWindow.onResize(self)
	if self.btnSelect then
		self.btnSelect:setWidth(self.width)
	end
end

function TaskGroupControl:redraw() -- super override
	BasicWindow.redraw(self) -- super

	local group = self.taskGroup
	if not group then return end

	local c = default.colors
	local bg = self.selected and c.selected or c.background
	local statusColor = group:getStatusColor()

	-- The click target is a full-width Button, and Box:redraw paints its own
	-- frame inside the row. Lay the plate down over it so the selection reads as
	-- one solid band rather than a rule with gaps where the glyphs sit.
	self:drawFilledBox(1, 1, self.width, 1, bg)

	-- lamp
	self:drawFilledBox(layout.lampX, 1, 1, 1, statusColor)

	-- id, clipped to its field so a long one cannot push the status along
	local id = string.sub(tostring(group.id), 1, layout.idW)
	self:drawText(layout.idX, 1, id, c.value, bg)

	-- abbreviated status, clipped to whatever the rail actually has left
	local room = self.width - layout.statusX + 1
	if room > 0 then
		local status = statusAbbrev(group:getStatus()):sub(1, room)
		self:drawText(layout.statusX, 1, status, statusColor, bg)
	end
end

return TaskGroupControl
