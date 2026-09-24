-- Direct turtle-side fix for Actually Useful Turtles blockColor watchdog timeout.
-- Run this ON THE TURTLE which shows "Too long without yielding".

if not turtle then error("Run this on the turtle.", 0) end

local target = "runtime/blockColor.lua"
if not fs.exists(target) then error(target .. " not found.", 0) end

local f = assert(fs.open(target, "r"))
local data = f.readAll()
f.close()

if data:find("LABENHANCED_BLOCKCOLOR_FIX", 1, true) then
    print("blockColor.lua is already fixed.")
else
    local old = "local dist = deltaEFromRGB(r, g, b, cr, cg, cb)"
    local new = "local dist = deltaE(r, g, b, cr, cg, cb) -- LABENHANCED_BLOCKCOLOR_FIX"
    local s, e = data:find(old, 1, true)
    if not s then error("Could not locate color-distance line.", 0) end
    data = data:sub(1, s - 1) .. new .. data:sub(e + 1)

    local old2 = "nameToBlit[name] = blitTab[best]\n\t\tidToBlit[nameToId[name]] = blitTab[best]"
    local new2 = "nameToBlit[name] = blitTab[best]\n\t\tlocal id = nameToId[name]\n\t\tif id then idToBlit[id] = blitTab[best] end\n\t\tsleep(0)"
    local s2, e2 = data:find(old2, 1, true)
    if not s2 then error("Could not locate palette output lines.", 0) end
    data = data:sub(1, s2 - 1) .. new2 .. data:sub(e2 + 1)

    local out = assert(fs.open(target, "w"))
    out.write(data)
    out.close()
    print("Fixed runtime/blockColor.lua")
end

print("Reboot this turtle now.")
