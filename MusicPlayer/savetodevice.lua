-- Save a song URL into this computer's library, so no disk is needed.

local ui = require("ui")

local SONGS = "songs"

local args = { ... }
local name, uri = args[1], args[2]

if not name or not uri then
    ui.err("Invalid syntax.")
    ui.info('Correct syntax: savetodevice "<song name>" "<direct url>"')
    ui.reset()
    return
end

if not uri:match("^https?://") then
    ui.err("That is not a direct URL: " .. ui.fit(uri, 40))
    ui.info("It must start with http:// or https:// and point straight at the file.")
    ui.reset()
    return
end

-- Song names become filenames, so strip anything the filesystem would choke on.
local safeName = (name:gsub('[/\\:%*%?"<>|]', "_"))
if safeName == "" then
    ui.err("That song name cannot be used as a filename.")
    ui.reset()
    return
end

-- Nothing else creates this directory, and 'play' lists it on startup.
if not fs.isDir(SONGS) then
    fs.makeDir(SONGS)
end

local path = fs.combine(SONGS, safeName .. ".txt")
local replaced = fs.exists(path)

local file = fs.open(path, "w")
if not file then
    ui.err("Could not write to " .. path)
    ui.reset()
    return
end

file.write(uri)
file.close()

ui.banner(replaced and "REPLACED" or "SAVED TO DEVICE")
ui.ok(safeName)
if safeName ~= name then
    ui.info("Renamed from '" .. name .. "' to keep it filename-safe.")
end
ui.info("Run 'play' and pick it from the library.")
ui.reset()
