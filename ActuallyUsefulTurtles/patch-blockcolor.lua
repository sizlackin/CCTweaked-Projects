-- Fix Actually Useful Turtles startup crash: "Too long without yielding"
-- Run on the HOST/controller computer, not on a turtle.

local sourcePath = "general/blockColor.lua"
if not fs.exists(sourcePath) then
    error("general/blockColor.lua not found. Run this on the host/controller.", 0)
end

local f = assert(fs.open(sourcePath, "r"))
local data = f.readAll()
f.close()

if data:find("processed %% 8 == 0") then
    print("blockColor.lua is already patched.")
else
    local function replacePlain(text, old, new)
        local s, e = text:find(old, 1, true)
        if not s then return nil end
        return text:sub(1, s - 1) .. new .. text:sub(e + 1)
    end

    data = replacePlain(
        data,
        "for name, rgb in pairs(nameToRGB) do",
        "local processed = 0\n\tfor name, rgb in pairs(nameToRGB) do"
    )
    if not data then error("Could not find palette loop to patch.", 0) end

    data = replacePlain(
        data,
        "idToBlit[nameToId[name]] = blitTab[best]\n\tend\nend\nmapToPalette()",
        "local id = nameToId[name]\n\t\tif id then idToBlit[id] = blitTab[best] end\n\t\tprocessed = processed + 1\n\t\tif processed % 8 == 0 then sleep(0) end\n\tend\nend\nmapToPalette()"
    )
    if not data then error("Could not find palette loop ending to patch.", 0) end

    local out = assert(fs.open(sourcePath, "w"))
    out.write(data)
    out.close()
    print("Patched general/blockColor.lua")
end

fs.makeDir("runtime")
if fs.exists("runtime/blockColor.lua") then fs.delete("runtime/blockColor.lua") end
fs.copy(sourcePath, "runtime/blockColor.lua")

print("Patched runtime/blockColor.lua")
print("Reboot the HOST, wait for dashboard, then reboot each turtle.")
