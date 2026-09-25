local SimpleVector = {}
SimpleVector.__index = SimpleVector

local function newVector( x, y, z )
    return setmetatable( { x = x or 0, y = y or 0, z = z or 0 }, SimpleVector )
end

function isvector( vTbl )
    return getmetatable( vTbl ) == SimpleVector
end

function SimpleVector.__unm( vTbl )
    return newVector( -vTbl.x, -vTbl.y, -vTbl.z )
end

function SimpleVector.__add( a, b )
    return newVector( a.x + b.x, a.y + b.y, a.z + b.z )
end

function SimpleVector.__sub( a, b )
    return newVector( a.x - b.x, a.y - b.y, a.z - b.z )
end

function SimpleVector.__mul( a, b )
    if type( a ) == "number" then
        return newVector( a * b.x, a * b.y, a * b.z )
    elseif type( b ) == "number" then
        return newVector( a.x * b, a.y * b, a.z * b )
    else
        return newVector( a.x * b.x, a.y * b.y, a.z * b.z )
    end
end

function SimpleVector.__div( a, b )
    return newVector( a.x / b, a.y / b, a.z /b )
end

function SimpleVector.__eq( a, b )
    return a.x == b.x and a.y == b.y and a.z == b.z
end

function SimpleVector:__tostring()
    return "(" .. self.x .. ", " .. self.y .. ", " .. self.z .. ")"
end

function SimpleVector:getId()
    if self._ID == nil then
        local x, y, z = self.x, self.y, self.z
		if x < 0 then 
			x = -x 
			y = y + 448 
		end
		if z < 0 then 
			z = -z 
			y = y + 896 
		end
		y = y + 64 -- default.minHeight
		--------------------------------------------------------
		local temp = 0.5 * ( x + y ) * ( x + y + 1 ) + y
		self._ID = 0.5 * ( temp + z ) * ( temp + z + 1 ) + z 
		--------------------------------------------------------
    end

    return self._ID
end

function SimpleVector:toVector()
	return vector.new(self.x, self.y, self.z)
end

return setmetatable( SimpleVector, { __call = function( _, ... ) return newVector( ... ) end } )