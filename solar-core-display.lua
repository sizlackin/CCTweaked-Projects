-- SOLAR CORE | Industrial telemetry display for CC:Tweaked / ATM10
-- Monitor computer: monitor attached, Ender Modem on top.
-- Designed for a 3-wide x 2-high monitor wall: small clean text, framed layout,
-- high-contrast sections, and a subtle animated core/scan line.

local mon = peripheral.find("monitor")
if not mon then error("No monitor found. Connect a monitor to this computer.") end
if not peripheral.isPresent("top") or peripheral.getType("top") ~= "modem" then
  error("No modem found on top. Attach the Ender Modem to the top.")
end

rednet.open("top")

-- 0.5 gives the fine, readable dashboard typography (not giant billboard text).
mon.setTextScale(0.5)
mon.setBackgroundColor(colors.black)
mon.setTextColor(colors.white)
mon.setCursorBlink(false)

local W, H = mon.getSize()
local lastSeen = 0
local solar, wind = 4, 4
local tick = 0

local C = {
  frame = colors.gray,
  muted = colors.lightGray,
  cyan = colors.cyan,
  solar = colors.yellow,
  wind = colors.lightBlue,
  good = colors.lime,
  warn = colors.orange,
  white = colors.white,
  black = colors.black
}

local function put(x, y, s, fg)
  if y < 1 or y > H or x > W then return end
  s = tostring(s)
  if x < 1 then s = string.sub(s, 2 - x); x = 1 end
  local room = W - x + 1
  if #s > room then s = string.sub(s, 1, room) end
  mon.setBackgroundColor(C.black)
  mon.setTextColor(fg or C.white)
  mon.setCursorPos(x, y)
  mon.write(s)
end

local function clearInner(y)
  if y < 2 or y > H - 1 then return end
  mon.setBackgroundColor(C.black)
  mon.setTextColor(C.white)
  mon.setCursorPos(2, y)
  mon.write(string.rep(" ", math.max(0, W - 2)))
end

local function line(y, s, fg, align)
  if y < 2 or y > H - 1 then return end
  clearInner(y)
  s = tostring(s)
  local innerW = math.max(1, W - 2)
  if #s > innerW then s = string.sub(s, 1, innerW) end
  local x = 2
  if align == "center" then x = math.max(2, math.floor((W - #s) / 2) + 1)
  elseif align == "right" then x = math.max(2, W - #s) end
  put(x, y, s, fg)
end

local function split(y, left, right, leftColor, rightColor)
  if y < 2 or y > H - 1 then return end
  clearInner(y)
  left, right = tostring(left), tostring(right)
  local innerW = math.max(1, W - 2)
  if #left + #right + 2 > innerW then
    local maxLeft = math.max(1, innerW - #right - 2)
    left = string.sub(left, 1, maxLeft)
  end
  put(2, y, left, leftColor or C.white)
  put(math.max(2, W - #right), y, right, rightColor or C.white)
end

local function rule(y, char, fg)
  if y < 1 or y > H then return end
  mon.setBackgroundColor(C.black)
  mon.setTextColor(fg or C.frame)
  mon.setCursorPos(1, y)
  if y == 1 or y == H then
    mon.write("+" .. string.rep(char, math.max(0, W - 2)) .. "+")
  else
    mon.write("+" .. string.rep(char, math.max(0, W - 2)) .. "+")
  end
end

local function frame()
  mon.setBackgroundColor(C.black)
  mon.clear()
  if W >= 3 and H >= 3 then
    mon.setTextColor(C.frame)
    mon.setCursorPos(1, 1)
    mon.write("+" .. string.rep("-", W - 2) .. "+")
    for y = 2, H - 1 do
      mon.setCursorPos(1, y); mon.write("|")
      mon.setCursorPos(W, y); mon.write("|")
    end
    mon.setCursorPos(1, H)
    mon.write("+" .. string.rep("-", W - 2) .. "+")
  end
end

local function render()
  local now = os.clock()
  local online = lastSeen > 0 and (now - lastSeen) < 12
  local age = online and math.max(0, now - lastSeen) or nil

  -- Compact fallback for smaller monitor configurations.
  if H < 18 or W < 30 then
    line(2, "SOLAR CORE", C.cyan, "center")
    line(3, "ENERGY CONTROL / ATM10", C.muted, "center")
    if H >= 5 then rule(4, "-", C.frame) end
    local core = {"[ * . . . ]  CORE IDLE", "[ . * . . ]  CORE IDLE",
                  "[ . . * . ]  CORE IDLE", "[ . . . * ]  CORE IDLE"}
    if H >= 6 then line(5, core[(math.floor(tick / 2) % #core) + 1], C.cyan, "center") end
    if H >= 7 then line(6, "GENERATION FLEET", C.muted, "center") end
    if H >= 8 then split(7, "SOLAR ARRAYS", string.format("%02d NODES", solar), C.solar, C.solar) end
    if H >= 9 then split(8, "WIND TURBINES", string.format("%02d NODES", wind), C.wind, C.wind) end
    if H >= 10 then rule(9, "-", C.frame) end
    if H >= 11 then split(10, "WIRELESS LINK", online and "ONLINE" or "STANDBY", C.cyan, online and C.good or C.warn) end
    if H >= 12 then line(11, online and string.format("LAST PACKET  %.1fs", age) or "WAITING FOR TELEMETRY", C.muted, "center") end
    if H >= 13 then line(12, "ATM10 / TO THE SKY", C.frame, "center") end
    return
  end

  line(2, "S O L A R   C O R E", C.cyan, "center")
  line(3, "GRID OPERATIONS  /  ATM10 SKYBLOCK", C.muted, "center")
  rule(4, "=", C.frame)

  local coreFrames = {
    "[  *        ]   CORE IDLE",
    "[   *       ]   CORE IDLE",
    "[    +      ]   CORE IDLE",
    "[     *     ]   CORE IDLE",
    "[      *    ]   CORE IDLE",
    "[     +     ]   CORE IDLE",
    "[    *      ]   CORE IDLE",
    "[   *       ]   CORE IDLE"
  }
  local activeFrames = {
    "[  *  +  *  ]   CORE SYNCHRONIZED",
    "[  +  *  +  ]   CORE SYNCHRONIZED",
    "[  *  +  *  ]   CORE SYNCHRONIZED",
    "[  +  *  +  ]   CORE SYNCHRONIZED"
  }
  local anim = online and activeFrames[(math.floor(tick / 2) % #activeFrames) + 1]
                     or coreFrames[(math.floor(tick / 2) % #coreFrames) + 1]
  line(5, anim, online and C.good or C.cyan, "center")

  line(6, "GENERATION FLEET", C.muted, "left")
  split(7, "SOLAR ARRAYS", string.format("%02d CONFIGURED", solar), C.solar, C.solar)
  split(8, "WIND TURBINES", string.format("%02d CONFIGURED", wind), C.wind, C.wind)
  rule(9, "-", C.frame)

  split(10, "WIRELESS UPLINK", online and "ONLINE" or "STANDBY",
    C.cyan, online and C.good or C.warn)
  split(11, "LAST TELEMETRY", online and string.format("%.1f SEC AGO", age) or "AWAITING NODE",
    C.muted, online and C.good or C.warn)

  local pulse = math.floor(tick / 2) % math.max(1, W - 12)
  local barW = math.min(18, math.max(8, W - 22))
  local pos = math.floor(tick / 2) % barW
  local scan = string.rep(".", barW)
  if barW > 0 then
    local chars = {}
    for i = 1, barW do chars[i] = (i == pos + 1) and "*" or "-" end
    scan = table.concat(chars)
  end
  line(12, "SIGNAL SCAN   [" .. scan .. "]", online and C.good or C.frame, "center")
  split(13, "DISPLAY NODE", "SC-02  /  ACTIVE", C.muted, C.cyan)
  rule(14, "-", C.frame)
  split(15, "CONTROL MODE", "MONITORING", C.muted, C.good)
  line(16, "FIELD TELEMETRY  //  ENERGY NETWORK", C.frame, "center")
  line(17, "ATM10  /  TO THE SKY", C.muted, "center")
end

frame()
while true do
  local id, msg = rednet.receive("SOLARCORE", 0.2)
  if id and type(msg) == "table" then
    lastSeen = os.clock()
    solar = tonumber(msg.solar) or solar
    wind = tonumber(msg.wind) or wind
  end
  tick = tick + 1
  render()
end
