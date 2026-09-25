local PathFinder = require("classPathFinder")
local CheckPointer = require("classCheckPointer")
--require("classMap")
require("classLogger")
require("classList")
local ChunkyMap = require("classChunkyMap")
local TaskQueue = require("classTaskQueue")
local bluenet = require("bluenet")
local MinerTaskAssignment = require("classMinerTaskAssignment")
local TunnelMap = require("classTunnelMap") -- LABENHANCED_TUNNEL_NAV
local TunnelNavigator = require("classTunnelNavigator")
local TunnelMapper = require("classTunnelMapper")
local config = config

-- local blockTranslation = require("blockTranslation")
-- local nameToId = blockTranslation.nameToId
-- local idToName = blockTranslation.idToName

local default = {
	waitTimeFallingBlock = 0.25,
	maxVeinRadius = 10, --8 MAX:16
	maxVeinSize = 256,
	inventorySize = 16,
	criticalFuelLevel = 512,
	goodFuelLevel = 4099,
	--maxHomeDistance = 128, -- unused
	file = "runtime/miner.txt",
	fuelAmount = 16,
	turtleName = "computercraft:turtle_advanced",
	pathfinding = {
		maxTries = 15,
		maxParts = 2,
		maxDistance = 10,
	}
}

local fuelItems = {
["minecraft:coal"]=80,
["minecraft:charcoal"]=80,
["minecraft:coal_block"]=800,
["minecraft:lava_bucket"]=1000,
}

-- LabEnhanced clean-mining patch:
-- temporary ore-vein cavities are sealed with cobbled deepslate only.
local veinBackfillItem = "minecraft:cobbled_deepslate"
local philoliteBlockName = "create_unbreakable:philolite_block"
-- do not translate

-- blocks that can explicitly be mined, without making the world look destroyed
-- otherwise turtle might decide to navigate through decorative blocks of the base
-- though this could lead to pathfinding issues if the target pos is a leaf block
local mineBlocks = {
["minecraft:cobblestone"]=true,
["minecraft:stone"]=true,
["minecraft:grass_block"]=true,
["minecraft:dirt"]=true,
["minecraft:gravel"]=true,
["minecraft:sand"]=true,
["minecraft:flint"]=true,
["minecraft:sandstone"]=true,
["minecraft:diorite"]=true,
["minecraft:granite"]=true,
["minecraft:andesite"]=true,
["minecraft:tuff"]=true,
["minecraft:deepslate"]=true,
["minecraft:cobbled_deepslate"]=true,
["minercraft:calcite"]=true,
-- own array with fluids / allowedBlocks
["minecraft:water"]=true,
["minecraft:lava"]=true,
["minecraft:glass"]=true,
}
--mineBlocks = blockTranslation.translateTable(mineBlocks)


local inventoryBlocks = {
["minecraft:chest"]=true,
["minecraft:trapped_chest"]=true,
["minecraft:ender_chest"]=true, -- ?? 
["minecraft:shulker_box"]=true,
["minecraft:white_shulker_box"]=true,
["minecraft:orange_shulker_box"]=true,
["minecraft:magenta_shulker_box"]=true,
["minecraft:light_blue_shulker_box"]=true,
["minecraft:yellow_shulker_box"]=true,
["minecraft:lime_shulker_box"]=true,
["minecraft:pink_shulker_box"]=true,
["minecraft:gray_shulker_box"]=true,
["minecraft:light_gray_shulker_box"]=true,
["minecraft:cyan_shulker_box"]=true,
["minecraft:purple_shulker_box"]=true,
["minecraft:blue_shulker_box"]=true,
["minecraft:brown_shulker_box"]=true,
["minecraft:green_shulker_box"]=true,
["minecraft:red_shulker_box"]=true,
["minecraft:black_shulker_box"]=true,
["minecraft:hopper"]=true,
["minecraft:barrel"]=true,
}
--inventoryBlocks = blockTranslation.translateTable(inventoryBlocks)

-- LabEnhanced compatibility: Sophisticated Storage chests.
-- Accept any current/future Sophisticated Storage block whose registry id ends in "_chest"
-- (and the base "chest" id), without having to hard-code every tier/material.
local function isSophisticatedStorageChest(id)
    return type(id) == "string"
        and string.match(id, "^sophisticatedstorage:.*chest$") ~= nil
end

local function isInventoryBlock(id)
    return inventoryBlocks[id] == true or isSophisticatedStorageChest(id)
end

local function isTurtleBlockId(id)
	-- LABENHANCED_MINING_ROUTE_BRIDGE
	return id == "computercraft:turtle_advanced"
		or id == "computercraft:turtle_normal"
		or id == "computercraft:turtle"
end

-- LABENHANCED_AUTO_TORCHES
-- One stack maximum per miner. Vanilla torches emit block light 14; with the
-- torch one block sideways and one block above the turtle floor, placing every
-- 11 forward blocks keeps the floor at block-light >= 1. The next block would
-- otherwise be spawnable (block light 0 in modern vanilla).
local tunnelTorchItem = "minecraft:torch"
local tunnelTorchMax = 64
local tunnelTorchSpacing = 11

local disallowedBlocks = {
["minecraft:chest"] = true,
["minecraft:hopper"]=true,
["computercraft:turtle_advanced"] = true,
["computercraft:computer_advanced"] = true,
["computercraft:wireless_modem_advanced"] = true,
["computercraft:monitor_advanced"] = true,
["minecraft:bedrock"]=true,
--["minecraft:glass"]=true,
["minecraft:white_wool"]=true,
}
--disallowedBlocks = blockTranslation.translateTable(disallowedBlocks)
-- local blocks = {
-- iron = { iron_ore = { id = "minecraft:iron_ore", doMine = true, level = 99 },
	-- { deepslate_iron_ore = { id = "minecraft:deepslate_iron_ore", doMine = true, level = 99 } }
-- coal = { coal
-- }

local oreBlocks = {
["create_unbreakable:philolite_block"]=true,
["minecraft:iron_ore"]=true,
["minecraft:deepslate_iron_ore"]=true,
["minecraft:coal_ore"]=true,
["minecraft:deepslate_coal_ore"]=true,
["minecraft:gold_ore"]=true,
["minecraft:deepslate_gold_ore"]=true,
["minecraft:diamond_ore"]=true,
["minecraft:deepslate_diamond_ore"]=true,
["minecraft:redstone_ore"]=true,
["minecraft:deepslate_redstone_ore"]=true,
["minecraft:lapis_ore"]=true,
["minecraft:deepslate_lapis_ore"]=true,
["minecraft:copper_ore"]=true,
["minecraft:deepslate_copper_ore"]=true,
["minecraft:emerald_ore"]=true,
["minecraft:deepslate_emerald_ore"]=true,

-- Nether ores
["minecraft:nether_gold_ore"]=true,
["minecraft:nether_quartz_ore"]=true,
["minecraft:ancient_debris"]=true,

-- Raw ore blocks (storage blocks of raw materials)
["minecraft:raw_iron_block"]=true,
["minecraft:raw_copper_block"]=true,
["minecraft:raw_gold_block"]=true,

-- Amethyst (geodes)
["minecraft:amethyst_block"]=true, 
-- ["minecraft:budding_amethyst"]=true, does not drop
["minecraft:amethyst_cluster"]=true,
["minecraft:large_amethyst_bud"]=true,
["minecraft:medium_amethyst_bud"]=true,
["minecraft:small_amethyst_bud"]=true,

}
--oreBlocks = blockTranslation.translateTable(oreBlocks)
local turtle = turtle
local vector = vector
local debuginfo = debug.getinfo
local tablepack = table.pack
local tableunpack = table.unpack
local osEpoch = os.epoch

local vectors = {
	[0] = vector.new(0,0,1),  -- 	+z = 0	south
	[1] = vector.new(-1,0,0), -- 	-x = 1	west
	[2] = vector.new(0,0,-1), -- 	-z = 2	north
	[3] = vector.new(1,0,0),  -- 	+x = 3 	east
}

local vectorUp = vector.new(0,1,0)
local vectorDown = vector.new(0,-1,0)

local Miner = {}
Miner.__index = Miner

-- variables for extensions to access
Miner.default = default
Miner.fuelItems = fuelItems
Miner.vectors = vectors
Miner.vectorUp = vectorUp
Miner.vectorDown = vectorDown
Miner.mineBlocks = mineBlocks

function Miner:new()
	local o = o or {} --Worker:new()
	setmetatable(o,self)

	print("----INITIALIZING----")
	print("LabEnhanced miner: shared tunnel-navigation v8")
	assert(turtle,"this device is not a turtle")
	
	o.fuelLimit = turtle.getFuelLimit()
	if o.fuelLimit == "unlimited" then o.fuelLimit = 0 end
	
	o.home = nil
	o.startupPos = nil
	o.homeOrientation = 0
	o.orientation = 0
	o.node = global.node
	o.nodeRefuel = global.nodeRefuel
	o.pos = vector.new(0,70,0)
	o.gettingFuel = false
	o.initializing = true
	o.lookingAt = vector.new(0,0,0)
	o.map = ChunkyMap:new(true)
	o.taskList = List:new()
	o.queue = TaskQueue:new(o)
	o.vectors = vectors
	o.checkPointer = CheckPointer:new()
	o.statusCount = 0
	o.veinTrace = nil
	o.veinExcavated = nil
	o.veinRecording = false
	o.activeTunnelAnchor = nil
	o.activeTunnelOrientation = nil
	o.philoliteRepairCells = nil
	o.philoliteRepairPending = false
	o.activeMiningBounds = nil

	-- Controller-authoritative tunnel-road navigation.
	o.tunnelPendingUpdates = {}
	o.tunnelPendingIndex = {}
	o.tunnelNavigator = TunnelNavigator:new(o)
	o.tunnelMapper = TunnelMapper:new(o, o.tunnelNavigator) -- LABENHANCED_MAPPER_NAV_FIX
	
	o:initialize() -- initialize after starting parallel tasks in startup.lua
	--print("--------------------")
	return o
end


function Miner:initialize()
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	
	-- preset chunk request but try not to during initialization
	self.map.requestChunk = function(chunkId) return self:requestChunk(chunkId) end
	self.map:setCheckFunction(self.checkOreBlock)
	
	self:initPosition()
	self:refuel(true) -- simple refuel
	print("fuel level:", turtle.getFuelLevel())

	self:initOrientation()

	if not self:requestStation() then
		self:loadStation() -- TODO
		self:setHome(self.pos.x, self.pos.y, self.pos.z)
	end
	self:setStartupPos(self.pos)

	self.initializing = nil
	self.taskList:remove(currentTask)

	self:restoreState()
end	

function Miner:restoreState()
	-- split initialization into two parts why tho, because we didnt want to wait for returnhome etc
	-- but this is not needed anymore if we add everything to the queue which is then executed afterwards
	
	self.queue:load()
	local existsCheckpoint = self.checkPointer:existsCheckpoint()

	if not existsCheckpoint then

		-- do we also return home first if the queue is not empty?

		self.queue:addDirectTask("DO", "refuel", nil, 1)
		self.queue:addDirectTask("DO", "returnHome", nil, 2)
		
	else
		if self.checkPointer:load(self) then
				
			if not self.checkPointer:restoreTaskAssignment(self) then
				print("CHECKPOINT TASK ASSIGNMENT NOT RESTORED, USING PSEUDO")

				local task = MinerTaskAssignment:pseudo()
				task:setCheckpoint(self.checkPointer.checkpoint)
				self.queue:addTask(task, 1)

				--[[ alternatively: 
					local func = function()
						local ok, err = pcall( function() self.checkPointer:executeTasks(self) end )
						if not ok then
							self:error("CHECKPOINT TASKS NOT EXECUTED")
						end
					end
					self.queue:addArbitraryTask(func, 1)
				--]]
			else
				print("CHECKPOINT RESTORED")
			end
		end
	end
	
end

function Miner:initPosition()
	local x,y,z = gps.locate()
	if x and y and z then
		self.pos = vector.new(x,y,z)
	else
		--gps not working
		self:error("GPS UNAVAILABLE")
		-- self.pos = vector.new(0,70,0)
	end
	print("position:",self.pos.x,self.pos.y,self.pos.z)
end

function Miner:initOrientation()
	local newPos
	local turns = 0
	for i=1,4 do
		if not turtle.forward() then
			self:turnLeft()
			turns = turns + 1
		else
			newPos = vector.new(gps.locate())
			break
		end
	end
	if not newPos then
		-- retry with breaking
		print("breaking blocks")
		for i=1,4 do
			local hasBlock, data = turtle.inspect()
			if not Miner.checkDisallowed(data.name) then -- or checkSafe(data.name)
				turtle.dig()
				sleep(default.waitTimeFallingBlock)
			end
			if not turtle.forward() then
				self:turnLeft()
				turns = turns + 1
			else
				newPos = vector.new(gps.locate())
				break
			end
		end
	end
	if not newPos then
		self:sendAlert()
		self:error("ORIENTATION NOT DETERMINABLE")
		self.orientation = 0
	else
		-- print(newPos, self.pos, turns, self.orientation)
		local diff = newPos - self.pos
		self.pos = newPos
		if diff.x < 0 then self.orientation = 1
		elseif diff.x > 0 then self.orientation = 3
		elseif diff.z < 0 then self.orientation = 2
		else self.orientation = 0
		end
		self:updateLookingAt()

		-- go back without requesting a chunk --self:back()
		if turtle.back() then 
			self.pos = self.pos - self.vectors[self.orientation]
		self:recordTunnelTraversal(tunnelFrom,self.pos)
		end
		
		self:turnTo((self.orientation+turns)%4)
		self.homeOrientation = self.orientation
	end
	print("orientation:", self.orientation)
end

function Miner:save(fileName)
	-- this already includes the map!
	if not fileName then fileName = default.file end
	local f = fs.open(fileName,"w")
	f.write(textutils.serialize(self))
	f.close()
end
function Miner:load(fileName)
	if not fileName then fileName = default.file end
	local f = fs.open(fileName,"r")
	if f then
		self = textutils.unserialize( f.readAll() )
		f.close()
	else
		print("FILE DOES NOT EXIST")
	end
end

function Miner:setStartupPos(pos)
	self.startupPos = vector.new(pos.x,pos.y,pos.z)
end
function Miner:setHome(x,y,z)
	self.home = vector.new(x,y,z)
	print("home:", self.home.x, self.home.y, self.home.z)
end

function Miner:requestMap()
	-- ask host for the map
	local retval = false
	if self.node and self.node.host then
		local answer, forMsg = self.node:send(global.node.host,
		{"REQUEST_MAP"},true,true,10)
		if answer then
			if answer.data[1] == "MAP" then
				retval = true
				self.map:setMap(answer.data[2])
				-- not just the map but all map information, including the log etc.
			end
		end
	end
	return retval  
end

function Miner:requestChunk(chunkId)
	-- ask host for a chunk
	-- perhaps use own protocol for this?
	local start = osEpoch("local")
	if self.node and self.node.host then
		local answer, forMsg = self.node:send(self.node.host,
			{"REQUEST_CHUNK", chunkId},true,true,1,"chunk")
		if answer then
			if answer.data[1] == "CHUNK" then
				print(osEpoch("local")-start,"RECEIVED CHUNK", chunkId)
				return answer.data[2]
			else
				print("received other", answer.data[1])
			end
		end
		--print("no answer")
	end
	print(osEpoch("local")-start, "CHUNK REQUEST FAILED", chunkId)
	return nil
end

function Miner:requestStation()
	-- ask host for station
	local retval = false
	if global.node and global.node.host then
		local answer, forMsg = self.node:send(global.node.host,{"REQUEST_STATION"},true,true,10)
		if answer then
			if answer.data[1] == "STATION" then
				retval = true
				local station = answer.data[2]
				self:setStation(station)
			elseif answer.data[1] == "STATIONS_FULL" then
				self:setStation(nil)
			end
			--print("station", textutils.serialize(answer.data[2]))
		else
			print("no station answer")
		end
	else
		print("no station host or node", global.node, global.node.host)
	end
	
	return retval
end
function Miner:setStation(station)
	if station then
		self:setHome(station.pos.x,station.pos.y,station.pos.z)
		if station.orientation then
			self.homeOrientation = station.orientation
		end
		
		--if self.taskList.count == 0 -- no task
		--	or self.taskList.count == 1 then -- or initializing
		--	self:returnHome()
		--end
	else
		-- TODO: try remember station, lmao
		-- settings set get etc.?
		print("NO STATION AVAILABLE")
	end
end

function Miner:sendAlert()
	-- nofity host to be recovered at pos
	-- alternatively broadcast distress signal to all turtles and wait for recovery
	local result = false

	self.stuck = true
	print("help me stepbro, im stuck D:")

	local state = {}
	state.id = os.getComputerID()
	state.label = os.getComputerLabel() or id
	state.time = osEpoch("utc")
		
	state.pos = self.pos
	state.orientation = self.orientation
	
	state.fuelLevel = self:getFuelLevel()
	state.emptySlots = self:getEmptySlots()
	
	if self.taskList.first then
		state.task = self.taskList.first[1]
		state.lastTask = self.taskList.last[1]
	end

	-- why not just use default state communication?
	-- -> its an important event that needs according handling

	local start = osEpoch("local")
	if self.node and self.node.host then
		local answer, forMsg = self.node:send(self.node.host,
			{"ALERT", state },true,true,5)
		if answer then
			if answer.data[1] == "ALERT_RECEIVED" then
				print(osEpoch("local")-start,"ALERT RECEIVED")
				result = true
			else
				print("received other", answer.data[1])
			end
		end
		--print("no answer")
	end
	
	if not result then 
		print(osEpoch("local")-start, "ALERT FAILED")
		-- TODO: broadcast to turtles directly if host is not available
		-- alternatively continuously resend alert until confirmed

	end
	return result
end

function Miner:getCostHome()
	local result = 0
	if self.home then
		local diff = self.pos - self.home
		result = math.abs(diff.x) + math.abs(diff.y) + math.abs(diff.z)	
	end
	return result
end

function Miner:getDistanceToPos(x,y,z)
	local diff = self.pos - vector.new(x,y,z)
	local result = math.abs(diff.x) + math.abs(diff.y) + math.abs(diff.z)
	return result
end

function Miner:returnHome()
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	local result = false
	self.returningHome = true
	if self.home then
		print("RETURNING HOME", self.home.x, self.home.y, self.home.z)
		result = self:navigateOpenPathToPos(self.home.x, self.home.y, self.home.z)
		self:turnTo(self.homeOrientation)
	end
	self.returningHome = false
	self.taskList:remove(currentTask)
	return result
end


--- TASK QUEUE AND ASSIGNMENT STUFF
function Miner:setTaskAssignment(taskAssignment)
	self.currentTaskAssignment = taskAssignment
	if taskAssignment then 
		taskAssignment:setGlobals(self, self.node)
	end
	self:clearProgress()
end
function Miner:getTaskAssignment()
	return self.currentTaskAssignment
end 
function Miner:getAssignmentState()
	if self.currentTaskAssignment then
		return self.currentTaskAssignment:toState()
	end
	return nil
end
function Miner:cancelTaskAssignment(taskId, msg)
	if not taskId then return false end
	local taskAssignment = self.currentTaskAssignment
	if taskAssignment and taskAssignment.id == taskId then
		self.currentTaskAssignment = nil
	end

	local qt = self.queue:remove(taskId)
	if qt then taskAssignment = qt end

	if taskAssignment and taskAssignment.id == taskId then
		return taskAssignment:onCancel(msg)
	end
	return false
end

function Miner:error(reason, fake)
	-- TODO: create image of current Miner to load later on
	-- self:save()

	if self.taskList.count > 0 then func = "ERR:"..self.taskList.first[1]
	else func = "ERR:unknown" end
	
	local checkpoint = self.checkPointer:getLastSavedCheckpoint()
	self.taskList:clear()
	if fake then
		-- delete Checkpoint file / save after clearing taskList
		self.checkPointer:save(self)
	end
	error({fake=fake,text=reason,func=func,checkpoint=checkpoint}) -- watch out that this is not caught by some other function
end 

function Miner:addCheckTask(task, isCheckpointable, ...)
	-- called by most functions to interrupt execution
	-- if task[1] is nil, could be due to return self:function()

	if self.stop then
		self.stop = false
		self:error("stopped",true)
	end

	if isCheckpointable and self.taskList.first
		and ( task[1] == "?" or self.taskList.first[1] == task[1] ) then
		-- task already currently in list (probably loaded by checkpointer)
		return self.taskList.first
	else
		return self.taskList:addFirst(task)
	end
end

function Miner:checkStatus()
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	-- called by self:forward()
	self:refuel()
	self:cleanInventory()
	self.statusCount = self.statusCount + 1
	if self.statusCount > 40 then
		self:checkMinedTurtle()
		self.statusCount = 0
	end
	
	self.taskList:remove(currentTask)
end




function Miner:getFuelLevel()
	return turtle.getFuelLevel()
end

function Miner:hasFullInventory(minOpen)
	minOpen = minOpen or 0
	if self:getEmptySlots() <= minOpen then
		return true
	end
	return false
end

function Miner:getEmptySlots()
	local empty = 0
	for slot = 1,default.inventorySize do
		if turtle.getItemCount(slot) == 0 then
			empty = empty + 1
		end
	end
	return empty
end


function Miner:findInventoryItem(name)
	-- check for item in inventory
	local found = nil
	for slot = 1,default.inventorySize do
		local data = turtle.getItemDetail(slot)
		if data and data.name == name then
			found = slot
			break
		end
	end
	return found
end

function Miner:checkMinedTurtle()
	-- in very rare cases, a turtle might have ran in front of another turtle during stripmining without safety checks
	-- check inventory for turtles and place them back down 
	local slot = self:findInventoryItem(default.turtleName)
	if slot then
		print("OH NO, I MINED A TURTLE :(")
		self:select(slot)
		-- try and place it
		local direction
		if turtle.placeUp() then direction = "top"
		elseif turtle.placeDown() then direction = "bottom"
		elseif turtle.place() then direction = "front"
		else
			print("could not place turtle")
			return false
		end
		
		if direction then 
			sleep(1) 
			-- give it half the fuel
			for slot = 1, default.inventorySize do
				local data = turtle.getItemDetail(slot)
				if data and fuelItems[data.name] then
					-- could be unreliable if turtle has more than one stack but doesnt really matter
					self:select(slot)
					local amount = data.count/2 
					if direction == "top" then turtle.dropUp(amount)
					elseif direction == "bottom" then turtle.dropDown(amount)
					elseif direction == "front" then turtle.drop(amount) end
					print("giving turtle", amount, "fuel")
					break 
				end
			end
			sleep(1) 
			print("placed", direction, "now turning on")
			local tut = peripheral.wrap(direction)
			if tut then 
				print("turning on turtle", tut.getID())
				tut.turnOn()
				sleep(5) -- give it some time to fuck off before continuing with whatever
				return true
			else 
				self:error("FAILED TO RESTART TURTLE")
				return false
			end
		end
	end
	return true
end


function Miner:cleanInventory()
	-- check for full inventory and take action
	-- if turtles are still being mined and not placed back down, increase to at least 1 open slot at all times
	if not self.cleaningInventory and self:getEmptySlots() == 0 then 
		self:condenseInventory()
		if self:getEmptySlots() < 2 then
			self:dumpBadItems()
			if self:getEmptySlots() < 2 then
				self:offloadItemsAtHome()
			end
		end
	end
end

function Miner:offloadItemsAtHome()
	-- return home, empty inventory, return to task
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	self.cleaningInventory = true
	
	local startPos = vector.new(self.pos.x, self.pos.y, self.pos.z)
	local startOrientation = self.orientation

	if self:returnHome() then
		self:dumpBadItems(true) -- DELELTE; DROP ALL ITEMS: ONLY FOR TESTING SO I DONT HAVE TO CLEAR THE CHESTS
		self:transferItems()
		if self:getEmptySlots() < 2 then
			-- catch this in stripmine e.g.
			self.cleaningInventory = false
			self:error("INVENTORY_FULL")
		else
			-- do nothing and return to task
			self:navigateOpenPathToPos(startPos.x, startPos.y, startPos.z)
			self:turnTo(startOrientation)
		end
	end

	self.cleaningInventory = false
	self.taskList:remove(currentTask)
end

function Miner:transferItems()
	--check for chest and transfer items
	--do not transfer all fuel items (keep 1 stack)
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	local hasFuel = false
	local hasTunnelMaterial = false
	local keptTorches = 0 -- LABENHANCED_AUTO_TORCHES: never keep more than 64
	local hasInventory = false
	local startOrientation = self.orientation
	
	for k=1,4 do
	--check for chest
		self:inspect(true)
		local block = self:getMapValue(self.lookingAt.x, self.lookingAt.y, self.lookingAt.z)
		if block and isInventoryBlock(block) then
			hasInventory = true
			break
		end
		self:turnRight()
	end
	if not hasInventory then 
		print("no inventory found")
		--assert(hasInventory, "no inventory found")
	else
		local startSlot = turtle.getSelectedSlot()
		for i = 0,default.inventorySize-1 do
			local slot = (i+startSlot-1)%default.inventorySize +1
			local data = turtle.getItemDetail(slot)
			if data and data.name then
				if not hasFuel and fuelItems[data.name] then
					hasFuel = true --keep the fuel
				elseif data.name == tunnelTorchItem then
					local keep = math.min(data.count,math.max(tunnelTorchMax-keptTorches,0))
					keptTorches = keptTorches + keep
					if keep < data.count then
						self:select(slot)
						local excess = data.count - keep
						local ok = turtle.drop(excess)
						if ok ~= true then
							print(ok,"inventory in front is full")
							break
						end
					end
				elseif data.name == veinBackfillItem and (self.veinTrace or not hasTunnelMaterial) then
					-- Always keep one stack for tunnel/lava maintenance. During a
					-- vein excursion keep all cobbled deepslate until cleanup is done.
					hasTunnelMaterial = true
				else
					--transfer items
					self:select(slot)
					local ok = turtle.drop(data.count)
					if ok ~= true then
						print(ok,"inventory in front is full")
						break
					end
				end
			end
		end
	end
	self:turnTo(startOrientation)
	self.taskList:remove(currentTask)
end

function Miner:dumpBadItems(dropAll)
	--check for bad items and drop them
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	local startSlot = turtle.getSelectedSlot()
	local hasTunnelMaterial = false
	for i = 0,default.inventorySize-1 do
		local slot = (i+startSlot-1)%default.inventorySize +1
		local data = turtle.getItemDetail(slot)
		if data and data.name ~= tunnelTorchItem
		and (mineBlocks[data.name] or ( dropAll and not fuelItems[data.name])) then
			if data.name == veinBackfillItem and (self.veinTrace or not hasTunnelMaterial) then
				-- Always reserve one stack for tunnel maintenance. Preserve all
				-- cobbled deepslate while closing an active vein excursion.
				hasTunnelMaterial = true
			else
				--drop items
				self:select(slot)
				local ok = turtle.drop(data.count)
				if ok ~= true then
					print(ok,"inventory in front is full")
				end
			end
		end
	end	
	self.taskList:remove(currentTask)
end

function Miner:condenseInventory()
	--stack items
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	local startSlot = turtle.getSelectedSlot()
	for i = 0,default.inventorySize-1 do
		local slot = (i+startSlot-1)%default.inventorySize +1
		local data = turtle.getItemDetail(slot)
		if data and data.name then
			for targetSlot=1,default.inventorySize do
				--search matching items starting at the first slot
				if targetSlot ~= slot then
					local targetData = turtle.getItemDetail(targetSlot)
					if targetData and targetData.name == data.name then
						local fromSlot = slot
						local toSlot = targetSlot
						if targetSlot > slot then
							fromSlot = targetSlot
							toSlot = slot
						end
						--deal with multiple stacks
						if turtle.getItemSpace(toSlot) > 0 then
							self:select(fromSlot)
							turtle.transferTo(toSlot)
							if turtle.getItemCount(fromSlot) == 0 then
								break
							end
						end
					end
				end
			end
		end
	end
	self.taskList:remove(currentTask)
end

function Miner:getSelectedItemName()
	local slot = turtle.getSelectedSlot()
	local data = turtle.getItemDetail(slot)
	return data and data.name
end

function Miner:select(slot)
	if slot > default.inventorySize then
		slot = (slot-1)%default.inventorySize+1
	end

	if turtle.getSelectedSlot() ~= slot then
		return turtle.select(slot)
	end
	return true
end

function Miner:refuel(simple)
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})

	local refueled = false
	local goodLevel = false
	
	if not self.gettingFuel and self.fuelLimit > 0 and turtle.getFuelLevel() <= default.criticalFuelLevel then
		print("refueling...")
		for slot = 1, default.inventorySize do
			data = turtle.getItemDetail(slot)
			if data and fuelItems[data.name] then
				self:select(slot)
				repeat
					local ok, err = turtle.refuel(1)
					goodLevel = ( turtle.getFuelLevel() >= default.goodFuelLevel )
				until goodLevel or not ok
				if goodLevel then break end
			end
		end
		if turtle.getFuelLevel() > default.criticalFuelLevel then
			-- and turtle.getFuelLevel() > 2 * self:getCostHome() then
			refueled = true
		elseif turtle.getFuelLevel() == 0 then
			-- ran out of fuel
			self:sendAlert()
			self:error("NEED FUEL, STUCK")
		else
			if not simple then -- for initializing
			--if self:getCostHome() * 2 > turtle.getFuelLevel() then
				local startPos = vector.new(self.pos.x, self.pos.y, self.pos.z)
				local startOrientation = self.orientation
				if not self:getFuel() then
					if not self:returnHome() and turtle.getFuelLevel() == 0 then
						-- could not refuel, ran out on the way back home
						self:sendAlert()
						self:error("NEED FUEL, STUCK")
					else
						self:error("NEED FUEL") -- -> terminates stripMine etc.
					end
				else
					refueled = true
					if not self.returningHome then
						self:navigateOpenPathToPos(startPos.x, startPos.y, startPos.z)
						self:turnTo(startOrientation)
					end
					-- actual refueling happens with the next refuel call
				end
			--end
			end
		end
		print("fuel level:", turtle.getFuelLevel())
	else
		refueled = true
	end
	self.taskList:remove(currentTask)
	return refueled
end







function Miner:clearStaleLocks()
	-- clear old locks on stations to avoid waiting for noone
    local currentTime = osEpoch("utc")
    for id, station in pairs(config.stations.refuel) do
        if station.occupied and (currentTime - (station.lastClaimed or 0)) > 10000 then -- 10 seconds
            -- print("Clearing stale lock on station:", id)
            station.occupied = false
        end
    end
end

function Miner:requestRefuelStation()

	self.refuelClaim = {
		approvedByOwner = false,
		ok = false,
		occupiedStation = nil,
		waiting = false,
		lastClaimed = 0,
		priority = 0,
	}
	local refuelClaim = self.refuelClaim

	-- clear occupied stations
	for id,station in pairs(config.stations.refuel) do
		station.occupied = false
	end

	-- get all the occupied stations
	bluenet.openChannel(bluenet.modem, bluenet.default.channels.refuel)
	self.nodeRefuel:send(bluenet.default.channels.refuel, {"REQUEST_STATION"}, false, false) 
	sleep(1) -- handle responses in onReceive and onRequestAnswer in miner/receive.lua
	-- config should now be updated with occupied stations

	refuelClaim.waiting = true
	-- try to claim a station or wait for one
	local startTime = osEpoch("utc")
	repeat
		local ok = self:tryClaimStation()
		if not ok then 
			sleep(0.5 + math.random()) -- random offset so not every turtle requests at the same time
			self:clearStaleLocks()
		end
	until refuelClaim.ok or ( osEpoch("utc") - startTime )  > 500000 -- 200 seconds for big boy refuels

	refuelClaim.waiting = false

	if refuelClaim.ok and refuelClaim.occupiedStation then
		-- claim successfull
	else 
		-- print(refuelClaim.ok, "claim station", refuelClaim.occupiedStation, "failed")
		refuelClaim.occupiedStation = nil
	end

	return refuelClaim.occupiedStation
end


function Miner:tryClaimStation()
	local refuelClaim = self.refuelClaim
	local result = false
	for id,station in pairs(config.stations.refuel) do
		if not station.occupied or station.occupied == false then
			refuelClaim.occupiedStation = id -- reserve it to deny other claim requests
			refuelClaim.lastClaimed = osEpoch("utc")
			-- print("claiming station", id)
			refuelClaim.ok = true
			self.nodeRefuel:send(bluenet.default.channels.refuel, {"CLAIM_STATION", id}, false, false)
			sleep(1) -- wait for denying answers

			if refuelClaim.ok or refuelClaim.approvedByOwner then 
				print("claimed station", id, "owner approved:", refuelClaim.approvedByOwner)
				refuelClaim.ok = true
				result = true
				break
			else
				refuelClaim.occupiedStation = nil
				refuelClaim.lastClaimed = 0
				--print("claim station failed", id)
			end
		end
	end
	return result
end

function Miner:releaseStation()
	if self.refuelClaim and self.refuelClaim.occupiedStation then
		--print("releasing station", self.refuelClaim, self.refuelClaim.occupiedStation)
		self.refuelClaim.isReleasing = true
		self.nodeRefuel:send(bluenet.default.channels.refuel, 
				{"RELEASE_STATION", self.refuelClaim.occupiedStation}, false, false)
		-- wait a bit (~1s) to solve claim conflicts using owner acks
		self:back()
		self:back()
		self:back()
		-- self:back()
		-- self:back()
		-- self:back()
		--sleep(1)
		
		self.refuelClaim = {occupiedStation = nil}
		--print(osEpoch("utc")/1000, "released station")
	end
	-- close channel to stop listening
	bluenet.closeChannel(bluenet.modem, bluenet.default.channels.refuel)
	
end

function Miner:getRefuelStation(random)
	local id 
	-- print("not random", not random, self.nodeRefuel)
	if not random and self.nodeRefuel then
		id = self:requestRefuelStation()
	end
	if id then 
		return id
	else
		-- fallback, use random station 
		local ct = 0
		for _,v in pairs(config.stations.refuel) do ct = ct + 1 end
		local index = math.random(1, ct)
		ct = 0
		for id, station in pairs(config.stations.refuel) do
			ct = ct + 1
			if ct == index then 
				print("using random station", id)
				return id
			end
		end
	end
end


function Miner:getFuel()

	-- default method:
	-- 1. move near to refuel stations based on config
	-- 2. ask turtles if stations are occupied 
	-- 3. claim station
	--    if occupied, wait for station
	-- 3. move to station and refuel
	-- 4. report station as free and leave

	-- no station available:
	-- wait in queue for station, but this would also require messaging etc...
	-- not nice
	-- could use home-stations as queue that is always available

	-- no host available:
	-- use config or ask other turtles if they are refueling

	-- TODO: advanced method:
	-- add support turtles that represent a temporary refuel station
	-- they act like a passive provider chest
	-- this way turtles dont have to return all the way home for big tasks
	-- different types of turtles
	-- general turtle with all the default methods like navigation etc.
	-- types: support(refuel, collect items), miner, "forester"

	-- TODO: change from config to internal variable?
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	
	self.gettingFuel = true
	local previousVeinRecording = self.veinRecording
	self.veinRecording = false
	local result = false
	
	local ok, err = pcall( function() 

		-- move near the refuel stations

		local isInQueue = false
		
		if config.stations.refuelQueue and config.stations.refuelQueue.origin then 
			local tries = 0
			local origin = config.stations.refuelQueue.origin
			local maxDistance = config.stations.refuelQueue.maxDistance or 8
			repeat 
				tries = tries + 1
				local randomPosition = vector.new(
					math.random(origin.x-maxDistance, origin.x+maxDistance),
					origin.y,
					math.random(origin.z-maxDistance, origin.z+maxDistance)
				)
				print("moving to queue", randomPosition)
				isInQueue = self:navigateOpenPathToPos(randomPosition.x, randomPosition.y, randomPosition.z)
				if not isInQueue and tries > 3 then
					print("cant reach refuel queue")
					isInQueue = true -- set to true anyways, should be nearby the queue
					-- return false-- only leave pcall function !
					break
				end
			until isInQueue
		end

		local useRandomStation = not isInQueue
		-- print("using random station", useRandomStation)
		local id = self:getRefuelStation(useRandomStation)
		local station = config.stations.refuel[id]

		-- actually refuel
		if not self:navigateOpenPathToPos(station.pos.x, station.pos.y, station.pos.z) then
			--print("unable to reach station")
			return false
		end

		if station.orientation then 
			self:turnTo(station.orientation) 
		end
		
		local hasInventory = false
		
		for k=1,4 do
		--check for chest
			self:inspect(true) -- true for wrong map entries or new stations
			local block = self:getMapValue(self.lookingAt.x, self.lookingAt.y, self.lookingAt.z)
			if block and isInventoryBlock(block) then
				hasInventory = true
				break
			end
			self:turnRight()
		end
		if not hasInventory then 
			print("no inventory found")
			--assert(hasInventory, "no inventory found")
		else
			result = turtle.suck(default.fuelAmount)
		end
	
	end )

	-- !! cancellation while getting fuel can result in no more refueling
	if not ok then
		self.gettingFuel = false
		bluenet.closeChannel(bluenet.modem, bluenet.default.channels.refuel)
		error(err,0) -- pass error
	end
	
	if not result then
		print("unable to refuel", result)
		result = false
	end

	-- done refueling
	self:releaseStation()

	self.gettingFuel = false -- to allow actual refueling
	self.veinRecording = previousVeinRecording

	if self:getEmptySlots() < 10 then -- 8
		-- already at home, also offload items
		self:offloadItemsAtHome() 
	end

	
	
	self.taskList:remove(currentTask)
	return result
end




-- LABENHANCED_TUNNEL_NAV
-- Compact edge updates are queued locally and piggyback on the existing state
-- stream. Strict navigation can flush them synchronously before requesting a
-- fresh controller route.
function Miner:queueTunnelUpdate(pos,dir,state,opts)
	if not pos or not dir or not state then return false end
	opts = opts or {}
	local key = TunnelMap.key(pos).."|"..dir
	local update = {
		pos={x=pos.x,y=pos.y,z=pos.z},
		dir=dir,
		state=state,
		seen=opts.seen or os.epoch("utc"),
		blockedUntil=opts.blockedUntil,
		resume=opts.resume,
		blockedReason=opts.blockedReason, -- LABENHANCED_TORCH_REROUTE
	}
	local index = self.tunnelPendingIndex[key]
	if index then
		self.tunnelPendingUpdates[index] = update
	else
		self.tunnelPendingUpdates[#self.tunnelPendingUpdates+1] = update
		self.tunnelPendingIndex[key] = #self.tunnelPendingUpdates
	end
	return true
end

function Miner:drainTunnelUpdates(maxCount)
	maxCount = maxCount or #self.tunnelPendingUpdates
	local count = math.min(maxCount,#self.tunnelPendingUpdates)
	if count <= 0 then return {} end

	local out = {}
	for i=1,count do out[i] = self.tunnelPendingUpdates[i] end

	local remaining = {}
	local index = {}
	for i=count+1,#self.tunnelPendingUpdates do
		local u = self.tunnelPendingUpdates[i]
		remaining[#remaining+1] = u
		index[TunnelMap.key(u.pos).."|"..u.dir] = #remaining
	end
	self.tunnelPendingUpdates = remaining
	self.tunnelPendingIndex = index
	return out
end

function Miner:requeueTunnelUpdates(updates)
	if not updates then return end
	for _,u in ipairs(updates) do
		self:queueTunnelUpdate(u.pos,u.dir,u.state,u)
	end
end

function Miner:flushTunnelUpdatesSync()
	if not self.tunnelNavigator then return false end
	while #self.tunnelPendingUpdates > 0 do
		local batch = self:drainTunnelUpdates(128)
		local ok = self.tunnelNavigator:sendUpdates(batch)
		if not ok then
			self:requeueTunnelUpdates(batch)
			return false
		end
	end
	return true
end

function Miner:recordTunnelTraversal(fromPos,toPos)
	if not fromPos or not toPos then return end
	-- LABENHANCED_NO_ROUTE_RESCAN
	-- A controller-issued tunnel route is already authoritative. Traversing it
	-- should not re-report every known OPEN edge as though it were being mapped
	-- again. Newly dug/bootstrap/yield movement still records normally.
	if self.traversingKnownTunnelRoute then return end
	local dir = TunnelMap.directionBetween(fromPos,toPos)
	if dir then
		self:queueTunnelUpdate(fromPos,dir,TunnelMap.STATE.OPEN)
		-- Batch normal task/mining travel so the controller learns new road
		-- segments without a modem message or disk write for every single move.
		if #self.tunnelPendingUpdates >= 24 then
			self:flushTunnelUpdatesSync()
		end
	end
end


function Miner:setMapValue(x,y,z,value)
	--self.map:logData(x,y,z,value)
	self.map:setData(x,y,z,value,true)
end

function Miner:getMapValue(x,y,z)
	return self.map:getData(x,y,z)
end	

function Miner:turnTo(orient)
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	if orient then 
		orient = orient%4
		while self.orientation ~= orient do
		
			local diff = self.orientation - orient
			if ( diff > 0 and math.abs(diff) < 3 ) or ( self.orientation == 0 and orient == 3 ) then
				self:turnLeft()
			else
				self:turnRight()
			end
		end
	end
	self.taskList:remove(currentTask)
end

function Miner:turnInspect(orient, safe)
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	-- turn to orientation and inspect while spinning, could probably be one function
	if orient then 
		orient = orient%4
		while self.orientation ~= orient do
		
			local diff = self.orientation - orient
			if ( diff > 0 and math.abs(diff) < 3 ) or ( self.orientation == 0 and orient == 3 ) then
				self:turnLeft()
			else
				self:turnRight()
			end
			self:inspect(safe)
		end
	end
	self.taskList:remove(currentTask)
end

function Miner:getTargetOrientation(x, y, z)
	-- should be and adjacent position to current pos
	local cx, cy, cz = self.pos.x, self.pos.y, self.pos.z
	local dx = x -cx
	local dy = y -cy
	local dz = z -cz

	local targetOr = nil
	if dx > 0 then targetOr =  3
	elseif dx < 0 then targetOr = 1
	elseif dz > 0 then targetOr = 0
	elseif dz < 0 then targetOr = 2
	end

	-- if dy > 0 then "up"
	-- if dy < 0 then "down"

	return targetOr
end

function Miner:turnToPos(x,y,z)
	local targetOr = self:getTargetOrientation(x,y,z)
	self:turnTo(targetOr)
end



function Miner:updateLookingAt()
	-- 	+z = 0	south
	-- 	-x = 1	west
	-- 	-z = 2	north
	-- 	+x = 3 	east
	self.lookingAt = self.pos + self.vectors[self.orientation]
end

function Miner:forward()
	local tunnelFrom = vector.new(self.pos.x,self.pos.y,self.pos.z)
	--local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	local result = turtle.forward()
	if result then
		self:setMapValue(self.pos.x, self.pos.y, self.pos.z, 0)
		self.pos = self.pos + self.vectors[self.orientation]
		self:recordTunnelTraversal(tunnelFrom,self.pos)
		if self.veinRecording and self.veinTrace then
			table.insert(self.veinTrace, vector.new(self.pos.x,self.pos.y,self.pos.z))
		end
		-- TODO: setMapValue of current position to avoid wrong entries
		--self:setMapValue(self.pos.x, self.pos.y, self.pos.z,default.turtleName)
	end
	self:checkStatus()
	--self.taskList:remove(currentTask)
	return result
end

function Miner:back()
	local tunnelFrom = vector.new(self.pos.x,self.pos.y,self.pos.z)
	--local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	local result = turtle.back()
	if result then
		self:setMapValue(self.pos.x, self.pos.y, self.pos.z, 0)
		self.pos = self.pos - self.vectors[self.orientation]
		self:recordTunnelTraversal(tunnelFrom,self.pos)
		if self.veinRecording and self.veinTrace then
			table.insert(self.veinTrace, vector.new(self.pos.x,self.pos.y,self.pos.z))
		end
		--self:setMapValue(self.pos.x, self.pos.y, self.pos.z,default.turtleName)
	end
	--self.taskList:remove(currentTask)
	return result
end

function Miner:up()
	local tunnelFrom = vector.new(self.pos.x,self.pos.y,self.pos.z)
	--local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	local result = turtle.up()
	if result then
		self:setMapValue(self.pos.x, self.pos.y, self.pos.z, 0)
		self.pos.y = self.pos.y + 1
		self:recordTunnelTraversal(tunnelFrom,self.pos)
		if self.veinRecording and self.veinTrace then
			table.insert(self.veinTrace, vector.new(self.pos.x,self.pos.y,self.pos.z))
		end
		--self:setMapValue(self.pos.x, self.pos.y, self.pos.z,default.turtleName)
	end
	--self.taskList:remove(currentTask)
	return result
end

function Miner:down()
	local tunnelFrom = vector.new(self.pos.x,self.pos.y,self.pos.z)
	--local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	local result = turtle.down()
	if result then
		self:setMapValue(self.pos.x, self.pos.y, self.pos.z, 0)
		self.pos.y = self.pos.y - 1
		self:recordTunnelTraversal(tunnelFrom,self.pos)
		if self.veinRecording and self.veinTrace then
			table.insert(self.veinTrace, vector.new(self.pos.x,self.pos.y,self.pos.z))
		end
		--self:setMapValue(self.pos.x, self.pos.y, self.pos.z,default.turtleName)
	end
	--self.taskList:remove(currentTask)
	return result
end

function Miner:turnLeft()
	--local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	turtle.turnLeft()
	self.orientation = ( self.orientation - 1 ) % 4
	--self.taskList:remove(currentTask)
end

function Miner:turnRight()
	turtle.turnRight()
	self.orientation = ( self.orientation + 1 ) % 4
end


function Miner:placeBlock(blockName)
	local ok, reason
	if blockName then 
		ok, reason = self:placeInternal(blockName, "front")
	else
		blockName = self:getSelectedItemName()
		ok, reason = self:placeDown()
	end
	if ok then 
		self:setMapValue(self.lookingAt.x, self.lookingAt.y, self.lookingAt.z, blockName)
	end
	return ok, reason
end
function Miner:placeBlockUp(blockName)
		local ok, reason
	if blockName then 
		ok, reason = self:placeInternal(blockName, "up")
	else
		blockName = self:getSelectedItemName()
		ok, reason = self:placeUp()
	end
	if ok then 
		self:setMapValue(self.pos.x, self.pos.y+1, self.pos.z, blockName)
	end
	return ok, reason
end
function Miner:placeBlockDown(blockName)
	local ok, reason
	if blockName then 
		ok, reason = self:placeInternal(blockName, "down")
	else
		blockName = self:getSelectedItemName()
		ok, reason = self:placeDown()
	end
	if ok then 
		self:setMapValue(self.pos.x, self.pos.y-1, self.pos.z, blockName)
	end
	return ok, reason
end
-- special case of using buckets where we place or remove "blocks"
function Miner:useItem(itemName)
	local ok, reason = self:placeInternal(itemName, "front")
	return ok, reason
end
function Miner:useItemUp(itemName)
	local ok, reason = self:placeInternal(itemName, "up")
	return ok, reason
end
function Miner:useItemDown(itemName)
	local ok, reason = self:placeInternal(itemName, "down")
	return ok, reason
end
function Miner:placeInternal(itemName, side)
	local ok, reason
	local slot = self:findInventoryItem(itemName)
	if slot then
		local placeFunc
		if side == "front" then placeFunc = self.place
		elseif side == "up" then placeFunc = self.placeUp
		elseif side == "down" then placeFunc = self.placeDown
		else return false, "invalid side" end

		if self:select(slot) then 
			ok, reason = placeFunc(self)
		end
	end
	return ok, reason
end
function Miner:place(text)
	local ok, reason = turtle.place(text)
	return ok, reason
end
function Miner:placeDown(text)
	local ok, reason = turtle.placeDown(text)
	return ok, reason
end
function Miner:placeUp(text)
	local ok, reason = turtle.placeUp(text)
	return ok, reason
end

function Miner:dig(side)
	--local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	self:updateLookingAt()
	local target = vector.new(self.lookingAt.x,self.lookingAt.y,self.lookingAt.z)
	if self.activeMiningBounds and not self:isInsideActiveMiningBounds(target)
	and not self.allowTorchNicheDig then
		print("MINING BOUNDARY - REFUSING TO DIG OUTSIDE JOB")
		return false
	end
	local blockBefore = self:getMapValue(target.x,target.y,target.z)
	if blockBefore == philoliteBlockName then
		self:preparePhiloliteBlastRepair(target)
	end
	local result = turtle.dig(side)
	if result and blockBefore == philoliteBlockName then sleep(0.4) end
	if result then
		if self.veinRecording and self.veinExcavated then
			self.veinExcavated[target.x..","..target.y..","..target.z] = true
		end
		-- local block = self:getMapValue(self.lookingAt.x, self.lookingAt.y, self.lookingAt.z)
		-- if block and block ~= 0 then
			self:setMapValue(self.lookingAt.x, self.lookingAt.y, self.lookingAt.z,0)
		-- end
	end
	--self.taskList:remove(currentTask)
	return result
end

function Miner:digUp(side)
	--local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	local target = vector.new(self.pos.x,self.pos.y+1,self.pos.z)
	if self.activeMiningBounds and not self:isInsideActiveMiningBounds(target) then
		print("MINING BOUNDARY - REFUSING TO DIG OUTSIDE JOB")
		return false
	end
	local blockBefore = self:getMapValue(target.x,target.y,target.z)
	if blockBefore == philoliteBlockName then
		self:preparePhiloliteBlastRepair(target)
	end
	local result = turtle.digUp(side)
	if result and blockBefore == philoliteBlockName then sleep(0.4) end
	if result then
		if self.veinRecording and self.veinExcavated then
			self.veinExcavated[target.x..","..target.y..","..target.z] = true
		end
		-- local block = self:getMapValue(self.pos.x, self.pos.y+1, self.pos.z)
		-- if block and block ~= 0 then
			self:setMapValue(self.pos.x, self.pos.y+1, self.pos.z, 0)
		-- end
	end
	--self.taskList:remove(currentTask)
	return result
end

function Miner:digDown(side)
	--local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	local target = vector.new(self.pos.x,self.pos.y-1,self.pos.z)
	if self.activeMiningBounds and not self:isInsideActiveMiningBounds(target) then
		print("MINING BOUNDARY - REFUSING TO DIG OUTSIDE JOB")
		return false
	end
	local blockBefore = self:getMapValue(target.x,target.y,target.z)
	if blockBefore == philoliteBlockName then
		self:preparePhiloliteBlastRepair(target)
	end
	local result = turtle.digDown(side)
	if result and blockBefore == philoliteBlockName then sleep(0.4) end
	if result then
		if self.veinRecording and self.veinExcavated then
			self.veinExcavated[target.x..","..target.y..","..target.z] = true
		end
		-- local block = self:getMapValue(self.pos.x, self.pos.y-1, self.pos.z) 
		-- if block and block ~= 0 then
			self:setMapValue(self.pos.x, self.pos.y-1, self.pos.z, 0)
		-- end
	end
	--self.taskList:remove(currentTask)
	return result
end

function Miner.checkOreBlock(blockName)
	if blockName and blockName ~= 0 then
		if oreBlocks[blockName] then
			return true
		elseif string.find(blockName, "_ore") then
			oreBlocks[blockName] = true -- save this block as an ore
			-- TODO: save new blocks in translation on host when seeting map data?
			return true
		end
	end
	return false
end
local checkOreBlock = Miner.checkOreBlock

function Miner.checkDisallowed(id)
	-- blacklist function
	return disallowedBlocks[id] or isSophisticatedStorageChest(id)
end
local checkDisallowed = Miner.checkDisallowed

function Miner.checkSafe(id)
	-- whitelist function
	-- does not take changed blocks into account if id comes from the map value
	if not id or id == 0 or mineBlocks[id] or checkOreBlock(id) then
		return true
	end
	return false
end
local checkSafe = Miner.checkSafe

function Miner:inspect(safe)
	-- WARNING: NOT safe does NOT update the Map if the block has been explored before
	self:updateLookingAt()
	local block, hasBlock, data
	if not safe then 
		block = self:getMapValue(self.lookingAt.x, self.lookingAt.y, self.lookingAt.z)
	end
	if block == nil then
		-- never inspected before
		hasBlock, data = turtle.inspect()
		--block = hasBlock and ( nameToId[data.name] or data.name ) or 0
		self:setMapValue(self.lookingAt.x,self.lookingAt.y,self.lookingAt.z,
		( data and data.name ) or 0)
		block = data.name
	elseif checkOreBlock(block) then
		self.map:rememberOre(self.lookingAt.x,self.lookingAt.y,self.lookingAt.z, block)
	end
	return block, data
end

function Miner:inspectUp(safe)
	local block, hasBlock, data
	if not safe then
		block = self:getMapValue(self.pos.x, self.pos.y+1, self.pos.z)
	end
	if block == nil then
		hasBlock, data = turtle.inspectUp()
		self:setMapValue(self.pos.x,self.pos.y+1,self.pos.z,
		( data and data.name ) or 0)
		block = data.name
	elseif checkOreBlock(block) then
		self.map:rememberOre(self.pos.x,self.pos.y+1,self.pos.z, block)
	end
	return block, data
end

function Miner:inspectDown(safe)
	local block, hasBlock, data
	if not safe then
		block = self:getMapValue(self.pos.x, self.pos.y-1, self.pos.z)
	end
	if block == nil then
		hasBlock, data = turtle.inspectDown()
		self:setMapValue(self.pos.x,self.pos.y-1,self.pos.z,
		( data and data.name ) or 0)
		block = data.name
	elseif checkOreBlock(block) then
		self.map:rememberOre(self.pos.x,self.pos.y-1,self.pos.z, block)
	end
	return block, data
end
function Miner:inspectLeft()
	local block = self.pos + self.vectors[(self.orientation-1)%4]
	local name = self:getMapValue(block.x, block.y, block.z)
	local hasBlock, data
	if name == nil then
		self:turnTo((self.orientation-1)%4)
		hasBlock, data = turtle.inspect()
		self:setMapValue(block.x, block.y, block.z, 
		( data and data.name ) or 0)
		block = data.name
	elseif checkOreBlock(name) then
		self.map:rememberOre(block.x, block.y, block.z, name)
		block = name
	end
	return block, data
end
function Miner:inspectRight()
	local block = self.pos + self.vectors[(self.orientation+1)%4]
	local name = self:getMapValue(block.x, block.y, block.z)
	local hasBlock, data
	if name == nil then
		self:turnTo((self.orientation+1)%4)
		hasBlock, data = turtle.inspect()
		self:setMapValue(block.x, block.y, block.z,
		( data and data.name ) or 0)
		block = data.name
	elseif checkOreBlock(name) then
		self.map:rememberOre(block.x, block.y, block.z, name)
		block = name
	end
	return block, data
end

function Miner:inspectAll()
	--inspectLeft + inspectRigth ist gleich schnell wie inspectAll
	--AUßER: eines von beiden wurde bereits inspected und behind ist irrelevant
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	
	local orientation = self.orientation
	local hasBlock, data
	--self:inspect()
	self:inspectDown()
	self:inspectUp()
	
	-- inspect Front, Left, Behind, Right
	for i=0,3 do
		local block = self.pos + self.vectors[(orientation+i)%4]
		local mapValue = self:getMapValue(block.x, block.y, block.z)

		if mapValue == nil then
			self:turnTo((orientation+i)%4)
			hasBlock, data = turtle.inspect()
			self:setMapValue(block.x, block.y, block.z, 
			( data and data.name ) or 0)
		elseif checkOreBlock(mapValue) then
			-- mark as ore block
			self.map:rememberOre(block.x, block.y, block.z, mapValue)
		end
	end
	self.taskList:remove(currentTask)
end

function Miner:digMove(safe)
	-- tries to dig the block in front and move forwards
	-- while not mining any turtles
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	local ct = 0
	local result = true
	local failureReason = nil
	local trafficWaits = 0

	-- all changes here should be made in Down and Up as well
	
	-- optimization: if it is known that a block is in front -> dig first, then move
	-- trust, that the mapvalue is correct/up to date?
	-- could lead to mining another turtle
	-- why have the map in the first place if it cannot be trusted?
	-- solution: only check block if not safe -> no trust issues
	local blockName, data
	-- if not safe then
		-- blockName = self:inspect() -- or getMapValue for faster mining
		-- if blockName and blockName ~= 0 then
			-- if not checkDisallowed(blockName) then
				-- self:dig()
			-- end
		-- end
		-- -- else 
			-- -- nonone has been here before -> must be safe -- only for getMapValue
			-- -- but block could also be free so dig is redundant
			-- -- self:dig()
		-- -- end
	-- end
	-- end of optimization --> perhaps delete
	
	--try to move
	while not self:forward() do
		blockName, data = self:inspect(true) -- cannot move so there has to be a block
		--check block
		if blockName then
			--dig if safe
			local doMine = true
			if safe then
				doMine = checkSafe(blockName)
			else
				-- -> check if its explictly disallowed
				doMine = not checkDisallowed(blockName)
			end
			if doMine then
				self:dig()
				sleep(0.25)
				--print("digMove", checkSafe(blockName), blockName)
			elseif isTurtleBlockId(blockName) then
				-- LABENHANCED_COOP_MINING_TRAFFIC
				-- Never mine a teammate. Briefly yield here, then hand control
				-- back to tunnel() so it can use an open no-dig passing space
				-- instead of sitting in the same lane indefinitely.
				trafficWaits = trafficWaits + 1
				print("TURTLE TRAFFIC AHEAD - YIELD",trafficWaits.."/6")
				sleep(0.5)
				if trafficWaits >= 6 then
					failureReason = "traffic"
					result = false
					break
				end
			else
				print("NOT SAFE",blockName)
				result = false -- return false
				break
			end
		end
		ct = ct + 1
		if ct > 100 then
			if turtle.getFuelLevel() == 0 then
				self:refuel()
				ct = 90
				--possible endless loop if fuel is empty -> no refuel raises error
			else
				print("UNABLE TO MOVE")
			end
			result = false -- return false
			break
		end
	end

	self.taskList:remove(currentTask)

	return ( result and ( blockName or true ) ) or false, data, failureReason
end

function Miner:digMoveDown(safe)
	-- check digMove for documentation
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	local ct = 0
	local result = true
	
	-- might be an unnecessary optimization for up/down
	-- delete if there are problems with turtles mining each other
	local blockName, data
	-- if not safe then
		-- blockName = self:inspectDown()
		-- if blockName and blockName ~= 0 then
			-- if not checkDisallowed(blockName) then
				-- self:digDown()
			-- end
		-- end
	-- end
	
	while not self:down() do
		blockName, data = self:inspectDown(true)
		if blockName then
			local doMine = true
			if safe then
				doMine = checkSafe(blockName)
			else
				doMine = not checkDisallowed(blockName)
			end
			if doMine then
				self:digDown()
				sleep(0.25)
				--print("digMoveDown", checkSafe(blockName), blockName)
			else
				print("NOT SAFE DOWN", blockName)
				result = false
				break
			end
		end
		ct = ct+1
		if ct>100 then
			if turtle.getFuelLevel() == 0 then
				self:refuel()
				ct = 90
			else
				print("UNABLE TO MOVE DOWN")
			end
			result = false
			break
		end
	end
	
	self.taskList:remove(currentTask)
	return ( result and ( blockName or true ) ) or false, data
end

function Miner:digMoveUp(safe)
	-- check digMove for documentation
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	local ct = 0
	local result = true
	
	local blockName, data
	-- if not safe then
		-- blockName = self:inspectUp()
		-- if blockName and blockName ~= 0 then
			-- if not checkDisallowed(blockName) then
				-- self:digUp()
			-- end
		-- end
	-- end
	
	while not self:up() do
		blockName, data = self:inspectUp(true)
		if blockName then
			local doMine = true
			if safe then
				doMine = checkSafe(blockName)
			else
				doMine = not checkDisallowed(blockName)
			end
			if doMine then
				self:digUp()
				sleep(0.25)
				--print("digMoveUp", checkSafe(blockName), blockName)
			else
				print("NOT SAFE UP", blockName)
				result = false
				break
			end
		end
		ct = ct+1
		if ct>100 then
			if turtle.getFuelLevel() == 0 then
				self:refuel()
				ct = 90
			else
				print("UNABLE TO MOVE UP")
			end
			result = false
			break
		end
	end
	self.taskList:remove(currentTask)
	return ( result and ( blockName or true ) ) or false, data
end


function Miner:digToPos(x,y,z,safe)	
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	print("digToPos:", x, y, z, "safe:", safe)
	-- TODO: if digToPos fails, retry with navigateToPos
	-- 		if that fails as well (not immediately), return to digToPos
	-- NO, navigateToPos calls digToPos which could lead to recursive calls
	
	-- inspect is unnecessary due to digMove inspecting on demand
	local result = true
	
	if self.pos.x < x then
		self:turnTo(3) -- +x
		self:inspect()
	elseif self.pos.x > x then
		self:turnTo(1) -- -x
		self:inspect()
	end
	while self.pos.x ~= x do
		if not self:digMove(safe) then result = false; break end
		self:inspect()
		self:inspectDown()
		self:inspectUp()
	end
	if result then
		if self.pos.z < z then
			self:turnTo(0) -- +z
			self:inspect()
		elseif self.pos.z > z then
			self:turnTo(2) -- -z
			self:inspect()
		end
		
		while self.pos.z ~= z do
			if not self:digMove(safe) then result = false; break end
			self:inspect()
			self:inspectDown()
			self:inspectUp()
		end
		
		if result then
			while self.pos.y ~= y do
				if self.pos.y < y then
					if not self:digMoveUp(safe) then result = false; break end
					self:inspect()
					self:inspectUp()
				else
					if not self:digMoveDown(safe) then result = false; break end
					self:inspect()
					self:inspectDown()
				end
			end
		end
	end
	self.taskList:remove(currentTask)
	return result
end

local function cleanPosKey(pos)
	return pos.x..","..pos.y..","..pos.z
end

function Miner:moveNoDigToAdjacent(target)
	local dx = target.x - self.pos.x
	local dy = target.y - self.pos.y
	local dz = target.z - self.pos.z
	if math.abs(dx) + math.abs(dy) + math.abs(dz) ~= 1 then
		return false,"not_adjacent"
	end

	-- LABENHANCED_MINING_ROUTE_BRIDGE
	-- Use Miner movement wrappers, not raw turtle movement. That means every
	-- successful known-air traversal is also learned by the shared TunnelMap.
	local ok = false
	if dy > 0 then
		ok = self:up()
	elseif dy < 0 then
		ok = self:down()
	else
		self:turnToPos(target.x,target.y,target.z)
		ok = self:forward()
	end

	if ok then
		self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)
		return true
	end

	local hasBlock,data
	if dy > 0 then
		hasBlock,data = turtle.inspectUp()
	elseif dy < 0 then
		hasBlock,data = turtle.inspectDown()
	else
		hasBlock,data = turtle.inspect()
	end

	local name = hasBlock and data and data.name or nil
	if isTurtleBlockId(name) then
		-- A turtle is traffic, not terrain. Do not write it permanently into
		-- the physical map or the next path search will think the tunnel closed.
		return false,"traffic",name
	end

	self:setMapValue(
		target.x,target.y,target.z,
		(hasBlock and name) or 0
	)
	return false,hasBlock and "blocked" or "transient",name
end

function Miner:placeCobbledDeepslateAt(target)
	local slot = self:findInventoryItem(veinBackfillItem)
	if not slot then return false, "NO_COBBLED_DEEPSLATE" end
	if not self:select(slot) then return false, "SELECT_FAILED" end

	local dx = target.x - self.pos.x
	local dy = target.y - self.pos.y
	local dz = target.z - self.pos.z
	if math.abs(dx) + math.abs(dy) + math.abs(dz) ~= 1 then return false, "NOT_ADJACENT" end

	local ok, reason
	if dy > 0 then
		ok, reason = turtle.placeUp()
	elseif dy < 0 then
		ok, reason = turtle.placeDown()
	else
		self:turnToPos(target.x,target.y,target.z)
		ok, reason = turtle.place()
	end

	if ok then
		self:setMapValue(target.x,target.y,target.z,veinBackfillItem)
	end
	return ok, reason
end

function Miner:cleanupVeinTrace(startPos, startOrientation)
	local trace = self.veinTrace or {}
	local excavated = self.veinExcavated or {}
	local remaining = {}
	for _,pos in ipairs(trace) do
		local key = cleanPosKey(pos)
		remaining[key] = (remaining[key] or 0) + 1
	end

	self.veinRecording = false
	local startKey = cleanPosKey(startPos)
	local warned = false
	local result = true

	for i = #trace, 2, -1 do
		local cur = trace[i]
		local prev = trace[i-1]
		local curKey = cleanPosKey(cur)

		if not self:moveNoDigToAdjacent(prev) then
			print("VEIN RETURN BLOCKED - REFUSING TO DIG")
			result = false
			break
		end

		remaining[curKey] = (remaining[curKey] or 1) - 1
		if curKey ~= startKey and excavated[curKey] and remaining[curKey] <= 0 then
			local ok, reason = self:placeCobbledDeepslateAt(cur)
			if not ok and reason == "NO_COBBLED_DEEPSLATE" and not warned then
				print("NO COBBLED DEEPSLATE - SKIPPING VEIN BACKFILL")
				warned = true
			end
		end
	end

	self.veinTrace = nil
	self.veinExcavated = nil
	self.veinRecording = false
	self:turnTo(startOrientation)
	return result and self.pos == startPos
end

function Miner:navigateKnownAirBootstrap(x,y,z)
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	local goal = vector.new(x,y,z)
	local wasRecording = self.veinRecording
	self.veinRecording = false
	local result = false

	if self.pos == goal then
		result = true
	elseif self:getMapValue(goal.x,goal.y,goal.z) ~= 0 then
		print("OPEN PATH GOAL NOT KNOWN OPEN - REFUSING TO DIG")
		result = false
	else
		self.map:setMaxChunks(800)
		for attempt=1,3 do
			local pathFinder = PathFinder()
			pathFinder.checkValid = function(id) return id == 0 end
			local path = pathFinder:aStarPart(self.pos, self.orientation, goal, self.map, 10000)
			if not path then
				print("NO OPEN PATH TO",x,y,z,"- REFUSING TO DIG")
				break
			end

			result = true
			for i=1,#path do
				local step = path[i]
				if step.pos ~= self.pos then
					local moved,moveReason = self:moveNoDigToAdjacent(step.pos)
					if not moved then
						if moveReason == "traffic" then
							print("OPEN PATH TURTLE TRAFFIC - WAITING")
							sleep(0.75)
						else
							print("OPEN PATH BLOCKED - REFUSING TO DIG")
						end
						result = false
						break
					end
				end
			end
			if result and self.pos == goal then
				if self.flushTunnelUpdatesSync then self:flushTunnelUpdatesSync() end
				break
			end
		end
	end

	self.veinRecording = wasRecording
	self.taskList:remove(currentTask)
	return result and self.pos == goal
end


-- LABENHANCED_COOP_MINING_TRAFFIC
-- Use the already-dug upper half of a 1x2 tunnel as a temporary passing bay.
-- This NEVER digs a block. It gives head-on traffic a way to pass in a
-- one-wide floor lane before the navigator considers the route jammed.
function Miner:yieldForTurtleTraffic(waitSeconds)
	waitSeconds = tonumber(waitSeconds) or 4
	local hasUp = turtle.inspectUp()
	if hasUp then
		return false,"no_headspace"
	end

	local originalY = self.pos.y
	if not self:up() then
		return false,"headspace_move_failed"
	end

	print("TRAFFIC YIELD - USING OPEN HEADSPACE")
	local deadline = os.epoch("utc") + math.floor(waitSeconds * 1000)
	sleep(0.5)

	while os.epoch("utc") < deadline do
		local hasDown,data = turtle.inspectDown()
		if not hasDown then
			if self:down() then
				return self.pos.y == originalY,"headspace"
			end
		elseif not isTurtleBlockId(data and data.name) then
			break
		end
		sleep(0.5)
	end

	-- A teammate may still be directly underneath us. Stay out of its way a
	-- little longer rather than forcing a block break or descending onto it.
	for _=1,8 do
		local hasDown,data = turtle.inspectDown()
		if not hasDown and self:down() then
			return self.pos.y == originalY,"headspace"
		end
		if hasDown and not isTurtleBlockId(data and data.name) then
			break
		end
		sleep(0.5)
	end

	print("TRAFFIC YIELD COULD NOT REJOIN FLOOR")
	return false,"yield_rejoin_blocked"
end

function Miner:navigateOpenPathToPos(x,y,z)
	local goal = vector.new(x,y,z)
	self.lastNavigationFailureReason = nil
	if self.pos == goal then return true end

	if self.tunnelNavigator then
		local ok,reason,stats = self.tunnelNavigator:navigateTo(goal)
		if ok then return true end
		self.lastNavigationFailureReason = reason

		if reason == "traffic_jam_timeout" then
			print("TURTLE TRAFFIC JAM TIMEOUT - REFUSING TO PUSH THROUGH")
			return false
		end

		-- LABENHANCED_MINING_ROUTE_BRIDGE
		-- The logical road graph can legitimately lag behind the older physical
		-- ChunkyMap, especially when starting a new mining area. If the target
		-- is already known-open, use the strict no-dig known-air path as a bridge.
		-- moveNoDigToAdjacent records every successful step back into TunnelMap.
		local goalKnownOpen = self:getMapValue(goal.x,goal.y,goal.z) == 0
		if (stats and stats.nodes == 0) or goalKnownOpen then
			if stats and stats.nodes == 0 then
				print("TUNNEL GRAPH EMPTY - USING KNOWN-AIR BOOTSTRAP")
			else
				print("TUNNEL GRAPH MISSING KNOWN-AIR ROUTE - BRIDGING")
			end
			local bridged = self:navigateKnownAirBootstrap(x,y,z)
			if bridged then return true end
		end

		print("NO VALID TUNNEL ROUTE - REFUSING TO DIG")
		return false
	end

	local ok = self:navigateKnownAirBootstrap(x,y,z)
	if not ok then self.lastNavigationFailureReason = "no_open_route" end
	return ok
end

-- LABENHANCED_CONTAINED_MINING
-- mineArea is constrained to its assigned X/Z rectangle. Y is intentionally
-- not constrained because the normal tunnel is two blocks tall and multi-level
-- jobs legitimately move vertically.
function Miner:setActiveMiningBounds(startPos, finishPos)
	if not startPos or not finishPos then
		self.activeMiningBounds = nil
		return
	end
	self.activeMiningBounds = {
		minX = math.min(startPos.x,finishPos.x),
		maxX = math.max(startPos.x,finishPos.x),
		minZ = math.min(startPos.z,finishPos.z),
		maxZ = math.max(startPos.z,finishPos.z),
	}
end

function Miner:isInsideActiveMiningBounds(pos)
	local b = self.activeMiningBounds
	if not b or not pos then return true end
	return pos.x >= b.minX and pos.x <= b.maxX
		and pos.z >= b.minZ and pos.z <= b.maxZ
end

function Miner:mineExposedOreFront(target)
	local hasBlock,data = turtle.inspect()
	local name = hasBlock and data and data.name or 0
	self:setMapValue(target.x,target.y,target.z,name)
	if hasBlock and checkOreBlock(name) and self:isInsideActiveMiningBounds(target) then
		if self:dig() then
			if self:getTunnelMaterialSlot() then self:placeBlock(veinBackfillItem) end
			return true
		end
	end
	return false
end

function Miner:mineExposedOreDown(target)
	local hasBlock,data = turtle.inspectDown()
	local name = hasBlock and data and data.name or 0
	self:setMapValue(target.x,target.y,target.z,name)
	if hasBlock and checkOreBlock(name) and self:isInsideActiveMiningBounds(target) then
		if self:digDown() then
			if self:getTunnelMaterialSlot() then self:placeBlockDown(veinBackfillItem) end
			return true
		end
	end
	return false
end

function Miner:mineExposedOreUp(target)
	local hasBlock,data = turtle.inspectUp()
	local name = hasBlock and data and data.name or 0
	self:setMapValue(target.x,target.y,target.z,name)
	if hasBlock and checkOreBlock(name) and self:isInsideActiveMiningBounds(target) then
		if self:digUp() then
			if self:getTunnelMaterialSlot() then self:placeBlockUp(veinBackfillItem) end
			return true
		end
	end
	return false
end

function Miner:mineExposedTunnelOres()
	-- Fair-mining mode: inspect only blocks physically touching the intentional
	-- 1x2 corridor. Never search the map for a remembered ore and never move
	-- sideways/down a branch to chase a vein.
	local startOrientation = self.orientation
	local lowerPos = vector.new(self.pos.x,self.pos.y,self.pos.z)

	-- Lower side walls.
	self:turnTo(startOrientation-1)
	self:mineExposedOreFront(self.pos + self.vectors[self.orientation])
	self:turnTo(startOrientation+1)
	self:mineExposedOreFront(self.pos + self.vectors[self.orientation])
	self:turnTo(startOrientation)

	-- Floor.
	self:mineExposedOreDown(vector.new(self.pos.x,self.pos.y-1,self.pos.z))

	-- Upper half of the existing 1x2 corridor. We only enter the upper AIR cell;
	-- if it is not open, leave it for the normal 2-high tunnel logic.
	if turtle.up() then
		self:setMapValue(lowerPos.x,lowerPos.y,lowerPos.z,0)
		self.pos.y = self.pos.y + 1
		self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)

		self:turnTo(startOrientation-1)
		self:mineExposedOreFront(self.pos + self.vectors[self.orientation])
		self:turnTo(startOrientation+1)
		self:mineExposedOreFront(self.pos + self.vectors[self.orientation])
		self:turnTo(startOrientation)

		-- Ceiling.
		self:mineExposedOreUp(vector.new(self.pos.x,self.pos.y+1,self.pos.z))

		if turtle.down() then
			self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)
			self.pos.y = self.pos.y - 1
			self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)
		else
			print("EXPOSED ORE CHECK: unable to return to lower tunnel cell")
		end
	end

	self:turnTo(startOrientation)
end


function Miner:mineVein()
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})

	-- No x-ray / remembered-ore chasing. Only harvest ores that are currently
	-- exposed directly to the maintained 1x2 tunnel, without leaving it.
	self:mineExposedTunnelOres()

	self.taskList:remove(currentTask)
end

function Miner:stripMine(rowLength, rows, levels, rowFactor, levelFactor, offset, noInspect)
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name}, true)
	print("stripmining", "rows", rows, "levels", levels)

	local directionFactor = 1 -- -1 for right hand mining

	local taskState = currentTask.taskState
	if taskState then
		rowLength, rows, levels, rowFactor, levelFactor, offset, noInspect = tableunpack(taskState.args,1,taskState.args.n)
	else
		taskState = {
			stage = 1,
			ignorePosition = false,
			vars = {
				currentRow = 1,
				currentLevel = 1,
				rowOrientation = self.orientation,
				tunnelDirection = -1 * directionFactor,
				startPos = vector.new(self.pos.x, self.pos.y, self.pos.z),
				startOrientation = self.orientation,
				torchSide = -1,
			},
			args = tablepack(rowLength, rows, levels, rowFactor, levelFactor, offset, noInspect),
		}
	end
	local vars = taskState.vars
	currentTask.taskState = taskState
	self.checkPointer:save(self)
	-- prepare values

	if not levels then levels = 1 end
	local positiveLevel = true
	if levels < 0 then 
		positiveLevel = false 
		levels = levels * -1
	end


-- OPTIMAL STRATEGIES
-- M -> Mine
-- * -> gets looked at

-- MULTILEVEL lookAtAll
--------------------
--	 * 	 *	 *		
-- * M * M * M *	
--	 * * * * * *
--	 * M * M * M *
--	   *   *   *	
--------------------
	-- local rowFactor = 2
	-- local rowLength = (rows-1) * rowFactor
	-- for currentLevel=1,levels do
		-- for currentRow=1,rows do
			-- self:tunnelMine(rowLength,1,1)
			-- --self:turnRight()
			-- if currentRow < rows then
				-- self:turnTo(startOrientation-1)
				-- self:tunnelMine(rowFactor,1,1)
				-- if currentRow%2 == 1 then
					-- self:turnTo(startOrientation-2)
				-- else
					-- self:turnTo(startOrientation)
				-- end
			-- end
		-- end
		-- -- go up one level
	-- end



	
-- MULTILEVEL speed (leaves areas uninspected)
--------------------
--	 * 	   *	 *		
-- * M * * M * * M *	
--	 * *   * *   * *
--	 * M * * M * * M *
--	   *     *     *	
--------------------


	self:addProgressLevel("level", levels, "Y Level")
	self:addProgressLevel("row", rows, "Rows")

	if taskState.stage == 1 then
		-- try, catch
		local ok,err = pcall(function()

			if not rowFactor then rowFactor = 3 end
			if not levelFactor then levelFactor = 2 end
			if not offset then offset = 1 end
			
			for currentLevel = vars.currentLevel, levels do
				vars.currentLevel = currentLevel
				self.checkPointer:save(self)

				if currentLevel%2 == 0 and rows%2 == 0 then 
					vars.tunnelDirection = 1 * directionFactor
				else vars.tunnelDirection = -1 * directionFactor end
				
				for currentRow = vars.currentRow, rows do
					vars.currentRow = currentRow
					self.checkPointer:save(self) -- perhaps at start of for-loop
					

					-- LABENHANCED_AUTO_TORCHES
					-- Only the long mining row receives torches. Short connector
					-- moves between rows do not, keeping the layout clean.
					if self.activeMiningBounds and not noInspect then
						self.autoTunnelTorches = true
						self.tunnelTorchSteps = 0
						self.tunnelTorchSide = vars.torchSide or -1

						-- Seed each row with a light at the entrance, then place the
						-- next one just before vanilla block light would reach 0.
						self:placeTunnelTorchNiche(self.tunnelTorchSide)
						vars.torchSide = self.tunnelTorchSide
					end

					self:tunnelStraight(rowLength, noInspect)

					if self.autoTunnelTorches then
						vars.torchSide = self.tunnelTorchSide
						self.autoTunnelTorches = false
						self.tunnelTorchSteps = 0
						self.checkPointer:save(self)
					end

					if currentRow < rows then
						self:turnTo(vars.rowOrientation + vars.tunnelDirection)
						self:tunnelStraight(rowFactor, noInspect)
						if currentRow%2 == 1 then
							self:turnTo(vars.rowOrientation-2)
						else
							self:turnTo(vars.rowOrientation)
						end
					end
					self:updateProgress("row", currentRow)
				end

				-- move to next level
				self:disableProgressUpdates()
				vars.currentRow = 1 -- reset row to start at 1 again, not saved state
				if currentLevel < levels then
					-- move up
					if positiveLevel then
						self:tunnelUp(levelFactor, noInspect)
					else
						self:tunnelDown(levelFactor, noInspect)
					end
					if self.orientation == vars.startOrientation or currentLevel%2 == 0 then
							self:turnRight() 
							self:tunnelStraight(offset, noInspect)
							self:turnRight()
							self:tunnelStraight(offset, noInspect)
					else
						if rows%2 == 0 then
							self:tunnelStraight(offset, noInspect)
							self:turnLeft()
							self:tunnelStraight(offset, noInspect)
							self:turnLeft()
						else
							self:turnLeft()
							self:tunnelStraight(offset, noInspect)
							self:turnLeft()
							self:tunnelStraight(offset, noInspect)
						end
					end
				end
				self:enableProgressUpdates()

				vars.rowOrientation = self.orientation
				self:updateProgress("level", currentLevel)
			end
			
		end)
	
		if not ok then 
			if err == "TUNNEL FAIL" then
				print(ok, err)
			else
				-- pass error
				error(err)
			end
		end
		taskState.stage = 2
		taskState.ignorePosition = true
		self.checkPointer:save(self)
	end

--SINGLE LEVEL PART OF MULTILEVEL
--------------------
--	 * 	   *     *
-- * M * * M * * M *
--	 *     *     *
--------------------

	if taskState.stage == 2 then
		self.autoTunnelTorches = false
		self.tunnelTorchSteps = 0
		-- Return through the tunnel network only. Never carve a 1x1 shortcut
		-- back to the strip-mine entrance.
		if not self:navigateOpenPathToPos(vars.startPos.x, vars.startPos.y, vars.startPos.z) then
			print("NO OPEN TUNNEL PATH BACK TO STRIP START")
		end
		self:turnTo(vars.startOrientation)
	end

	self.taskList:remove(currentTask)
	self.checkPointer:save(self)
end

function Miner:getAreaStart(start, finish)
	-- determine nearest starting position for an area

	local minX = math.min(start.x, finish.x)
	local minY = math.min(start.y, finish.y)
	local minZ = math.min(start.z, finish.z)
	local maxX = math.max(start.x, finish.x)
	local maxY = math.max(start.y, finish.y)
	local maxZ = math.max(start.z, finish.z)
	
	local corners = {
		-- 1-4 bottom
		vector.new(minX, minY, minZ),
		vector.new(minX, minY, maxZ),
		vector.new(maxX, minY, minZ),
		vector.new(maxX, minY, maxZ),
		-- 5-8 top
		vector.new(maxX, maxY, maxZ),
		vector.new(maxX, maxY, minZ),
		vector.new(minX, maxY, maxZ),
		vector.new(minX, maxY, minZ),
		-- 1 is opposite to (id + 4) % 8
	}
	
	local minCost, minId
	for id,corner in ipairs(corners) do
		local cost = math.abs(self.pos.x - corner.x) + math.abs(self.pos.y - corner.y) + math.abs(self.pos.z - corner.z)
		if minCost == nil or cost < minCost then
			minCost = cost
			minId = id
		end
	end
	
	start = corners[minId]
	finish = corners[((minId+3)%8)+1] -- opposite corner

	-- turn to the correct orientation 
	-- 	+z = 0	south
	-- 	-x = 1	west
	-- 	-z = 2	north
	-- 	+x = 3 	east
	local diff = finish - start
	local orientation
	if diff.x <= 0 and diff.z > 0 then
		orientation = 1 
	elseif diff.x <= 0 and diff.z <= 0 then
		orientation = 2 
	elseif diff.x > 0 and diff.z <= 0 then
		orientation = 3 
	else
		orientation = 0 
	end

	return start, finish, orientation

end

function Miner:initProgress(taskName, hierarchy)
	self:enableProgressUpdates()
	print("initProgress", taskName)
	--fs.delete("calc.txt")
	--local f = fs.open("calc.txt", "w"); f.writeLine("INIT PROGRESS " .. taskName); f.close()
	local values, keyMap = {}, {}
	for i, level in ipairs(hierarchy) do
		level.max = math.abs(level.max)
		if not level.label then level.label = level.key end
		if not level.minMargin then level.minMargin = 0 end
		if not level.maxMargin then level.maxMargin = 1 end
		values[level.key] = 0
		keyMap[level.key] = i
	end
	self.progress = {
		task = taskName, 
		startTime = os.epoch("utc"),
		hierarchy = hierarchy, -- key, max, label, minMargin, maxMargin
		values = values,
		keyMap = keyMap,
	}
end

function Miner:restoreProgress(progress)
	-- to restore progress hierarchy from a checkpointed task
	if progress then
		self.progress = progress
	end
end

function Miner:addProgressLevel(key, max, label, minMargin, maxMargin)
	local progress = self.progress
	if progress then 
		max = math.abs(max)
		local index = progress.keyMap[key]

		if index then
			local level = progress.hierarchy[index]
			local oldMax = level.max
			level.max = max
			local val = progress.values[key]
			if max > oldMax then 
				if val == oldMax then 
					progress.values[key] = max
				else
					-- scale existing value to new max
					local percent = val/oldMax
					progress.values[key] = percent * max
				end
			elseif val > max then
				-- clip to max, reset to 0 happens in updateProgress
				progress.values[key] = max
			end
			-- resets previous margins
			level.minMargin = minMargin or 0 
			level.maxMargin = maxMargin or 1

		else
			-- level does not exist, add new level
			table.insert(progress.hierarchy,
				{key = key, max = max, label = label or key, minMargin = minMargin or 0, maxMargin = maxMargin or 1})
			progress.values[key] = 0
			progress.keyMap[key] = #progress.hierarchy
		end
	end
end
function Miner:getOverallProgress()
	local total = nil
	-- return nil to indicate no progress is being tracked
	local progress = self.progress
	if progress then 
		local hierarchy, values = progress.hierarchy, progress.values
		total = 0
		local weight = 1
		for i = 1, #hierarchy do
	
			local level = hierarchy[i]
			local key, max = level.key, level.max
			local value = values[key] or 0
			local minMargin, maxMargin = level.minMargin, level.maxMargin

			if max > 0 then 
				local percent = value / max
				total = total + percent * weight
				-- limit contribution of lower levels to overall progress

				--local f = fs.open("calc.txt", "a")
				--f.writeLine("total " .. total .. " level " .. i .. " key " .. key .. " val " .. value .. " max " .. max .. " percent " .. percent .. " weight " .. weight .. " contrib " .. (percent * weight) .. " minMargin " .. minMargin .. " maxMargin " .. maxMargin)
				--f.close()
				weight = weight / max * (maxMargin - minMargin)
			end
		end
		-- rounding errors of 0.000001 can lead to "decreased" progress
		if total > 100 then 
			print("TOTAL > 100, consider disableUpdates " .. total)
		end
	end
	return total
end

function Miner:disableProgressUpdates()
	self.doProgressUpdates = false
end
function Miner:enableProgressUpdates()
	self.doProgressUpdates = true
end
function Miner:updateProgress(key, value, allowDecrease)
	local progress = self.progress
	if progress and self.doProgressUpdates then 

		local values = progress.values
		local oldVal = values[key]
		if oldVal and ( allowDecrease or value > oldVal ) then
		
			values[key] = value

			if not allowDecrease then 
				local index = progress.keyMap[key]
				local hierarchy = progress.hierarchy

				-- reset next lower level (this cascades, so all lower levels get reset)
				-- l3 resets l4, l2 resets l3, l1 resets l2 -> all but l1 are 0 -> never over 100%
				local nextLevel = hierarchy[index+1]
				if nextLevel then 
					values[nextLevel.key] = 0
				end
			end
		end
	end
end

function Miner:clearProgress()
	self.progress = nil
end


-- LABENHANCED_SMART_MINE_ACCESS
-- Reuse known open tunnel space for as long as possible before making a new
-- approach tunnel. Only the designated access leader may create the external
-- connector; followers wait for and reuse that route.
local function accessPosKey(x,y,z)
	return x .. "," .. y .. "," .. z
end

local function sameAccessPos(a,b)
	-- LABENHANCED_SHARED_ACCESS_POS_FIX
	-- Positions received over rednet are plain tables, not vector objects.
	-- Never use table identity (self.pos == target) for network-supplied coords.
	return a and b
		and a.x == b.x
		and a.y == b.y
		and a.z == b.z
end

function Miner:followExistingTunnelToward(target,trafficAvoid,replanDepth)
	if not target then return false end
	if sameAccessPos(self.pos,target) then return true end
	trafficAvoid = trafficAvoid or {}
	replanDepth = replanDepth or 0

	-- Breadth-first walk over KNOWN AIR only. Besides being safe, this gives us
	-- the reachable existing tunnel point closest to the new mining entrance.
	-- LABENHANCED_MINING_ROUTE_BRIDGE: traffic cells are locally excluded so a
	-- mining leader can choose another existing branch instead of immediately
	-- trying to drill through a turtle.
	local queue = { vector.new(self.pos.x,self.pos.y,self.pos.z) }
	local head = 1
	local visited = {}
	local previous = {}
	local positions = {}
	local startKey = accessPosKey(self.pos.x,self.pos.y,self.pos.z)
	visited[startKey] = true
	positions[startKey] = queue[1]

	local bestKey = startKey
	local bestScore = math.abs(self.pos.x-target.x)
		+ math.abs(self.pos.z-target.z)
		+ math.abs(self.pos.y-target.y) * 6
	local bestSteps = 0
	local steps = {[startKey]=0}
	local maxNodes = 12000
	local nodes = 0
	local dirs = {
		vector.new(1,0,0), vector.new(-1,0,0),
		vector.new(0,0,1), vector.new(0,0,-1),
		vector.new(0,1,0), vector.new(0,-1,0),
	}

	while head <= #queue and nodes < maxNodes do
		local p = queue[head]
		head = head + 1
		nodes = nodes + 1
		local pk = accessPosKey(p.x,p.y,p.z)
		local psteps = steps[pk] or 0

		local score = math.abs(p.x-target.x)
			+ math.abs(p.z-target.z)
			+ math.abs(p.y-target.y) * 6
		if score < bestScore or (score == bestScore and psteps < bestSteps) then
			bestScore = score
			bestKey = pk
			bestSteps = psteps
		end
		if score == 0 then
			bestKey = pk
			break
		end

		for _,d in ipairs(dirs) do
			local n = p + d
			local nk = accessPosKey(n.x,n.y,n.z)
			if not visited[nk] and not trafficAvoid[nk] then
				visited[nk] = true
				if self:getMapValue(n.x,n.y,n.z) == 0 then
					previous[nk] = pk
					positions[nk] = n
					steps[nk] = psteps + 1
					table.insert(queue,n)
				end
			end
		end

		if nodes % 1000 == 0 then sleep(0) end
	end

	if bestKey == startKey then
		return false
	end

	local reverse = {}
	local key = bestKey
	while key and key ~= startKey do
		table.insert(reverse,positions[key])
		key = previous[key]
	end

	for i=#reverse,1,-1 do
		local moved,moveReason = self:moveNoDigToAdjacent(reverse[i])
		if not moved then
			if moveReason == "traffic" and replanDepth < 6 then
				local blocked = reverse[i]
				trafficAvoid[accessPosKey(blocked.x,blocked.y,blocked.z)] = true
				print("EXISTING ACCESS TURTLE TRAFFIC - REPLANNING")
				sleep(0.5)
				return self:followExistingTunnelToward(
					target,trafficAvoid,replanDepth+1
				)
			end
			print("EXISTING ACCESS PATH BLOCKED")
			return false
		end
	end

	if self.flushTunnelUpdatesSync then self:flushTunnelUpdatesSync() end
	return true
end

function Miner:digNeatAccessTunnelTo(target)
	if not target then return false end

	-- Keep the connector simple and readable: one continuous Manhattan route,
	-- always using the same 1-wide x 2-high horizontal tunnel machinery.
	local function digAxis(axis)
		local delta
		if axis == "x" then delta = target.x - self.pos.x
		else delta = target.z - self.pos.z end
		if delta == 0 then return true end

		if axis == "x" then
			self:turnTo(delta > 0 and 3 or 1)
		else
			self:turnTo(delta > 0 and 0 or 2)
		end
		self:tunnelStraight(math.abs(delta), true)
		return true
	end

	-- Prefer the longer horizontal leg first so the access route has at most
	-- one clean corner and does not staircase/zig-zag through untouched rock.
	local dx = math.abs(target.x-self.pos.x)
	local dz = math.abs(target.z-self.pos.z)
	if dx >= dz then
		digAxis("x")
		digAxis("z")
	else
		digAxis("z")
		digAxis("x")
	end

	-- Most mining floors are on the same Y level. If not, finish with one
	-- compact vertical connector rather than allowing generic 1x1 navigation.
	local dy = target.y - self.pos.y
	if dy > 0 then
		self:tunnelUp(dy,true)
	elseif dy < 0 then
		self:tunnelDown(-dy,true)
	end

	local reached = sameAccessPos(self.pos,target)
	if not reached then
		print("ACCESS END MISMATCH",
			"at",self.pos.x,self.pos.y,self.pos.z,
			"wanted",target.x,target.y,target.z)
	end
	return reached
end

function Miner:reachSharedMineEntrance(sharedEntry, sharedEnd, accessEntry, isLeader)
	if not sharedEntry then return false end

	if isLeader then
		-- First reuse the known tunnel network as far as it already goes.
		if not self:navigateOpenPathToPos(sharedEntry.x,sharedEntry.y,sharedEntry.z) then
			self:followExistingTunnelToward(sharedEntry)
			print("CREATING SHARED 1x2 MINE ACCESS")
			if not self:digNeatAccessTunnelTo(sharedEntry) then
				return false
			end
		end

		-- With 3-4 turtles, continue the SAME maintained 1x2 corridor across
		-- the stripe entries inside the green box. This is the only distribution
		-- spine; followers never create parallel approaches.
		if sharedEnd and not sameAccessPos(self.pos,sharedEnd) then
			if not self:navigateOpenPathToPos(sharedEnd.x,sharedEnd.y,sharedEnd.z) then
				print("CREATING SHARED IN-BOX ACCESS SPINE")
				if not self:digNeatAccessTunnelTo(sharedEnd) then return false end
			end
		end

		-- Return along the just-created open spine to this turtle's own entry.
		local ownEntry = accessEntry or sharedEntry
		if not sameAccessPos(self.pos,ownEntry) then
			if not self:navigateOpenPathToPos(ownEntry.x,ownEntry.y,ownEntry.z) then
				return false
			end
		end
		return true
	else
		-- Followers are not allowed to make a second access tunnel. Wait until
		-- the leader has opened a complete path all the way to this stripe entry.
		-- LABENHANCED_SHARED_ACCESS_POS_FIX
		-- Do not spam the routefinder while the entry is still unknown rock.
		local ownEntry = accessEntry or sharedEntry
		print("WAITING FOR SHARED MINE ACCESS")
		for attempt=1,300 do
			if sameAccessPos(self.pos,ownEntry) then
				return true
			end

			local entryValue = self:getMapValue(ownEntry.x,ownEntry.y,ownEntry.z)
			if entryValue == 0 then
				if self:navigateOpenPathToPos(ownEntry.x,ownEntry.y,ownEntry.z) then
					return true
				end
			end

			if attempt % 15 == 0 then
				print("SHARED ACCESS NOT READY YET",attempt.."/300")
			end
			sleep(1)
		end
		print("SHARED MINE ACCESS TIMEOUT - REFUSING SECOND TUNNEL")
		return false
	end
end

-- LABENHANCED_FAR_EDGE_SPINE
-- Close the "open comb" at the far end of a mining stripe. stripMine already
-- creates parallel rows and short 3-block turns; this adds one continuous 1x2
-- spine along the opposite edge so every row endpoint is tied into the same
-- tunnel network. It stays inside this turtle's assigned stripe.
function Miner:connectMiningFarEdge(startPos,finishPos,orientation)
	if not startPos or not finishPos or orientation == nil then return false end

	local y = startPos.y
	local edgeStart,edgeEnd

	if orientation % 2 == 0 then
		-- Mining rows run north/south (Z). Join them across X at the far Z edge.
		edgeStart = vector.new(startPos.x,y,finishPos.z)
		edgeEnd = vector.new(finishPos.x,y,finishPos.z)
	else
		-- Mining rows run east/west (X). Join them across Z at the far X edge.
		edgeStart = vector.new(finishPos.x,y,startPos.z)
		edgeEnd = vector.new(finishPos.x,y,finishPos.z)
	end

	if sameAccessPos(edgeStart,edgeEnd) then return true end

	-- The first point is the end of the first mining row, so it should already
	-- be open. Travel there through known tunnels only; never cut a shortcut.
	local reached = self:navigateOpenPathToPos(edgeStart.x,edgeStart.y,edgeStart.z)
	if not reached then
		print("FAR EDGE SPINE: NO OPEN ROUTE TO START - SKIPPING")
		return false
	end

	print("CONNECTING FAR EDGE TUNNEL SPINE")
	local ok = self:digNeatAccessTunnelTo(edgeEnd)
	if ok and self.flushTunnelUpdatesSync then
		self:flushTunnelUpdatesSync()
	end
	return ok
end

function Miner:mineArea(start, finish) 
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name}, true)
	-- mine area within start and finish pos
	-- 8 corners = 8 possible starting locations, pick nearest
	-- determine how many rows and levels to mine and in which direction
	
	local taskState = currentTask.taskState
	if taskState then
		start, finish = tableunpack(taskState.args,1,taskState.args.n)
	else
		taskState = {
			stage = 1, -- Stage 1: Execute stripMine, Stage 2: Execute post-stripMine steps
			ignorePosition = true,
			vars = {
			},
			args = tablepack(start, finish),
		}
	end
	local vars = taskState.vars
	currentTask.taskState = taskState
	self.checkPointer:save(self)

	self:initProgress("mineArea", { { key = "stage", max = 1, label = "Stage", minMargin = 0.05, maxMargin = 0.95 } } )
	print("excecuting stage:", taskState.stage)
	
	if taskState.stage == 1 then

		-- Keep the controller-assigned stripe bounds intact. Shared mining uses
		-- these later so each turtle can start directly on its shared-spine corner
		-- instead of carving a private connector to a recomputed nearest corner.
		local assignedBounds = {
			minX=math.min(start.x,finish.x), maxX=math.max(start.x,finish.x),
			minY=math.min(start.y,finish.y), maxY=math.max(start.y,finish.y),
			minZ=math.min(start.z,finish.z), maxZ=math.max(start.z,finish.z),
		}

		local orientation
		start, finish, orientation = self:getAreaStart(start, finish)
		
		local diff = finish - start
		local width = math.abs(diff.x)
		local height = math.abs(diff.y)
		local depth = math.abs(diff.z)

		-- LABENHANCED_PAIRED_MINING
		-- Prefer the long horizontal axis for strip tunnels. This keeps
		-- assigned stripes straight and reduces connector/path clutter.
		if width >= depth then
			orientation = (diff.x >= 0) and 3 or 1
		else
			orientation = (diff.z >= 0) and 0 or 2
		end
		
		
		local rowFactor = 3
		local levelFactor = 2
		local rowLength, rows, levels
		if orientation%2 == 0 then
			rowLength = depth
			rows = (width+rowFactor)/rowFactor
		else
			rowLength = width
			rows = (depth+rowFactor)/rowFactor
		end
		if diff.y < 0 then
			levels = math.floor(((-height-levelFactor)/levelFactor)+0.5)
		else
			levels = math.floor(((height+levelFactor)/levelFactor)+0.5)
		end
		
		rows = math.floor(rows+0.5)
		--self.map:load()
		
		print("start", start,"end",finish, "diff", diff, "levels", levels)
		self:updateProgress("stage", 0.01)

		local assignmentVars = self.currentTaskAssignment and self.currentTaskAssignment.vars or {}
		local sharedEntry = assignmentVars.sharedAccessEntry
		local sharedEnd = assignmentVars.sharedAccessEnd
		local accessEntry = assignmentVars.accessEntry
		local accessLeader = assignmentVars.accessLeader

		local reachedArea = false
		if sharedEntry then
			if not vars.accessComplete then
				reachedArea = self:reachSharedMineEntrance(sharedEntry,sharedEnd,accessEntry,accessLeader == true)
				if reachedArea then
					vars.accessComplete = true
					self.checkPointer:save(self)
				end
			else
				reachedArea = self:navigateOpenPathToPos((accessEntry or sharedEntry).x,(accessEntry or sharedEntry).y,(accessEntry or sharedEntry).z)
			end

			-- LABENHANCED_NO_PRIVATE_STRIPE_CONNECTOR
			-- The shared access spine now lands on an actual corner of every
			-- assigned stripe. Start mining from THAT corner. Never carve a
			-- turtle-specific connector from the shared road to some other start.
			if reachedArea then
				local entry = accessEntry or sharedEntry
				local b = assignedBounds
				local onXEdge = entry and (entry.x == b.minX or entry.x == b.maxX)
				local onZEdge = entry and (entry.z == b.minZ or entry.z == b.maxZ)

				if not entry or not onXEdge or not onZEdge then
					-- Old task groups used midpoint entries. Do not preserve that
					-- layout by drilling a private shortcut; require a freshly
					-- created group using corner entries.
					print("SHARED ENTRY IS NOT A STRIPE CORNER - REFUSING PRIVATE CONNECTOR")
					reachedArea = false
				else
					start = vector.new(entry.x,b.minY,entry.z)
					finish = vector.new(
						(entry.x == b.minX) and b.maxX or b.minX,
						b.maxY,
						(entry.z == b.minZ) and b.maxZ or b.minZ
					)

					local stripeDx = finish.x - start.x
					local stripeDz = finish.z - start.z
					if math.abs(stripeDx) >= math.abs(stripeDz) then
						orientation = (stripeDx >= 0) and 3 or 1
					else
						orientation = (stripeDz >= 0) and 0 or 2
					end

					if not sameAccessPos(self.pos,start) then
						reachedArea = self:navigateOpenPathToPos(start.x,start.y,start.z)
						if not reachedArea then
							print("NO OPEN SHARED ROUTE TO STRIPE START - NOT DIGGING A SHORTCUT")
						end
					end
				end
			end
		else
			-- Backward-compatible single-turtle/non-paired jobs: still prefer
			-- existing tunnels, then make one neat 1x2 approach instead of a
			-- generic 1x1 navigation tunnel.
			reachedArea = self:navigateOpenPathToPos(start.x,start.y,start.z)
			if not reachedArea then
				self:followExistingTunnelToward(start)
				reachedArea = self:digNeatAccessTunnelTo(start)
			end
		end

		if not reachedArea then
			self:returnHome()
			self:error("UNABLE TO GET TO AREA") -- resumable
		else
			-- The shared-spine corner may deliberately differ from the nearest
			-- corner chosen before travel. Recompute ALL mining geometry from
			-- the final start/finish so row direction and vertical direction
			-- cannot inherit stale values from the pre-access position.
			diff = finish - start
			width = math.abs(diff.x)
			height = math.abs(diff.y)
			depth = math.abs(diff.z)

			if width >= depth then
				orientation = (diff.x >= 0) and 3 or 1
			else
				orientation = (diff.z >= 0) and 0 or 2
			end

			if orientation%2 == 0 then
				rowLength = depth
				rows = (width+rowFactor)/rowFactor
			else
				rowLength = width
				rows = (depth+rowFactor)/rowFactor
			end
			if diff.y < 0 then
				levels = math.floor(((-height-levelFactor)/levelFactor)+0.5)
			else
				levels = math.floor(((height+levelFactor)/levelFactor)+0.5)
			end
			rows = math.floor(rows+0.5)

			self:turnTo(orientation)
			self:setActiveMiningBounds(start,finish)

			self:updateProgress("stage", 0.05)
			taskState.stage = 2
			taskState.ignorePosition = true
			self.checkPointer:save(self)

			self:stripMine(rowLength, rows, levels)

			-- LABENHANCED_FAR_EDGE_SPINE
			-- Turn the striped "comb" into one connected tunnel network at the
			-- far end as well. Each turtle only connects the far edge of its own
			-- assigned stripe; adjacent stripes meet naturally into one spine.
			if levels == 1 or levels == -1 then
				self:connectMiningFarEdge(start,finish,orientation)
			else
				print("FAR EDGE SPINE: MULTI-LEVEL JOB - CONNECTING BASE LEVEL ONLY")
				self:connectMiningFarEdge(start,finish,orientation)
			end
			
		end
	end

	-- Stage 2: Execute post-stripMine steps
	if taskState.stage == 2 then
		self.activeMiningBounds = nil

		self:updateProgress("stage", 0.96)
		self:returnHome()
		self:updateProgress("stage", 0.97)
		self:condenseInventory()
		self:updateProgress("stage", 0.98)
		self:dumpBadItems()
		self:updateProgress("stage", 0.99)
		self:transferItems()
		self:updateProgress("stage", 1)
		--self:getFuel()
		--self.map:save()
	end 

	self.taskList:remove(currentTask)
	self.checkPointer:save(self)
end


-- LABENHANCED_PHILOLITE_REPAIR
-- Philolite explodes when broken. Before mining it, snapshot the solid shell
-- surrounding the active 1x2 tunnel. After the blast, restore only shell blocks
-- which were solid before the explosion. Existing intersections/openings remain open.
local function philolitePosKey(pos)
	return pos.x .. "," .. pos.y .. "," .. pos.z
end

function Miner:rememberPhiloliteShellCell(interior, shellPos, side)
	local value = self:getMapValue(shellPos.x,shellPos.y,shellPos.z)
	if value == nil or value == 0 then return end

	self.philoliteRepairCells = self.philoliteRepairCells or {}
	local key = philolitePosKey(interior)
	local cell = self.philoliteRepairCells[key]
	if not cell then
		cell = {
			pos = vector.new(interior.x,interior.y,interior.z),
			sides = {},
		}
		self.philoliteRepairCells[key] = cell
	end
	cell.sides[side] = true
end

function Miner:capturePhiloliteTunnelShell(anchor, orientation)
	if not anchor or orientation == nil then return end
	local axis = self.vectors[orientation]
	local left = self.vectors[(orientation-1)%4]
	local right = self.vectors[(orientation+1)%4]

	-- Explosion strength is large enough to damage several adjacent tunnel cells.
	-- Snapshot a seven-block section centered on the active tunnel position.
	for offset=-3,3 do
		local p = anchor + axis * offset
		self:rememberPhiloliteShellCell(p, p + vectorDown, "floor")
		self:rememberPhiloliteShellCell(p, p + left, "leftLower")
		self:rememberPhiloliteShellCell(p, p + right, "rightLower")
		self:rememberPhiloliteShellCell(p, p + vectorUp * 2, "ceiling")
		self:rememberPhiloliteShellCell(p, p + vectorUp + left, "leftUpper")
		self:rememberPhiloliteShellCell(p, p + vectorUp + right, "rightUpper")
	end
end

function Miner:preparePhiloliteBlastRepair(blastPos)
	if self.activeTunnelAnchor and self.activeTunnelOrientation ~= nil then
		self:capturePhiloliteTunnelShell(self.activeTunnelAnchor,self.activeTunnelOrientation)

		-- If the Philolite is the next lower tunnel cell directly ahead, that
		-- cell has not been inspected from the inside yet. Its six shell faces
		-- are supposed to become solid tunnel lining, so remember them explicitly
		-- even when the pre-blast map has those neighbors as unknown.
		local axis = self.vectors[self.activeTunnelOrientation]
		local expected = self.activeTunnelAnchor + axis
		if blastPos.x == expected.x and blastPos.y == expected.y and blastPos.z == expected.z then
			local left = self.vectors[(self.activeTunnelOrientation-1)%4]
			local right = self.vectors[(self.activeTunnelOrientation+1)%4]
			self.philoliteRepairCells = self.philoliteRepairCells or {}
			local key = philolitePosKey(expected)
			local cell = self.philoliteRepairCells[key] or {
				pos = vector.new(expected.x,expected.y,expected.z),
				sides = {},
			}
			cell.sides.floor = true
			cell.sides.ceiling = true
			cell.sides.leftLower = true
			cell.sides.rightLower = true
			cell.sides.leftUpper = true
			cell.sides.rightUpper = true
			self.philoliteRepairCells[key] = cell
		end

		self.philoliteRepairPending = true
		print("PHILOLITE - tunnel repair queued")
	end
end

function Miner:rawInspectAndRepair(direction, shouldRepair)
	if not shouldRepair then return true end

	local hasBlock, data
	if direction == "up" then
		hasBlock, data = turtle.inspectUp()
	elseif direction == "down" then
		hasBlock, data = turtle.inspectDown()
	else
		hasBlock, data = turtle.inspect()
	end

	if hasBlock and data and data.name ~= "minecraft:lava" then
		return true
	end

	local ok
	if direction == "up" then
		ok = self:placeBlockUp(veinBackfillItem)
	elseif direction == "down" then
		ok = self:placeBlockDown(veinBackfillItem)
	else
		self:updateLookingAt()
		ok = self:placeBlock(veinBackfillItem)
	end
	return ok == true
end

function Miner:repairPhiloliteShellCell(cell, orientation)
	if not cell or self.pos ~= cell.pos then return false end
	if not self:getTunnelMaterialSlot() then return false end

	local sides = cell.sides or {}
	local startOrientation = self.orientation

	-- Lower tunnel cell: floor and side walls.
	self:rawInspectAndRepair("down", sides.floor)

	self:turnTo(orientation-1)
	self:rawInspectAndRepair("front", sides.leftLower)
	self:turnTo(orientation+1)
	self:rawInspectAndRepair("front", sides.rightLower)
	self:turnTo(orientation)

	-- Keep the upper interior cell open. Explosion debris/falling blocks should
	-- not turn a 1x2 tunnel back into 1x1.
	local hasAbove, aboveData = turtle.inspectUp()
	if hasAbove then
		local aboveName = aboveData and aboveData.name
		if aboveName == "minecraft:lava" then
			local placed = self:placeBlockUp(veinBackfillItem)
			if placed then
				turtle.digUp()
				self:setMapValue(self.pos.x,self.pos.y+1,self.pos.z,0)
			end
		elseif aboveName and not checkDisallowed(aboveName) then
			if turtle.digUp() then
				self:setMapValue(self.pos.x,self.pos.y+1,self.pos.z,0)
			end
		end
	end

	-- Move into the upper interior without triggering refuel/offload checks.
	local lower = vector.new(self.pos.x,self.pos.y,self.pos.z)
	if turtle.up() then
		self:setMapValue(lower.x,lower.y,lower.z,0)
		self.pos.y = self.pos.y + 1
		self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)

		self:turnTo(orientation-1)
		self:rawInspectAndRepair("front", sides.leftUpper)
		self:turnTo(orientation+1)
		self:rawInspectAndRepair("front", sides.rightUpper)
		self:turnTo(orientation)
		self:rawInspectAndRepair("up", sides.ceiling)

		if turtle.down() then
			self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)
			self.pos.y = self.pos.y - 1
			self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)
		else
			print("PHILOLITE REPAIR: unable to return to lower tunnel cell")
			self:turnTo(startOrientation)
			return false
		end
	end

	self:turnTo(startOrientation)
	return true
end

function Miner:repairPhiloliteBlastDamage()
	if not self.philoliteRepairPending then return true end
	local cells = self.philoliteRepairCells
	if not cells then
		self.philoliteRepairPending = false
		return true
	end

	if not self:getTunnelMaterialSlot() then
		print("PHILOLITE BLAST - NO COBBLED DEEPSLATE FOR REPAIR")
		self.philoliteRepairCells = nil
		self.philoliteRepairPending = false
		return false
	end

	local returnPos = vector.new(self.pos.x,self.pos.y,self.pos.z)
	local returnOrientation = self.orientation
	local orientation = self.activeTunnelOrientation or returnOrientation
	local list = {}

	for _,cell in pairs(cells) do
		-- Repair only cells which are currently known as tunnel air. This avoids
		-- digging into untouched rock merely to reach a damaged shell section.
		if self:getMapValue(cell.pos.x,cell.pos.y,cell.pos.z) == 0 then
			table.insert(list,cell)
		end
	end

	table.sort(list,function(a,b)
		local da = math.abs(a.pos.x-returnPos.x)+math.abs(a.pos.y-returnPos.y)+math.abs(a.pos.z-returnPos.z)
		local db = math.abs(b.pos.x-returnPos.x)+math.abs(b.pos.y-returnPos.y)+math.abs(b.pos.z-returnPos.z)
		return da < db
	end)

	local repaired = 0
	for _,cell in ipairs(list) do
		if self.pos == cell.pos or self:navigateOpenPathToPos(cell.pos.x,cell.pos.y,cell.pos.z) then
			if self:repairPhiloliteShellCell(cell,orientation) then
				repaired = repaired + 1
			end
		end
	end

	if self.pos ~= returnPos then
		self:navigateOpenPathToPos(returnPos.x,returnPos.y,returnPos.z)
	end
	self:turnTo(returnOrientation)

	print("PHILOLITE REPAIR:",repaired,"tunnel cells checked")
	self.philoliteRepairCells = nil
	self.philoliteRepairPending = false
	return true
end


-- LABENHANCED_LAVA_TUNNEL
-- Keep a one-wide, two-high corridor usable when a strip tunnel crosses lava.
-- Cobbled deepslate is only placed where lava directly touches the corridor;
-- ordinary deepslate walls/floor/ceiling are left alone.
function Miner:getTunnelMaterialSlot()
	return self:findInventoryItem(veinBackfillItem)
end

function Miner:placeTunnelMaterial(side)
	if not self:getTunnelMaterialSlot() then
		return false, "NO_COBBLED_DEEPSLATE"
	end
	if side == "up" then
		return self:placeBlockUp(veinBackfillItem)
	elseif side == "down" then
		return self:placeBlockDown(veinBackfillItem)
	else
		self:updateLookingAt()
		return self:placeBlock(veinBackfillItem)
	end
end

function Miner:displaceLavaAhead()
	self:updateLookingAt()
	local block = self:getMapValue(self.lookingAt.x,self.lookingAt.y,self.lookingAt.z)
	if block == nil then block = self:inspect(true) end
	if block ~= "minecraft:lava" then return true end

	local ok = self:placeTunnelMaterial("front")
	if not ok then
		print("LAVA AHEAD - NO COBBLED DEEPSLATE TO DISPLACE IT")
		return false
	end

	-- Re-open the corridor cell after replacing the lava source.
	self:dig()
	return true
end

function Miner:sealLavaAtCurrentLayer(verticalBoundary)
	local startOrientation = self.orientation

	-- The lower tunnel cell owns the floor; the upper tunnel cell owns the
	-- ceiling. Never fill the open cell between the two tunnel levels.
	if verticalBoundary == "floor" then
		local below = self:inspectDown(true)
		if below == "minecraft:lava" then
			self:placeTunnelMaterial("down")
		end
	elseif verticalBoundary == "ceiling" then
		local above = self:inspectUp(true)
		if above == "minecraft:lava" then
			self:placeTunnelMaterial("up")
		end
	end

	-- Only seal the two side walls. Front/back remain the tunnel axis.
	for _,offset in ipairs({-1,1}) do
		self:turnTo(startOrientation + offset)
		local sideBlock = self:inspect(true)
		if sideBlock == "minecraft:lava" then
			self:placeTunnelMaterial("front")
		end
	end
	self:turnTo(startOrientation)
end

function Miner:maintainLavaTunnel()
	local startOrientation = self.orientation

	-- Lower half: side walls + floor, while keeping the upper interior open.
	self:sealLavaAtCurrentLayer("floor")

	-- If the upper interior cell is itself a lava source, replace it briefly
	-- with cobbled deepslate, then dig that block back out to create air.
	local above = self:inspectUp(true)
	if above == "minecraft:lava" then
		local ok = self:placeTunnelMaterial("up")
		if ok then self:digUp() end
	end

	-- Temporarily move into the upper tunnel cell WITHOUT calling checkStatus().
	-- This lets us seal the upper side walls and ceiling without triggering
	-- refuel/offload logic halfway through tunnel maintenance.
	local oldPos = vector.new(self.pos.x,self.pos.y,self.pos.z)
	if turtle.up() then
		self:setMapValue(oldPos.x,oldPos.y,oldPos.z,0)
		self.pos.y = self.pos.y + 1
		self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)

		self:sealLavaAtCurrentLayer("ceiling")

		if turtle.down() then
			self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)
			self.pos.y = self.pos.y - 1
			self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)
		else
			print("WARNING: COULD NOT RETURN TO LOWER TUNNEL CELL")
		end
	end

	self:turnTo(startOrientation)
end


-- LABENHANCED_OPTIMIZED_TUNNEL_SCAN
-- The previous contained-mining build scanned the 1x2 tunnel shell twice per
-- block: once for exposed ores and again for lava. That doubled rotations,
-- inspections and up/down movement. This pass handles BOTH in one physical
-- shell scan while preserving the same fair-mining and lava behavior.
-- LABENHANCED_AUTO_TORCHES
function Miner:countTunnelTorches()
	local count = 0
	for slot=1,default.inventorySize do
		local data = turtle.getItemDetail(slot)
		if data and data.name == tunnelTorchItem then
			count = count + data.count
		end
	end
	return count
end

function Miner:placeTunnelTorchNiche(side)
	-- Put a standing torch in a one-block recess beside the UPPER half of the
	-- 1x2 tunnel. The lower travel lane remains completely unobstructed.
	local slot = self:findInventoryItem(tunnelTorchItem)
	if not slot then
		if not self.torchEmptyWarned then
			print("OUT OF TORCHES - CONTINUING WITHOUT LIGHTING")
			self.torchEmptyWarned = true
		end
		return false
	end

	local startOrientation = self.orientation
	local startSlot = turtle.getSelectedSlot()
	local lowerY = self.pos.y

	-- The upper tunnel cell must be open; never dig upward just to place light.
	local blockedUp = turtle.inspectUp()
	if blockedUp or not turtle.up() then
		self:turnTo(startOrientation)
		self:select(startSlot)
		return false
	end
	-- Temporary placement movement is not a navigable road edge.
	self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)
	self.pos.y = self.pos.y + 1
	self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)

	local sideOffset = (side or -1) < 0 and -1 or 1
	self:turnTo(startOrientation + sideOffset)

	-- Only carve a torch recess into a real wall. If this side is already open
	-- (intersection/cave), skip it rather than placing a torch in travel space.
	local hasWall,wallData = turtle.inspect()
	local wallName = hasWall and wallData and wallData.name or nil
	local placed = false

	if hasWall and not checkDisallowed(wallName) then
		self.allowTorchNicheDig = true
		local dug = self:dig()
		self.allowTorchNicheDig = false

		if dug then
			self:select(slot)
			placed = turtle.place()
			local target = self.pos + self.vectors[self.orientation]
			if placed then
				self:setMapValue(target.x,target.y,target.z,tunnelTorchItem)
				print("TORCH",sideOffset < 0 and "LEFT" or "RIGHT",
					"remaining",self:countTunnelTorches())
			else
				-- Keep the tunnel wall neat if the torch itself could not be placed.
				if self:getTunnelMaterialSlot() then
					self:placeBlock(veinBackfillItem)
				end
			end
		end
	end

	self:turnTo(startOrientation)

	-- Return to the lower travel lane. A teammate below is traffic, not a block
	-- to mine; give it a brief chance to clear.
	local returned = false
	for _=1,20 do
		if turtle.down() then
			self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)
			self.pos.y = self.pos.y - 1
			self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)
			returned = true
			break
		end
		local hasDown,data = turtle.inspectDown()
		if hasDown and not isTurtleBlockId(data and data.name) then break end
		sleep(0.25)
	end

	self:turnTo(startOrientation)
	self:select(startSlot)

	if not returned or self.pos.y ~= lowerY then
		error("TORCH NICHE: COULD NOT RETURN TO LOWER TUNNEL CELL",0)
	end

	if placed then
		self.tunnelTorchSide = -sideOffset
		self.tunnelTorchSteps = 0
	end
	return placed
end

function Miner:maybePlaceTunnelTorch()
	if not self.autoTunnelTorches then return false end
	self.tunnelTorchSteps = (self.tunnelTorchSteps or 0) + 1
	if self.tunnelTorchSteps < tunnelTorchSpacing then return false end
	return self:placeTunnelTorchNiche(self.tunnelTorchSide or -1)
end

function Miner:inspectTunnelShellFace(direction, allowOre)
	local hasBlock, data
	local target

	if direction == "down" then
		target = vector.new(self.pos.x,self.pos.y-1,self.pos.z)
		hasBlock, data = turtle.inspectDown()
	elseif direction == "up" then
		target = vector.new(self.pos.x,self.pos.y+1,self.pos.z)
		hasBlock, data = turtle.inspectUp()
	else
		self:updateLookingAt()
		target = vector.new(self.lookingAt.x,self.lookingAt.y,self.lookingAt.z)
		hasBlock, data = turtle.inspect()
	end

	local name = hasBlock and data and data.name or 0
	self:setMapValue(target.x,target.y,target.z,name)

	-- Lava protection takes priority: replace the touching lava cell with
	-- cobbled deepslate so the maintained corridor remains dry.
	if name == "minecraft:lava" then
		if direction == "down" then
			return self:placeTunnelMaterial("down")
		elseif direction == "up" then
			return self:placeTunnelMaterial("up")
		else
			return self:placeTunnelMaterial("front")
		end
	end

	-- Fair ore mining: only mine a block physically touching this tunnel cell.
	-- Never move into the ore hole and never search through the map for more ore.
	if allowOre and hasBlock and checkOreBlock(name)
	and self:isInsideActiveMiningBounds(target) then
		local dug = false
		if direction == "down" then
			dug = self:digDown()
		elseif direction == "up" then
			dug = self:digUp()
		else
			dug = self:dig()
		end

		if dug and self:getTunnelMaterialSlot() then
			if direction == "down" then
				self:placeBlockDown(veinBackfillItem)
			elseif direction == "up" then
				self:placeBlockUp(veinBackfillItem)
			else
				self:placeBlock(veinBackfillItem)
			end
		end
		return dug
	end

	return true
end

function Miner:maintainAndInspectTunnelCell(allowOre)
	-- LABENHANCED_TUNNEL_FLOOR_LOCK
	-- Invariant: this routine must always finish on the SAME lower tunnel cell
	-- it started on. Access/spine tunnels use noInspect=true, so they never need
	-- to physically climb into the upper air cell just to inspect ore.
	local startOrientation = self.orientation
	local lowerPos = vector.new(self.pos.x,self.pos.y,self.pos.z)

	-- Lower floor + side walls: one inspection each, handling ore OR lava.
	self:inspectTunnelShellFace("down",allowOre)

	self:turnTo(startOrientation-1)
	self:inspectTunnelShellFace("front",allowOre)
	self:turnTo(startOrientation+1)
	self:inspectTunnelShellFace("front",allowOre)
	self:turnTo(startOrientation)

	-- The upper interior itself must stay air. Lava is displaced with cobbled
	-- deepslate and then re-opened; unexpected mineable solids are cleared.
	local hasAbove, aboveData = turtle.inspectUp()
	local aboveName = hasAbove and aboveData and aboveData.name or 0
	self:setMapValue(self.pos.x,self.pos.y+1,self.pos.z,aboveName)
	if aboveName == "minecraft:lava" then
		local placed = self:placeBlockUp(veinBackfillItem)
		if placed then self:digUp() end
	elseif hasAbove and not checkDisallowed(aboveName) then
		self:digUp()
	end

	-- Access connectors/spines are no-inspect tunnels. Their only requirement is
	-- a clear 1x2 interior; do NOT climb into the upper cell. This removes the
	-- failure mode where another turtle/falling block occupies the lower cell and
	-- the leader accidentally continues tunnelling one block too high.
	if not allowOre then
		self:turnTo(startOrientation)
		self:repairPhiloliteBlastDamage()
		return true
	end

	-- Normal strip mining still scans upper side walls + ceiling for exposed ore.
	-- If we climb, returning to lowerPos is mandatory before continuing.
	if turtle.up() then
		self:setMapValue(lowerPos.x,lowerPos.y,lowerPos.z,0)
		self.pos.y = self.pos.y + 1
		self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)

		self:turnTo(startOrientation-1)
		self:inspectTunnelShellFace("front",allowOre)
		self:turnTo(startOrientation+1)
		self:inspectTunnelShellFace("front",allowOre)
		self:turnTo(startOrientation)
		self:inspectTunnelShellFace("up",allowOre)

		local returned = false
		for attempt=1,20 do
			if turtle.down() then
				self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)
				self.pos.y = self.pos.y - 1
				self:setMapValue(self.pos.x,self.pos.y,self.pos.z,0)
				returned = true
				break
			end

			local blocked,data = turtle.inspectDown()
			local name = blocked and data and data.name or nil

			if isTurtleBlockId(name) then
				if attempt == 1 then
					print("TUNNEL SCAN: turtle below - waiting to return")
				end
				sleep(0.25)
			elseif blocked and not checkDisallowed(name) then
				-- The lower interior was known air when we climbed. Falling
				-- gravel/sand or another safe mineable block may have entered it.
				-- Re-open that interior cell, never the floor below it.
				self:digDown()
				sleep(0.1)
			else
				sleep(0.25)
			end
		end

		if not returned then
			-- Never silently continue from y+1. A hard stop is safer than
			-- shifting the entire mining/access tunnel to the wrong level.
			self:turnTo(startOrientation)
			error("TUNNEL SCAN LOWER CELL BLOCKED",0)
		end
	end

	self:turnTo(startOrientation)
	self:repairPhiloliteBlastDamage()
	return true
end

function Miner:tunnel(length, direction, noInspect)
	-- throws error
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	
	local result = true
	local skipSteps = 0
	
	-- noInspect default false: look for and mine ore veins while tunneling

	-- determine direction to mine
	local directionVector, digFunc

	if not direction or direction == "straight" then 
		directionVector = self.vectors[self.orientation]
		digFunc = Miner.digMove
	elseif direction == "up" then
		directionVector = vectorUp
		digFunc = Miner.digMoveUp
	elseif direction == "down" then
		directionVector = vectorDown
		digFunc = Miner.digMoveDown
	end
	
	local expectedEndPos = self.pos + directionVector * length
	local startOrientation = self.orientation
	local previousTunnelAnchor = self.activeTunnelAnchor
	local previousTunnelOrientation = self.activeTunnelOrientation
	if not direction or direction == "straight" then
		self.activeTunnelOrientation = startOrientation
	end

	self:addProgressLevel("tunnel", length, "Blocks") -- Remove later?

	-- Scan the starting tunnel cell once. Every newly-created cell is scanned
	-- once after entering it below, so no cell needs the old duplicate pass.
	if not direction or direction == "straight" then
		self.activeTunnelAnchor = vector.new(self.pos.x,self.pos.y,self.pos.z)
		self:maintainAndInspectTunnelCell(not noInspect)
	end
	
	-- actually mine
	for i=1,length do
		if skipSteps == 0 then 
		
			if not direction or direction == "straight" then
				self.activeTunnelAnchor = vector.new(self.pos.x,self.pos.y,self.pos.z)
				self:displaceLavaAhead()
			end
			local moved,_,moveReason = digFunc(self)
			if not moved and moveReason == "traffic" then
				-- LABENHANCED_COOP_MINING_TRAFFIC
				-- We should not queue behind another working turtle. Use the
				-- open 2-high headspace as a passing/yield bay, then retry once.
				local yielded = self:yieldForTurtleTraffic(4)
				if yielded then
					moved,_,moveReason = digFunc(self)
				else
					-- If we could not safely rejoin the floor lane, do not ever
					-- continue mining from the upper cell.
					self.lastNavigationFailureReason = "traffic_jam_timeout"
					result = false
					break
				end
			end
			if not moved then
				-- If the step still cannot be made, only use already-open roads
				-- for recovery. No collision recovery is allowed to dig a bypass.
				if i < length - 1 then
					local newPos = self.pos + directionVector * 2
					if not self:navigateOpenPathToPos(newPos.x, newPos.y, newPos.z) then
						result = false
						break
					else 
						self:turnTo(startOrientation)
						skipSteps = 2
						--skip the next step as well
					end
				else
					result = false
					break
				end
			end
		else
			skipSteps = skipSteps - 1
		end

		-- LABENHANCED_2HIGH_TUNNELS
		-- Horizontal mining tunnels are kept two blocks tall.
		if not direction or direction == "straight" then
			local above = self:inspectUp(true)
			if above and not checkDisallowed(above) then
				self:digUp()
			end
			self.activeTunnelAnchor = vector.new(self.pos.x,self.pos.y,self.pos.z)
			self:maintainAndInspectTunnelCell(not noInspect)
			if self.autoTunnelTorches and not noInspect then
				self:maybePlaceTunnelTorch()
			end
		end

		self:updateProgress("tunnel", i)
	end
	
	if self.philoliteRepairPending then
		self:repairPhiloliteBlastDamage()
	end
	
	if self.pos ~= expectedEndPos then
		-- Only recover through known open tunnel cells. Never drill a 1x1
		-- correction tunnel after a mining row finishes.
		if not self:navigateOpenPathToPos(expectedEndPos.x, expectedEndPos.y, expectedEndPos.z) then
			-- we truly failed
			result = false
		else 
			result = true
		end
		self:turnTo(startOrientation)
	end
	
	self.activeTunnelAnchor = previousTunnelAnchor
	self.activeTunnelOrientation = previousTunnelOrientation
	self.taskList:remove(currentTask)
	
	if not result then error("TUNNEL FAIL", 0) end
	return result
	
end

function Miner:tunnelStraight(length, noInspect)
	local result = self:tunnel(length,"straight", noInspect)
	return result
end

function Miner:tunnelUp(height, noInspect)
	local result = self:tunnel(height,"up", noInspect)
	return result
end

function Miner:tunnelDown(height, noInspect)
	local result = self:tunnel(height,"down", noInspect)
	return result
end

function Miner:inspectMine()
	-- useless function
	self:mineVein()
	return
end


function Miner:excavateArea(start, finish)
	-- similar to mineArea, but digs out everything
	-- works but does a lot of unnecessary inspecting -> slow
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name}, true)

	local taskState = currentTask.taskState
	if taskState then
		start, finish = tableunpack(taskState.args,1,taskState.args.n)
	else
		taskState = {
			stage = 1,
			ignorePosition = true,
			vars = {
			},
			args = tablepack(start, finish),
		}
	end
	local vars = taskState.vars
	currentTask.taskState = taskState
	self.checkPointer:save(self)


	if taskState.stage == 1 then

		local orientation
		start, finish, orientation = self:getAreaStart(start, finish)

		local diff = finish - start
		local width = math.abs(diff.x) + 1
		local height = math.abs(diff.y) + 1
		local depth = math.abs(diff.z) + 1
		
		local rowLength, rows, levels
		if orientation%2 == 0 then
			rowLength = depth
			rows = width
		else
			rowLength = width
			rows = depth
		end
		if diff.y < 0 then
			levels = -height
		else
			levels = height
		end
		rowLength = rowLength - 1

		print("start", start,"end",finish, "diff", diff, "levels", levels)
		
		if not self:navigateToPos(start.x, start.y, start.z) then
			print("unable to get to area")
			self:returnHome()
			-- save checkpoint, tasklist remove
			-- error? could resume after error?
			self.checkPointer:save(self) -- next time turtle will try again
			self:error("UNABLE TO REACH AREA")
		else
		
			self:turnTo(orientation)
			
			taskState.stage = 2
			taskState.ignorePosition = true
			self.checkPointer:save(self)

			local rowFactor, levelFactor, offset = 1, 1, 0
			local noInspect = true -- excavate does not need inspecting
			self:stripMine(rowLength, rows, levels, rowFactor, levelFactor, offset, noInspect)
			
		end
	end

	-- Stage 2: Execute post-excavation steps
	if taskState.stage == 2 then
		self:returnHome()
		self:condenseInventory()
		self:dumpBadItems()
		self:transferItems()
		--self:getFuel()
	end 

	self.taskList:remove(currentTask)
	self.checkPointer:save(self)

end




-- LABENHANCED_TUNNEL_REMAP
-- Compatibility entry point used by the existing start-tunnel-remap scripts.
-- The v8 implementation delegates to the controller-authoritative Mapper.
function Miner:remapTunnels(radius,maxCells)
	return self.tunnelMapper:mapNetwork(radius,maxCells)
end

function Miner:mapTunnelNetwork(radius,maxCells)
	return self.tunnelMapper:mapNetwork(radius,maxCells)
end

function Miner:recoverTurtle(id, pos)
	-- UNTESTED
	-- navigate to a turtle at pos, mine, place, reboot
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})
	print("recoverTurtle", id, "at", pos.x, pos.y, pos.z)

	local result = true

	local startPos = vector.new(self.pos.x, self.pos.y, self.pos.z)
	local startOrientation = self.orientation

	-- make sure inventory has at least one free slot
	if self:getEmptySlots() == 0 then
		self:condenseInventory()
		if self:getEmptySlots() == 0 then
			self:dumpBadItems() 
			if self:getEmptySlots() == 0 then
				-- cannot recover turtle
				-- self:error("NO FREE INVENTORY SLOTS TO RECOVER TURTLE")
				print("NO FREE INVENTORY SLOTS TO RECOVER TURTLE")
				result = false
			end
		end
	end

	-- somehow ping turtle? make sure its there using low level communication (automatic responses)
	-- self.node:lookup("turtlename")
	
	if not self:navigateToPos(pos.x, pos.y+1, pos.z) then
		print("UNABLE TO REACH TURTLE")
		--self:error("UNABLE TO REACH TURTLE")
		result = false
	else
		-- mine turtle
		local block = self:inspectDown(true)
		if block == "computercraft:turtle_normal" or
		   block == default.turtleName then
			self:digDown()
			sleep(1)
			self:checkMinedTurtle()
		else
			print("Block", block)
			-- self:error("NO TURTLE FOUND TO RECOVER")
			print("NO TURTLE FOUND TO RECOVER")
			result = false
		end
	end

	self:navigateToPos(startPos.x, startPos.y, startPos.z)
	self:turnTo(startOrientation)

	self.taskList:remove(currentTask)
	return result
end

--##############################################################
-- add to classMiner
--local PathFinderOld = require("classPathFinderOldTest")
function Miner:testPathfinding(distance)
	
	local goal
	if type(distance) == "number" then 
		goal = vector.new(self.pos.x + distance, self.pos.y, self.pos.z)
	else
		goal = distance 
	end
	
	self.map:setMaxChunks(800)
	local pathFinder = PathFinder()
	--local pathFinderOld = PathFinderOld()
	self.pf = pathFinder
	pathFinder.checkValid = checkSafe
	--pathFinderOld.checkValid = checkSafe
	local path = pathFinder:aStarPart(self.pos, self.orientation, goal , self.map, 10000)
	--local path = pathFinderOld:aStarPart(self.pos, self.orientation, goal , self.map, 10000)
end



function Miner:setNavigateTo(x,y,z)
	-- update the navigation goal from the outside
	if not self.navigationGoal then
		self.navigationGoal = vector.new(x,y,z)
	else 
		self.navigationGoal.x, self.navigationGoal.y, self.navigationGoal.z = x,y,z
	end
end

function Miner:navigateToPos(x,y,z)
	-- default miner navigation with safety override near goal
	local options = {
		safe = true,
		safeDistance = 3, -- within 3 blocks of goal, safety is ignored if block is not disallowed
	}
	local result = self:navigate(x,y,z, self.map, options)
	return result
end

function Miner:navigateInfrontOf(x,y,z,sameYLevel)
	-- navigate to a position in front of the target pos, keeping the target pos in sight
	local options = {
		safe = true,
		stepOffset = 1, -- stop 1 block away from goal
	}
	local result = self:navigate(x,y,z, self.map, options)

	-- idk if this should be part of navigate or not and controlled through options
	-- no we dont want navigate to be able to call itself recursively (except for returnHome)
	if result and sameYLevel and self.pos.y ~= y then

		local pathFinder = PathFinder()
		pathFinder.checkValid = options.checkValidFunc or checkSafe
		options.stepOffset = 0
		-- options.safeDistance = 1 ?

		local target = vector.new(x,y,z)
		local minLen = math.huge
		local candidates = {}

		for i = 0, 3 do
			local pos = target + vectors[i]
			local block = self:getMapValue(pos.x, pos.y, pos.z)
			if checkSafe(block) then
				-- before starting the navigation, choose the best block to navigate to
				-- for this use the least complex path
				local path = pathFinder:aStarPart(self.pos, self.orientation, pos, self.map, 10)
				local len = path and ( #path - 1 )
				if len and len < minLen then 
					minLen = len 
					table.insert(candidates, { pos = pos, len = len, path = path })
				end
			end
		end
		local triedCandidates = {}
		if #candidates > 0 then
			table.sort(candidates, function(a,b) return a.len < b.len end)
			for i ,candidate in ipairs(candidates) do
				local pos = candidate.pos
				-- instead of navigate, we can also try using followPath directly
				-- but that only works for the first candidate the others would need to be recalculated
				triedCandidates[pos.x .. pos.y .. pos.z] = true
				result = self:navigate(pos.x, pos.y, pos.z, self.map, options)
				--result = self:followPath(candidate.path, options.safe, self.map, options.stepOffset)
				if result then break end
			end
		else
			-- no candidates to get next to the block... thats rough, try anyways
			for i = 0, 3 do
				local pos = target + vectors[i]
				if not triedCandidates[pos.x .. pos.y .. pos.z] then
					result = self:navigate(pos.x, pos.y, pos.z, self.map, options)
					if result then break end
				end
			end
		end
		if not result then
			print("FAILED TO NAVIGATE IN FRONT OF TARGET ON SAME Y LEVEL")
		else
			self:turnToPos(x, y, z)
		end
	end
	return result
end

-- issues:
-- navigate is a safe function which does not mine decorative blocks
-- however some underground structures like the copper stuff have tuff bricks which results in
-- no path being found 

function Miner:navigate(x, y, z, map, options)
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})

	local result = true
	local goal = vector.new(x,y,z)
	self.navigationGoal = goal

	if not options then options = {} end

	local safe = options.safe == nil and true or options.safe
	local safeDistance = options.safeDistance or nil
	local maxDistance = options.maxDistance or default.pathfinding.maxDistance
	local stepOffset = options.stepOffset or 0 -- how many steps away from goal to stop

	local checkValidFunc = options.checkValidFunc or checkSafe
	local followFunc = options.followFunc or function(path, safe, map, stepOffset) 
		local result = self:followPath(path, safe, map, stepOffset)
		return result -- to not upset debug.getinfo
	end
	local updateGoalFunc = options.updateGoalFunc or nil
	

	local checkGoal = function()
		local diff = self.pos - goal
		local moves = math.abs(diff.x) + math.abs(diff.y) + math.abs(diff.z)
		return moves <= stepOffset
	end

	if not checkGoal() then

		-- calculate how many tries are allowed
		local diff = self.pos - goal
		local cost = math.abs(diff.x) + math.abs(diff.y) + math.abs(diff.z)
		local maxTries = cost / 2
		if maxTries < 15 then maxTries = default.pathfinding.maxTries end -- how many tries for navigation are allowed
		local maxParts = ( cost / maxDistance ) * 2  -- into how many sub-problems the navigation is split
		if maxParts < 2 then maxParts = default.pathfinding.maxParts end
		local tryCount = 0
		local minDist = math.huge
		local mapReset = false
		
		
		local pathFinder = PathFinder()
		pathFinder.checkValid = checkValidFunc
		
		repeat
			tryCount = tryCount + 1
			local partsCount = 0
			repeat 
				partsCount = partsCount + 1

				if updateGoalFunc then
					local oldGoal = goal
					goal = updateGoalFunc(oldGoal)
					if goal ~= oldGoal then
						print("UPDATED GOAL", oldGoal, "->", goal)
						tryCount, partsCount = 0, 0
						minDist = math.huge
					end
					self.navigationGoal = goal
				end

				
				local path = pathFinder:aStarPart(self.pos, self.orientation, goal, map, maxDistance)

				local movesToGoal
				if safeDistance and safeDistance > 0 then
					-- check near goal, and path leads to goal
					-- if path and path[#path].pos == goal and #path < safeDistance + 3 then -- keep eye on this ordeal
					movesToGoal = math.abs(self.pos.x - goal.x) + math.abs(self.pos.y - goal.y) + math.abs(self.pos.z - goal.z)
					if movesToGoal <= safeDistance then
						if not checkDisallowed(self:getMapValue(goal.x, goal.y, goal.z)) then
							if safe then print("OVERRIDE SAFETY", movesToGoal) end
							safe = false
						end
					end
				end

				if path then 
					if not followFunc(path,safe,map,stepOffset) then 
						result = false
					else 
						if checkGoal() then
							result = true
						else
							result = false

							-- check if the goal can be reached
							local cp = self.pos
							local dist = math.abs(cp.x - goal.x) + math.abs(cp.y - goal.y) + math.abs(cp.z - goal.z)
							--print("min", minDist, "dist", dist, "try", tryCount, "part", partsCount)
							
							if dist < minDist then
								minDist = dist
							elseif dist >= minDist and tryCount > 1 then 
								-- we overshot the target
								path = pathFinder:checkPossible(self.pos, self.orientation, goal, map, nil, not mapReset)
								if not path then 
									
									if not mapReset then 
										mapReset = true
										partsCount = 0
										tryCount = math.max(tryCount, maxTries/2)
									else
										-- path truly impossible
										print("IMPOSSIBLE GOAL", goal)
										
										if self.returningHome == false then 
											self:returnHome()
										end
										tryCount = maxTries
										partsCount = maxParts
										result = false -- return false otherwise will continue prev. task
									end
									
								else
									print("GOAL POSSIBLE", goal, #path)
									result = followFunc(path, safe, map, stepOffset)
								end
							end
						end
					end
				else
					-- dig to target
					safe = ( safeDistance and movesToGoal > safeDistance ) or safe
					if not self:digToPos(goal.x, goal.y, goal.z, safe) then
						print("NOT SAFE TO DIG TO POS")
						result = false
						partsCount = maxParts
						sleep(0.5) -- give other turtles a chance to move out the way
					else result = true end
				end
			until result == true or partsCount >= maxParts
		until result == true or tryCount >= maxTries
	end
	
	if not checkGoal() then result = false end
	if result == false then 
		print("NOT SAFE TO FOLLOW PATH AFTER MULTIPLE TRIES")
	end
	
	self.taskList:remove(currentTask)
	return result
end

function Miner:followPath(path, safe, map, stepOffset)
	-- safe function
	local currentTask = self:addCheckTask({debug.getinfo(1, "n").name})

	local result = true
	if safe == nil then safe = true end

	for i=1, #path-stepOffset do
		local step = path[i]
		if step.pos ~= self.pos  then
			local diff = step.pos - self.pos
			local upDown = 0

			local newOr = self:getTargetOrientation(step.pos.x, step.pos.y, step.pos.z)
			if not newOr then
				if diff.y < 0 then upDown = -1
				else upDown = 1 end
			end

			local block = map:getBlockName(step.pos.x, step.pos.y, step.pos.z)
			local moveBackwards = newOr and (newOr-2)%4 == self.orientation and block == 0

			-- inspect as much as possible without additional movement
			if i > 1 then
				if upDown ~= 1 then self:inspectUp() end
				if upDown ~= -1 then self:inspectDown() end
				if not newOr or newOr ~= self.orientation then self:inspect() end -- and not moveBackwards
			end

			if upDown > 0 then
				if not self:digMoveUp(safe) then result = false; break end
			elseif upDown < 0 then
				if not self:digMoveDown(safe) then result = false; break end
			else
				if moveBackwards then
					if not self:back() then
						self:turnInspect(newOr, false)
						if not self:digMove(safe) then result = false; break end
					end
				else
					self:turnInspect(newOr, false)
					if not self:digMove(safe) then result = false; break end
				end
			end
		end
	end

	if result and stepOffset > 0 then
		local lastStep = path[#path]
		if lastStep then 
			self:turnToPos(lastStep.pos.x, lastStep.pos.y, lastStep.pos.z)
		end
		-- print("FACING", lastStep.pos) -- !! could also be above or below
	end

	if result and #path > 0 then
		self:inspect()
		self:inspectUp()
		self:inspectDown()
	end

	--if not result and path[#path].pos == step.pos then
	--	self:error("GOAL IS BLOCKED")
	-- leads to infinite loop
	--end
	self.taskList:remove(currentTask)
	return result
end
-- add to classMiner
--local PathFinderOld = require("classPathFinderOldTest")
function Miner:testPathfinding(distance)
	
	local goal
	if type(distance) == "number" then 
		goal = vector.new(self.pos.x + distance, self.pos.y, self.pos.z)
	else
		goal = distance 
	end
	
	self.map:setMaxChunks(800)
	local pathFinder = PathFinder()
	--local pathFinderOld = PathFinderOld()
	self.pf = pathFinder
	pathFinder.checkValid = checkSafe
	--pathFinderOld.checkValid = checkSafe
	local path = pathFinder:aStarPart(self.pos, self.orientation, goal , self.map, 10000)
	--local path = pathFinderOld:aStarPart(self.pos, self.orientation, goal , self.map, 10000)
end





return Miner