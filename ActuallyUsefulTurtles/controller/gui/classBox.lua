local defaultBackgroundColor = colors.gray

local Box = {}

function Box:new(x,y,width,height,color)
    local o = o or {}
    setmetatable(o,self)
    self.__index = self
    o.x = x or 0
    o.y = y or 0
    o.width = width or 0
    o.height = height or 0
    o.backgroundColor = color or defaultBackgroundColor
    o.borderColor = o.backgroundColor
	o.borderWidth = 2
	o:initialize()
    return o
end

function Box:initialize()
	self:calculateMid()
end
function Box:setX(x)
	self.x = x
	self:calculateMid()
end
function Box:setY(y)
	self.y = y
	self:calculateMid()
end
function Box:setPos(x,y)
	self:setX(x)
	self:setY(y)
end
function Box:calculateMid()
	self.midWidth = math.floor(self.width/2)
	self.midHeight = math.floor(self.height/2)
	self.midX = self.x + self.midWidth
    self.midY = self.y + self.midHeight
end

function Box:setBorderColor(color)
    if color == nil then
        color = self.backgroundColor
    end
    self.borderColor = color
end

function Box:setBackgroundColor(color)
	self.prvBackgroundColor = self.backgroundColor
	if color == nil then
		color = defaultBackgroundColor
	end
	self.backgroundColor = color
end
function Box:getBackgroundColor()
	--TODO: check if border is clicked
    return self.backgroundColor
end

function Box:restoreBackgroundColor()
	local color = self.prvBackgroundColor
	if not color then
		color = defaultBackgroundColor
	end
	self.backgroundColor = color
end

function Box:setWidth(width)
    self.width = width
end

function Box:setHeight(height)
	self.height = height
end

function Box:redraw()
	if self.parent and self.visible then
		self.parent:drawFilledBox(self.x,self.y,self.width,self.height,	self.backgroundColor)
		if self.borderColor ~= self.backgroundColor then
			self.parent:drawBox(self.x, self.y, self.width, self.height, self.borderColor, self.borderWidth, self.backgroundColor)
		end
	end
end

return Box