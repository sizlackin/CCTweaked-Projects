-- Furnace stats: a label row plus a live fill bar for every furnace
-- slot, with long item names scrolling sideways in place.
--
-- Three ways to run it:
--   furnacestats          draw to monitors this computer can reach
--                         directly or over a wired modem network
--   furnacestats host     the same, and also broadcast the stats over
--                         a wireless modem
--   furnacestats client   draw stats received from a host over a
--                         wireless modem (run this on a computer next
--                         to the remote monitor)
--
-- Wireless modems cannot share peripherals, so a far-away monitor
-- needs its own computer running `client`. Copy this file to it.

-- ---------------------------------------------------------------- config

-- Host/local: one entry per furnace. `monitor` may be nil only when
-- there is a single entry, in which case any monitor found is used.
-- Use `monitor = false` for a furnace you only want to broadcast.
local DISPLAYS = {
    { title = "FURNACE", furnace = "front", monitor = nil, reader = nil, scale = 0.5 },

    -- Add more furnaces by wiring each one and its monitor to the
    -- network with wired modems, then listing the pair here:
    -- { title = "FURNACE 2", furnace = "minecraft:furnace_1", monitor = "monitor_1" },
    -- { title = "SMELTER",   furnace = "minecraft:blast_furnace_0", monitor = false,
    --   reader = "blockReader_0" },
}

-- Client: which monitor to draw on (nil = any found) and which furnace
-- to show (nil = the first one heard from, which is right when the host
-- only has one).
local CLIENT_MONITOR = nil
local CLIENT_WATCH = nil
local CLIENT_SCALE = 0.5

local PROTOCOL = "furnacestats"
local STALE_AFTER = 10 -- seconds without an update before saying so

local HEADER_BG = colors.lightGray
local HEADER_FG = colors.black
local TRACK_COLOR = colors.gray

local SCROLL_INTERVAL = 0.4 -- seconds per character step
local POLL_INTERVAL = 1.2 -- seconds between furnace reads / broadcasts
local SCROLL_GAP = "   " -- separates the end of a name from its repeat
local SCROLL_HOLD = 3 -- frames to pause at the start of a name

local SLOTS = {
    { slot = 1, label = "In", color = colors.lightBlue },
    { slot = 2, label = "Fuel", color = colors.orange },
    { slot = 3, label = "Out", color = colors.lime },
}

-- ---------------------------------------------------------------- helpers

local function fit(text, width)
    if #text > width then
        return text:sub(1, width)
    end
    return text
end

local function centered(text, w)
    return fit((" "):rep(math.max(math.floor((w - #text) / 2), 0)) .. text .. (" "):rep(w), w)
end

local function listPeripherals()
    print("Attached peripherals:")
    for _, name in ipairs(peripheral.getNames()) do
        print(("  %s (%s)"):format(name, table.concat({ peripheral.getType(name) }, ", ")))
    end
end

-- rednet needs the modem's name, and only a wireless one can carry it.
local function openWirelessModem()
    local found
    peripheral.find("modem", function(name, modem)
        if not found and modem.isWireless() then
            found = name
        end
    end)
    if not found then
        listPeripherals()
        error("No wireless modem attached -- wired modems cannot carry rednet", 0)
    end
    rednet.open(found)
    return found
end

-- ---------------------------------------------------------------- drawing

-- Characters left for the item name once the label and count are placed.
local function nameWidth(section, w)
    return math.max(w - #section.label - #tostring(section.value) - 2, 0)
end

-- Marquee window into the name, restarting whenever the item changes.
local function scrolledName(display, section, width)
    local state = display.scroll[section.label]
    if not state or state.name ~= section.name then
        state = { name = section.name, offset = 0, hold = 0 }
        display.scroll[section.label] = state
    end

    if #section.name <= width then
        state.offset, state.hold = 0, 0
        return section.name
    end

    local padded = section.name .. SCROLL_GAP
    return (padded .. padded):sub(state.offset + 1, state.offset + width)
end

local function advanceScroll(display)
    if not display.mon or not display.sections then
        return
    end
    local w = display.mon.getSize()
    for _, section in ipairs(display.sections) do
        local state = display.scroll[section.label]
        if state and #section.name > nameWidth(section, w) then
            if state.offset == 0 and state.hold < SCROLL_HOLD then
                state.hold = state.hold + 1
            else
                state.offset = (state.offset + 1) % (#section.name + #SCROLL_GAP)
                if state.offset == 0 then
                    state.hold = 0
                end
            end
        end
    end
end

-- Every row is written as one full-width blit, so redraws overwrite the
-- previous frame instead of clearing it. Avoids flicker while scrolling.
local function blitRow(mon, y, text, fg, bg)
    mon.setCursorPos(1, y)
    mon.blit(text, fg, bg)
end

local function drawHeader(display, w)
    blitRow(display.mon, 1, centered(display.title, w),
        colors.toBlit(HEADER_FG):rep(w), colors.toBlit(HEADER_BG):rep(w))
end

-- Solid left-to-right bar: spaces tinted by their background color, so
-- the filled part reads as one block of color against a gray track.
local function drawBar(mon, y, fraction, color, w)
    local filled = math.floor(w * math.min(math.max(fraction, 0), 1) + 0.5)
    blitRow(mon, y, (" "):rep(w), colors.toBlit(color):rep(w),
        colors.toBlit(color):rep(filled) .. colors.toBlit(TRACK_COLOR):rep(w - filled))
end

-- Label and name on the left, count flush right so it never clips.
local function drawLabelRow(display, y, section, w)
    local value = tostring(section.value)
    local name = scrolledName(display, section, nameWidth(section, w))
    local left = fit(section.label .. " " .. name, math.max(w - #value, 0))
    local labelLen = math.min(#section.label, #left)

    blitRow(display.mon, y,
        left .. (" "):rep(w - #left - #value) .. value,
        colors.toBlit(section.color):rep(labelLen)
            .. colors.toBlit(colors.white):rep(#left - labelLen)
            .. colors.toBlit(colors.lightGray):rep(w - #left),
        colors.toBlit(colors.black):rep(w))
end

local function drawMessage(display, message)
    local w, h = display.mon.getSize()
    local blank, black = (" "):rep(w), colors.toBlit(colors.black):rep(w)
    local mid = math.max(math.floor(h / 2), 2)

    drawHeader(display, w)
    for y = 2, h do
        if y == mid then
            blitRow(display.mon, y, centered(message, w), colors.toBlit(colors.red):rep(w), black)
        else
            blitRow(display.mon, y, blank, black, black)
        end
    end
end

local function draw(display)
    if not display.mon then
        return
    end
    if not display.sections then
        drawMessage(display, display.emptyMessage or "NO FURNACE")
        return
    end

    local mon = display.mon
    local w, h = mon.getSize()
    local blank, black = (" "):rep(w), colors.toBlit(colors.black):rep(w)
    local sections = display.sections

    drawHeader(display, w)

    -- Space sections out only if every one of them still fits.
    local spacing = (1 + #sections * 3 <= h) and 1 or 0
    local y = 2

    for _, section in ipairs(sections) do
        drawLabelRow(display, y, section, w)
        drawBar(mon, y + 1, section.fraction, section.color, w)
        y = y + 2 + spacing
        if spacing > 0 and y - 1 <= h then
            blitRow(mon, y - 1, blank, black, black)
        end
    end

    while y <= h do
        blitRow(mon, y, blank, black, black)
        y = y + 1
    end
end

local function prepareMonitor(mon, scale)
    mon.setTextScale(scale or 0.5)
    mon.setBackgroundColor(colors.black)
    mon.clear()
end

-- ---------------------------------------------------------------- reading

local function readSections(display)
    local furnace = display.furnace
    if not furnace then
        return nil
    end

    local ok, sections = pcall(function()
        local result = {}
        for _, config in ipairs(SLOTS) do
            local item = furnace.getItemDetail(config.slot)
            local limit = item and (item.maxCount or furnace.getItemLimit(config.slot) or 64) or 1
            result[#result + 1] = {
                label = config.label,
                color = config.color,
                name = item and (item.displayName or item.name) or "empty",
                value = item and item.count or 0,
                fraction = item and item.count / limit or 0,
            }
        end
        return result
    end)
    if not ok then
        return nil
    end

    if display.reader then
        local readOk, data = pcall(display.reader.getBlockData)
        if readOk and data then
            local burning = (data.BurnTime or 0) > 0
            local cookTime, cookTotal = data.CookTime or 0, data.CookTimeTotal or 0
            local fraction = cookTotal > 0 and cookTime / cookTotal or 0
            sections[#sections + 1] = {
                label = "Cook",
                color = burning and colors.orange or TRACK_COLOR,
                name = burning and "burning" or "idle",
                value = math.floor(fraction * 100) .. "%",
                fraction = fraction,
            }
        end
    end

    return sections
end

-- Resolve one configured pair into wrapped peripherals, or a reason why not.
local function resolveDisplay(config, total)
    local mon
    if config.monitor == false then
        mon = nil -- broadcast only, nothing drawn here
    elseif config.monitor then
        mon = peripheral.wrap(config.monitor)
        if not mon then
            return nil, ("monitor '%s' not found"):format(config.monitor)
        end
    elseif total > 1 then
        return nil, "monitor name required when several displays are configured"
    else
        mon = peripheral.find("monitor")
        if not mon then
            return nil, "no monitor found"
        end
    end

    local reader
    if config.reader then
        reader = peripheral.wrap(config.reader)
        if not reader then
            return nil, ("block reader '%s' not found"):format(config.reader)
        end
    end

    if mon then
        prepareMonitor(mon, config.scale)
    end

    return {
        title = config.title or "FURNACE",
        furnaceName = config.furnace,
        furnace = peripheral.wrap(config.furnace),
        reader = reader,
        mon = mon,
        scroll = {}, -- own marquee state, so displays scroll independently
        sections = nil,
    }
end

-- ---------------------------------------------------------------- modes

local function runLocal(broadcast)
    local displays, problems = {}, {}
    for _, config in ipairs(DISPLAYS) do
        local display, reason = resolveDisplay(config, #DISPLAYS)
        if display then
            displays[#displays + 1] = display
        else
            problems[#problems + 1] = ("%s: %s"):format(config.title or config.furnace, reason)
        end
    end

    for _, problem in ipairs(problems) do
        print("Skipping " .. problem)
    end
    if #displays == 0 then
        listPeripherals()
        error("No display could be set up -- check the names in DISPLAYS", 0)
    end

    if broadcast then
        print("Broadcasting on '" .. PROTOCOL .. "' via modem " .. openWirelessModem())
    end

    local framesPerPoll = math.max(math.floor(POLL_INTERVAL / SCROLL_INTERVAL + 0.5), 1)
    local frame = 0

    local function poll()
        for _, display in ipairs(displays) do
            -- Re-wrap in case a cable was broken and reconnected.
            if not display.furnace then
                display.furnace = peripheral.wrap(display.furnaceName)
            end
            display.sections = readSections(display)
            if not display.sections then
                display.furnace = nil
            end
            if broadcast and display.sections then
                rednet.broadcast({ title = display.title, sections = display.sections }, PROTOCOL)
            end
        end
    end

    poll()
    while true do
        for _, display in ipairs(displays) do
            draw(display)
        end

        sleep(SCROLL_INTERVAL)

        for _, display in ipairs(displays) do
            advanceScroll(display)
        end

        frame = frame + 1
        if frame % framesPerPoll == 0 then
            poll()
        end
    end
end

local function runClient()
    local mon = CLIENT_MONITOR and peripheral.wrap(CLIENT_MONITOR) or peripheral.find("monitor")
    if not mon then
        listPeripherals()
        error(CLIENT_MONITOR and ("monitor '" .. CLIENT_MONITOR .. "' not found") or "No monitor found", 0)
    end
    prepareMonitor(mon, CLIENT_SCALE)

    print("Listening on '" .. PROTOCOL .. "' via modem " .. openWirelessModem())

    local display = {
        title = CLIENT_WATCH or "FURNACE",
        mon = mon,
        scroll = {},
        sections = nil,
        emptyMessage = "NO SIGNAL",
    }
    local lastHeard = nil

    draw(display)
    local timer = os.startTimer(SCROLL_INTERVAL)

    while true do
        local event, a, b, c = os.pullEvent()

        if event == "timer" and a == timer then
            if lastHeard and os.clock() - lastHeard > STALE_AFTER then
                display.sections = nil -- fall back to NO SIGNAL
            end
            draw(display)
            advanceScroll(display)
            timer = os.startTimer(SCROLL_INTERVAL)
        elseif event == "rednet_message" and c == PROTOCOL then
            local message = b
            if type(message) == "table" and type(message.sections) == "table" then
                -- With no CLIENT_WATCH set, latch onto the first host heard.
                if not CLIENT_WATCH or message.title == CLIENT_WATCH then
                    display.title = message.title or display.title
                    display.sections = message.sections
                    lastHeard = os.clock()
                end
            end
        end
    end
end

-- ---------------------------------------------------------------- dispatch

local MODE = (({ ... })[1] or "local"):lower()

if MODE == "local" then
    runLocal(false)
elseif MODE == "host" then
    runLocal(true)
elseif MODE == "client" then
    runClient()
else
    print("Usage: furnacestats [host|client]")
    print("  (no argument)  draw to local and wired-network monitors")
    print("  host           the same, plus broadcast over a wireless modem")
    print("  client         draw stats received over a wireless modem")
end
