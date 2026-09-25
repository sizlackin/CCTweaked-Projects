local Box = require("classBox")

local default = {
	borderColor = colors.gray,
	backgroundColor = colors.black,
	textColor = colors.white
}
local Frame = Box:new()

function Frame:new(text,x,y,width,height,borderColor)
	local o = o or Box:new(x,y,width,height,default.backgroundColor)
	setmetatable(o, self)
	self.__index = self
	
	o.backgroundColor = default.backgroundColor
	o.borderColor = borderColor or default.borderColor
	o.textColor = default.textColor
	o.text = text or ""
	--o.area = Area:new(o.x-1, o.y-1, o.width-2, o.height-2)
	
	return o
end

function Frame:setText(text)
	self.text = tostring(text)
end

function Frame:getText()
	return self.text
end
function Frame:setBorderColor(color)
	self.borderColor = color
end
function Frame:getBorderColor()
	return self.borderColor
end
function Frame:setTextColor(color)
	self.textColor = color
end
function Frame:getTextColor()
	return self.textColor
end
function Frame:redraw()
	--super
	Box.redraw(self)
	
	--Label
	if self.parent and self.visible then
		self.parent:drawText(self.x+3, self.y, " " .. self:getText() .. " ", self.textColor, self.backgroundColor)
	end
end

return Frame