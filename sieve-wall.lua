-- SIEVE WALL | 3x3 Main Monitor status board
-- Tap a stage card for its crusher, collection and barrel contents; tap the
-- attention panel for every alert; "?" explains the line; BACK returns.
-- Cobble -> BCF #1 gravel -> BCF #2 sand -> BCF #3 dust, each split into an
-- Auto Sieve (drops into Storage Barrel #n) and a crushed-block collection.
--
-- Needs: an advanced monitor, and a wired modem on every block it reads
-- (factories, collections, barrels, cobble generator), all on one network.
--
-- Install: wget https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/refs/heads/main/sieve-wall.lua sieve-wall.lua
-- Start:   sieve-wall
--
-- The computer's own screen lists every peripheral it can see and what each
-- was recognised as. If a stage is wrong, put the names in CONFIG below.

-- ============================ CONFIG =====================================
local CONFIG = {
  monitor   = nil,  -- nil = largest monitor found
  scale     = 1,    -- 1 = big readable text on a 3x3 (29x19); 0.5 fits more
  refresh   = 2,    -- seconds between reads
  idleReturn = 90,  -- seconds untouched before a detail page returns home
  -- Names as the chat shows them when a modem is clicked. nil = auto:
  -- collections by what they hold, factories and barrels in name order.
  cobble    = "functionalstorage:oak_1_0",
  collect   = { "advancedBin_0", "advancedBin_1", "advancedBin_2" },  -- gravel, sand, dust
  factories = { "basicCrushingFactory_0", "basicCrushingFactory_1", "advancedCrushingFactory_0" },
  barrels   = { "sophisticatedstorage:barrel_2", "sophisticatedstorage:barrel_1", nil },
  barrelWarn = 0.85,              -- fraction of slots used before warning
}
-- =========================================================================

local STAGES = {
  { key = "gravel", label = "GRAVEL", color = colors.lightGray, match = "^minecraft:gravel$" },
  { key = "sand",   label = "SAND",   color = colors.yellow,    match = "^minecraft:sand$" },
  { key = "dust",   label = "DUST",   color = colors.white,     match = ":dust$" },
}

-- ---------------------------------------------------------------------------
-- Discovery
-- ---------------------------------------------------------------------------
local function suffix(name) return tonumber(name:match("_(%d+)$")) or 0 end
local function byName(a, b)
  local pa, pb = a:gsub("_%d+$", ""), b:gsub("_%d+$", "")
  if pa ~= pb then return pa < pb end
  return suffix(a) < suffix(b)
end

local function pickMonitor()
  if CONFIG.monitor then return peripheral.wrap(CONFIG.monitor) end
  local best, area = nil, -1
  for _, m in ipairs({ peripheral.find("monitor") }) do
    m.setTextScale(CONFIG.scale)
    local w, h = m.getSize()
    if w * h > area then best, area = m, w * h end
  end
  return best
end

local function dominant(inv)
  local ok, items = pcall(inv.list)
  if not ok or not items then return nil end
  local counts = {}
  for _, it in pairs(items) do counts[it.name] = (counts[it.name] or 0) + it.count end
  local top, n = nil, 0
  for name, c in pairs(counts) do if c > n then top, n = name, c end end
  return top
end

local roles = {}  -- peripheral name -> human description, for the terminal

local function discover()
  local inv, fac = {}, {}
  for _, name in ipairs(peripheral.getNames()) do
    local p = peripheral.wrap(name)
    if p and p.getEnergyFilledPercentage and p.getRecipeProgress then
      fac[#fac + 1] = name
    elseif p and p.list and p.size then
      inv[#inv + 1] = name
    end
  end
  table.sort(inv, byName)
  table.sort(fac, byName)

  local used, sys = {}, { collect = {}, factories = {}, barrels = {} }
  local function take(name, role)
    used[name] = true
    roles[name] = role
    return name
  end
  for _, n in pairs(CONFIG.collect) do used[n] = true end
  for _, n in pairs(CONFIG.factories) do used[n] = true end
  for _, n in pairs(CONFIG.barrels) do used[n] = true end
  if CONFIG.cobble then used[CONFIG.cobble] = true end

  for i, st in ipairs(STAGES) do
    local n = CONFIG.collect[i]
    if n then roles[n] = st.label .. " collection (config)" end
    if not n then
      for _, name in ipairs(inv) do
        local top = not used[name] and dominant(peripheral.wrap(name))
        if top and top:match(st.match) then n = take(name, st.label .. " collection (auto)") break end
      end
    end
    sys.collect[i] = n
  end
  sys.cobble = CONFIG.cobble
  if not sys.cobble then
    for _, name in ipairs(inv) do
      if not used[name] and dominant(peripheral.wrap(name)) == "minecraft:cobblestone" then
        sys.cobble = take(name, "cobble buffer (auto)") break
      end
    end
  end
  local fi, bi = 1, 1
  for i = 1, 3 do
    sys.factories[i] = CONFIG.factories[i]
    if not sys.factories[i] then
      while fac[fi] and used[fac[fi]] do fi = fi + 1 end
      if fac[fi] then sys.factories[i] = take(fac[fi], "BCF #" .. i .. " (auto)") end
    end
    sys.barrels[i] = CONFIG.barrels[i]
    if not sys.barrels[i] then
      while inv[bi] and used[inv[bi]] do bi = bi + 1 end
      if inv[bi] then sys.barrels[i] = take(inv[bi], "Storage Barrel #" .. i .. " (auto)") end
    end
  end
  for i = 1, 3 do
    if CONFIG.factories[i] then roles[CONFIG.factories[i]] = "BCF #" .. i .. " (config)" end
    if CONFIG.barrels[i] then roles[CONFIG.barrels[i]] = "Storage Barrel #" .. i .. " (config)" end
  end
  return sys
end

-- ---------------------------------------------------------------------------
-- Reading
-- ---------------------------------------------------------------------------
local function readInv(name)
  local p = name and peripheral.wrap(name)
  if not p then return nil end
  -- Mekanism bins: one item type, read through their own methods
  if p.getStored and p.getCapacity then
    local okS, it = pcall(p.getStored)
    local okC, cap = pcall(p.getCapacity)
    if not okS or not okC then return nil end
    local n = (type(it) == "table" and it.count) or 0
    local r = { total = n, slots = n > 0 and 1 or 0, size = 1, items = {}, cap = cap }
    if n > 0 and it.name then r.items[it.name] = n end
    r.fill = cap > 0 and n / cap or 0
    return r
  end
  local ok, items = pcall(p.list)
  if not ok or not items then return nil end
  local size = p.size()
  local r = { total = 0, slots = 0, size = size, items = {} }
  for slot, it in pairs(items) do
    r.total = r.total + it.count
    r.slots = r.slots + 1
    r.items[it.name] = (r.items[it.name] or 0) + it.count
  end
  -- drawers hold one item in a few huge slots; barrels fill by slot
  if size <= 4 then
    local cap = 0
    for s = 1, size do
      local okL, lim = pcall(p.getItemLimit, s)
      cap = cap + ((okL and lim) or 64)
    end
    r.fill = cap > 0 and r.total / cap or 0
    r.cap = cap
  else
    r.fill = r.slots / size
  end
  return r
end

local function readFactory(name)
  local p = name and peripheral.wrap(name)
  if not p then return nil end
  local ok, e = pcall(p.getEnergyFilledPercentage)
  if not ok then return nil end
  -- basic factories have 3 lanes, advanced 5; asking past the last one errors
  local busy, lanes = 0, 0
  for proc = 0, 8 do
    local okP, prog = pcall(p.getRecipeProgress, proc)
    if not okP then break end
    lanes = lanes + 1
    if (prog or 0) > 0 then busy = busy + 1 end
  end
  local okM, mode = pcall(p.getRedstoneMode)
  return { energy = e or 0, busy = busy, lanes = lanes, mode = okM and mode or nil }
end

-- ---------------------------------------------------------------------------
-- System power. The crushers are switched through their Mekanism redstone
-- mode: "DISABLED" ignores redstone (always runs); "HIGH" runs only with a
-- redstone signal, so with none wired in they stop and the energy goes on to
-- other machines. Remembered across restarts.
-- ---------------------------------------------------------------------------
local STATE_FILE = "/sieve-wall.state"
local power = { on = true }
do
  local f = fs.open(STATE_FILE, "r")
  if f then power.on = f.readAll() ~= "off" f.close() end
end
local function wantMode() return power.on and "DISABLED" or "HIGH" end
-- false when the factory refuses (its security is not public)
local function applyMode(name)
  local p = name and peripheral.wrap(name)
  if not p or not p.setRedstoneMode then return false end
  return (pcall(p.setRedstoneMode, wantMode()))
end
local function setPower(on, sys)
  power.on = on
  local f = fs.open(STATE_FILE, "w")
  if f then f.write(on and "on" or "off") f.close() end
  for i = 1, 3 do applyMode(sys.factories[i]) end
end

-- items per minute from a short history of totals
local history = {}
local function rate(key, value)
  if not value then return nil end
  local now = os.epoch("utc") / 1000
  local h = history[key] or {}
  history[key] = h
  h[#h + 1] = { t = now, v = value }
  while #h > 2 and now - h[1].t > 60 do table.remove(h, 1) end
  local dt = now - h[1].t
  if dt < 1 then return nil end
  return (value - h[1].v) / dt * 60
end

-- ---------------------------------------------------------------------------
-- Look
-- ---------------------------------------------------------------------------
-- Light theme: white panels on a pale gray page, page-tone insets, solid
-- colour blocks for buttons and stage identity. The palette is remapped on
-- this monitor only and restored when the program stops.
local BG, PANEL, INSET = colors.lightGray, colors.white, colors.lightGray
local DIM, TEXT, ON_SOLID = colors.gray, colors.black, colors.white
local PALETTE = {
  [colors.lightGray] = 0xc9ced6, -- page, insets, bar tracks
  [colors.white]     = 0xf8f9fb, -- panels; text on solid buttons
  [colors.black]     = 0x1f2329, -- text
  [colors.gray]      = 0x6b7280, -- captions, secondary text
  [colors.green]     = 0x2f9e55,
  [colors.orange]    = 0xdd7a12,
  [colors.red]       = 0xd23c32,
  [colors.cyan]      = 0x1f8eb8, -- buttons, power bar
  [colors.purple]    = 0x8c939d, -- gravel
  [colors.yellow]    = 0xe2c46a, -- sand
  [colors.brown]     = 0xcdbfa6, -- dust
}
STAGES[1].color, STAGES[1].ink = colors.purple, colors.white
STAGES[2].color, STAGES[2].ink = colors.yellow, colors.black
STAGES[3].color, STAGES[3].ink = colors.brown, colors.black

local mon = pickMonitor()
if not mon then error("Sieve Wall: no monitor found. Attach the 3x3 advanced monitor.") end
mon.setTextScale(CONFIG.scale)
local W, H = mon.getSize()
-- draw off-screen, then show the finished frame at once: no flicker in game
local win = window.create(mon, 1, 1, W, H, false)
for c, rgb in pairs(PALETTE) do win.setPaletteColour(c, rgb) end

local function at(x, y, text, fg, bg)
  win.setCursorPos(x, y)
  win.setTextColor(fg or TEXT)
  win.setBackgroundColor(bg or BG)
  win.write(text)
end
local function fill(x, y, w, h, bg)
  win.setBackgroundColor(bg)
  for r = y, y + h - 1 do win.setCursorPos(x, r) win.write((" "):rep(w)) end
end
local function right(xEnd, y, text, fg, bg) at(xEnd - #text + 1, y, text, fg, bg) end
-- centre text within columns x .. x+w-1 (whole screen by default)
local function cx(text, x, w) return (x or 1) + math.floor(((w or W) - #text) / 2) end
local function center(y, text, fg, bg, x, w) at(cx(text, x, w), y, text, fg, bg) end
local function fit(s, w) return #s > w and s:sub(1, w - 1) .. "." or s end

local function commas(n)
  if not n then return "--" end
  if n >= 1e7 then return ("%.1fM"):format(n / 1e6) end
  local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (s:gsub("^,", ""))
end
-- fits a 9-wide card
local function compact(n)
  if n and n >= 1e5 then return ("%.1fK"):format(n / 1e3) end
  return commas(n)
end
local function rateText(r)
  if not r then return "--/min" end
  local n = math.floor(math.abs(r) + 0.5)
  return (r < 0 and "-" or "+") .. compact(n) .. "/min"
end
local function pretty(id)
  local s = id:gsub("^[^:]+:", ""):gsub("_", " ")
  return (s:gsub("(%a)(%w*)", function(a, b) return a:upper() .. b end))
end
local function pct(f) return math.floor((f or 0) * 100 + 0.5) .. "%" end

local function bar(x, y, w, frac, color)
  frac = math.max(0, math.min(1, frac or 0))
  local n = math.floor(frac * w + 0.5)
  fill(x, y, w, 1, INSET)
  if n > 0 then fill(x, y, n, 1, color) end
end

-- small indicator light (cc-mek-scada style: one teletext glyph). Alarms blink.
local blinkOn = true
local function led(x, y, color, bg, alarm)
  if alarm and not blinkOn then color = (bg == BG) and PANEL or BG end
  at(x, y, "\140", color, bg)
end
-- light + label, centred as one unit
local function ledLabel(y, color, text, bg, alarm, x, w)
  local s = "\140 " .. text
  local sx = cx(s, x, w)
  led(sx, y, color, bg, alarm)
  at(sx + 1, y, " " .. text, color, bg)
end

local function fillColor(frac)
  if frac >= 0.97 then return colors.red end
  if frac >= CONFIG.barrelWarn then return colors.orange end
  return colors.green
end
local function crusherState(f)
  if not f then return "NO LINK", colors.red, true end
  if not power.on then return "OFF", DIM end
  if f.energy < 0.05 then return "NO POWER", colors.red, true end
  if f.busy > 0 then return "ACTIVE", colors.green end
  return "IDLE", colors.orange
end

-- ---------------------------------------------------------------------------
-- Pages. Each draw registers its own touch areas, so what is drawn and what
-- is clickable cannot drift apart.
-- ---------------------------------------------------------------------------
local ui = { page = "home", stage = 1, itemPage = 1, touched = 0 }
local hits = {}
local function hit(x, y, w, h, fn) hits[#hits + 1] = { x, y, x + w - 1, y + h - 1, fn } end
local function go(page, stage) ui.page, ui.stage, ui.itemPage = page, stage or ui.stage, 1 end

-- title bar; with `back`, a solid cyan button on the left
local function titleBar(title, color, back)
  fill(1, 1, W, 1, PANEL)
  center(1, title, color, PANEL)
  if back then
    fill(1, 1, 8, 1, colors.cyan)
    center(1, "\171 BACK", ON_SOLID, colors.cyan, 1, 8)
    hit(1, 1, 8, 1, function() go("home") end)
  end
end

local function alertSummary(alerts)
  if #alerts == 0 then return "ALL CLEAR", colors.green, false end
  local c = colors.orange
  for _, a in ipairs(alerts) do if a.level == "red" then c = colors.red end end
  return #alerts .. (#alerts == 1 and " ALERT" or " ALERTS"), c, c == colors.red
end

local CARD_W = math.floor((W - 2) / 3)
local function cardX(i) return 1 + (i - 1) * (CARD_W + 1) end

local function drawHome(d)
  local state, sc, alarm = alertSummary(d.alerts)
  titleBar("SIEVE WALL", TEXT)
  fill(W - 2, 1, 3, 1, colors.cyan)
  at(W - 1, 1, "?", ON_SOLID, colors.cyan)
  hit(W - 3, 1, 4, 1, function() go("help") end)

  -- cobble feed (left, above stage 1) | system power switch (right)
  local half = math.floor((W - 1) / 2)
  local rx, rw = half + 2, W - half - 1
  fill(1, 3, half, 2, PANEL)
  center(3, "COBBLE FEED", DIM, PANEL, 1, half)
  if d.cobble then
    local n, r = compact(d.cobble.total), rateText(d.cobbleRate)
    if #n + #r + 1 > half - 2 then r = r:gsub("/min$", "/m") end
    local sx = cx(n .. " " .. r, 1, half)
    at(sx, 4, n, TEXT, PANEL)
    at(sx + #n + 1, 4, r, DIM, PANEL)
  else
    center(4, "NO LINK", colors.red, PANEL, 1, half)
  end

  -- two taps to switch, so a stray click cannot stop the line
  fill(rx, 3, rw, 2, PANEL)
  center(3, "SYSTEM", DIM, PANEL, rx, rw)
  local armed = ui.armed and os.clock() - ui.armed < 3
  local label, fg, bg = "OFFLINE", DIM, INSET
  if armed then label, fg, bg = "TAP AGAIN", ON_SOLID, colors.orange
  elseif power.on then label, fg, bg = "ACTIVE", ON_SOLID, colors.green end
  fill(rx + 1, 4, rw - 2, 1, bg)
  center(4, label, fg, bg, rx, rw)
  hit(rx, 3, rw, 2, function()
    if armed then ui.armed, ui.toggle = nil, true else ui.armed = os.clock() end
  end)
  at(cardX(1) + math.floor(CARD_W / 2), 5, "\31", DIM)

  -- one card per stage, left to right like the wall
  for i, st in ipairs(STAGES) do
    local x, c, b, f = cardX(i), d.collect[i], d.barrels[i], d.factories[i]
    fill(x, 6, CARD_W, 11, PANEL)
    fill(x, 6, CARD_W, 1, st.color)
    center(6, st.label, st.ink, st.color, x, CARD_W)

    local s, scol, salarm = crusherState(f)
    ledLabel(8, scol, s == "NO POWER" and "NO PWR" or s, PANEL, salarm, x, CARD_W)

    if c then
      center(10, compact(c.total), TEXT, PANEL, x, CARD_W)
      center(11, "stored", DIM, PANEL, x, CARD_W)
      center(12, rateText(d.collectRate[i]), DIM, PANEL, x, CARD_W)
    else
      center(10, "NO LINK", colors.red, PANEL, x, CARD_W)
    end

    center(14, "BARREL", DIM, PANEL, x, CARD_W)
    if b then
      local full = b.fill >= 0.97
      if not (full and not blinkOn) then bar(x + 1, 15, CARD_W - 2, b.fill, fillColor(b.fill))
      else bar(x + 1, 15, CARD_W - 2, 0, BG) end
      center(16, pct(b.fill), full and colors.red or TEXT, PANEL, x, CARD_W)
    else
      center(15, "NO LINK", colors.red, PANEL, x, CARD_W)
    end
    if i < #STAGES then at(x + CARD_W, 11, "\16", DIM) end
    hit(x, 6, CARD_W, 11, function() go("stage", i) end)
  end

  -- attention panel
  fill(1, H - 1, W, 2, PANEL)
  ledLabel(H - 1, sc, state, PANEL, alarm)
  if #d.alerts == 0 then
    center(H, "Nothing needs you", DIM, PANEL)
  else
    local more = #d.alerts > 1 and ("  +" .. (#d.alerts - 1)) or ""
    center(H, fit(d.alerts[1].short, W - 2 - #more) .. more, DIM, PANEL)
    right(W - 1, H - 1, "\187", DIM, PANEL)
  end
  hit(1, H - 1, W, 2, function() go("alerts") end)
end

-- gray panel with a centred caption on its first row
local function panel(x, y, w, h, caption)
  fill(x, y, w, h, PANEL)
  if caption then center(y, caption, DIM, PANEL, x, w) end
end

local function drawStage(d, i)
  local st = STAGES[i]
  local c, b, f = d.collect[i], d.barrels[i], d.factories[i]
  titleBar("STAGE " .. i, TEXT, true)

  -- stage tabs: solid blocks, the open one in its stage colour
  for k, o in ipairs(STAGES) do
    local x, on = cardX(k), k == i
    fill(x, 2, CARD_W, 1, on and o.color or PANEL)
    center(2, o.label, on and o.ink or DIM, on and o.color or PANEL, x, CARD_W)
    hit(x, 2, CARD_W, 1, function() go("stage", k) end)
  end

  -- crusher | collection, side by side
  local half = math.floor((W - 1) / 2)
  local lx, rx, rw = 1, half + 2, W - half - 1
  panel(lx, 4, half, 6, "CRUSHER")
  local s, scol, alarm = crusherState(f)
  ledLabel(5, scol, s, PANEL, alarm, lx, half)
  if f then
    center(6, "Power " .. pct(f.energy), TEXT, PANEL, lx, half)
    bar(lx + 1, 7, half - 2, f.energy, f.energy < 0.2 and colors.red or colors.cyan)
    -- one light per lane; five lanes only fit without the caption
    local label = f.lanes <= 3 and "Lanes " or ""
    local sx = cx(label .. ("\140 "):rep(f.lanes - 1) .. "\140", lx, half)
    at(sx, 8, label, DIM, PANEL)
    for l = 1, f.lanes do led(sx + #label + (l - 1) * 2, 8, l <= f.busy and colors.green or BG, PANEL) end
  end

  panel(rx, 4, rw, 6, "COLLECTION")
  if c then
    local full = c.cap and c.fill >= 0.97
    if full then ledLabel(5, colors.orange, "FULL", PANEL, false, rx, rw)
    elseif c.cap then center(5, pct(c.fill) .. " full", TEXT, PANEL, rx, rw) end
    center(6, commas(c.total), TEXT, PANEL, rx, rw)
    if c.cap then bar(rx + 1, 7, rw - 2, c.fill, full and colors.orange or st.color) end
    center(8, rateText(d.collectRate[i]), DIM, PANEL, rx, rw)
  else
    ledLabel(6, colors.red, "NO LINK", PANEL, true, rx, rw)
  end

  -- barrel: header, fill, then a black inset list of what the sieve dropped
  local by = 11
  panel(1, by, W, H - by + 1)
  if not b then
    center(by, "BARREL #" .. i, DIM, PANEL)
    ledLabel(by + 2, colors.red, "NO LINK", PANEL, true)
    return
  end
  local warn = b.fill >= CONFIG.barrelWarn
  if warn then ledLabel(by, fillColor(b.fill), "BARREL #" .. i, PANEL, b.fill >= 0.97)
  else center(by, "BARREL #" .. i, DIM, PANEL) end
  bar(2, by + 1, W - 7, b.fill, fillColor(b.fill))
  right(W - 1, by + 1, pct(b.fill), TEXT, PANEL)
  at(2, by + 2, b.slots .. "/" .. b.size .. " slots", DIM, PANEL)
  right(W - 1, by + 2, rateText(d.barrelRate[i]), DIM, PANEL)

  local list = {}
  for id, n in pairs(b.items) do list[#list + 1] = { id = id, n = n } end
  table.sort(list, function(a, z) return a.n > z.n end)
  local top, rows = by + 3, H - by - 4
  fill(2, top, W - 2, rows, INSET)
  local pages = math.max(1, math.ceil(#list / rows))
  ui.itemPage = math.min(ui.itemPage, pages)
  local first = (ui.itemPage - 1) * rows
  for r = 1, rows do
    local e = list[first + r]
    if e then
      local n = commas(e.n)
      at(3, top + r - 1, fit(pretty(e.id), W - #n - 6), TEXT, INSET)
      right(W - 2, top + r - 1, n, DIM, INSET)
    end
  end
  if #list == 0 then center(top, "Empty", DIM, INSET) end
  if pages > 1 then
    local prev, nxt = ui.itemPage > 1, ui.itemPage < pages
    fill(2, H, 5, 1, prev and colors.cyan or BG)
    center(H, "\171", prev and ON_SOLID or PANEL, prev and colors.cyan or BG, 2, 5)
    fill(W - 5, H, 5, 1, nxt and colors.cyan or BG)
    center(H, "\187", nxt and ON_SOLID or PANEL, nxt and colors.cyan or BG, W - 5, 5)
    center(H, ui.itemPage .. " / " .. pages, DIM, PANEL)
    hit(1, H, 7, 1, function() ui.itemPage = math.max(1, ui.itemPage - 1) end)
    hit(W - 6, H, 7, 1, function() ui.itemPage = ui.itemPage + 1 end)
  end
end

-- word-wrap into at most `max` lines of width w
local function wrap(text, w, max)
  local lines, line = {}, ""
  for word in text:gmatch("%S+") do
    if #line + #word + (#line > 0 and 1 or 0) > w then
      lines[#lines + 1] = line
      line = word
    else
      line = #line > 0 and (line .. " " .. word) or word
    end
  end
  lines[#lines + 1] = line
  while #lines > max do table.remove(lines) end
  return lines
end

local function drawAlerts(d)
  local state, sc = alertSummary(d.alerts)
  titleBar(state, sc, true)
  if #d.alerts == 0 then
    panel(1, 3, W, 4)
    ledLabel(4, colors.green, "ALL CLEAR", PANEL)
    center(5, "Nothing needs you", DIM, PANEL)
    return
  end
  local y = 3
  for _, a in ipairs(d.alerts) do
    local lines = wrap(a.text, W - 6, 3)
    if y + #lines + 1 > H + 1 then break end
    local col = a.level == "red" and colors.red or colors.orange
    panel(1, y, W, #lines + 2)
    fill(1, y, 1, #lines + 2, col)
    led(3, y + 1, col, PANEL, a.level == "red")
    for k, l in ipairs(lines) do at(5, y + k, l, TEXT, PANEL) end
    y = y + #lines + 3
  end
end

-- the "?" page: what the line does and how to read the lights, in plain words
local function drawHelp()
  titleBar("HELP", TEXT, true)

  panel(1, 3, W, 9, "THE LINE")
  local flow = { "COBBLE" }
  for _, st in ipairs(STAGES) do flow[#flow + 1] = st.label end
  local width = -1
  for _, f in ipairs(flow) do width = width + #f + 1 end
  local x = cx((" "):rep(width))
  for k, f in ipairs(flow) do
    at(x, 4, f, TEXT, PANEL)
    x = x + #f
    if k < #flow then at(x, 4, "\16", DIM, PANEL) x = x + 1 end
  end
  local text = {
    "Each crusher grinds the",
    "block one step finer.",
    "Some goes to a sieve. What",
    "it finds lands in the",
    "barrel under it.",
  }
  for k, l in ipairs(text) do center(5 + k, l, TEXT, PANEL) end

  panel(1, 13, W, 7, "THE LIGHTS")
  local lights = {
    { colors.green, "Running fine" },
    { colors.orange, "Check soon" },
    { colors.red, "Fix now (blinks)" },
  }
  for k, l in ipairs(lights) do
    led(3, 13 + k, l[1], PANEL, k == 3)
    at(5, 13 + k, l[2], TEXT, PANEL)
  end
  center(17, "Tap a card for details", DIM, PANEL)
  center(18, "SYSTEM: tap twice, on/off", DIM, PANEL)
end

local function render(d)
  hits = {}
  win.setVisible(false)
  win.setBackgroundColor(BG)
  win.clear()
  if ui.page == "stage" then drawStage(d, ui.stage)
  elseif ui.page == "alerts" then drawAlerts(d)
  elseif ui.page == "help" then drawHelp()
  else drawHome(d) end
  win.setVisible(true)
end

local function touch(x, y)
  ui.touched = os.clock()
  for k = #hits, 1, -1 do
    local h = hits[k]
    if x >= h[1] and x <= h[3] and y >= h[2] and y <= h[4] then h[5]() return true end
  end
end

-- ---------------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------------
local function collect(sys)
  local d = { collect = {}, collectRate = {}, factories = {}, barrels = {}, barrelRate = {}, alerts = {} }
  -- text for the alerts page, short for the home tile
  local function alert(level, text, short)
    d.alerts[#d.alerts + 1] = { level = level, text = text, short = short }
  end
  d.cobble = readInv(sys.cobble)
  d.cobbleRate = rate("cobble", d.cobble and d.cobble.total)
  for i, st in ipairs(STAGES) do
    local c = readInv(sys.collect[i])
    d.collect[i] = c
    d.collectRate[i] = rate("c" .. i, c and c.total)
    d.factories[i] = readFactory(sys.factories[i])
    local b = readInv(sys.barrels[i])
    d.barrels[i] = b
    d.barrelRate[i] = rate("b" .. i, b and b.total)

    local f = d.factories[i]
    if not f then alert("red", "BCF #" .. i .. " is not on the network.", "BCF #" .. i .. " no link")
    elseif f.energy < 0.05 then alert("red", "BCF #" .. i .. " has no power.", "BCF #" .. i .. " no power")
    elseif f.mode and f.mode:upper() ~= wantMode() and not applyMode(sys.factories[i]) then
      alert("red", "BCF #" .. i .. " refused the on/off switch. Set its security to public.",
        "BCF #" .. i .. " won't switch")
    elseif f.busy == 0 and power.on then
      local feed = i == 1 and "cobble" or STAGES[i - 1].label:lower()
      alert("orange", "BCF #" .. i .. " is idle. Check its " .. feed .. " supply.",
        "BCF #" .. i .. " idle, no " .. feed)
    end
    if not b then alert("red", "Storage Barrel #" .. i .. " is not on the network.", "Barrel #" .. i .. " no link")
    elseif b.fill >= 0.97 then alert("red", "Storage Barrel #" .. i .. " is full. Sieve " .. i .. " will back up.",
        "Barrel #" .. i .. " FULL")
    elseif b.fill >= CONFIG.barrelWarn then
      alert("orange", ("Storage Barrel #%d is %s full. Empty it soon."):format(i, pct(b.fill)),
        ("Barrel #%d %s full"):format(i, pct(b.fill)))
    end
    if c and c.cap and c.fill >= 0.97 then
      local name = st.label:sub(1, 1) .. st.label:sub(2):lower()
      alert("orange", name .. " collection is full.", name .. " collection full")
    end
  end
  return d
end

-- terminal: what was found, so wiring mistakes are visible without the monitor
local function printRoles()
  term.clear()
  term.setCursorPos(1, 1)
  print("SIEVE WALL - peripherals seen:")
  for _, name in ipairs(peripheral.getNames()) do
    print((" %-28s %s"):format(name, roles[name] or ("(" .. tostring(peripheral.getType(name)) .. ")")))
  end
  print("Wrong stage? Set names in CONFIG. Ctrl+T stops.")
end

local function main()
  local sys = discover()
  printRoles()
  setPower(power.on, sys)  -- put the crushers in the remembered state
  local data = collect(sys)
  render(data)
  local timer = os.startTimer(CONFIG.refresh)
  local blink = os.startTimer(0.5)
  while true do
    local ev, a, x, y = os.pullEvent()
    if ev == "monitor_touch" then
      if touch(x, y) then
        if ui.toggle then
          ui.toggle = nil
          setPower(not power.on, sys)
          data = collect(sys)
        end
        render(data)
      end
    elseif ev == "timer" and a == blink then
      blinkOn = not blinkOn
      render(data)
      blink = os.startTimer(0.5)
    elseif ev == "timer" and a == timer then
      -- wander back to the overview after a while untouched
      if ui.page ~= "home" and os.clock() - ui.touched > CONFIG.idleReturn then go("home") end
      data = collect(sys)
      render(data)
      timer = os.startTimer(CONFIG.refresh)
    elseif ev == "peripheral" or ev == "peripheral_detach" then
      sys = discover()
      printRoles()
    end
  end
end

local ok, err = pcall(main)
-- put the monitor back the way other programs expect it
for c in pairs(PALETTE) do mon.setPaletteColour(c, term.nativePaletteColour(c)) end
mon.setBackgroundColor(colors.black)
mon.clear()
if not ok and err ~= "Terminated" then error(err, 0) end
