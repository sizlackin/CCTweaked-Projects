-- SOLAR CORE | Animated information billboard
-- CC:Tweaked / ATM10: To the Sky
-- Computer 2: monitor connected, Ender Modem on top.
-- Clean centered composition: no window chrome or boxed panels.

local mon = peripheral.find("monitor")
if not mon then error("No monitor found. Connect a monitor to this computer.") end
if not peripheral.isPresent("top") or peripheral.getType("top") ~= "modem" then
  error("No modem found on top. Attach the Ender Modem to the top.")
end

rednet.open("top")
mon.setTextScale(0.5)
mon.setCursorBlink(false)
mon.setBackgroundColor(colors.black)

local W, H = mon.getSize()
local lastSeen = 0
local solar, wind = 4, 4

local C = {
  black = colors.black,
  muted = colors.lightGray,
  dim = colors.gray,
  white = colors.white,
  cyan = colors.cyan,
  core = colors.lightBlue,
  solar = colors.yellow,
  wind = colors.lightBlue,
  good = colors.lime,
  warn = colors.orange
}

local function put(x, y, text, fg, bg)
  if y < 1 or y > H or x > W then return end
  text = tostring(text)
  if x < 1 then
    text = string.sub(text, 2 - x)
    x = 1
  end
  local room = W - x + 1
  if #text > room then text = string.sub(text, 1, room) end
  if #text == 0 then return end
  mon.setBackgroundColor(bg or C.black)
  mon.setTextColor(fg or C.white)
  mon.setCursorPos(x, y)
  mon.write(text)
end

local function centeredAt(cx, y, text, fg)
  text = tostring(text)
  if y < 1 or y > H then return end
  if #text > W then text = string.sub(text, 1, W) end
  put(math.floor(cx - (#text - 1) / 2), y, text, fg or C.white)
end

local function centered(y, text, fg)
  centeredAt((W + 1) / 2, y, text, fg)
end

local function accentBar(centerX, y, width, color)
  width = math.min(width, W)
  local startX = math.floor(centerX - (width - 1) / 2)
  if startX < 1 then startX = 1 end
  if startX + width - 1 > W then startX = W - width + 1 end
  if startX < 1 or y < 1 or y > H then return end
  mon.setBackgroundColor(color)
  mon.setTextColor(color)
  mon.setCursorPos(startX, y)
  mon.write(string.rep(" ", width))
end

local function statusIndicator(y, online, blink)
  local text = online and "LINK ONLINE" or "LINK STANDBY"
  local fg = online and C.good or C.warn
  centered(y, text, fg)
  local startX = math.floor((W - #text) / 2) + 1
  local led = (online and blink) and C.white or fg
  if startX > 2 then accentBar(startX - 2, y, 1, led) end
  if startX + #text + 1 <= W then accentBar(startX + #text + 1, y, 1, led) end
end

local coreFrames = {
  "    .  *  .    ",
  "    *  +  *    ",
  "    .  +  .    ",
  "    *  +  *    ",
  "    .  *  .    ",
  "    +  *  +    "
}

local function render()
  local now = os.clock()
  local online = lastSeen > 0 and (now - lastSeen) < 12
  local age = online and string.format("%.1fs", math.max(0, now - lastSeen)) or nil
  local blink = math.floor(now * 2) % 2 == 0

  mon.setBackgroundColor(C.black)
  mon.setTextColor(C.white)
  mon.clear()

  -- Header: centered identity with a small, solid-color accent.
  centered(2, "SOLAR CORE", C.cyan)
  centered(3, "POWER NETWORK  /  ATM10 : TO THE SKY", C.muted)
  accentBar((W + 1) / 2, 4, math.min(7, W), C.cyan)

  -- Keep the original animated core as the visual focal point.
  local coreY = math.max(5, math.floor(H * 0.28))
  centered(coreY, coreFrames[(math.floor(now * 2.5) % #coreFrames) + 1],
    blink and C.cyan or C.core)
  centered(coreY + 1, online and "ENERGY MATRIX / SYNCHRONIZED" or "ENERGY MATRIX / STANDBY",
    online and C.good or C.muted)

  -- Symmetrical generator readouts with matching label/value/accent positions.
  local fleetY = math.max(coreY + 3, math.floor(H * 0.49))
  centered(fleetY, "GENERATION FLEET", C.muted)

  local leftCenter = math.floor(W * 0.28)
  local rightCenter = math.floor(W * 0.72)

  centeredAt(leftCenter, fleetY + 1, "SOLAR ARRAYS", C.solar)
  centeredAt(leftCenter, fleetY + 2, string.format("%02d CONFIGURED", solar), C.white)
  accentBar(leftCenter, fleetY + 3, math.min(9, W), C.solar)

  centeredAt(rightCenter, fleetY + 1, "WIND TURBINES", C.wind)
  centeredAt(rightCenter, fleetY + 2, string.format("%02d CONFIGURED", wind), C.white)
  accentBar(rightCenter, fleetY + 3, math.min(9, W), C.wind)

  -- Informational wireless status, not a button or window element.
  local linkY = math.min(H - 4, math.max(fleetY + 5, math.floor(H * 0.75)))
  statusIndicator(linkY, online, blink)
  local detail = online and ("WIRELESS UPLINK  /  LAST RX " .. age)
    or "WIRELESS UPLINK  /  AWAITING SIGNAL"
  centered(linkY + 1, detail, online and C.muted or C.warn)

  centered(H - 1, "ATM10  /  TO THE SKY", C.dim)
end

while true do
  local id, msg = rednet.receive("SOLARCORE", 0.15)
  if id and type(msg) == "table" then
    lastSeen = os.clock()
    solar = tonumber(msg.solar) or solar
    wind = tonumber(msg.wind) or wind
  end
  render()
end
