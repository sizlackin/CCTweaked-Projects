-- Fake controller state for the emulator harness.
--
-- These mirror the SHAPES the real controller produces (method names, return
-- types) so the real UI classes run unmodified. None of it is real data and
-- none of it is ever written back to the live controller.

local M = {}

-- Same mapping as TaskGroup.statusToColor; kept here so a fake group colours
-- itself exactly like a real one.
local statusToColor = {
	new = colors.white,
	completed = colors.lightBlue,
	started = colors.green,
	partially_started = colors.yellow,
	resumed = colors.green,
	partially_resumed = colors.yellow,
	error = colors.red,
	cancelled = colors.orange,
	deleted = colors.gray,
}

local function vec(x, y, z) return { x = x, y = y, z = z } end

-- ---------------------------------------------------------------------------
-- Fake task group
-- ---------------------------------------------------------------------------

local Group = {}
Group.__index = Group

function Group.new(spec)
	local g = setmetatable({}, Group)
	g.id = spec.id
	g.taskName = spec.taskName or "mineArea"
	g.groupSize = spec.groupSize or 4
	g.status = spec.status or "started"
	g.activeTurtles = spec.active or 0
	g.progress = spec.progress            -- nil = untrackable
	g.uptime = spec.uptime or "00:00.00"
	g.area = spec.area
	g.tasks = {}
	return g
end

function Group:getStatus() return self.status end
function Group:getStatusColor() return statusToColor[self.status] or colors.white end
function Group:getActiveTurtles() return self.activeTurtles end
function Group:isActive()
	local s = self.status
	return s == "started" or s == "resumed"
		or s == "partially_started" or s == "partially_resumed"
end
function Group:isResumable() return self.status == "cancelled" end
function Group:getArea() return self.area end
function Group:getUptimeText() return self.uptime end

function Group:getProgress() return self.progress end
function Group:getProgressText()
	local p = self.progress
	return (p and string.format("%3d%%", math.floor(p * 100))) or ""
end

function Group:getAreaDetails()
	local a = self.area
	if not a then return end
	local minX, maxX = math.min(a.start.x, a.finish.x), math.max(a.start.x, a.finish.x)
	local minY, maxY = math.min(a.start.y, a.finish.y), math.max(a.start.y, a.finish.y)
	local minZ, maxZ = math.min(a.start.z, a.finish.z), math.max(a.start.z, a.finish.z)
	local start = vec(minX, minY, minZ)
	local finish = vec(maxX, maxY, maxZ)
	local focus = vec(minX + math.floor((maxX - minX) / 2), maxY,
		minZ + math.floor((maxZ - minZ) / 2))
	return start, finish, focus
end

-- ---------------------------------------------------------------------------
-- Scenarios. Deliberately awkward: the widest status, long task names, six
-- digit coordinates, 100%+ progress, a group with no area at all.
-- ---------------------------------------------------------------------------

M.scenarios = {
	default = {
		{ id = "28c2f0", status = "completed", taskName = "no task",
		  groupSize = 0, active = 0, progress = 1.0, uptime = "00:00.00",
		  area = { start = vec(0, 0, 0), finish = vec(0, 0, 0) } },
		{ id = "536e11", status = "cancelled", taskName = "mineArea",
		  groupSize = 4, active = 0, progress = 0.37, uptime = "03:58.85",
		  area = { start = vec(-91, -59, 692), finish = vec(-127, -59, 671) } },
		{ id = "3587aa", status = "partially_started", taskName = "mineArea",
		  groupSize = 4, active = 2, progress = 0.62, uptime = "08:18.15",
		  area = { start = vec(-91, -59, 692), finish = vec(-127, -59, 665) } },
		{ id = "89d9bc", status = "started", taskName = "mineArea",
		  groupSize = 4, active = 4, progress = 0.01, uptime = "00:09.75",
		  area = { start = vec(-129, -59, 722), finish = vec(-145, -59, 692) } },
	},
	-- Values chosen to break naive column widths.
	stress = {
		{ id = "ffffffff", status = "partially_resumed",
		  taskName = "mineAreaWithAVeryLongName", groupSize = 16, active = 12,
		  progress = 1.0, uptime = "123:45.67",
		  area = { start = vec(-30000, -64, -30000), finish = vec(30000, 319, 30000) } },
		{ id = "a", status = "error", taskName = "x", groupSize = 1, active = 0,
		  progress = 0, uptime = "00:00.00",
		  area = { start = vec(1, 2, 3), finish = vec(4, 5, 6) } },
		{ id = "noarea", status = "deleted", taskName = "returnHome",
		  groupSize = 2, active = 0, progress = nil, uptime = "00:01.00",
		  area = nil },
	},
	empty = {},
}

-- ---------------------------------------------------------------------------

function M.buildGlobal(say, scenarioName)
	local scenario = M.scenarios[scenarioName or "default"] or M.scenarios.default

	local groups = {}
	for _, spec in ipairs(scenario) do
		groups[spec.id] = Group.new(spec)
	end
	if say then say("fake groups: %d (scenario %s)", #scenario, scenarioName or "default") end

	local nextId = 0
	local taskManager
	taskManager = {
		groups = groups,
		getGroups = function(self) return groups end,
		getTasks = function(self) return {} end,
		createGroup = function(self)
			nextId = nextId + 1
			local g = Group.new({ id = "new" .. nextId .. "abcd", status = "new",
				taskName = nil, groupSize = 4, active = 0 })
			g.setGroupSize = function(self2, n) self2.groupSize = math.max(1, n) end
			g.setFunction = function() end
			g.start = function() end
			return g
		end,
	}

	local g = {
		running = true,
		displaying = true,
		printStatus = false,
		printMainTime = false,
		printEvents = false,
		printDisplayTime = false,
		printSend = false,
		printSendTime = false,
		pos = vec(0, 64, 0),
		floatPos = vec(0, 64, 0),
		turtles = {},
		alerts = {},
		taskGroups = groups,
		taskManager = taskManager,
		node = nil,
		map = nil,
		storage = nil,
	}
	return g
end

M.config = {
	get = function() return nil end,
	set = function() end,
}

return M
