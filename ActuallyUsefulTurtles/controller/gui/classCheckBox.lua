local Button = require("classButton")

local defaultBackgroundColor = colors.black
local defaultHeight = 1
local defaultTextOn = "[X]"
local defaultTextOff = "[ ]"

local CheckBox = Button:new()

function CheckBox:new(x,y,text,active, width,height,color)
	local o = o or Button:new(text, x,y,width ,height or defaultHeight, color or defaultBackgroundColor)
	setmetatable(o, self)
	self.__index = self
	o.textOn = defaultTextOn
	o.textOff = defaultTextOff
	o.midX = o.x
	o.active = active or false
	o.text = text or ""
	o:initialize()
	return o
end

function CheckBox:initialize()
	self:setText(self.text or "")
	self.width = width or string.len(self.labelText) + string.len(self.textOn) + 1
end
	
function CheckBox:handleClick()
	self:toggle()
	--super
	Button.handleClick(self)
	
	self:redraw()
end

function CheckBox:toggle()
	self.active = (self.active == false)
	self:refresh()
end

function CheckBox:setText(text)
	--override
	self.labelText = tostring(text)
	self:refresh()
end

function CheckBox:refresh()
	if self.active then
		self.text = self.textOn .. " " .. self.labelText
	else
		self.text = self.textOff ..  " " .. self.labelText
	end
end

function CheckBox:setTextOn(text)
	self.textOn = tostring(text)
	self:refresh()
end

function CheckBox:setTextOff(text)
	self.textOff = tostring(text)
	self:refresh()
end
	
return CheckBox