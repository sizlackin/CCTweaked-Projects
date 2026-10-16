-- SOLAR CORE wireless display for CC:Tweaked / ATM10
-- Computer 2: monitor on back, Ender Modem on top.
local mon = peripheral.find("monitor")
if not mon then error("No monitor found. Check the monitor is connected to this computer.") end
if not peripheral.isPresent("top") or peripheral.getType("top") ~= "modem" then
  error("No modem found on top. Attach the Ender Modem to the top.")
end
rednet.open("top")
mon.setTextScale(0.5)
local W,H = mon.getSize()
local lastSeen = 0
local solar, wind = 4, 4
local function centered(y, s, c)
  s = tostring(s)
  local x = math.max(1, math.floor((W-#s)/2)+1)
  mon.setCursorPos(x,y)
  if c then mon.setTextColor(c) end
  mon.write(s)
end
local tick = 0
while true do
  local id, msg = rednet.receive("SOLARCORE", 0.15)
  if id and type(msg) == "table" then
    lastSeen = os.clock()
    solar = tonumber(msg.solar) or solar
    wind = tonumber(msg.wind) or wind
  end
  tick = tick + 1
  mon.setBackgroundColor(colors.black)
  mon.setTextColor(colors.cyan)
  mon.clear()
  centered(1, "S O L A R   C O R E", colors.cyan)
  mon.setTextColor(colors.gray)
  centered(2, "POWER SYSTEMS  //  ATM10", colors.gray)
  local frames = {"[     *     ]","[   * * *   ]","[ * * * * * ]","[   * * *   ]"}
  centered(math.max(4,math.floor(H/2)-1), frames[(math.floor(tick/3)%#frames)+1], colors.lightBlue)
  centered(math.max(5,math.floor(H/2)), ">>> ENERGY MATRIX <<<", colors.white)
  centered(math.max(6,math.floor(H/2)+2), "SOLAR GEN   "..solar, colors.yellow)
  centered(math.max(7,math.floor(H/2)+3), "WIND GEN    "..wind, colors.lightBlue)
  local online = lastSeen > 0 and (os.clock()-lastSeen) < 12
  centered(H-1, online and "LINK: ONLINE" or "LINK: STANDBY", online and colors.lime or colors.orange)
  centered(H, "WIRELESS UPLINK", colors.gray)
end
