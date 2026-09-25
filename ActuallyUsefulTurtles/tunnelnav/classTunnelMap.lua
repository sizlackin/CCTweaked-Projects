-- LabEnhanced shared tunnel road graph.
-- Controller is authoritative. Nodes represent positions a turtle has actually
-- traversed/surveyed; edges represent valid road connections, not arbitrary air.

local TunnelMap = {}
TunnelMap.__index = TunnelMap

TunnelMap.STATE = {
	OPEN = "open",
	BLOCKED = "blocked",
	TEMPORARILY_BLOCKED = "temporarily_blocked",
	UNMAPPED = "unmapped",
}

TunnelMap.DIRS = {
	north = {x=0,y=0,z=-1, opposite="south"},
	south = {x=0,y=0,z=1, opposite="north"},
	west  = {x=-1,y=0,z=0, opposite="east"},
	east  = {x=1,y=0,z=0, opposite="west"},
	up    = {x=0,y=1,z=0, opposite="down"},
	down  = {x=0,y=-1,z=0, opposite="up"},
}

local dirOrder = {"north","south","west","east","up","down"}
local now = function() return os.epoch("utc") end

local function manhattan(a,b)
	return math.abs(a.x-b.x)+math.abs(a.y-b.y)+math.abs(a.z-b.z)
end

local function copyPos(p)
	return {x=p.x,y=p.y,z=p.z}
end

function TunnelMap.key(x,y,z)
	if type(x) == "table" then
		return tostring(x.x)..","..tostring(x.y)..","..tostring(x.z)
	end
	return tostring(x)..","..tostring(y)..","..tostring(z)
end

function TunnelMap.parseKey(key)
	local x,y,z = string.match(key, "^(-?%d+),(-?%d+),(-?%d+)$")
	if not x then return nil end
	return {x=tonumber(x),y=tonumber(y),z=tonumber(z)}
end

function TunnelMap.target(pos, dir)
	local d = TunnelMap.DIRS[dir]
	if not d then return nil end
	return {x=pos.x+d.x,y=pos.y+d.y,z=pos.z+d.z}
end

function TunnelMap.directionBetween(a,b)
	local dx,dy,dz = b.x-a.x,b.y-a.y,b.z-a.z
	if dx == 1 and dy == 0 and dz == 0 then return "east" end
	if dx == -1 and dy == 0 and dz == 0 then return "west" end
	if dx == 0 and dy == 0 and dz == 1 then return "south" end
	if dx == 0 and dy == 0 and dz == -1 then return "north" end
	if dx == 0 and dy == 1 and dz == 0 then return "up" end
	if dx == 0 and dy == -1 and dz == 0 then return "down" end
	return nil
end

function TunnelMap:new(opts)
	opts = opts or {}
	local o = {
		nodes = {},
		frontiers = {},
		claims = {}, -- LABENHANCED_MULTI_MAPPER_CLAIMS
		claimsByOwner = {},
		routeIntents = {}, -- LABENHANCED_SMART_FRONTIER_SCORING
		revision = 0,
		dirty = false,
		lastSave = 0,
		saveInterval = opts.saveInterval or 5000,
		fileName = opts.fileName or "runtime/tunnelMap.txt",
	}
	setmetatable(o,self)
	return o
end

function TunnelMap:ensureNode(pos, seen)
	local key = TunnelMap.key(pos)
	local node = self.nodes[key]
	if not node then
		node = {
			x=pos.x,y=pos.y,z=pos.z,
			connections={},
			firstSeen=seen or now(),
			lastSeen=seen or now(),
		}
		self.nodes[key] = node
		self.dirty = true
	else
		node.lastSeen = math.max(node.lastSeen or 0, seen or 0)
	end
	return node
end

function TunnelMap:getNode(pos)
	return self.nodes[TunnelMap.key(pos)]
end

function TunnelMap:getNodeByKey(key)
	return self.nodes[key]
end

function TunnelMap:_frontierKey(pos,dir)
	return TunnelMap.key(pos).."|"..dir
end

function TunnelMap:cleanupExpiredIntents()
	local t = now()
	for owner,intent in pairs(self.routeIntents or {}) do
		if not intent.expires or intent.expires <= t then
			self.routeIntents[owner] = nil
		end
	end
end

function TunnelMap:setRouteIntent(owner,path,goal,ttlMs,kind)
	if owner == nil then return false end
	self:cleanupExpiredIntents()
	local keys = {}
	for _,p in ipairs(path or {}) do
		keys[TunnelMap.key(p)] = true
	end
	if goal then keys[TunnelMap.key(goal)] = true end
	self.routeIntents[owner] = {
		pathKeys=keys,
		goal=goal and copyPos(goal) or nil,
		expires=now() + (ttlMs or 120000),
		kind=kind or "route",
	}
	return true
end

function TunnelMap:clearRouteIntent(owner)
	if owner == nil then return false end
	self.routeIntents[owner] = nil
	return true
end

function TunnelMap:_intentNodePenalty(pos,claimant)
	self:cleanupExpiredIntents()
	local key = TunnelMap.key(pos)
	local penalty = 0
	for owner,intent in pairs(self.routeIntents) do
		if owner ~= claimant and intent.pathKeys and intent.pathKeys[key] then
			penalty = penalty + 2.5
		end
	end
	return penalty
end

function TunnelMap:_nodeTrafficPenalty(pos)
	local node = self:getNode(pos)
	if not node then return 0 end
	local penalty = 0
	for _,dir in ipairs(dirOrder) do
		local conn = self:getConnection(node,dir)
		if conn and conn.state == TunnelMap.STATE.TEMPORARILY_BLOCKED then
			if conn.blockedReason == "turtle_traffic" then
				penalty = penalty + 4
			else
				penalty = penalty + 1
			end
		end
	end
	return math.min(penalty,8)
end

function TunnelMap:_frontierPotential(node)
	local count = 0
	for _,dir in ipairs(dirOrder) do
		local conn = self:getConnection(node,dir)
		if conn and conn.state == TunnelMap.STATE.UNMAPPED then
			count = count + 1
		end
	end
	return count
end

function TunnelMap:_workSeparationPenalty(pos,claimant)
	self:cleanupExpiredClaims()
	self:cleanupExpiredIntents()
	local nearest = nil
	local seenOwners = {}

	for owner,intent in pairs(self.routeIntents) do
		if owner ~= claimant and intent.goal then
			seenOwners[owner] = true
			local d = manhattan(pos,intent.goal)
			if not nearest or d < nearest then nearest = d end
		end
	end

	-- Compatibility fallback for claims created before route-intent support.
	for fk,claim in pairs(self.claims) do
		if claim.owner ~= claimant and not seenOwners[claim.owner] then
			local f = self.frontiers[fk]
			if f then
				local target = {x=f.tx,y=f.ty,z=f.tz}
				local d = manhattan(pos,target)
				if not nearest or d < nearest then nearest = d end
			end
		end
	end

	if not nearest then return 0,nil end
	if nearest <= 8 then
		return 18 + (8-nearest)*1.5,nearest
	elseif nearest <= 16 then
		return 4 + (16-nearest)*1.25,nearest
	elseif nearest <= 32 then
		return (32-nearest)*0.25,nearest
	end
	return 0,nearest
end

function TunnelMap:_releaseClaimKey(fk)
	local claim = self.claims[fk]
	if not claim then return false end
	if self.claimsByOwner[claim.owner] == fk then
		self.claimsByOwner[claim.owner] = nil
	end
	self:clearRouteIntent(claim.owner)
	self.claims[fk] = nil
	return true
end

function TunnelMap:cleanupExpiredClaims()
	local t = now()
	for fk,claim in pairs(self.claims) do
		if not claim.expires or claim.expires <= t then
			self:_releaseClaimKey(fk)
		end
	end
end

function TunnelMap:claimFrontier(pos,dir,owner,ttlMs)
	if owner == nil then return true,nil end
	self:cleanupExpiredClaims()
	local fk = self:_frontierKey(pos,dir)
	if not self.frontiers[fk] then return false,"not_frontier" end

	local existing = self.claims[fk]
	if existing and existing.owner ~= owner then
		return false,"claimed"
	end

	-- One active frontier per turtle. Claiming a new one releases the old one.
	local oldKey = self.claimsByOwner[owner]
	if oldKey and oldKey ~= fk then
		self:_releaseClaimKey(oldKey)
	end

	local expires = now() + (ttlMs or 120000)
	self.claims[fk] = {owner=owner,expires=expires}
	self.claimsByOwner[owner] = fk
	return true,expires
end

function TunnelMap:renewFrontierClaim(pos,dir,owner,ttlMs)
	if owner == nil then return false,"no_owner" end
	self:cleanupExpiredClaims()
	local fk = self:_frontierKey(pos,dir)
	local claim = self.claims[fk]
	if not claim or claim.owner ~= owner then return false,"not_owner" end
	claim.expires = now() + (ttlMs or 120000)
	local intent = self.routeIntents and self.routeIntents[owner]
	if intent then intent.expires = claim.expires end
	return true,claim.expires
end

function TunnelMap:releaseFrontierClaim(pos,dir,owner)
	local fk = self:_frontierKey(pos,dir)
	local claim = self.claims[fk]
	if not claim then return true end
	if owner ~= nil and claim.owner ~= owner then return false end
	self:_releaseClaimKey(fk)
	return true
end

function TunnelMap:_setFrontier(pos,dir,enabled,seen)
	local fk = self:_frontierKey(pos,dir)
	if enabled then
		local target = TunnelMap.target(pos,dir)
		self.frontiers[fk] = {
			x=pos.x,y=pos.y,z=pos.z,
			dir=dir,
			tx=target.x,ty=target.y,tz=target.z,
			seen=seen or now(),
		}
	else
		self.frontiers[fk] = nil
		self:_releaseClaimKey(fk)
	end
end

function TunnelMap:getConnection(nodeOrPos,dir)
	local node = nodeOrPos.connections and nodeOrPos or self:getNode(nodeOrPos)
	if not node then return nil end
	local conn = node.connections[dir]
	if conn and conn.state == TunnelMap.STATE.TEMPORARILY_BLOCKED
	and conn.blockedUntil and conn.blockedUntil <= now() then
		conn.state = conn.resume or TunnelMap.STATE.OPEN
		conn.blockedUntil = nil
		conn.resume = nil
		self.dirty = true
	end
	return conn
end

function TunnelMap:getConnectionState(nodeOrPos,dir)
	local c = self:getConnection(nodeOrPos,dir)
	return c and c.state or nil
end

function TunnelMap:_applyOne(pos,dir,state,seen,blockedUntil,resume,blockedReason)
	local d = TunnelMap.DIRS[dir]
	if not d then return false end
	seen = seen or now()
	local node = self:ensureNode(pos,seen)
	local old = node.connections[dir]

	-- Ignore stale updates.
	if old and old.seen and seen < old.seen then return false end

	local target = TunnelMap.target(pos,dir)
	if state == TunnelMap.STATE.UNMAPPED and self:getNode(target) then
		-- If the adjacent coordinate is already a verified road node and the
		-- current turtle sees the way clear, this is a known open connection.
		state = TunnelMap.STATE.OPEN
	end

	local changed = not old
		or old.state ~= state
		or old.blockedUntil ~= blockedUntil
		or old.resume ~= resume
		or old.blockedReason ~= blockedReason

	node.connections[dir] = {
		state=state,
		seen=seen,
		blockedUntil=blockedUntil,
		resume=resume,
		blockedReason=blockedReason, -- LABENHANCED_TORCH_REROUTE
	}
	node.lastSeen = math.max(node.lastSeen or 0,seen)

	self:_setFrontier(pos,dir,state == TunnelMap.STATE.UNMAPPED,seen)

	if state == TunnelMap.STATE.OPEN then
		local other = self:ensureNode(target,seen)
		local opp = d.opposite
		local otherOld = other.connections[opp]
		if not otherOld or not otherOld.seen or seen >= otherOld.seen then
			other.connections[opp] = {state=TunnelMap.STATE.OPEN,seen=seen}
			self:_setFrontier(target,opp,false,seen)
			changed = true
		end
	elseif state == TunnelMap.STATE.TEMPORARILY_BLOCKED then
		local other = self:getNode(target)
		if other then
			local opp = d.opposite
			local otherOld = other.connections[opp]
			if not otherOld or not otherOld.seen or seen >= otherOld.seen then
				other.connections[opp] = {
					state=TunnelMap.STATE.TEMPORARILY_BLOCKED,
					seen=seen,blockedUntil=blockedUntil,resume=resume or TunnelMap.STATE.OPEN,
					blockedReason=blockedReason
				}
				changed = true
			end
		end
	elseif state == TunnelMap.STATE.BLOCKED then
		local other = self:getNode(target)
		if other then
			local opp = d.opposite
			local otherOld = other.connections[opp]
			if otherOld and (not otherOld.seen or seen >= otherOld.seen) then
				other.connections[opp] = {
					state=TunnelMap.STATE.BLOCKED,seen=seen,blockedReason=blockedReason
				}
				self:_setFrontier(target,opp,false,seen)
				changed = true
			end
		end
	end

	if changed then
		self.revision = self.revision + 1
		self.dirty = true
	end
	return changed
end

function TunnelMap:applyUpdates(updates)
	local changed = 0
	if type(updates) ~= "table" then return changed end
	for _,u in ipairs(updates) do
		local p = u.pos or u.position or u.from
		if p and u.dir and u.state then
			if self:_applyOne(p,u.dir,u.state,u.seen,u.blockedUntil,u.resume,u.blockedReason) then
				changed = changed + 1
			end
		end
	end
	return changed
end

function TunnelMap:makeUpdate(pos,dir,state,opts)
	opts = opts or {}
	return {
		pos=copyPos(pos),
		dir=dir,
		state=state,
		seen=opts.seen or now(),
		blockedUntil=opts.blockedUntil,
		resume=opts.resume,
		blockedReason=opts.blockedReason,
	}
end

function TunnelMap:getOpenNeighbors(pos)
	local node = self:getNode(pos)
	if not node then return {} end
	local out = {}
	for _,dir in ipairs(dirOrder) do
		local conn = self:getConnection(node,dir)
		if conn and conn.state == TunnelMap.STATE.OPEN then
			local target = TunnelMap.target(node,dir)
			if self:getNode(target) then
				out[#out+1] = {pos=target,dir=dir}
			end
		end
	end
	return out
end

local function heapPush(heap,item)
	local i = #heap + 1
	heap[i] = item
	while i > 1 do
		local p = math.floor(i/2)
		if heap[p].score <= item.score then break end
		heap[i] = heap[p]
		i = p
	end
	heap[i] = item
end

local function heapPop(heap)
	if #heap == 0 then return nil end
	local root = heap[1]
	local last = table.remove(heap)
	if #heap > 0 then
		local i = 1
		while true do
			local l,r = i*2,i*2+1
			if l > #heap then break end
			local c = l
			if r <= #heap and heap[r].score < heap[l].score then c = r end
			if heap[c].score >= last.score then break end
			heap[i] = heap[c]
			i = c
		end
		heap[i] = last
	end
	return root
end

local function reconstruct(came,positions,startKey,endKey)
	local reverse = {}
	local key = endKey
	while key and key ~= startKey do
		reverse[#reverse+1] = positions[key] or TunnelMap.parseKey(key)
		key = came[key]
	end
	local path = {}
	for i=#reverse,1,-1 do path[#path+1] = reverse[i] end
	return path
end

function TunnelMap:findPath(startPos,goalPos,maxNodes,opts)
	opts = opts or {}
	maxNodes = maxNodes or 30000
	local startKey = TunnelMap.key(startPos)
	local goalKey = TunnelMap.key(goalPos)
	if startKey == goalKey then return {} end
	if not self.nodes[startKey] then return nil,"unknown_start" end
	if not self.nodes[goalKey] then return nil,"unknown_goal" end

	local open = {}
	local came,g,positions,closed = {},{[startKey]=0},{[startKey]=copyPos(startPos)},{}
	heapPush(open,{key=startKey,score=manhattan(startPos,goalPos)})
	local expanded = 0

	while #open > 0 and expanded < maxNodes do
		local cur = heapPop(open)
		if cur and not closed[cur.key] then
			if cur.key == goalKey then
				return reconstruct(came,positions,startKey,goalKey),nil,expanded
			end
			closed[cur.key] = true
			expanded = expanded + 1
			local pos = positions[cur.key] or TunnelMap.parseKey(cur.key)
			for _,n in ipairs(self:getOpenNeighbors(pos)) do
				local nk = TunnelMap.key(n.pos)
				if not closed[nk] then
					local tentative = (g[cur.key] or math.huge) + 1
						+ self:_intentNodePenalty(n.pos,opts.claimant)
						+ self:_nodeTrafficPenalty(n.pos)
					if not g[nk] or tentative < g[nk] then
						g[nk] = tentative
						came[nk] = cur.key
						positions[nk] = n.pos
						heapPush(open,{key=nk,score=tentative+manhattan(n.pos,goalPos)})
					end
				end
			end
		end
	end
	return nil,"no_route",expanded
end

local function withinRadius(pos,origin,radius)
	if not origin or not radius then return true end
	local dx,dy,dz = pos.x-origin.x,pos.y-origin.y,pos.z-origin.z
	return dx*dx+dy*dy+dz*dz <= radius*radius
end

function TunnelMap:findNearestFrontier(startPos,opts)
	opts = opts or {}
	self:cleanupExpiredClaims()
	self:cleanupExpiredIntents()
	local startKey = TunnelMap.key(startPos)
	if not self.nodes[startKey] then return nil,"unknown_start" end

	-- LABENHANCED_SMART_FRONTIER_SCORING
	-- Search the reachable road graph with weighted cost rather than taking the
	-- first frontier encountered. Other turtles' intended routes, active traffic,
	-- nearby assigned work, branch potential and branch-rescue discoveries all
	-- influence which frontier is selected.
	local open = {}
	local came = {}
	local positions = {[startKey]=copyPos(startPos)}
	local cost = {[startKey]=0}
	local steps = {[startKey]=0}
	local closed = {}
	heapPush(open,{key=startKey,score=0})

	local expanded = 0
	local maxNodes = opts.maxNodes or 30000
	local claimant = opts.claimant
	local claimTtl = opts.claimTtl or 120000
	local sawClaimedFrontier = false
	local best = nil

	while #open > 0 and expanded < maxNodes do
		local cur = heapPop(open)
		if cur and not closed[cur.key] then
			closed[cur.key] = true
			expanded = expanded + 1
			local pos = positions[cur.key] or TunnelMap.parseKey(cur.key)
			local node = self.nodes[cur.key]
			local baseCost = cost[cur.key] or math.huge

			if withinRadius(pos,opts.origin,opts.radius) then
				for _,dir in ipairs(dirOrder) do
					local conn = self:getConnection(node,dir)
					if conn and conn.state == TunnelMap.STATE.UNMAPPED then
						local target = TunnelMap.target(pos,dir)
						if withinRadius(target,opts.origin,opts.radius) then
							local fk = self:_frontierKey(pos,dir)
							local claim = self.claims[fk]
							if not claim or claim.owner == claimant then
								local potential = self:_frontierPotential(node)
								local spreadPenalty,nearestWork =
									self:_workSeparationPenalty(pos,claimant)
								local branchBonus = math.min(math.max(potential-1,0)*3,9)
								local rescueBonus =
									(conn.blockedReason == "branch_rescue") and 5 or 0
								local frontierData = self.frontiers[fk]
								local ageBonus = 0
								if frontierData and frontierData.seen then
									ageBonus = math.min(
										math.max(now()-frontierData.seen,0)/30000,
										4
									)
								end

								local score = baseCost + spreadPenalty
									- branchBonus - rescueBonus - ageBonus

								if not best or score < best.score
								or (score == best.score
									and (steps[cur.key] or math.huge) < best.distance) then
									best = {
										source=copyPos(pos),
										target=target,
										dir=dir,
										endKey=cur.key,
										score=score,
										distance=steps[cur.key] or 0,
										branchPotential=potential,
										nearestOtherWork=nearestWork,
										routeCost=baseCost,
										spreadPenalty=spreadPenalty,
										branchBonus=branchBonus,
										rescueBonus=rescueBonus,
										ageBonus=ageBonus,
									}
								end
							else
								sawClaimedFrontier = true
							end
						end
					end
				end
			end

			for _,n in ipairs(self:getOpenNeighbors(pos)) do
				local nk = TunnelMap.key(n.pos)
				if not closed[nk] and withinRadius(n.pos,opts.origin,opts.radius) then
					local nextCost = baseCost + 1
						+ self:_intentNodePenalty(n.pos,claimant)
						+ self:_nodeTrafficPenalty(n.pos)
					if not cost[nk] or nextCost < cost[nk] then
						cost[nk] = nextCost
						steps[nk] = (steps[cur.key] or 0) + 1
						came[nk] = cur.key
						positions[nk] = n.pos
						heapPush(open,{key=nk,score=nextCost})
					end
				end
			end

			if expanded % 500 == 0 then sleep(0) end
		end
	end

	if best then
		local ok,expires = self:claimFrontier(
			best.source,best.dir,claimant,claimTtl
		)
		if ok then
			local path = reconstruct(came,positions,startKey,best.endKey)
			best.endKey = nil
			best.path = path
			best.claimExpires = expires
			self:setRouteIntent(claimant,path,best.target,claimTtl,"mapping")
			return best,nil,expanded
		end
	end

	if sawClaimedFrontier then
		return nil,"all_frontiers_claimed",expanded
	end
	return nil,"no_frontier",expanded
end

function TunnelMap:getStats()
	self:cleanupExpiredClaims()
	local nodeCount,edgeCount,frontierCount,tempCount,claimCount = 0,0,0,0,0
	for _,node in pairs(self.nodes) do
		nodeCount = nodeCount + 1
		for _,dir in ipairs(dirOrder) do
			local c = self:getConnection(node,dir)
			if c then
				if c.state == TunnelMap.STATE.OPEN then edgeCount = edgeCount + 1 end
				if c.state == TunnelMap.STATE.TEMPORARILY_BLOCKED then tempCount = tempCount + 1 end
			end
		end
	end
	for _ in pairs(self.frontiers) do frontierCount = frontierCount + 1 end
	for _ in pairs(self.claims) do claimCount = claimCount + 1 end
	self:cleanupExpiredIntents()
	local intentCount = 0
	for _ in pairs(self.routeIntents) do intentCount = intentCount + 1 end
	return {
		nodes=nodeCount,
		openEdges=math.floor(edgeCount/2),
		frontiers=frontierCount,
		temporaryBlocks=math.floor(tempCount/2),
		claimedFrontiers=claimCount,
		activeRouteIntents=intentCount,
		revision=self.revision,
	}
end

function TunnelMap:save(fileName)
	fileName = fileName or self.fileName
	local f = fs.open(fileName,"w")
	if not f then return false end
	f.write(textutils.serialize({
		version=1,
		revision=self.revision,
		nodes=self.nodes,
	}, {allow_repetitions=true}))
	f.close()
	self.dirty = false
	self.lastSave = now()
	return true
end

function TunnelMap:load(fileName)
	fileName = fileName or self.fileName
	local f = fs.open(fileName,"r")
	if not f then return false end
	local data = textutils.unserialize(f.readAll())
	f.close()
	if type(data) ~= "table" then return false end
	self.nodes = data.nodes or {}
	self.revision = data.revision or 0
	self.frontiers = {}
	self.claims = {}
	self.claimsByOwner = {}
	self.routeIntents = {}
	for _,node in pairs(self.nodes) do
		for dir,conn in pairs(node.connections or {}) do
			if conn and conn.state == TunnelMap.STATE.UNMAPPED then
				self:_setFrontier(node,dir,true,conn.seen)
			end
		end
	end
	self.dirty = false
	self.lastSave = now()
	return true
end

function TunnelMap:maybeSave(force)
	if not self.dirty then return false end
	if force or now()-self.lastSave >= self.saveInterval then
		return self:save()
	end
	return false
end

return TunnelMap
