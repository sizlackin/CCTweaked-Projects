
--require("classNetworkNode")
local utils = require("utils") -- this also sets global sleep


require("classBluenetNode")
local Monitor = require("classMonitor")
local HostDisplay = require("classHostDisplay")
--require("classMap")
local ChunkyMap = require("classChunkyMap")
-- LABENHANCED_TUNNEL_NAV_BOOTSAFE: load TunnelMap later with pcall so a
-- tunnel-nav module problem can never prevent the base controller from booting.
local TaskGroup = require("classTaskGroup")
local RemoteStorage = require("classRemoteStorage")
local TaskManager = require("classTaskManager")


local function initNode()
	global.node = NetworkNode:new("miner",true)
end
local function initStream()
	global.nodeStream = NetworkNode:new("miner_stream",true)
end
local function initUpdate()
	global.nodeUpdate = NetworkNode:new("update",true)
end
local function initStorage()
	global.storage = RemoteStorage:new()
end

local function initPosition()
	local x,y,z = gps.locate()
	if x and y and z then
		x, y, z = math.floor(x), math.floor(y), math.floor(z)
		global.pos = vector.new(x,y,z)
	else
		print("gps not working")
		global.pos = vector.new(0,70,0) -- this is bad for turtles especially
	end
	print("position:",global.pos.x,global.pos.y,global.pos.z)
end

local function loadGroups(fileName)
	if not fileName then fileName = "runtime/taskGroups.txt" end
	local f = fs.open(fileName,"r")
	local groups = nil
	if f then
		groups = textutils.unserialize( f.readAll() )
		f.close()
	else
		-- no problem if this file does not exist yet
		-- print("FILE DOES NOT EXIST", fileName)
	end
	if groups then 
		for _,group in pairs(groups) do
			local taskGroup = TaskGroup:new(global.turtles,nil,group)
			global.taskGroups[taskGroup.id] = taskGroup
		end
	else
		global.taskGroups = {}
	end
end


local function initTaskManager()
	loadGroups()
	global.taskManager = TaskManager:new(global.node, global.turtles, global.taskGroups)
end


-- quick boot
parallel.waitForAll(initNode,initStream,initUpdate)

-- Storage used to be initialized near the end. Keep it available before any
-- optional subsystem is loaded, so host/main.lua and host/receive.lua can never
-- crash on global.storage if a later feature fails to initialize.
initStorage()

initPosition()
global.map = ChunkyMap:new(false)
global.map:setMaxChunks(2048) --256 for operational use
global.map:setLifeTime(-1)
global.map:load()

-- Tunnel navigation is an enhancement, not a boot dependency.
global.tunnelMap = nil
local tunnelOk,TunnelMap = pcall(require,"classTunnelMap")
if tunnelOk and TunnelMap then
	local createOk,tunnelOrErr = pcall(function()
		local tm = TunnelMap:new({
			fileName = "runtime/tunnelMap.txt",
			saveInterval = 5000,
		})
		tm:load()
		return tm
	end)
	if createOk then
		global.tunnelMap = tunnelOrErr
		print("tunnel navigation graph ready")
	else
		print("TUNNEL NAV DISABLED:",tostring(tunnelOrErr))
	end
else
	print("TUNNEL NAV DISABLED:",tostring(TunnelMap))
end

global.loadTurtles()
global.loadStations()

initTaskManager()
global.loadAlerts()

if not pocket then -- pocket uses shellDisplay
	global.monitor = Monitor:new()
	global.display = HostDisplay:new(1,1,global.monitor:getWidth(),global.monitor:getHeight())
end


