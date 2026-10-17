-- SOLAR CORE | Solar and wind monitor
-- CC:Tweaked / ATM10: To the Sky
-- Computer 2: CC:Tweaked monitor connected, Ender Modem on top.
-- Static industrial composition: solar, core, and wind graphics with readouts.
--
-- Tom's Peripherals 1.3.1 provides pixel graphics on a separate tm_gpu
-- peripheral that drives its own monitor blocks, not the CC:Tweaked monitor
-- returned by peripheral.find("monitor"). The icons below are character-cell
-- art in the existing diff renderer to avoid competing writers/flicker.
--
-- The installed tm_gpu API includes fill, filled rectangles, rectangles,
-- lines, text/image drawing, and sync. Counts/states use recent telemetry only.

local mon = peripheral.find("monitor")
if not mon then error("No monitor found. Connect a monitor to this computer.") end
if not peripheral.isPresent("top") or peripheral.getType("top") ~= "modem" then
  error("No modem found on top. Attach the Ender Modem to the top.")
end

rednet.open("top")
mon.setTextScale(0.5)
mon.setCursorBlink(false)

local W, H = mon.getSize()
local C = {
  black = colors.black,
  white = colors.white,
  muted = colors.lightGray,
  dim = colors.gray,
  cyan = colors.cyan,
  solar = colors.yellow,
  wind = colors.lightBlue,
  good = colors.lime,
  warn = colors.orange,
}

-- Diff renderer: only changed character, foreground, or background cells write.
local shadow, live = {}, {}

local function setCell(x, y, ch, fg, bg)
  if x < 1 or x > W or y < 1 or y > H then return end
  shadow[(y - 1) * W + x] = { ch, fg or C.white, bg or C.black }
end

local function writeText(y, x, text, fg, bg)
  if y < 1 or y > H then return end
  for i = 1, #text do setCell(x + i - 1, y, text:sub(i, i), fg, bg) end
end

local function writeClipped(y, x, text, fg, width)
  if y < 1 or y > H or x < 1 or x > W then return end
  if type(text) == "table" then text, fg = text.text, text.color end
  width = math.min(width or (W - x + 1), W - x + 1)
  if width > 0 then writeText(y, x, text:sub(1, width), fg) end
end

local function center(y, text, fg)
  if y < 1 or y > H then return end
  if type(text) == "table" then text, fg = text.text, text.color end
  text = tostring(text)
  if #text > W then text = text:sub(1, W) end
  writeText(y, math.floor((W - #text) / 2) + 1, text, fg)
end

local function clearShadow()
  for i = 1, W * H do shadow[i] = { " ", C.white, C.black } end
end

local function flush()
  for y = 1, H do
    for x = 1, W do
      local i = (y - 1) * W + x
      local s, l = shadow[i] or { " ", C.white, C.black }, live[i]
      if l == nil or l[1] ~= s[1] or l[2] ~= s[2] or l[3] ~= s[3] then
        mon.setBackgroundColour(s[3])
        mon.setTextColour(s[2])
        mon.setCursorPos(x, y)
        mon.write(s[1])
        live[i] = { s[1], s[2], s[3] }
      end
    end
  end
end

local function divider(y)
  if y >= 1 and y <= H then writeText(y, 1, string.rep("-", W), C.dim) end
end

-- Static, low-resolution solar, core, and turbine icons for the CC monitor.
local function pattern(x, y, rows, color)
  for row = 1, #rows do
    for col = 1, #rows[row] do
      setCell(x + col - 1, y + row - 1, rows[row]:sub(col, col), color)
    end
  end
end

local function drawIcons(y)
  if W < 27 or H < 12 then return false end
  local solarX, coreX, windX = 5, math.floor((W + 1) / 2), W - 4
  if solarX + 2 >= coreX - 2 or coreX + 2 >= windX - 2 then return false end
  pattern(solarX - 2, y, { " \\|/ ", "-(O)-", " /|\\ " }, C.solar)
  pattern(coreX - 2, y, { "+---+", "|>_ |", "+---+" }, C.cyan)
  pattern(windX - 2, y, { "  |  ", "\\-O-/", "  |  " }, C.wind)
  return true
end

local function drawMiniIcons(y)
  if W >= 1 then setCell(1, y, "*", C.solar) end
  if W >= 3 then setCell(math.floor((W + 1) / 2), y, ">", C.cyan) end
  if W >= 2 then setCell(W, y, "Y", C.wind) end
end

-- The primary 29x12 wall uses the reference composition. Taller walls gain
-- breathing room; shorter or narrower displays stack their main readouts.
local wide = W >= 27 and H >= 12
local expanded = W >= 37 and H >= 15
local iconTop = expanded and 5 or (wide and 3 or 2)
local titleRow = expanded and 2 or 1
local ruleRow = expanded and 4 or (wide and 2 or nil)
local sectionRow = expanded and 8 or (wide and 6 or nil)
local countRow = sectionRow and sectionRow + 1 or nil
local stateRow = sectionRow and sectionRow + 2 or nil
local ruleFooterRow = expanded and 11 or (wide and 9 or nil)
local statusRow = expanded and 12 or (wide and 10 or math.max(1, H - 3))
local detailRow = expanded and H - 1 or (wide and 11 or math.max(1, H - 2))
local compactReadoutRow = math.max(3, math.floor(H / 2))

-- Live state / sender compatibility.
local lastSeen = 0
local solar, wind = 0, 0
local solarKnown, windKnown = false, false
local solarPowered, windPowered = nil, nil
local telemetry, telemetryWind = nil, nil
local senderOutdated = false

local function isOnline(now)
  return lastSeen > 0 and (now - lastSeen) < 12
end

local function hasTelemetry(source)
  return type(source) == "string" and source ~= ""
end

local function powerState(now, powered, source)
  if not isOnline(now) then return lastSeen > 0 and "LINK LOST" or "UNKNOWN", C.warn end
  if senderOutdated or not hasTelemetry(source) or powered == nil then return "UNKNOWN", C.warn end
  if powered then return "PRODUCING", C.good end
  return "CONFIGURED", C.white
end

local function statusInfo(now)
  if not isOnline(now) then return "LINK OFFLINE", C.warn end
  if senderOutdated or not hasTelemetry(telemetry) then return "LINK ONLINE / SOLAR UNKNOWN", C.warn end
  if solarPowered then return "ONLINE / SOLAR PRODUCING", C.good end
  return "ONLINE / SOLAR CONFIGURED", C.white
end

local function detailInfo(now)
  if not isOnline(now) then return "WIRELESS / AWAITING SIGNAL", C.warn end
  if senderOutdated then return "SENDER OUTDATED / UPDATE REQUIRED", C.warn end
  if hasTelemetry(telemetry) then return "WIRELESS / " .. tostring(telemetry), C.muted end
  return "WIRELESS / NO SENSOR DATA", C.warn
end

local function footerText()
  return H >= 12 and "ATM10 / TO THE SKY" or "ATM10"
end

local function countText(value, known)
  if not known then return "--" end
  local n = tonumber(value)
  if not n then return "--" end
  return string.format("%02d", math.max(0, math.floor(n)))
end

local function render(now)
  clearShadow()
  local online = isOnline(now)
  local link = online and "ONLINE" or "OFFLINE"
  local solarState, solarColor = powerState(now, solarPowered, telemetry)
  local windState, windColor = powerState(now, windPowered, telemetryWind)

  if wide then
    if expanded then
      writeClipped(titleRow, 2, "SOLAR CORE", C.cyan, W - 12)
      writeClipped(titleRow, W - #link + 1, link, online and C.good or C.warn, #link)
      center(3, "POWER NETWORK / ATM10 : TO THE SKY", C.muted)
    else
      writeClipped(titleRow, 2, "SOLAR CORE", C.cyan, W - 12)
      writeClipped(titleRow, W - #link + 1, link, online and C.good or C.warn, #link)
    end
    if ruleRow then divider(ruleRow) end
    if not drawIcons(iconTop) then drawMiniIcons(iconTop) end

    local leftX, rightX = 2, W - 14
    local leftWidth = rightX - leftX - 1
    if sectionRow then
      writeClipped(sectionRow, leftX, "SOLAR ARRAYS", C.solar, leftWidth)
      writeClipped(sectionRow, rightX, "WIND TURBINES", C.wind, W - rightX)
      writeClipped(countRow, leftX, "UNITS: " .. countText(solar, solarKnown), C.white, leftWidth)
      writeClipped(countRow, rightX, "UNITS: " .. countText(wind, windKnown), C.white, W - rightX)
      writeClipped(stateRow, leftX, solarState, solarColor, leftWidth)
      writeClipped(stateRow, rightX, windState, windColor, W - rightX)
    end
    if ruleFooterRow then divider(ruleFooterRow) end
    local status, statusColor = statusInfo(now)
    center(statusRow, status, statusColor)
    if detailRow > statusRow and detailRow < H then
      local detail, detailColor = detailInfo(now)
      center(detailRow, detail, detailColor)
    end
  else
    center(1, W >= 9 and "SOLAR CORE" or "CORE", C.cyan)
    if H >= 6 then drawMiniIcons(2) end
    if H >= 6 then
      local readoutY = math.min(compactReadoutRow, H - 3)
      writeClipped(readoutY, 1, "SOLAR " .. countText(solar, solarKnown) .. " " .. solarState, solarColor)
      writeClipped(readoutY + 1, 1, "WIND " .. countText(wind, windKnown) .. " " .. windState, windColor)
    elseif H >= 3 then
      writeClipped(2, 1, "S " .. countText(solar, solarKnown), C.solar)
      writeClipped(3, 1, "W " .. countText(wind, windKnown), C.wind)
    end
    local status, statusColor = statusInfo(now)
    center(statusRow, status, statusColor)
    if detailRow > statusRow and detailRow < H then
      local detail, detailColor = detailInfo(now)
      center(detailRow, detail, detailColor)
    end
  end

  if H >= 2 then center(H, footerText(), C.dim) end
  flush()
end

-- Keep the existing top modem and SOLARCORE protocol/timeout behavior.
mon.setBackgroundColour(colors.black)
mon.setTextColour(colors.white)
mon.clear()

while true do
  local id, msg = rednet.receive("SOLARCORE", 0.15)
  local now = os.clock()

  if id and type(msg) == "table" then
    lastSeen = now
    local solarValue, windValue = tonumber(msg.solar), tonumber(msg.wind)
    if solarValue ~= nil then solar, solarKnown = solarValue, true end
    if windValue ~= nil then wind, windKnown = windValue, true end

    senderOutdated = type(msg.solarPowered) ~= "boolean"
    if type(msg.solarPowered) == "boolean" then
      solarPowered = msg.solarPowered
    else
      solarPowered = nil
    end
    if type(msg.windPowered) == "boolean" then
      windPowered = msg.windPowered
    else
      windPowered = nil
    end
    telemetry, telemetryWind = msg.telemetry, msg.telemetryWind
  end

  render(now)
end
