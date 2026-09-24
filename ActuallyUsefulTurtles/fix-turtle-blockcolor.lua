-- Robust turtle-side fix for Actually Useful Turtles blockColor watchdog timeout.
-- Run this ON a turtle showing "runtime/blockColor.lua:... Too long without yielding".

if not turtle then error("Run this on the turtle.", 0) end

local target = "runtime/blockColor.lua"
if not fs.exists(target) then error(target .. " not found.", 0) end

local f = assert(fs.open(target, "r"))
local data = f.readAll()
f.close()

local changed = false

-- Use the much cheaper CIE76 distance during palette generation.
local oldDist = "local dist = deltaEFromRGB(r, g, b, cr, cg, cb)"
local newDist = "local dist = deltaE(r, g, b, cr, cg, cb) -- LABENHANCED_BLOCKCOLOR_FIX"
if data:find(oldDist, 1, true) then
    data = data:gsub(oldDist, newDist, 1)
    changed = true
end

-- Make the palette mapping nil-safe and yield once per mapped block.
local oldLine = "idToBlit[nameToId[name]] = blitTab[best]"
local replacement = "local id = nameToId[name]\n\t\tif id then idToBlit[id] = blitTab[best] end\n\t\tsleep(0) -- LABENHANCED_BLOCKCOLOR_YIELD"

if not data:find("LABENHANCED_BLOCKCOLOR_YIELD", 1, true) then
    if data:find(oldLine, 1, true) then
        data = data:gsub(oldLine, replacement, 1)
        changed = true
    else
        -- Handle an older partially-patched form which already has the nil guard.
        local oldGuard = "if id then idToBlit[id] = blitTab[best] end"
        if data:find(oldGuard, 1, true) then
            data = data:gsub(oldGuard, oldGuard .. "\n\t\tsleep(0) -- LABENHANCED_BLOCKCOLOR_YIELD", 1)
            changed = true
        end
    end
end

if not data:find("LABENHANCED_BLOCKCOLOR_YIELD", 1, true) then
    error("Could not add watchdog yield to blockColor.lua.", 0)
end

local out = assert(fs.open(target, "w"))
out.write(data)
out.close()

print(changed and "Fixed runtime/blockColor.lua" or "blockColor.lua already fully fixed.")
print("Reboot this turtle now.")
