-- Fix Actually Useful Turtles blockColor watchdog timeout.
-- Run on the HOST/controller computer.

local sourcePath = "general/blockColor.lua"
if not fs.exists(sourcePath) then
    error("general/blockColor.lua not found. Run this on the host/controller.", 0)
end

local f = assert(fs.open(sourcePath, "r"))
local data = f.readAll()
f.close()

local changed = false

local oldDist = "local dist = deltaEFromRGB(r, g, b, cr, cg, cb)"
local newDist = "local dist = deltaE(r, g, b, cr, cg, cb) -- LABENHANCED_BLOCKCOLOR_FIX"
if data:find(oldDist, 1, true) then
    data = data:gsub(oldDist, newDist, 1)
    changed = true
end

local oldLine = "idToBlit[nameToId[name]] = blitTab[best]"
local replacement = "local id = nameToId[name]\n\t\tif id then idToBlit[id] = blitTab[best] end\n\t\tsleep(0) -- LABENHANCED_BLOCKCOLOR_YIELD"
if not data:find("LABENHANCED_BLOCKCOLOR_YIELD", 1, true) then
    if data:find(oldLine, 1, true) then
        data = data:gsub(oldLine, replacement, 1)
        changed = true
    else
        local oldGuard = "if id then idToBlit[id] = blitTab[best] end"
        if data:find(oldGuard, 1, true) then
            data = data:gsub(oldGuard, oldGuard .. "\n\t\tsleep(0) -- LABENHANCED_BLOCKCOLOR_YIELD", 1)
            changed = true
        end
    end
end

if not data:find("LABENHANCED_BLOCKCOLOR_YIELD", 1, true) then
    error("Could not add watchdog yield to host blockColor.lua.", 0)
end

local out = assert(fs.open(sourcePath, "w"))
out.write(data)
out.close()

fs.makeDir("runtime")
local runtimePath = "runtime/blockColor.lua"
local out2 = assert(fs.open(runtimePath, "w"))
out2.write(data)
out2.close()

print(changed and "Patched host blockColor source/runtime." or "Host blockColor already fully patched.")
print("Reboot HOST, then reboot turtles.")
