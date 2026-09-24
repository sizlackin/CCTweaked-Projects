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

local function isTunnelDecoration(name)
	return name == "minecraft:torch"
		or name == "minecraft:wall_torch"
		or name == "minecraft:soul_torch"
		or name == "minecraft:soul_wall_torch"
end

local orientForDir = {
	north=2,south=0,west=1,east=3,
}

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

	-- Inspect the floor first. If this node is part of a vertical shaft (air
	-- below plus an already-open vertical edge), do not fan out through the
	-- upper/head-space layer of nearby 2-high tunnels.
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

	local upKnown = known and known.up and known.up.state == TunnelMap.STATE.OPEN
	local downKnown = downConn and downConn.state == TunnelMap.STATE.OPEN
	local verticalTransit = (not hasDown) and (upKnown or downKnown)

	-- Horizontal road candidates.
	if not verticalTransit then
	for _,entry in ipairs(horizontal) do
		local conn = known and known[entry.name]
		local state = conn and conn.state
		if state == nil or state == TunnelMap.STATE.UNMAPPED
		or state == TunnelMap.STATE.TEMPORARILY_BLOCKED then
			m:turnTo(entry.orient)
			local hasBlock,data = turtle.inspect()
			local target = TunnelMap.target(pos,entry.name)
			if hasBlock then
				local name = data and data.name or "unknown:block"
				m:setMapValue(target.x,target.y,target.z,name)
				if isTunnelDecoration(name) then
					-- LABENHANCED_TORCH_BYPASS
					-- Keep the frontier discoverable. The mapper will go over
					-- the torch through the upper half of the 2-high tunnel.
					self:_queue(pos,entry.name,TunnelMap.STATE.UNMAPPED)
				else
					self:_queue(pos,entry.name,TunnelMap.STATE.BLOCKED)
				end
			else
				-- Adjacent air is only a FRONTIER until the turtle actually
				-- traverses it. This avoids treating arbitrary observed air as
				-- a verified road node.
				self:_queue(pos,entry.name,TunnelMap.STATE.UNMAPPED)
			end
		end
		sleep(0)
	end
	end
	m:turnTo(originalOrientation)

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

-- Preserve floor/wall torches without treating them as dead ends.
-- In a normal 2-high tunnel the turtle can climb into the upper cell, pass
-- above one or more lower-cell torches, then descend once lower air resumes.
-- No block is broken or placed.
function Mapper:bypassDecoration(frontier,blockName)
	if not frontier or not orientForDir[frontier.dir]
	or not isTunnelDecoration(blockName) then
		return false
	end

	local m = self.miner
	local source = vector.new(m.pos.x,m.pos.y,m.pos.z)
	local originalOrientation = m.orientation
	local orient = orientForDir[frontier.dir]
	local travelled = 0

	print("TORCH IN TUNNEL - USING UPPER BYPASS")

	-- Direct lower edge really is unavailable while the torch remains, so keep
	-- that edge blocked. The upper detour becomes the valid shared road.
	self:_queue(source,frontier.dir,TunnelMap.STATE.BLOCKED)
	m:flushTunnelUpdatesSync()

	if not m:up() then
		m:turnTo(originalOrientation)
		return false
	end

	m:turnTo(orient)
	for i=1,8 do
		if not m:forward() then
			for j=1,travelled do m:back() end
			m:down()
			m:turnTo(originalOrientation)
			return false
		end
		travelled = travelled + 1

		local hasDown,dataDown = turtle.inspectDown()
		if not hasDown then
			if m:down() then
				m:turnTo(originalOrientation)
				m:flushTunnelUpdatesSync()
				return true
			end
		else
			local name = dataDown and dataDown.name or nil
			if not isTunnelDecoration(name) then
				for j=1,travelled do m:back() end
				m:down()
				m:turnTo(originalOrientation)
				return false
			end
			-- Still above another torch: continue through upper tunnel space.
		end
	end

	for j=1,travelled do m:back() end
	m:down()
	m:turnTo(originalOrientation)
	return false
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

	-- LABENHANCED_MAPPER_REFRESH_KNOWN
	-- The road graph may already know this node while the visual/block map does
	-- not (for example after a map reset or when floor-colors were enabled
	-- later). Refresh the occupied cell/floor and discover only directions that
	-- are still missing/unmapped; surveyCurrent preserves known OPEN edges.
	local currentNode = nav:requestNode(m.pos)
	self:surveyCurrent(currentNode)
	if not currentNode then
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
			local ok = true
			for i=1,#frontier.path do
				local p = frontier.path[i]
				if not nav:moveAdjacent(vector.new(p.x,p.y,p.z)) then
					ok = false
					break
				end

				-- Dedicated mapping mode should refresh visual coverage while
				-- travelling over known roads. This does NOT dig and does not
				-- re-explore already-known OPEN connections.
				local knownNode = nav:requestNode(m.pos)
				self:surveyCurrent(knownNode)
				if i % 16 == 0 then sleep(0) end
			end

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
			local ok,moveReason,blockName = nav:moveAdjacent(target)

			-- A lower-cell torch is decoration, not the end of a tunnel. Preserve
			-- it and take the upper half of the existing 2-high tunnel around it.
			if not ok and moveReason == "decoration" then
				ok = self:bypassDecoration(frontier,blockName)
			end

			if ok then
				mapped = mapped + 1
				-- Successful movement queued the OPEN road edges. Flush them,
				-- then survey only the newly reached lower road node.
				m:flushTunnelUpdatesSync()
				local reachedNode = nav:requestNode(m.pos)
				self:surveyCurrent(reachedNode)

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
