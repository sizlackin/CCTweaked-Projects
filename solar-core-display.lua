-- SOLAR CORE billboard display for CC:Tweaked / ATM10
-- Computer 2: monitor connected, Ender Modem on top.
-- Automatically chooses the largest text scale that fits the full sign.

local mon = peripheral.find("monitor")
if not mon then error("No monitor found. Connect a monitor to this computer.") end
if not peripheral.isPresent("top") or peripheral.getType("top") ~= "modem" then
  error("No modem found on top. Attach the Ender Modem to the top.")
end

rednet.open("top")

-- Try the biggest text first, stepping down only when the whole sign won't fit.
local scales = {5, 4, 3, 2.5, 2, 1.5, 1, 0.75, 0.5}
local W, H
for _, scale in ipairs(scales) do
  local ok = pcall(function() mon.setTextScale(scale) end)
  if ok then
    W, H = mon.getSize()
    if W >= 12 and H >= 5 then break end
  end
end
W, H = mon.getSize()

local lastSeen = 0
local solar, wind = 4, 4

local function centered(y, s, color)
  s = tostring(s)
  if #s > W then s = string.sub(s, 1, W) end
  mon.setTextColor(color)
  mon.setCursorPos(math.max(1, math.floor((W - #s) / 2) + 1), y)
  mon.write(s)
end

local function render()
  mon.setBackgroundColor(colors.black)
  mon.clear()

  -- Five bold, high-contrast lines designed to be readable at a distance.
  local top = math.max(1, math.floor((H - 5) / 2) + 1)
  local online = lastSeen > 0 and (os.clock() - lastSeen) < 12

  centered(top,     "SOLAR CORE",  colors.cyan)
  centered(top + 1, "SOLAR GEN " .. solar, colors.yellow)
  centered(top + 2, "WIND GEN " .. wind, colors.lightBlue)
  centered(top + 3, online and "LINK ONLINE" or "LINK STANDBY",
    online and colors.lime or colors.orange)
  centered(top + 4, "ATM10 POWER", colors.gray)
end

while true do
  local id, msg = rednet.receive("SOLARCORE", 0.5)
  if id and type(msg) == "table" then
    lastSeen = os.clock()
    solar = tonumber(msg.solar) or solar
    wind = tonumber(msg.wind) or wind
  end
  render()
end
