-- LabEnhanced non-destructive tunnel surveyor.
-- Explores only during an explicit mapping task. Known road nodes are reused;
-- only stored UNMAPPED frontiers are expanded.

local TunnelMap = require("classTunnelMap")

local Mapper = {}
Mapper.__index = Mapper

local horizontal = {
	{name="north",orient=2},
	{name="south",orient=0},
	{name="west",orient=1},
	{name="east",orient=3},
}

local function posTable(p)
	return {x=p.x,y=p.y,z=p.z}
end

function Mapper:new(miner,navigator)
	local o = {
		miner=miner,
		navigator=navigator,
	}
	setmetatable(o,self)
	return o
end

function Mapper:_queue(pos,dir,state,opts)
	self.miner:queueTunnelUpdate(pos,dir,state,opts)
end

function Mapper:surveyCurrent(existingNode)
	local m = self.miner
	local pos = vector.new(m.pos.x,m.pos.y,m.pos.z)
	local originalOrientation = m.orientation
	local known = existingNode and existingNode.connections or {}

	m:setMapValue(pos.x,pos.y,pos.z,0)

	-- Horizontal road candidates.
	for _,entry in ipairs(horizontal) do
		local conn = known and known[entry.name]
		local state = conn and conn.state
		if state == nil or state == TunnelMap.STATE.UNMAPPED
		or state == TunnelMap.STATE.TEMPORARILY_BLOCKED then
			m:turnTo(entry.orient)
			local hasBlock,data = turtle.inspect()
			local target = TunnelMap.target(pos,entry.name)
			if hasBlock then
				m:setMapValue(target.x,target.y,target.z,data and data.name or "unknown:block")
				self:_queue(pos,entry.name,TunnelMap.STATE.BLOCKED)
			else
				-- Adjacent air is only a FRONTIER until the turtle actually
				-- traverses it. This avoids treating arbitrary observed air as
				-- a verified road node.
				self:_queue(pos,entry.name,TunnelMap.STATE.UNMAPPED)
			end
		end
		sleep(0)
	end
	m:turnTo(originalOrientation)

	-- Floor. A missing floor is a meaningful downward route candidate.
	local downConn = known and known.down
	local hasDown,downData = turtle.inspectDown()
	if hasDown then
		m:setMapValue(pos.x,pos.y-1,pos.z,downData and downData.name or "unknown:block")
		if not downConn or downConn.state ~= TunnelMap.STATE.OPEN then
			self:_queue(pos,"down",TunnelMap.STATE.BLOCKED)
		end
	elseif not downConn or downConn.state ~= TunnelMap.STATE.OPEN then
		m:setMapValue(pos.x,pos.y-1,pos.z,0)
		self:_queue(pos,"down",TunnelMap.STATE.UNMAPPED)
	end

	-- Up needs special handling because every normal 2-high tunnel has air
	-- immediately above the lower travel cell. Probe one block higher without
	-- digging: only a 3+ high opening becomes a new vertical frontier.
	local upConn = known and known.up
	if not upConn or upConn.state ~= TunnelMap.STATE.OPEN then
		local hasUp,upData = turtle.inspectUp()
		if hasUp then
			m:setMapValue(pos.x,pos.y+1,pos.z,upData and upData.name or "unknown:block")
		else
			m:setMapValue(pos.x,pos.y+1,pos.z,0)
			local moved = turtle.up()
			if moved then
				local hasUp2,upData2 = turtle.inspectUp()
				if hasUp2 then
					m:setMapValue(pos.x,pos.y+2,pos.z,upData2 and upData2.name or "unknown:block")
				else
					m:setMapValue(pos.x,pos.y+2,pos.z,0)
					self:_queue(pos,"up",TunnelMap.STATE.UNMAPPED)
				end
				if not turtle.down() then
					m:turnTo(originalOrientation)
					error("TUNNEL MAPPER VERTICAL PROBE COULD NOT RETURN",0)
				end
			end
		end
	end

	m:turnTo(originalOrientation)
	return m:flushTunnelUpdatesSync()
end

function Mapper:mapNetwork(radius,maxCells)
	radius = tonumber(radius) or 512
	maxCells = tonumber(maxCells) or 20000
	radius = math.max(8,math.min(radius,2048))
	maxCells = math.max(16,math.min(maxCells,100000))

	local m = self.miner
	local nav = self.navigator
	local startPos = vector.new(m.pos.x,m.pos.y,m.pos.z)
	local startOrientation = m.orientation
	local mapped = 0
	local failedFrontiers = 0
	local currentTask = m:addCheckTask({"mapTunnelNetwork"})

	print("SHARED TUNNEL NETWORK MAPPER")
	print("radius:",radius,"max new cells:",maxCells)
	print("NO BLOCKS WILL BE MINED")

	-- Do not rescan a node another turtle already mapped.
	local currentNode = nav:requestNode(m.pos)
	if not currentNode then
		self:surveyCurrent(nil)
		mapped = mapped + 1
	end

	while mapped < maxCells do
		-- addCheckTask makes STOP/cancellation work during a long mapping job.
		local pulse = m:addCheckTask({"mapTunnelNetworkStep"})
		m.taskList:remove(pulse)

		local frontier,reason,stats = nav:requestNearestFrontier(startPos,radius)
		if not frontier then
			if reason == "no_frontier" then
				print("NO UNMAPPED TUNNEL FRONTIERS REMAIN IN RANGE")
			else
				print("MAPPER STOPPED:",reason or "unknown")
			end
			break
		end

		if frontier.path and #frontier.path > 0 then
			local ok = nav:followPath(frontier.path)
			if not ok then
				failedFrontiers = failedFrontiers + 1
				if failedFrontiers > 32 then
					print("TOO MANY BLOCKED FRONTIERS - STOPPING SAFELY")
					break
				end
				sleep(0)
			else
				failedFrontiers = 0
			end
		end

		if m.pos.x == frontier.source.x
		and m.pos.y == frontier.source.y
		and m.pos.z == frontier.source.z then
			local target = vector.new(frontier.target.x,frontier.target.y,frontier.target.z)
			local ok = nav:moveAdjacent(target)
			if ok then
				mapped = mapped + 1
				-- Successful movement queued the OPEN edge. Flush it, then
				-- survey only this newly reached node.
				m:flushTunnelUpdatesSync()
				self:surveyCurrent(nil)

				if mapped % 25 == 0 then
					local s = nav:requestStats()
					if s then
						print("mapped",mapped,"new | graph",s.nodes,
							"nodes |",s.frontiers,"frontiers")
					else
						print("mapped",mapped,"new tunnel cells")
					end
				end
			else
				-- moveAdjacent classified the blockage and synchronised it.
				failedFrontiers = failedFrontiers + 1
			end
		end

		sleep(0)
	end

	m:flushTunnelUpdatesSync()

	print("MAPPING COMPLETE - RETURNING THROUGH ROAD NETWORK")
	local returned = nav:navigateTo(startPos,{maxReroutes=32})
	if returned then
		m:turnTo(startOrientation)
	else
		print("NO VALID ROUTE BACK TO MAPPER START")
	end

	local stats = nav:requestStats()
	if stats then
		print("tunnel graph:",stats.nodes,"nodes,",stats.openEdges,
			"edges,",stats.frontiers,"frontiers")
	end
	print("new cells mapped:",mapped)
	m.taskList:remove(currentTask)
	return returned,mapped,stats
end

return Mapper
