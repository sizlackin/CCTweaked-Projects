local GPU = 
{
prvBackgroundColor,
prvTextColor,
backgroundColor = colors.black,
textColor = colors.white,
old,
monitor,
}

function GPU:new(o,monitor)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    self.monitor = monitor or nil
    if self.monitor == nil then
        self:findMonitor()
    end
    return o
end

function GPU:findMonitor()
    local monitors = peripheral.find("monitor")
    if monitors[1] == nil then
        error("no monitor found",0)
    end
    self.monitor = monitors[1]
end
function GPU:setBackgroundColor(backgroundColor)
    self.prvBackgroundColor = self.monitor.getBackgroundColor()
    if backgroundColor == nil then
        self.backgroundColor = colors.white
    else
        self.backgroundColor = backgroundColor
    end
    self.monitor.setBackgroundColor(self.backgroundColor)
end

function GPU:setTextColor(textColor)
    self.prvTextColor = self.monitor.getTextColor()
    if textColor == nil then
        self.textColor = colors.white
    else
        self.textColor = textColor
    end
    self.monitor.setTextColor(self.textColor)
end
function GPU:setColor(backgroundColor, textColor)
    self:setBackgroundColor(backgroundColor)
    self:setTextColor(textColor)
end

function GPU:restoreColor()
    if self.prvBackgroundColor ~= nil then
        self.monitor.setBackgroundColor(self.prvBackgroundColor)
    else
        self.monitor.setBackgroundColor(colors.black)
    end
    if self.prvTextColor ~= nil then
        self.monitor.setTextColor(self.prvTextColor)
    else
        self.monitor.setTextColor(colors.white)
    end
end

function GPU:drawBox(x,y,width,height,color)
    self:setBackgroundColor(color)
    --local width = endX - x + 1
    --local height = endY - y + 1
    self.old = term.redirect(self.monitor)
    
    self.monitor.setCursorPos(x,y)
    
    for c=1,height do
        for ln = 1,width do
            self.monitor.write(" ")
        end
        self.monitor.setCursorPos(x, y+c)
    end    
    
    term.redirect(self.old)
    self:restoreColor()
    
end

return GPU