-- Boot screen: restore settings, report what hardware is connected, and
-- quietly check for a newer release.

local ui = require("ui")

-- Change this if you fork the project, so the update check and the installer
-- point at your copy. install.lua has the same constant.
local REPO = "https://raw.githubusercontent.com/Metalloriff/cc-music-player/main/"

local SONGS = "songs"

settings.define("media_center.volume", {
    description = "The volume to play songs at.",
    default = 1.0,
    type = "number",
})

-- settings.set only writes to memory, so without this the volume chosen last
-- session is thrown away on boot.
settings.load()

local function trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function readFile(path)
    local file = fs.open(path, "r")
    if not file then
        return nil
    end
    local contents = file.readAll()
    file.close()
    return contents
end

local function jingle(speaker)
    local instrument = "bell"
    for _, pitch in ipairs({ 4, 8, 15, 16 }) do
        speaker.playNote(instrument, 1, pitch)
        sleep(0.3)
    end
    -- All four at once, as a closing chord.
    for _, pitch in ipairs({ 4, 8, 15, 16 }) do
        speaker.playNote(instrument, 1, pitch)
    end
end

-- Runs on its own, because a failed request should never stop the boot screen.
local function checkForUpdate()
    if not fs.exists("version.txt") then
        return nil
    end

    local ok, response = pcall(http.get, REPO .. "version.txt")
    if not ok or not response then
        return nil
    end

    local latest = trim(response.readAll())
    response.close()

    local current = trim(readFile("version.txt"))
    if latest ~= "" and current ~= "" and latest ~= current then
        return latest, current
    end
    return nil
end

if not fs.isDir(SONGS) then
    fs.makeDir(SONGS)
end

local speaker = peripheral.find("speaker")
local drive = peripheral.find("drive")

ui.screen("MEDIA CENTER", "v" .. trim(readFile("version.txt") or "?"))
term.setCursorPos(1, 3)

if speaker then
    ui.ok("Speaker connected.")
else
    ui.err("No speaker found -- nothing will play.")
    ui.info("Place a speaker against the computer, or connect one with a modem.")
end

if drive then
    ui.ok("Disk drive connected. Insert a disk and run 'play'.")
else
    ui.warn("No disk drive found.")
    ui.info("Use 'savetodevice' to keep songs on this computer instead.")
end

-- Clamped, because an older version of setvolume could store up to 3.0.
local stored = math.min(math.max(settings.get("media_center.volume", 1.0), 0), 1.0)
ui.info(("Volume %d%%. Change it with 'setvolume'."):format(math.floor(stored * 100 + 0.5)))

print("")
ui.info("Type 'help' to get started.")

-- The old version only checked for updates when a speaker was present, and
-- crashed on any network failure.
local latest, current = checkForUpdate()
if latest then
    print("")
    ui.warn(("Version %s is available (you have %s)."):format(latest, current))
    ui.info("Run 'download' then 'install' to update.")
end

if speaker then
    pcall(jingle, speaker)
end

if fs.exists("download.lua") then
    fs.delete("download.lua")
end
if fs.exists("install.lua") then
    fs.delete("install.lua")
end

ui.reset()
