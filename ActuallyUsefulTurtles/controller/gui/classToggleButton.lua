local Button = require("classButton")

local defaultColorOn = colors.green
local defaultColorOff = colors.red
local defaultTextOn = "ON"
local defaultTextOff = "OFF"

local ToggleBtn = Button:new()

function ToggleBtn:new(x,y,width,height,colorOn,colorOff)
	local o = o or Button:new(defaultTextOn, x,y,width ,height, colorOn or defaultColorOn)
	setmetatable(o, self)
	self.__index = self
	o.colorOn = colorOn or defaultColorOn
	o.colorOff = colorOff or defaultColorOff
	o.textOn = defaultTextOn
	o.textOff = defaultTextOff
	o.active = true
	return o
end

function ToggleBtn:handleClick()
	--super
	Button.handleClick(self)
	--toggle
	self:toggle()
	self:redraw()
end
function ToggleBtn:toggle()
	self.active = (self.active == false)
	self:refresh()
end

function ToggleBtn:refresh()
	if self.active then
		self.backgroundColor = self.colorOn
		self:setText(self.textOn)
	else
		self.backgroundColor = self.colorOff
		self:setText(self.textOff)
	end
end
function ToggleBtn:setColorOn(color)
	self.colorOn = color
	self:refresh()
end
function ToggleBtn:setColorOff(color)
	self.colorOff = color
	self:refresh()
end
function ToggleBtn:setColor(colorOn,colorOff)
	self:setColorOn(colorOn)
	self:setColorOff(colorOff)
end
function ToggleBtn:setTextOn(text)
	self.textOn = tostring(text)
	self:refresh()
end
function ToggleBtn:setTextOff(text)
	self.textOff = tostring(text)
	self:refresh()
end
	
return ToggleBtn