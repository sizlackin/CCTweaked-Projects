-- Renders one Actually Useful Turtles screen inside CraftOS-PC and screenshots it.
--
-- Run through ./tools/emulate, which mounts the repo's source directories at
-- /src/* read-only and passes the screen name in as an argument.
--
-- Nothing here touches the live controller: the repo is mounted read-only and
-- the emulated computer keeps its own scratch data directory.

local screen, scenario, keep = ...
screen = screen or "groups"
scenario = scenario or "default"
keep = (keep == "keep")

-- patches/ first so customised classes win over the upstream copies
package.path = table.concat({
	"/emu/?.lua",
	"/src/patch/?.lua",
	"/src/tunnelnav/?.lua",
	"/src/general/?.lua",
	"/src/gui/?.lua",
	"/src/host/?.lua",
	"/src/storage/?.lua",
	package.path,
}, ";")

local log = fs.open("/harness.log", "w")
local function say(fmt, ...)
	local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
	log.writeLine(msg)
	log.flush()
end

say("screen=%s scenario=%s", screen, scenario)

-- ---------------------------------------------------------------------------
-- Fake runtime state. The UI classes read a module-level `global`, so it has to
-- exist before they are required. Values mirror the shapes the real controller
-- produces, not real data.
-- ---------------------------------------------------------------------------

local fakes = require("fakes")
_G.global = fakes.buildGlobal(say, scenario)
_G.global.__stage = scenario
-- CraftOS-PC provides its own `config` API, so this must overwrite rather than
-- defer to it - the UI expects the controller's config table (stations etc).
_G.config = fakes.config

-- ---------------------------------------------------------------------------
-- Render
-- ---------------------------------------------------------------------------

local Monitor = require("classMonitor")

local function render()
	local monitor = Monitor:new(term.current())

	local screens = require("screens")
	local build = screens[screen]
	if not build then
		error("unknown screen '" .. tostring(screen) .. "' - have: "
			.. table.concat(screens.names(), ", "), 0)
	end

	local root = build(_G.global, say)
	monitor:addObject(root)
	monitor:redraw()
	monitor:update()
	return monitor
end

local ok, monitor = pcall(render)
local err = monitor
if not ok then
	say("RENDER FAILED: %s", tostring(err))
	-- leave the message on screen too so the screenshot shows it
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.red)
	term.clear()
	term.setCursorPos(1, 1)
	local text = tostring(err)
	local w = term.getSize()
	local row = 1
	while #text > 0 and row < 20 do
		term.setCursorPos(1, row)
		term.write(text:sub(1, w))
		text = text:sub(w + 1)
		row = row + 1
	end
else
	say("render ok")
end

sleep(0.6)          -- let the renderer present a frame before capturing
term.screenshot()   -- lands in <datadir>/screenshots/<timestamp>.png
sleep(0.6)

if keep and ok and monitor then
	-- Leave the preview on screen until it is closed. Events are forwarded the
	-- same way host/display.lua does it, so buttons actually respond; a handler
	-- that reaches for state the harness does not fake must not kill the window,
	-- hence the pcall.
	say("preview open - close the window when done")
	log.close()
	while true do
		local e = { os.pullEventRaw() }
		if e[1] == "terminate" then break end
		if e[1] == "mouse_click" or e[1] == "mouse_up" or e[1] == "mouse_drag"
			or e[1] == "mouse_scroll" or e[1] == "term_resize" then
			pcall(function()
				monitor:addEvent(e)
				monitor:checkEvents()
				monitor:update()
			end)
		end
	end
	os.shutdown()
end

say("done")
log.close()
os.shutdown()
