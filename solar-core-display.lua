-- SOLAR CORE | Animated information billboard
-- CC:Tweaked / ATM10: To the Sky
-- Computer 2: monitor connected, Ender Modem on top.
-- Black background, restrained industrial colors, no window chrome, no boxes.
--
-- The sphere animates ONLY when the sender reports honest solar production
-- (msg.solarPowered, backed by msg.telemetry). Without real telemetry the
-- core is dim/dormant and the status row explains exactly what is missing.
-- Configured generator counts are shown as CONFIGURED, never as "producing".
--
-- Rendering is diff-based: a shadow buffer remembers every cell (char, fg, bg)
-- and flush() writes only cells whose content changed. The sphere region is
-- the only frequently-changing area, so redraw cost stays small and the
-- display never flickers from full clears.

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
  black    = colors.black,
  muted    = colors.lightGray,
  dim      = colors.gray,
  white    = colors.white,
  cyan     = colors.cyan,
  blue     = colors.lightBlue,
  deep     = colors.blue,
  solar    = colors.yellow,
  wind     = colors.lightBlue,
  good     = colors.lime,
  warn     = colors.orange,
  dormant  = colors.gray,
}

local atan2 = math.atan2 or function(y, x) return math.atan(y / x) end

-- ---------------------------------------------------------------------------
-- Diff renderer
-- ---------------------------------------------------------------------------

local shadow = {}            -- cells we want on screen
local live = {}              -- cells last flushed to the monitor

local function setCell(x, y, ch, fg, bg)
  if x < 1 or x > W or y < 1 or y > H then return end
  shadow[(y - 1) * W + x] = { ch, fg or C.white, bg or C.black }
end

local function writeText(y, x, text, fg, bg)
  for i = 1, #text do
    setCell(x + i - 1, y, text:sub(i, i), fg, bg)
  end
end

local function center(y, text, fg, bg)
  if y < 1 or y > H then return end
  text = tostring(text)
  if #text > W then text = text:sub(1, W) end
  writeText(y, math.floor((W - #text) / 2) + 1, text, fg, bg)
end

local function accent(cx, y, width, color)
  local startX = math.floor(cx - (width - 1) / 2)
  if startX < 1 then startX = 1 end
  for i = 1, width do
    setCell(startX + i - 1, y, " ", color, color)
  end
end

local function clearShadow()
  for i = 1, W * H do
    shadow[i] = { " ", C.white, C.black }
  end
end

local function flush()
  for y = 1, H do
    for x = 1, W do
      local i = (y - 1) * W + x
      local s = shadow[i] or { " ", C.white, C.black }
      local l = live[i]
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

-- ---------------------------------------------------------------------------
-- Energy sphere
-- A stylized holographic globe in characters: a rotating light side, a dark
-- side, latitude shading and an orbiting highlight. All frames are precomputed
-- once at the actual monitor size, so per-frame cost is a small blit.
-- ---------------------------------------------------------------------------

-- Glyph banks: index = brightness level, 1 = dimmest.
local SHADE_ACTIVE = { " ", ".", ":", "+", "=", "*", "%", "#" }
local SHADE_DORMANT = { " ", ":", ".", "=" }

local SPHERE_PHASES = 24
local sphereRows, sphereCols
local sphereFrames     -- [phase][row][col] = { char, color }
local dormantFrame     -- [row][col] = { char, color }

local function sphereDims(rows)
  local cols = math.max(15, math.floor(rows * 2.1))
  if cols % 2 == 0 then cols = cols + 1 end
  return rows, cols
end

local function buildFrames(rows)
  sphereRows, sphereCols = sphereDims(rows)
  local cx = (sphereCols + 1) / 2
  local cy = (sphereRows + 1) / 2
  local maxR = sphereRows / 2

  sphereFrames = {}
  for phase = 0, SPHERE_PHASES - 1 do
    local theta = (phase / SPHERE_PHASES) * math.pi * 2
    local f = {}
    for row = 1, sphereRows do
      local line = {}
      local dy = row - cy
      local halfW = math.sqrt(math.max(0, maxR * maxR - dy * dy)) * 2
      for col = 1, sphereCols do
        line[col] = { " ", C.black }
        local dx = (col - cx) / 2
        if math.abs(dx) <= halfW then
          local dz = math.sqrt(math.max(0, halfW * halfW - dx * dx)) / 2
          -- rotate the surface point around the vertical axis; cos of the
          -- angle to the light gives the terminator sweep
          local lightness = (math.cos(atan2(dz, dx) + theta) + 1) / 2
          lightness = lightness * (1 - (math.abs(dy) / maxR) * 0.35)
          local level = math.floor(lightness * (#SHADE_ACTIVE - 1)) + 1
          -- In-sphere cells are never blank: the shadow side keeps visible
          -- volume, so the silhouette always reads as a sphere.
          if level < 2 then level = 2 end
          local fg = (level <= 3) and C.deep or C.blue
          line[col] = { SHADE_ACTIVE[level], fg }
        end
      end
      f[row] = line
    end

    -- highlight: a small hot spot orbiting the upper hemisphere
    local ha = theta - math.pi / 3
    local hr = maxR * 0.55
    local hx = math.floor(cx + math.sin(ha) * hr * 2)
    local hy = math.floor(cy - math.cos(ha) * hr)
    if f[hy] and hx >= 1 and hx <= sphereCols and f[hy][hx][1] ~= " " then
      f[hy][hx] = { "@", C.white }
      if f[hy + 1] and f[hy + 1][hx] and f[hy + 1][hx][1] ~= " " then
        f[hy + 1][hx] = { "%", C.white }
      end
    end
    sphereFrames[phase] = f
  end

  -- Dormant: same silhouette, but reads as a globe even when still:
  -- a slightly brighter rim traces the outline, the body has a vertical
  -- gradient with a scanline texture, everything stays dim gray.
  dormantFrame = {}
  for row = 1, sphereRows do
    local line = {}
    local dy = row - cy
    local absdy = math.abs(dy)
    local halfW = math.sqrt(math.max(0, maxR * maxR - dy * dy)) * 2
    for col = 1, sphereCols do
      line[col] = { " ", C.black }
      local dx = (col - cx) / 2
      if math.abs(dx) <= halfW then
        local edge = halfW - math.abs(dx)
        local glyph, fg
        if edge <= 1.0 then
          glyph, fg = SHADE_DORMANT[#SHADE_DORMANT], C.muted -- rim
        else
          local lightness = 1 - absdy / maxR
          if row % 2 == 0 then lightness = lightness * 0.55 end
          local level = math.max(2,
            math.floor(lightness * (#SHADE_DORMANT - 2)) + 2)
          glyph, fg = SHADE_DORMANT[level], C.dormant
        end
        line[col] = { glyph, fg }
      end
    end
    dormantFrame[row] = line
  end
  -- small static gleam, upper left, just inside the rim
  local hx = math.floor(sphereCols * 0.35)
  local hy = math.max(2, math.floor(sphereRows * 0.3))
  if dormantFrame[hy][hx][1] ~= " " then
    dormantFrame[hy][hx] = { "*", C.white }
  end
end

local function drawSphere(topY, x0, frame)
  for r = 1, sphereRows do
    local line = frame[r]
    for col = 1, sphereCols do
      setCell(x0 + col - 1, topY + r - 1, line[col][1], line[col][2], C.black)
    end
  end
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

-- Vertical budget.
-- Full walls (H >= 13):
--   rows 2..4: header + subtitle + accent
--   row 5: breathing room under the accent
--   rows 6..(5+SR): sphere  (SR = H - 11, clamped 5..12)
--   +1: label row (solar left, wind right)
--   +1: value row (aligned under labels)
--   +1 blank, then link row and detail row
--   last row: footer
-- Compact terminals (H < 13): drop the subtitle accent rows and squeeze
-- sections together instead of letting the sphere eat the readouts.
local compact = H < 13
local sphereTop, SR, labelRow, valueRow, linkY, detailY
if compact then
  sphereTop = 3
  SR = math.max(3, math.min(5, H - 7))
  labelRow = sphereTop + SR
  valueRow = labelRow + 1
  linkY = valueRow + 1
  detailY = linkY + 1
else
  sphereTop = 6
  SR = math.max(5, math.min(12, H - 11))
  labelRow = sphereTop + SR
  valueRow = labelRow + 1
  linkY = valueRow + 2
  detailY = linkY + 1
end

buildFrames(SR)

-- ---------------------------------------------------------------------------
-- Live state
-- ---------------------------------------------------------------------------

local lastSeen = 0
local solar, wind = 0, 0
local solarPowered = false
local telemetry = nil
local senderOutdated = false  -- message arrived without solarPowered field

local function isOnline(now)
  return lastSeen > 0 and (now - lastSeen) < 12
end

local function statusInfo(now)
  if not isOnline(now) then
    return "LINK STANDBY", C.warn
  elseif senderOutdated then
    return "LINK ONLINE  /  SOLAR UNKNOWN", C.warn
  elseif telemetry then
    if solarPowered then
      return "LINK ONLINE  /  SOLAR PRODUCING", C.good
    end
    return "LINK ONLINE  /  SOLAR STANDBY", C.warn
  end
  return "LINK ONLINE  /  SOLAR UNKNOWN", C.warn
end

local function detailInfo(now)
  if not isOnline(now) then
    return "WIRELESS UPLINK  /  AWAITING SIGNAL", C.warn
  elseif senderOutdated then
    return "SENDER OUTDATED  /  UPDATE SOLAR-CORE-SENDER", C.warn
  elseif telemetry then
    return "WIRELESS UPLINK  /  SIGNAL: " .. tostring(telemetry), C.muted
  end
  return "NO POWER TELEMETRY  /  ADD AN ENERGY DETECTOR TO THE SENDER", C.warn
end

-- ---------------------------------------------------------------------------
-- Render
-- ---------------------------------------------------------------------------

local function render(now)
  local blink = math.floor(now * 2) % 2 == 0
  clearShadow()

  -- Header
  if compact then
    center(1, "SOLAR CORE", C.cyan)
  else
    center(2, "SOLAR CORE", C.cyan)
    center(3, "POWER NETWORK  /  ATM10 : TO THE SKY", C.muted)
    accent((W + 1) / 2, 4, math.min(7, W), C.cyan)
  end

  -- Hero sphere, centered
  local frame, cols
  if solarPowered and isOnline(now) then
    frame = sphereFrames[math.floor(now * 8) % SPHERE_PHASES]
    cols = sphereCols
  else
    frame = dormantFrame
    cols = sphereCols
  end
  drawSphere(sphereTop, math.floor((W - cols) / 2) + 1, frame)

  -- Fleet readouts: left solar, right wind, aligned columns.
  -- Wide walls: side-by-side blocks. Narrow terminals: stacked rows.
  local solarProducing = solarPowered and isOnline(now)
  -- While no message has ever arrived, counts are unknown, not zero:
  -- show "--" so an idle billboard does not read as an empty fleet.
  local solarCountText = (lastSeen == 0 and solar == 0) and "--"
    or string.format("%02d", solar)
  local windCountText = (lastSeen == 0 and wind == 0) and "--"
    or string.format("%02d", wind)
  local solarValue = string.format("%s %s", solarCountText,
    solarProducing and "PRODUCING" or "CONFIGURED")
  local windValue = string.format("%s CONFIGURED", windCountText)

  if W >= 37 then
    local leftX = 3
    local rightX = W - 17          -- mirror the left block's 4-space indent
    writeText(labelRow, leftX, "> SOLAR ARRAYS", C.solar)
    writeText(labelRow, rightX, "> WIND TURBINES", C.wind)
    writeText(valueRow, leftX + 4, solarValue,
      solarProducing and C.good or C.white)
    writeText(valueRow, rightX + 4, windValue, C.white)
  else
    writeText(labelRow, 3, "> SOLAR", C.solar)
    writeText(labelRow, 10, solarValue, solarProducing and C.good or C.white)
    writeText(valueRow, 3, "> WIND", C.wind)
    writeText(valueRow, 10, windValue, C.white)
  end

  -- Link status with subtle blinking side markers
  local status, statusColor = statusInfo(now)
  center(linkY, status, statusColor)
  local sx = math.floor((W - #status) / 2) + 1
  local led = (isOnline(now) and blink) and C.white or statusColor
  if sx > 2 then setCell(sx - 2, linkY, " ", led, led) end
  if sx + #status + 1 <= W then setCell(sx + #status + 1, linkY, " ", led, led) end

  local detail, detailColor = detailInfo(now)
  if detailY and detailY <= H - 1 then
    center(detailY, detail, detailColor)
  end

  -- Footer
  center(H, "ATM10  /  TO THE SKY", C.dim)

  flush()
end

-- ---------------------------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------------------------

mon.setBackgroundColour(colors.black)
mon.setTextColour(colors.white)
mon.clear()

while true do
  local id, msg = rednet.receive("SOLARCORE", 0.15)
  local now = os.clock()

  if id and type(msg) == "table" then
    lastSeen = now
    solar = tonumber(msg.solar) or solar
    wind = tonumber(msg.wind) or wind
    senderOutdated = (msg.solarPowered == nil)
    -- Honest state only: the flag must come from the sender's real probes.
    solarPowered = msg.solarPowered == true
    telemetry = msg.telemetry
  end

  render(now)
end
