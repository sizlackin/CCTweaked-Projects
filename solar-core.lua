-- Solar Core - ATM10: To the Sky
-- Animated ComputerCraft / CC:Tweaked monitor screensaver
-- Install: wget run https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/solar-core.lua
-- Stop with Ctrl+T. Press any key on the computer to exit the screensaver.

local monitor = peripheral.find("monitor")
if not monitor then
  error("Solar Core: no monitor found. Connect a monitor and modem.")
end

monitor.setTextScale(0.5)
monitor.setBackgroundColor(colors.black)
monitor.clear()

local W, H = monitor.getSize()
local frame = 0
local oldTerm = term.redirect(monitor)

local function put(x, y, text, color)
  if y < 1 or y > H then return end
  text = tostring(text or "")
  if color then monitor.setTextColor(color) end
  if #text > W then text = text:sub(1, W) end
  x = math.max(1, math.min(W - #text + 1, x))
  monitor.setCursorPos(x, y)
  monitor.write(text)
end

local function center(y, text, color)
  text = tostring(text or "")
  put(math.floor((W - #text) / 2) + 1, y, text, color)
end

local function safeRow(y, text, color)
  if y >= 1 and y <= H then center(y, text, color) end
end

local messages = {
  "GRID STABLE",
  "SOLAR ARRAY ACTIVE",
  "WIND NETWORK ACTIVE",
  "MONITORING THE SKY",
  "WELCOME HOME"
}

local function draw()
  monitor.setBackgroundColor(colors.black)
  monitor.setTextColor(colors.white)
  monitor.clear()

  -- Slowly drifting starfield
  for i = 1, math.min(30, math.floor(W * H / 20)) do
    local x = ((i * 19 + math.floor(frame * (i % 3 + 1))) % W) + 1
    local y = ((i * 11 + math.floor(frame / 2) * (i % 2 + 1)) % H) + 1
    local ch = (i % 5 == 0) and "+" or "."
    put(x, y, ch, (i % 4 == 0) and colors.white or colors.lightBlue)
  end

  -- Header
  safeRow(2, "S O L A R   C O R E", colors.cyan)
  safeRow(3, "ATM10 // SKYBASE NETWORK", colors.gray)

  -- Animated core: text-only, compatible with CC:Tweaked monitors
  local cores = {
    "     .     ",
    "   . o .   ",
    " .  (O)  . ",
    "   . @ .   ",
    "     *     ",
    "   . @ .   ",
    " .  (O)  . ",
    "   . o .   "
  }
  local coreY = math.max(4, math.floor(H * 0.36))
  safeRow(coreY, cores[math.floor(frame / 2) % #cores + 1], colors.lightBlue)
  safeRow(coreY + 1, "POWERING THE SKY", colors.white)

  -- Generator labels are intentionally illustrative, not live readings.
  safeRow(H - 5, "[ SOLAR ]  04 GENERATORS", colors.yellow)
  safeRow(H - 4, "[ WIND  ]  04 GENERATORS", colors.lightBlue)

  local message = messages[math.floor(frame / 6) % #messages + 1]
  safeRow(H - 2, message, colors.lime)
  safeRow(H, "SYSTEM ONLINE", colors.cyan)

  frame = frame + 1
end

local ok, err = pcall(function()
  while true do
    draw()
    sleep(0.35)
  end
end)

term.redirect(oldTerm)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)
monitor.clear()
if not ok and not tostring(err):find("Terminated") then
  print("Solar Core stopped: " .. tostring(err))
end
