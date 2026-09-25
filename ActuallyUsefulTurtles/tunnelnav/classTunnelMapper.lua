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
	-- LABENHANCED_TORCH_BYPASS_V2
	-- Any registry id ending in "torch" is treated as tunnel decoration.
	-- This covers vanilla wall/soul torches and modded torch variants.
	return type(name) == "string"
		and string.match(string.lower(name), ":.*torch$") ~= nil
end

local orientForDir = {
	north=2,south=0,west=1,east=3,
}

function Mapper:new(miner,navigator)
	local o = {
		miner=miner,
		navigator=navigator or (miner and miner.tunnelNavigator) or nil, -- LABENHANCED_MAPPER_NAV_FIX
	}
	setmetatable(o,self)
	return o
end

function Mapper:_queue(pos,dir,state,opts)
	self.miner:queueTunnelUpdate(pos,dir,state,opts)
end

function Mapper:_trafficKey(pos,dir)
	return tostring(pos.x)..","..tostring(pos.y)..","..tostring(pos.z).."|"..tostring(dir)
end

function Mapper:handleTraffic(frontier,target,dir,trafficHits)
	-- LABENHANCED_SMART_TRAFFIC
	-- First collision: give the turtle ahead a brief chance to clear the lane.
	-- Repeated/stalled collision: put that shared edge on a short cooldown,
	-- release our frontier, and let the controller choose the nearest reachable
	-- unclaimed frontier on another branch.
	local m = self.miner
	local nav = self.navigator
	local from = vector.new(m.pos.x,m.pos.y,m.pos.z)
	local key = self:_trafficKey(from,dir)
	local hits = (trafficHits[key] or 0) + 1
	trafficHits[key] = hits

	print("TURTLE TRAFFIC AHEAD - BRIEF YIELD")
	nav:renewFrontier(frontier)
	sleep(0.75)

	local ok,reason,name = nav:moveAdjacent(target)
	if ok then
		trafficHits[key] = nil
		print("TRAFFIC CLEARED - CONTINUING")
		return true,nil,nil
	end

	if reason ~= "traffic" then
		return false,reason,name
	end

	-- Escalate the shared avoidance window for repeated congestion on the same
	-- edge. This makes a mapper prefer a side branch / loop when one exists,
	-- while still allowing this road to reopen automatically later.
	local cooldown = math.min(3500 + (hits-1)*3000,15000)
	nav:deferTrafficEdge(from,dir,cooldown)
	nav:releaseFrontier(frontier)
	print("TRAFFIC STALLED - TRYING NEXT BEST BRANCH")
	return false,"traffic_reroute",name
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
	-- During an explicit mapping job we physically revalidate every direction,
	-- including old BLOCKED edges. This repairs stale graph entries caused by
	-- torches being mistaken for tunnel walls in older mapper versions.
	if not verticalTransit then
	for _,entry in ipairs(horizontal) do
		local conn = known and known[entry.name]
		local state = conn and conn.state
		m:turnTo(entry.orient)
		local hasBlock,data = turtle.inspect()
		local target = TunnelMap.target(pos,entry.name)

		if hasBlock then
			local name = data and data.name or "unknown:block"
			m:setMapValue(target.x,target.y,target.z,name)
			if isTunnelDecoration(name) then
				-- LABENHANCED_TORCH_REROUTE
				-- Old mapper versions could incorrectly leave torch edges BLOCKED,
				-- so those are still allowed one physical bypass attempt. Once this
				-- mapper has actually tried the upper route and proven it unusable,
				-- remember that fact and do not recreate the same frontier forever.
				if not (state == TunnelMap.STATE.BLOCKED
				and conn and conn.blockedReason == "decoration_no_bypass") then
					self:_queue(pos,entry.name,TunnelMap.STATE.UNMAPPED)
				end
			elseif state ~= TunnelMap.STATE.BLOCKED then
				self:_queue(pos,entry.name,TunnelMap.STATE.BLOCKED)
			end
		else
			-- If this road was previously confirmed OPEN, keep it OPEN.
			-- Otherwise mark it as a frontier; TunnelMap automatically promotes
			-- it to OPEN when the adjacent coordinate is already a known node.
			if state ~= TunnelMap.STATE.OPEN then
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
		return false,"not_decoration"
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
		self:_queue(source,frontier.dir,TunnelMap.STATE.BLOCKED,{
			blockedReason="decoration_no_bypass",
		})
		m:flushTunnelUpdatesSync()
		m:turnTo(originalOrientation)
		print("TORCH BYPASS BLOCKED - REROUTING")
		return false,"upper_entry_blocked"
	end

	m:turnTo(orient)
	for i=1,8 do
		if not m:forward() then
			for j=1,travelled do m:back() end
			m:down()
			self:_queue(source,frontier.dir,TunnelMap.STATE.BLOCKED,{
				blockedReason="decoration_no_bypass",
			})
			m:flushTunnelUpdatesSync()
			m:turnTo(originalOrientation)
			print("TORCH BYPASS BLOCKED - REROUTING")
			return false,"upper_path_blocked"
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
				self:_queue(source,frontier.dir,TunnelMap.STATE.BLOCKED,{
					blockedReason="decoration_no_bypass",
				})
				m:flushTunnelUpdatesSync()
				m:turnTo(originalOrientation)
				print("TORCH BYPASS BLOCKED - REROUTING")
				return false,"no_lower_landing"
			end
			-- Still above another torch: continue through upper tunnel space.
		end
	end

	for j=1,travelled do m:back() end
	m:down()
	self:_queue(source,frontier.dir,TunnelMap.STATE.BLOCKED,{
		blockedReason="decoration_no_bypass",
	})
	m:flushTunnelUpdatesSync()
	m:turnTo(originalOrientation)
	print("TORCH BYPASS BLOCKED - REROUTING")
	return false,"bypass_limit"
end


function Mapper:mapNetwork(radius,maxCells)
	if not self.navigator then
		error("TUNNEL MAPPER NAVIGATOR NOT INITIALIZED",0)
	end
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
	local trafficHits = {}
	local noFrontierConfirmations = 0
	local stopReason = nil
	local currentTask = m:addCheckTask({"mapTunnelNetwork"})

	print("SHARED TUNNEL NETWORK MAPPER")
	print("radius:",radius,"max new cells:",maxCells)
	print("NO BLOCKS WILL BE MINED")

	-- LABENHANCED_MAPPER_FAST_TRAVEL
	-- Known road nodes are trusted. Mapping only surveys genuinely new/frontier
	-- territory; already-explored corridors are traversal-only.
	local currentNode = nav:requestNode(m.pos)
	if not currentNode then
		self:surveyCurrent(nil)
		mapped = mapped + 1
	end

	while mapped < maxCells do
		-- addCheckTask makes STOP/cancellation work during a long mapping job.
		local pulse = m:addCheckTask({"mapTunnelNetworkStep"})
		m.taskList:remove(pulse)

		local frontier,reason,stats
		for requestTry=1,8 do
			frontier,reason,stats = nav:requestNearestFrontier(startPos,radius)
			if frontier or reason == "no_frontier"
			or reason == "all_frontiers_claimed" then break end

			if reason == "unknown_start" then
				-- Controller may not have received our newest node yet. Only
				-- survey if it is still genuinely unknown.
				local n = nav:requestNode(m.pos)
				if not n then self:surveyCurrent(nil) end
			else
				print("MAPPER LINK RETRY",requestTry,reason or "no response")
				sleep(0.5)
			end
		end

		if not frontier then
			if reason == "all_frontiers_claimed" then
				-- LABENHANCED_MULTI_MAPPER_CLAIMS
				-- Other turtles currently own the reachable frontier work.
				-- Stay alive: their scans may expose new branches for us.
				print("WAITING FOR AN UNCLAIMED FRONTIER")
				sleep(1)
			elseif reason == "no_frontier" then
				-- Another mapper can briefly consume a frontier before it has
				-- surveyed the next cell and published the next frontier.
				-- Require a stable no-work result before declaring completion.
				if stats and stats.claimedFrontiers and stats.claimedFrontiers > 0 then
					noFrontierConfirmations = 0
					print("WAITING FOR OTHER MAPPERS TO EXPOSE NEW FRONTIERS")
					sleep(1)
				else
					noFrontierConfirmations = noFrontierConfirmations + 1
					if noFrontierConfirmations < 4 then
						print("CONFIRMING MAP COMPLETE",noFrontierConfirmations.."/4")
						sleep(1)
					else
						stopReason = "all reachable frontiers mapped"
						print("NO UNMAPPED TUNNEL FRONTIERS REMAIN IN RANGE")
						break
					end
				end
			else
				stopReason = "controller link unavailable: "..tostring(reason or "unknown")
				print("MAPPER PAUSED:",stopReason)
				break
			end
		end

		if not frontier then
			-- Claimed-work/no-work confirmation path: retry the outer loop.
			sleep(0)
		else
		noFrontierConfirmations = 0

		local pathReady = true
		if frontier.path and #frontier.path > 0 then
			if #frontier.path >= 8 then
				print("FAST TRAVEL",#frontier.path,"known road cells")
			end
			for i=1,#frontier.path do
				local p = frontier.path[i]
				local target = vector.new(p.x,p.y,p.z)
				local from = vector.new(m.pos.x,m.pos.y,m.pos.z)
				local pathDir = TunnelMap.directionBetween(from,target)
				local ok,moveReason,blockName = nav:moveAdjacent(target)

				if not ok and moveReason == "traffic" and pathDir then
					ok,moveReason,blockName =
						self:handleTraffic(frontier,target,pathDir,trafficHits)
					if not ok and moveReason == "traffic_reroute" then
						pathReady = false
						failedFrontiers = 0
						break
					end
				end

				if not ok and moveReason == "decoration" and pathDir then
					ok = self:bypassDecoration({dir=pathDir},blockName)
					if ok then
						-- The upper bypass can land several cells beyond this
						-- stale route step. Ask the controller for a fresh route
						-- on the next outer iteration instead of following the
						-- remainder of the old path.
						pathReady = false
						failedFrontiers = 0
						break
					end
				end

				if not ok then
					pathReady = false
					failedFrontiers = failedFrontiers + 1
					if failedFrontiers % 8 == 0 then
						print("route changed/blocked",failedFrontiers,
							"times - continuing to reroute")
					end
					break
				end

				-- Known road: travel only. No inspect/turn/resurvey here.
				-- This is the Google-Maps-like fast-travel behavior.
				if i % 24 == 0 then
					nav:renewFrontier(frontier)
					sleep(0)
				end
			end

			if pathReady then
				failedFrontiers = 0
			else
				sleep(0)
			end
		end

		if pathReady
		and m.pos.x == frontier.source.x
		and m.pos.y == frontier.source.y
		and m.pos.z == frontier.source.z then
			nav:renewFrontier(frontier)
			local target = vector.new(frontier.target.x,frontier.target.y,frontier.target.z)
			local ok,moveReason,blockName = nav:moveAdjacent(target)

			if not ok and moveReason == "traffic" then
				local dir = TunnelMap.directionBetween(
					vector.new(m.pos.x,m.pos.y,m.pos.z),target
				)
				if dir then
					ok,moveReason,blockName =
						self:handleTraffic(frontier,target,dir,trafficHits)
				end
			end

			-- A lower-cell torch is decoration, not the end of a tunnel. Preserve
			-- it and take the upper half of the existing 2-high tunnel around it.
			if not ok and moveReason == "decoration" then
				ok = self:bypassDecoration(frontier,blockName)
			end

			if ok then
				mapped = mapped + 1
				-- Successful movement queued the OPEN road edges. Flush them,
				-- then survey the newly reached frontier/new road node only.
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
				-- A traffic reroute already released this frontier, so the next
				-- outer iteration will choose another accessible branch.
				if moveReason ~= "traffic_reroute" then
					failedFrontiers = failedFrontiers + 1
				else
					failedFrontiers = 0
				end
			end
		end

		end -- frontier exists
		sleep(0)
	end

	if mapped >= maxCells then
		stopReason = "maximum new-cell limit reached"
		print("MAPPER CELL LIMIT REACHED:",maxCells)
	end

	m:flushTunnelUpdatesSync()

	print("MAPPING STOP REASON:",stopReason or "mapping loop completed")
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
