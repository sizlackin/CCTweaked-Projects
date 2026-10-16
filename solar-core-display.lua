-- SOLAR CORE | Industrial information billboard
-- CC:Tweaked / ATM10: To the Sky
-- Monitor computer: monitor attached, Ender Modem on top.
-- Visual design: window-style title bar, inset instrument panels, color-coded
-- status chips, animated core + signal indicators. No close button; display only.

local mon = peripheral.find("monitor")
if not mon then error("No monitor found. Connect a monitor to this computer.") end
if not peripheral.isPresent("top") or peripheral.getType("top") ~= "modem" then
  error("No modem found on top. Attach the Ender Modem to the top.")
end

rednet.open("top")
mon.setTextScale(0.5)
mon.setCursorBlink(false)

local W, H = mon.getSize()
local lastSeen = 0
local solar, wind = 4, 4
local tick = 0

local C = {
  black = colors.black,
  border = colors.gray,
  title = colors.blue,
  panelTitle = colors.gray,
  text = colors.white,
  muted = colors.lightGray,
  cyan = colors.cyan,
  solar = colors.yellow,
  wind = colors.lightBlue,
  good = colors.lime,
  goodBg = colors.green,
  warn = colors.orange,
  warnDim = colors.gray,
  empty = colors.gray
}

local function fill(x, y, w, h, bg)
  if w < 1 or h < 1 then return end
  local x1, x2 = math.max(1, x), math.min(W, x + w - 1)
  local y1, y2 = math.max(1, y), math.min(H, y + h - 1)
  if x1 > x2 or y1 > y2 then return end
  mon.setBackgroundColor(bg)
  mon.setTextColor(bg)
  for row = y1, y2 do
    mon.setCursorPos(x1, row)
    mon.write(string.rep(" ", x2 - x1 + 1))
  end
end

local function put(x, y, s, fg, bg)
  if y < 1 or y > H or x > W then return end
  s = tostring(s)
  if x < 1 then s = string.sub(s, 2 - x); x = 1 end
  local room = W - x + 1
  if #s > room then s = string.sub(s, 1, room) end
  if #s < 1 then return end
  mon.setBackgroundColor(bg or C.black)
  mon.setTextColor(fg or C.text)
  mon.setCursorPos(x, y)
  mon.write(s)
end

local function centered(x, y, w, s, fg, bg)
  s = tostring(s)
  if #s > w then s = string.sub(s, 1, w) end
  put(x + math.max(0, math.floor((w - #s) / 2)), y, s, fg, bg)
end

local function rowClear(x, y, w)
  fill(x, y, w, 1, C.black)
end

local function splitRow(x, y, w, left, right, leftColor, rightColor)
  rowClear(x, y, w)
  left, right = tostring(left), tostring(right)
  local maxLeft = math.max(0, w - #right - 2)
  if #left > maxLeft then left = string.sub(left, 1, maxLeft) end
  put(x, y, left, leftColor or C.text)
  put(x + w - #right, y, right, rightColor or C.text)
end

-- A panel is a colored frame surrounding a dark inset surface; the header is
-- a filled title bar, rather than ASCII divider characters.
local function panel(x, y, w, h, accent, title)
  fill(x, y, w, h, accent)
  fill(x + 1, y + 1, w - 2, h - 2, C.black)
  fill(x + 1, y + 1, w - 2, 1, C.panelTitle)
  put(x + 2, y + 1, title, C.text, C.panelTitle)
end

local function drawSegments(x, y, count, accent, maxCount, blinkIndex)
  maxCount = maxCount or 4
  local slotW, gap = 2, 1
  local totalW = maxCount * slotW + (maxCount - 1) * gap
  local startX = x + math.max(0, math.floor((W - x + 1 - totalW) / 2))
  for i = 1, maxCount do
    local bg = i <= math.min(count, maxCount) and accent or C.empty
    if blinkIndex and i == blinkIndex then bg = C.text end
    fill(startX + (i - 1) * (slotW + gap), y, slotW, 1, bg)
  end
end

local function signalMeter(x, y, width, accent, phase)
  local segments = math.max(3, math.min(7, math.floor((width - 6) / 2)))
  put(x, y, "SIGNAL", C.muted)
  local startX = x + 7
  for i = 1, segments do
    local bg = C.border
    if i == phase then bg = accent end
    fill(startX + (i - 1) * 2, y, 1, 1, bg)
  end
end

local full = W >= 38 and H >= 16
local px1, px2, pw1, pw2, py, ph

local function drawFrame()
  mon.setBackgroundColor(C.black)
  mon.clear()
  fill(1, 1, W, 1, C.title)
  fill(1, H, W, 1, C.border)
  fill(1, 2, 1, H - 2, C.border)
  fill(W, 2, 1, H - 2, C.border)

  put(3, 1, "SOLAR CORE", C.text, C.title)
  local rightTitle = "ENERGY TELEMETRY"
  put(W - #rightTitle - 2, 1, rightTitle, C.text, C.title)
  put(3, 2, "GRID OPERATIONS", C.cyan)
  local subtitle = "ATM10 / TO THE SKY"
  put(W - #subtitle - 2, 2, subtitle, C.muted)

  if full then
    local interiorW = W - 2
    local gap = 1
    pw1 = math.floor((interiorW - gap) / 2)
    pw2 = interiorW - gap - pw1
    px1, px2, py, ph = 2, 2 + pw1 + gap, 3, H - 6
    panel(px1, py, pw1, ph, C.cyan, "CORE TELEMETRY")
    panel(px2, py, pw2, ph, C.wind, "GENERATOR FLEET")

    -- Toolbar-like status and footer areas.
    fill(2, H - 3, W - 2, 1, C.border)
    fill(2, H - 2, W - 2, 1, C.black)
    fill(2, H - 1, W - 2, 1, C.border)
    put(3, H - 1, "AUTOMATION / INFORMATION DISPLAY", C.text, C.border)
    local footerRight = "ATM10 / SKY"
    put(W - #footerRight - 2, H - 1, footerRight, C.text, C.border)
  else
    px1, py, pw1, ph = 2, 3, W - 3, math.max(4, H - 6)
    panel(px1, py, pw1, ph, C.cyan, "ENERGY MONITOR")
    fill(2, H - 3, W - 2, 1, C.border)
    fill(2, H - 2, W - 2, 1, C.black)
    fill(2, H - 1, W - 2, 1, C.border)
    centered(2, H - 1, W - 2, "AUTOMATION / ATM10 SKY", C.text, C.border)
  end
end

local function drawLinkChip(x, y, w, online, blink, label)
  fill(x, y, w, 1, C.black)
  local text = label or (online and "ONLINE" or "STANDBY")
  local chipW = math.min(w, #text + 4)
  local chipX = x + math.max(0, math.floor((w - chipW) / 2))
  local bg = online and C.goodBg or C.warnDim
  fill(chipX, y, chipW, 1, bg)
  local marker = blink and "*" or "+"
  put(chipX + 1, y, marker, online and C.good or C.warn, bg)
  put(chipX + 3, y, text, C.text, bg)
end

local coreFrames = {
  "    .  *  .    ",
  "    *  +  *    ",
  "    .  +  .    ",
  "    *  +  *    ",
  "    .  *  .    ",
  "    +  *  +    "
}

local function drawFull(now, online, blink)
  local age = online and string.format("%.1fs", math.max(0, now - lastSeen)) or "WAITING"

  -- Left instrument panel: animated core, link state, and signal scanner.
  local ix, iw = px1 + 1, pw1 - 2
  local coreY = py + 2
  rowClear(ix, coreY, iw)
  centered(ix, coreY, iw, coreFrames[(math.floor(now * 3) % #coreFrames) + 1],
    blink and C.cyan or C.wind)
  rowClear(ix, py + 3, iw)
  centered(ix, py + 3, iw, "ENERGY MATRIX", C.muted)
  drawLinkChip(ix + 1, py + 4, iw - 2, online, blink)
  rowClear(ix, py + 5, iw)
  signalMeter(ix + 1, py + 5, iw - 2, online and C.good or C.cyan,
    (math.floor(now * 4) % 5) + 1)
  rowClear(ix, py + 6, iw)
  centered(ix, py + 6, iw, online and ("LAST RX  " .. age) or "NO TELEMETRY",
    online and C.good or C.warn)
  rowClear(ix, py + 7, iw)
  centered(ix, py + 7, iw, "NODE ID  SC-02", C.cyan)
  rowClear(ix, py + 8, iw)
  centered(ix, py + 8, iw, "REDNET UPLINK", C.border)

  -- Right panel: clear, color-coded configured-unit counts.
  local gx, gw = px2 + 1, pw2 - 2
  splitRow(gx, py + 2, gw, "SOLAR ARRAYS",
    string.format("%02d", solar), C.solar, C.solar)
  rowClear(gx, py + 3, gw)
  centered(gx, py + 3, gw, "CONFIGURED NODES", C.muted)
  fill(gx, py + 4, gw, 1, C.black)
  -- Unit blocks are setup counts, not live generation or health readings.
  local maxCount, slotW, gap = 4, 2, 1
  local total = maxCount * slotW + (maxCount - 1) * gap
  local startX = gx + math.max(0, math.floor((gw - total) / 2))
  for i = 1, maxCount do
    fill(startX + (i - 1) * (slotW + gap), py + 4, slotW, 1,
      i <= math.min(solar, maxCount) and C.solar or C.empty)
  end
  splitRow(gx, py + 5, gw, "WIND UNITS",
    string.format("%02d", wind), C.wind, C.wind)
  rowClear(gx, py + 6, gw)
  centered(gx, py + 6, gw, "CONFIGURED NODES", C.muted)
  fill(gx, py + 7, gw, 1, C.black)
  startX = gx + math.max(0, math.floor((gw - total) / 2))
  for i = 1, maxCount do
    fill(startX + (i - 1) * (slotW + gap), py + 7, slotW, 1,
      i <= math.min(wind, maxCount) and C.wind or C.empty)
  end
  rowClear(gx, py + 8, gw)
  centered(gx, py + 8, gw, "CONFIGURED ONLY", C.border)

  -- Status toolbar uses a blinking marker like an industrial annunciator.
  local statusY = H - 3
  local chipLabel = online and "LINK ONLINE" or "LINK STANDBY"
  local chipBg = online and C.goodBg or C.warnDim
  local chipW = #chipLabel + 4
  fill(3, statusY, chipW, 1, chipBg)
  put(4, statusY, blink and "*" or "+", online and C.good or C.warn, chipBg)
  put(6, statusY, chipLabel, C.text, chipBg)
  local channel = "RECEIVER / REDNET"
  put(W - #channel - 2, statusY, channel, C.text, C.border)

  rowClear(3, H - 2, W - 4)
  put(3, H - 2, online and ("LAST RX  " .. age) or "WAITING FOR SENDER",
    online and C.good or C.warn)
  local protocol = "CHANNEL: SOLARCORE"
  put(W - #protocol - 2, H - 2, protocol, C.muted)
end

local function drawCompact(now, online, blink)
  local age = online and string.format("%.1fs", math.max(0, now - lastSeen)) or "WAITING"
  local ix, iw = px1 + 1, pw1 - 2
  local contentTop = py + 2
  local bottomInside = py + ph - 2
  rowClear(ix, contentTop, iw)
  centered(ix, contentTop, iw, coreFrames[(math.floor(now * 3) % #coreFrames) + 1],
    blink and C.cyan or C.wind)
  if contentTop + 1 <= bottomInside then
    rowClear(ix, contentTop + 1, iw)
    centered(ix, contentTop + 1, iw,
      string.format("SOLAR %02d   WIND %02d", solar, wind), C.solar)
  end
  if contentTop + 2 <= bottomInside then
    drawLinkChip(ix + 1, contentTop + 2, iw - 2, online, blink,
      online and "LINK ONLINE" or "LINK STANDBY")
  end
  if contentTop + 3 <= bottomInside then
    rowClear(ix, contentTop + 3, iw)
    signalMeter(ix + 1, contentTop + 3, iw - 2,
      online and C.good or C.cyan, (math.floor(now * 4) % 5) + 1)
  end
  if contentTop + 4 <= bottomInside then
    rowClear(ix, contentTop + 4, iw)
    centered(ix, contentTop + 4, iw, "LAST PACKET  " .. age, C.muted)
  end

  local statusY = H - 3
  fill(3, statusY, math.min(W - 4, 17), 1, online and C.goodBg or C.warnDim)
  put(4, statusY, blink and "*" or "+", online and C.good or C.warn,
    online and C.goodBg or C.warnDim)
  put(6, statusY, online and "LINK ONLINE" or "LINK STANDBY", C.text,
    online and C.goodBg or C.warnDim)
  rowClear(3, H - 2, W - 4)
  put(3, H - 2, online and ("LAST RX  " .. age) or "WAITING FOR SENDER",
    online and C.good or C.warn)
end

drawFrame()

while true do
  local id, msg = rednet.receive("SOLARCORE", 0.15)
  if id and type(msg) == "table" then
    lastSeen = os.clock()
    solar = tonumber(msg.solar) or solar
    wind = tonumber(msg.wind) or wind
  end

  tick = tick + 1
  local now = os.clock()
  local online = lastSeen > 0 and (now - lastSeen) < 12
  local blink = math.floor(now * 2) % 2 == 0

  if full then
    drawFull(now, online, blink)
  else
    drawCompact(now, online, blink)
  end
end
