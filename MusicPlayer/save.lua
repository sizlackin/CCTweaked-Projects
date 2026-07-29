-- Save a song URL onto a floppy disk, labelled with the song name.

local ui = require("ui")

local args = { ... }
local name, uri = args[1], args[2]

if not name or not uri then
    ui.err("Invalid syntax.")
    ui.info('Correct syntax: save "<song name>" "<direct url>"')
    ui.reset()
    return
end

if not uri:match("^https?://") then
    ui.err("That is not a direct URL: " .. ui.fit(uri, 40))
    ui.info("It must start with http:// or https:// and point straight at the file.")
    ui.reset()
    return
end

local drive = peripheral.find("drive")
if not drive then
    ui.err("No disk drive found.")
    ui.info("Place a disk drive against the computer, or use 'savetodevice' instead.")
    ui.reset()
    return
end

if not drive.isDiskPresent() then
    ui.err("No disk in the drive.")
    ui.info("Insert a floppy disk and try again.")
    ui.reset()
    return
end

-- Ask the drive where it is mounted instead of assuming "disk/", which breaks
-- with a second drive or one connected over a modem.
local mount = drive.getMountPath()
if not mount then
    ui.err("That disk has no filesystem.")
    ui.info("Use a floppy disk -- a vanilla music disc cannot store files.")
    ui.reset()
    return
end

local file = fs.open(fs.combine(mount, "song.txt"), "w")
if not file then
    ui.err("Could not write to the disk. Is it write protected?")
    ui.reset()
    return
end

file.write(uri)
file.close()
drive.setDiskLabel(name)

ui.banner("SAVED TO DISK")
ui.ok(name)
ui.info("Run 'play' to listen.")
ui.reset()
