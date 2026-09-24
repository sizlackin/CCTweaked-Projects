-- LabEnhanced strict road-network navigator.
-- Uses the existing "miner" NetworkNode to ask the controller for routes.
-- Movement in this module never calls dig/digUp/digDown.

local TunnelMap = require("classTunnelMap")

local Navigator = {}
Navigator.__index = Navigator

local orientForDir = {
	south=0,
	west=1,
	north=2,
	east=3,
}

local function posTable(p)
	return {x=p.x,y=p.y,z=p.z}
end

local function isTurtleBlock(name)
	return name == "computercraft:turtle_advanced"
		or name == "computercraft:turtle_normal"
		or name == "computercraft:turtle"
end

local function isTunnelDecoration(name)
	return name == "minecraft:torch"
		or name == "minecraft:wall_torch"
		or name == "minecraft:soul_torch"
		or name == "minecraft:soul_wall_torch"
end

Navigator.isTunnelDecoration = isTunnelDecoration -- LABENHANCED_TORCH_BYPASS

function Navigator:new(miner)
	local o = {
		miner=miner,
		node=miner.node,
		maxReroutes=24,
		tempBlockMs=5000,
	}
	setmetatable(o,self)
	return o
end

function Navigator:_request(command,payload,waitTime)
	if not self.node or not self.node.host then
		return nil,"NO TUNNEL MAP HOST"
	end
	local answer = self.node:send(
		self.node.host,
		{command,payload},
		true,true,waitTime or 3
	)
	if not answer or not answer.data then
		return nil,"NO TUNNEL MAP RESPONSE"
	end
	return answer.data
end

function Navigator:sendUpdates(updates)
	if not updates or #updates == 0 then return true end
	local data,err = self:_request("TUNNEL_MAP_UPDATE",updates,3)
	if not data then return false,err end
	return data[1] == "TUNNEL_MAP_ACK",data[2]
end

function Navigator:requestRoute(goal)
	if self.miner.flushTunnelUpdatesSync then
		self.miner:flushTunnelUpdatesSync()
	end
	local data,err = self:_request("TUNNEL_ROUTE_REQUEST",{
		start=posTable(self.miner.pos),
		goal=posTable(goal),
	},4)
	if not data then return nil,err end
	if data[1] ~= "TUNNEL_ROUTE" then
		return nil,data[2] or data[1],data[3]
	end
	local payload = data[2] or {}
	return payload.path or {},payload.reason,payload.stats
end

function Navigator:requestNearestFrontier(origin,radius)
	if self.miner.flushTunnelUpdatesSync then
		self.miner:flushTunnelUpdatesSync()
	end
	local data,err = self:_request("TUNNEL_FRONTIER_REQUEST",{
		start=posTable(self.miner.pos),
		origin=origin and posTable(origin) or nil,
		radius=radius,
	},4)
	if not data then return nil,err end
	if data[1] ~= "TUNNEL_FRONTIER" then
		return nil,data[2] or data[1],data[3]
	end
	return data[2],nil,data[3]
end

function Navigator:requestNode(pos)
	local data,err = self:_request("TUNNEL_NODE_REQUEST",posTable(pos),3)
	if not data then return nil,err end
	if data[1] == "TUNNEL_NODE" then return data[2] end
	return nil,data[2] or data[1]
end

function Navigator:requestStats()
	local data,err = self:_request("TUNNEL_STATS_REQUEST",{},3)
	if not data then return nil,err end
	if data[1] == "TUNNEL_STATS" then return data[2] end
	return nil,data[2] or data[1]
end

function Navigator:_inspectDirection(dir)
	local hasBlock,data
	if dir == "up" then
		hasBlock,data = turtle.inspectUp()
	elseif dir == "down" then
		hasBlock,data = turtle.inspectDown()
	else
		self.miner:turnTo(orientForDir[dir])
		hasBlock,data = turtle.inspect()
	end
	return hasBlock,data
end

function Navigator:_recordBlocked(fromPos,dir,hasBlock,data)
	local target = TunnelMap.target(fromPos,dir)
	local state,resume,until
	local name = hasBlock and data and data.name or nil

	if not hasBlock or isTurtleBlock(name) then
		state = TunnelMap.STATE.TEMPORARILY_BLOCKED
		resume = TunnelMap.STATE.OPEN
		until = os.epoch("utc") + self.tempBlockMs
	else
		state = TunnelMap.STATE.BLOCKED
		if target and self.miner.setMapValue then
			self.miner:setMapValue(target.x,target.y,target.z,name)
		end
	end

	if self.miner.queueTunnelUpdate then
		self.miner:queueTunnelUpdate(fromPos,dir,state,{until=until,resume=resume})
		self.miner:flushTunnelUpdatesSync()
	else
		self:sendUpdates({{
			pos=posTable(fromPos),dir=dir,state=state,
			seen=os.epoch("utc"),until=until,resume=resume,
		}})
	end

	return state,name
end

function Navigator:moveAdjacent(target)
	local from = vector.new(self.miner.pos.x,self.miner.pos.y,self.miner.pos.z)
	local dir = TunnelMap.directionBetween(from,target)
	if not dir then return false,"NON_ADJACENT_ROUTE_STEP" end

	local ok
	if dir == "up" then
		ok = self.miner:up()
	elseif dir == "down" then
		ok = self.miner:down()
	else
		self.miner:turnTo(orientForDir[dir])
		ok = self.miner:forward()
	end

	if ok then
		-- Miner movement records the OPEN road edge. Keep the current occupied
		-- cell explicitly known as air in the existing shared block map.
		self.miner:setMapValue(self.miner.pos.x,self.miner.pos.y,self.miner.pos.z,0)
		return true
	end

	local hasBlock,data = self:_inspectDirection(dir)
	local name = hasBlock and data and data.name or nil
	if hasBlock and isTunnelDecoration(name) then
		-- A turtle cannot occupy the same lower tunnel cell as a torch. Do not
		-- call it a permanent tunnel closure: the Mapper can preserve the torch
		-- and route through the upper half of the 2-high tunnel instead.
		return false,"decoration",name
	end
	local state
	state,name = self:_recordBlocked(from,dir,hasBlock,data)
	return false,state,name
end

function Navigator:followPath(path)
	for i=1,#path do
		local p = path[i]
		if not self:moveAdjacent(vector.new(p.x,p.y,p.z)) then
			return false,i
		end
		if i % 32 == 0 then sleep(0) end
	end
	return true
end

function Navigator:navigateTo(goal,opts)
	opts = opts or {}
	goal = vector.new(goal.x,goal.y,goal.z)
	if self.miner.pos == goal then return true end

	local attempts = 0
	while attempts < (opts.maxReroutes or self.maxReroutes) do
		attempts = attempts + 1
		local path,reason,stats = self:requestRoute(goal)
		if not path then
			if reason == "temporarily_blocked" or reason == "no_route_temp" then
				sleep(1)
			else
				print("NO VALID ROUTE",reason or "")
				return false,reason,stats
			end
		else
			local ok = self:followPath(path)
			if ok and self.miner.pos == goal then
				if self.miner.flushTunnelUpdatesSync then
					self.miner:flushTunnelUpdatesSync()
				end
				return true
			end
			-- A failed step already updated the authoritative road graph.
			-- Ask the controller for a fresh route instead of digging.
			sleep(0)
		end
	end

	print("NO VALID ROUTE - REROUTE LIMIT")
	return false,"reroute_limit"
end

return Navigator
