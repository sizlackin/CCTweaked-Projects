-- SOLAR CORE | Tom's Peripherals pixel display
-- CC:Tweaked / ATM10: To the Sky
-- Computer 2: Tom's tm_gpu on the right; Ender Modem on top.
-- The GPU drives its own connected Tom's monitor blocks. It is not a CC monitor.
--
-- Install: wget https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/refs/heads/main/solar-core-display.lua solar-core-display.lua
-- Start:   solar-core-display.lua

local gpu
if peripheral.getType("right") == "tm_gpu" then
  gpu = peripheral.wrap("right")
else
  gpu = peripheral.find("tm_gpu")
end
if not gpu then
  error("No Tom's Peripherals GPU found. Connect tm_gpu on the right and its monitors to the GPU.")
end

if not peripheral.isPresent("top") or peripheral.getType("top") ~= "modem" then
  error("No modem found on top. Attach the Ender Modem to the top.")
end
rednet.open("top")

-- refreshSize discovers Tom's monitor chain asynchronously; yield for it.
gpu.refreshSize()
local width, height, blocksWide, blocksHigh
for attempt = 1, 25 do
  sleep(0.2)
  width, height, blocksWide, blocksHigh = gpu.getSize()
  if blocksWide and blocksHigh and blocksWide > 0 and blocksHigh > 0 then break end
end
if not blocksWide or not blocksHigh or blocksWide < 1 or blocksHigh < 1 then
  error("Tom's GPU found, but no connected Tom's monitor blocks were detected.")
end

-- Use the GPU's highest supported per-block resolution for crisp pixel art.
-- Tom's API accepts resolutions from 16 through 64; the buffer remains modest
-- for normal monitor walls and the script adapts to the resulting canvas size.
gpu.setSize(64)
width, height, blocksWide, blocksHigh = gpu.getSize()
if not width or not height or width < 32 or height < 32 then
  error("Tom's GPU canvas is too small. Connect Tom's monitor blocks to the GPU.")
end

local COLOR = {
  bg       = 0xFF070B12,
  panel    = 0xFF0B121D,
  white    = 0xFFD2E4F4,
  muted    = 0xFF6C8BA8,
  dim      = 0xFF24506F,
  cyan     = 0xFF12D5E8,
  solar    = 0xFFFFD735,
  wind     = 0xFF24A9F2,
  good     = 0xFF00E39A,
  warn     = 0xFFFF762E,
  core     = 0xFF3D83AE,
}

-- Use the actual GPU font metrics to center and clip text safely. Tom's GPU
-- positions are one-based, and drawTextSmart accepts ARGB colors and a size.
local function textWidth(text, size)
  return gpu.getTextLength(text, size, 1)
end

local function drawText(text, x, y, color, size, align, maxWidth)
  text = tostring(text or "")
  size = math.max(1, math.floor(size or 1))
  maxWidth = math.max(1, math.floor(maxWidth or (width - x + 1)))
  while size > 1 and textWidth(text, size) > maxWidth do size = size - 1 end
  while #text > 1 and textWidth(text, size) > maxWidth do
    text = text:sub(1, -2)
  end
  local measured = textWidth(text, size)
  if align == "center" then x = x - math.floor(measured / 2)
  elseif align == "right" then x = x - measured + 1 end
  x = math.max(1, math.min(width - measured + 1, math.floor(x)))
  y = math.max(1, math.min(height - 8 * size + 1, math.floor(y)))
  gpu.drawTextSmart(x, y, text, color, COLOR.bg, false, size, 1)
end

local function fillRect(x, y, w, h, color)
  x, y = math.floor(x), math.floor(y)
  w, h = math.floor(w), math.floor(h)
  if w < 1 or h < 1 then return end
  if x < 1 then w, x = w + x - 1, 1 end
  if y < 1 then h, y = h + y - 1, 1 end
  w, h = math.min(w, width - x + 1), math.min(h, height - y + 1)
  if w > 0 and h > 0 then gpu.filledRectangle(x, y, w, h, color) end
end

local function outline(x, y, w, h, color)
  x, y = math.floor(x), math.floor(y)
  w, h = math.floor(w), math.floor(h)
  if x >= 1 and y >= 1 and w > 1 and h > 1
      and x + w - 1 <= width and y + h - 1 <= height then
    gpu.rectangle(x, y, w, h, color)
  end
end

local function line(x1, y1, x2, y2, color)
  x1, y1, x2, y2 = math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2)
  if x1 >= 1 and x1 <= width and x2 >= 1 and x2 <= width
      and y1 >= 1 and y1 <= height and y2 >= 1 and y2 <= height then
    gpu.line(x1, y1, x2, y2, color)
  end
end

local function disk(cx, cy, radius, color)
  for dy = -radius, radius do
    local half = math.floor(math.sqrt(radius * radius - dy * dy))
    fillRect(cx - half, cy + dy, half * 2 + 1, 1, color)
  end
end

local function sunIcon(cx, cy, radius, ray, color)
  disk(cx, cy, radius, color)
  line(cx, cy - radius - ray, cx, cy - radius - 2, color)
  line(cx, cy + radius + 2, cx, cy + radius + ray, color)
  line(cx - radius - ray, cy, cx - radius - 2, cy, color)
  line(cx + radius + 2, cy, cx + radius + ray, cy, color)
  line(cx - radius - ray, cy - radius - ray, cx - radius - 2, cy - radius - 2, color)
  line(cx + radius + 2, cy + radius + 2, cx + radius + ray, cy + radius + ray, color)
  line(cx + radius + 2, cy - radius - 2, cx + radius + ray, cy - radius - ray, color)
  line(cx - radius - ray, cy + radius + ray, cx - radius - 2, cy + radius + 2, color)
end

local function turbineIcon(cx, cy, radius, color)
  disk(cx, cy, math.max(2, math.floor(radius * 0.28)), color)
  line(cx, cy, cx, cy - radius, color)
  line(cx, cy, cx - radius, cy + math.floor(radius * 0.48), color)
  line(cx, cy, cx + radius, cy + math.floor(radius * 0.48), color)
  line(cx, cy + radius * 0.45, cx, cy + radius * 1.8, color)
end

local function centerText(text, y, color, size, maxWidth)
  drawText(text, math.floor(width / 2), y, color, size, "center", maxWidth or (width - 8))
end

-- Live state / sender compatibility. Counts are configured generators; the
-- sender does not report RF/t, so the UI deliberately shows truthful states.
local lastSeen = 0
local solar, wind = 0, 0
local solarKnown, windKnown = false, false
local solarPowered, windPowered = nil, nil
local telemetry, telemetryWind = nil, nil
local senderOutdated = false

local function online(now)
  return lastSeen > 0 and now - lastSeen < 12
end

local function hasTelemetry(source)
  return type(source) == "string" and source ~= ""
end

local function powerState(now, powered, source)
  if not online(now) then return lastSeen > 0 and "LINK LOST" or "UNKNOWN", COLOR.warn end
  if senderOutdated or not hasTelemetry(source) or powered == nil then return "UNKNOWN", COLOR.warn end
  if powered then return "PRODUCING", COLOR.good end
  return "STANDBY", COLOR.white
end

local function statusInfo(now)
  if not online(now) then return "LINK STANDBY", COLOR.warn end
  if senderOutdated or not hasTelemetry(telemetry) then return "LINK ONLINE / SENSOR UNKNOWN", COLOR.warn end
  return "LINK ONLINE", COLOR.good
end

local function detailInfo(now)
  if not online(now) then return "WIRELESS UPLINK / AWAITING SIGNAL", COLOR.muted end
  if senderOutdated then return "SENDER UPDATE REQUIRED", COLOR.warn end
  if hasTelemetry(telemetry) then return "SOLAR SENSOR / " .. tostring(telemetry), COLOR.muted end
  return "WIRELESS UPLINK / NO SENSOR DATA", COLOR.warn
end

local function countText(value, known)
  if not known then return "--" end
  local n = tonumber(value)
  if not n then return "--" end
  return string.format("%02d", math.max(0, math.floor(n)))
end

local function updateMessage(id, msg, now)
  if not id or type(msg) ~= "table" then return end
  lastSeen = now
  local solarValue, windValue = tonumber(msg.solar), tonumber(msg.wind)
  if solarValue ~= nil then solar, solarKnown = solarValue, true end
  if windValue ~= nil then wind, windKnown = windValue, true end
  senderOutdated = type(msg.solarPowered) ~= "boolean"
  solarPowered = type(msg.solarPowered) == "boolean" and msg.solarPowered or nil
  windPowered = type(msg.windPowered) == "boolean" and msg.windPowered or nil
  telemetry, telemetryWind = msg.telemetry, msg.telemetryWind
end

local function drawGeneratorPanel(x, y, panelWidth, title, count, known, powered, source, accent, now, icon, scale)
  local state, stateColor = powerState(now, powered, source)
  scale = scale or 1
  local function S(value) return math.floor(value * scale + 0.5) end
  local shortLabels = panelWidth < 110
  local unitsLabel = shortLabels and "UNITS" or "GENERATORS"
  local productionLabel = shortLabels and "PROD" or "PRODUCTION"
  local outputLabel = shortLabels and "OUTPUT" or "TOTAL OUTPUT"
  local statusLabel = shortLabels and "STATE" or "STATUS"
  local shortStates = { PRODUCING = "ACTIVE", CONFIGURED = "STANDBY", ["LINK LOST"] = "LOST" }
  local shownState = shortLabels and (shortStates[state] or state) or state
  local titleX = x + S(34)
  if icon == "sun" then
    sunIcon(x + S(11), y + S(7), math.max(2, S(4)), math.max(2, S(3)), accent)
  else
    turbineIcon(x + S(11), y + S(7), math.max(3, S(5)), accent)
  end
  drawText(title, titleX, y + S(2), accent, math.max(1, S(2)), nil, panelWidth - S(38))

  local labelX, valueX = x + S(2), x + panelWidth - S(2)
  local valueWidth = panelWidth * 0.48
  local labelWidth = panelWidth * 0.52
  local row = y + S(23)
  drawText(unitsLabel, labelX, row, COLOR.muted, 1, nil, labelWidth)
  drawText(countText(count, known), valueX, row, COLOR.white, 1, "right", valueWidth)
  row = row + S(13)
  drawText(productionLabel, labelX, row, COLOR.muted, 1, nil, labelWidth)
  drawText(shownState, valueX, row, stateColor, 1, "right", valueWidth)
  row = row + S(13)
  drawText(outputLabel, labelX, row, COLOR.muted, 1, nil, labelWidth)
  drawText("-- RF/t", valueX, row, COLOR.dim, 1, "right", valueWidth)
  row = row + S(13)
  drawText(statusLabel, labelX, row, COLOR.muted, 1, nil, labelWidth)
  drawText(shownState, valueX, row, stateColor, 1, "right", valueWidth)

  local barY = y + S(78)
  outline(x + S(2), barY, panelWidth - S(4), math.max(3, S(8)), accent)
  if powered == true and online(now) then
    fillRect(x + S(4), barY + S(2), math.max(2, panelWidth - S(8)), math.max(1, S(4)), accent)
  end
end

local function renderWide(now)
  local sx, sy = width / 320, height / 200
  local scale = math.min(sx, sy)
  local function X(v) return math.floor(v * sx + 0.5) end
  local function Y(v) return math.floor(v * sy + 0.5) end
  local function T(text, x, y, color, baseSize, align, maxWidth)
    drawText(text, X(x), Y(y), color, math.max(1, math.floor(baseSize * scale + 0.5)),
      align, maxWidth and X(maxWidth) or nil)
  end
  local function L(x1, y1, x2, y2, color)
    line(X(x1), Y(y1), X(x2), Y(y2), color)
  end
  local function R(x, y, w, h, color)
    outline(X(x), Y(y), math.max(2, X(w)), math.max(2, Y(h)), color)
  end
  local nowOnline = online(now)
  local solarState, solarColor = powerState(now, solarPowered, telemetry)
  local windState, windColor = powerState(now, windPowered, telemetryWind)
  -- Header, status lamp, and the fine cyan rule.
  T("SOLAR CORE", 160, 12, COLOR.cyan, 1.7, "center", 180)
  T("POWER NETWORK / ATM10 : TO THE SKY", 160, 31, COLOR.muted, 1, "center", 240)
  fillRect(X(251), Y(16), math.max(2, X(3)), math.max(2, Y(3)), nowOnline and COLOR.good or COLOR.warn)
  T(nowOnline and "ONLINE" or "OFFLINE", 260, 14, nowOnline and COLOR.good or COLOR.warn, 1, nil, 54)
  L(10, 46, 310, 46, COLOR.cyan)

  -- Source columns and the Tom GPU-drawn control core.
  local colWidth = 119
  drawGeneratorPanel(X(10), Y(61), X(colWidth), "SOLAR ARRAYS", solar, solarKnown,
    solarPowered, telemetry, COLOR.solar, now, "sun", scale)
  drawGeneratorPanel(X(191), Y(61), X(colWidth), "WIND TURBINES", wind, windKnown,
    windPowered, telemetryWind, COLOR.wind, now, "wind", scale)
  L(X(142), Y(62), X(142), Y(143), COLOR.core)
  L(X(178), Y(62), X(178), Y(143), COLOR.core)

  local coreX, coreY = X(150), Y(75)
  local coreW, coreH = X(20), Y(20)
  R(coreX, coreY, coreW, coreH, COLOR.wind)
  T(">_", 160, 81, COLOR.cyan, 1.4, "center", 18)
  L(X(153), Y(101), X(167), Y(101), COLOR.core)
  T("SYSTEM", 160, 108, COLOR.muted, 1, "center", 32)
  T((nowOnline and (solarPowered or windPowered)) and "ACTIVE" or "STANDBY",
    160, 119, (nowOnline and (solarPowered or windPowered)) and COLOR.good or COLOR.muted,
    1, "center", 38)
  L(X(153), Y(132), X(167), Y(132), COLOR.core)

  -- Lower wireless status band; rules are true GPU pixel lines, not hyphens.
  L(10, 155, 310, 155, COLOR.dim)
  local linkText, linkColor = statusInfo(now)
  fillRect(X(111), Y(169), math.max(2, X(4)), math.max(2, Y(4)), linkColor)
  T(linkText, 160, 166, linkColor, 1.2, "center", 190)
  fillRect(X(205), Y(169), math.max(2, X(4)), math.max(2, Y(4)), linkColor)
  local detail, detailColor = detailInfo(now)
  T(detail, 160, 181, detailColor, 1, "center", 250)
  L(10, 194, 46, 194, COLOR.cyan)
  L(274, 194, 310, 194, COLOR.cyan)
  T("ATM10 / TO THE SKY", 160, 190, COLOR.muted, 1, "center", 115)
  gpu.sync()
end

local function renderCompact(now)
  local scale = math.min(width / 180, height / 160)
  local function X(v) return math.floor(v * scale + 0.5) end
  local function T(text, x, y, color, size, align, maxWidth)
    drawText(text, X(x), X(y), color, math.max(1, math.floor(size * scale + 0.5)),
      align, maxWidth and X(maxWidth) or nil)
  end
  local function L(x1, y1, x2, y2, color)
    line(X(x1), X(y1), X(x2), X(y2), color)
  end
  local solarState, solarColor = powerState(now, solarPowered, telemetry)
  local windState, windColor = powerState(now, windPowered, telemetryWind)
  local narrow = width < 100 or height < 100
  if narrow then
    local fs = 1
    centerText("SOLAR CORE", 3, COLOR.cyan, fs, width - 8)
    line(3, 13, width - 2, 13, COLOR.dim)
    local compactStates = { PRODUCING = "ON", CONFIGURED = "IDLE", ["LINK LOST"] = "LOST", UNKNOWN = "?" }
    T("S " .. countText(solar, solarKnown) .. " " .. (compactStates[solarState] or solarState), 4, 18, solarColor, 1, nil, 100)
    T("W " .. countText(wind, windKnown) .. " " .. (compactStates[windState] or windState), 4, 29, windColor, 1, nil, 100)
    T("SYSTEM " .. (online(now) and "ONLINE" or "STANDBY"), 4, 40,
      online(now) and COLOR.good or COLOR.warn, 1, nil, 100)
    local detail, detailColor = statusInfo(now)
    centerText(detail, math.max(50, height - 12), detailColor, fs, width - 6)
    gpu.sync()
    return
  end

  centerText("SOLAR CORE", X(5), COLOR.cyan, math.max(1, math.floor(scale + 0.5)), width - 8)
  L(5, 23, 175, 23, COLOR.dim)
  local function miniIcon(x, y, color, kind)
    if kind == "sun" then disk(x, y, math.max(2, math.floor(scale * 2)), color)
    else turbineIcon(x, y, math.max(4, math.floor(scale * 3)), color) end
  end

  miniIcon(X(12), X(37), COLOR.solar, "sun")
  T("SOLAR ARRAYS", 23, 31, COLOR.solar, 1.3, nil, 150)
  T("GENERATORS  " .. countText(solar, solarKnown) .. " CONFIGURED", 6, 45, COLOR.white, 1, nil, 166)
  T("PRODUCTION  " .. ((solarState == "PRODUCING") and "ACTIVE" or solarState), 6, 57, solarColor, 1, nil, 166)
  L(5, 68, 175, 68, COLOR.dim)

  miniIcon(X(12), X(82), COLOR.wind, "wind")
  T("WIND TURBINES", 23, 76, COLOR.wind, 1.3, nil, 150)
  T("GENERATORS  " .. countText(wind, windKnown) .. " CONFIGURED", 6, 90, COLOR.white, 1, nil, 166)
  T("PRODUCTION  " .. ((windState == "PRODUCING") and "ACTIVE" or windState), 6, 102, windColor, 1, nil, 166)
  L(5, 113, 175, 113, COLOR.dim)

  local linkText, linkColor = statusInfo(now)
  T(linkText, 90, 122, linkColor, 1, "center", 164)
  local detail, detailColor = detailInfo(now)
  T(detail, 90, 136, detailColor, 1, "center", 164)
  T("ATM10", 90, 151, COLOR.muted, 1, "center", 70)
  gpu.sync()
end

local function renderMicro(now)
  local title = width >= 56 and "SOLAR CORE" or "CORE"
  centerText(title, 2, COLOR.cyan, 1, width - 4)
  line(2, 12, width - 1, 12, COLOR.dim)
  local solarState, solarColor = powerState(now, solarPowered, telemetry)
  local windState, windColor = powerState(now, windPowered, telemetryWind)
  local microStates = { PRODUCING = "ON", CONFIGURED = "IDLE", ["LINK LOST"] = "LOST", UNKNOWN = "?" }
  local solarSummary = "S " .. countText(solar, solarKnown) .. " " .. (microStates[solarState] or solarState)
  local windSummary = "W " .. countText(wind, windKnown) .. " " .. (microStates[windState] or windState)
  drawText(solarSummary, 2, 16, solarColor, 1, nil, width - 4)
  drawText(windSummary, 2, 27, windColor, 1, nil, width - 4)
  local linkText, linkColor = statusInfo(now)
  drawText(linkText, 2, 39, linkColor, 1, nil, width - 4)
  drawText(solarSummary .. " / " .. windSummary, 2, 48, COLOR.muted, 1, nil, width - 4)
  if height >= 56 then
    line(2, 50, width - 1, 50, COLOR.dim)
    centerText("ATM10", height - 11, COLOR.muted, 1, width - 4)
  end
  fillRect(math.max(1, width - 5), 2, 3, 3, online(now) and COLOR.good or COLOR.warn)
  gpu.sync()
end

local function render(now)
  gpu.fill(COLOR.bg)
  if width >= 240 and height >= 150 and width / height >= 1.3 then
    renderWide(now)
  elseif width >= 100 and height >= 100 then
    renderCompact(now)
  else
    renderMicro(now)
  end
end

while true do
  local id, msg = rednet.receive("SOLARCORE", 0.5)
  local now = os.clock()
  updateMessage(id, msg, now)
  render(now)
end
