-- SOLAR CORE wireless sender for CC:Tweaked / ATM10
-- Computer 1: Ender Modem on bottom.
if not peripheral.isPresent("bottom") or peripheral.getType("bottom") ~= "modem" then
  error("No modem found on bottom. Attach the Ender Modem underneath this computer.")
end
rednet.open("bottom")
while true do
  rednet.broadcast({solar=4,wind=4}, "SOLARCORE")
  sleep(3)
end
