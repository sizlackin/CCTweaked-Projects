-- Non-destructive core self-test for LabEnhanced shared tunnel navigation.
-- Run on the MAIN controller after enable-tunnel-navigation + reboot.
-- Does not contact or move turtles.

local TunnelMap = require("classTunnelMap")
local S = TunnelMap.STATE

local passed,failed = 0,0
local function check(name,ok,detail)
	if ok then
		passed = passed + 1
		print("PASS",name)
	else
		failed = failed + 1
		print("FAIL",name,detail or "")
	end
end

local function p(x,y,z) return {x=x,y=y,z=z} end
local function edge(map,a,dir,state,seen,extra)
	extra = extra or {}
	map:applyUpdates({{
		pos=a,dir=dir,state=state,seen=seen or os.epoch("utc"),
		until=extra.until,resume=extra.resume,
	}})
end

local map = TunnelMap:new({fileName="runtime/tunnelMap-selftest.txt",saveInterval=0})
local t = os.epoch("utc")

-- Main road: A-B-C, alternate road B-D-E-C.
local A,B,C = p(0,0,0),p(1,0,0),p(2,0,0)
local D,E = p(1,0,1),p(2,0,1)
edge(map,A,"east",S.OPEN,t+1)
edge(map,B,"east",S.OPEN,t+2)
edge(map,B,"south",S.OPEN,t+3)
edge(map,D,"east",S.OPEN,t+4)
edge(map,E,"north",S.OPEN,t+5)

local route = map:findPath(A,C)
check("A* direct route",route and #route == 2)

-- Permanent blockage forces B-D-E-C.
edge(map,B,"east",S.BLOCKED,t+10)
route = map:findPath(A,C)
check("reroute around permanent block",
	route and #route == 4
	and route[2].x == D.x and route[2].z == D.z)

-- A stale OPEN report may not overwrite the newer block.
edge(map,B,"east",S.OPEN,t+9)
check("stale map update rejected",
	map:getConnectionState(B,"east") == S.BLOCKED)

-- Temporary obstacle removes the road for now, then expires back to OPEN.
edge(map,B,"south",S.TEMPORARILY_BLOCKED,t+20,{
	until=os.epoch("utc")-1,resume=S.OPEN,
})
check("temporary block expires",
	map:getConnectionState(B,"south") == S.OPEN)

-- Frontier discovery uses already-known roads to reach the nearest unknown branch.
edge(map,E,"south",S.UNMAPPED,t+30)
local frontier = map:findNearestFrontier(A,{radius=50,maxNodes=100})
check("nearest unmapped frontier",frontier and frontier.source.x == E.x
	and frontier.source.z == E.z and frontier.dir == "south")

-- Full 3D edge support.
local V = p(2,1,1)
edge(map,E,"up",S.OPEN,t+40)
route = map:findPath(A,V)
check("3D vertical route",route and route[#route].y == 1)

-- Persistence.
if fs.exists("runtime/tunnelMap-selftest.txt") then
	fs.delete("runtime/tunnelMap-selftest.txt")
end
local saved = map:save()
local loaded = TunnelMap:new({fileName="runtime/tunnelMap-selftest.txt"})
local didLoad = loaded:load()
route = loaded:findPath(A,V)
check("persistent graph save/load",saved and didLoad and route ~= nil)
if fs.exists("runtime/tunnelMap-selftest.txt") then
	fs.delete("runtime/tunnelMap-selftest.txt")
end

local stats = map:getStats()
check("graph statistics",stats.nodes >= 6 and stats.revision > 0)

print("")
print("Tunnel navigation self-test:",passed,"passed,",failed,"failed")
if failed > 0 then
	error("Tunnel navigation core self-test failed.",0)
end
print("CORE GRAPH TESTS PASSED")
print("Live turtle movement/rerouting still needs an in-world test.")
