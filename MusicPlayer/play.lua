-- Stream a DFPWM song from a URL to every connected speaker.
--
-- Controls are single keypresses rather than typed commands: the old version
-- called read() while a background loop printed to the same screen, so the
-- two fought over the cursor. Keys also let the progress bar animate live.

local dfpwm = require("cc.audio.dfpwm")
local ui = require("ui")
local menu = require("menu")

-- DFPWM is one bit per sample at 48 kHz, so 6000 bytes is one second of audio.
-- That is what lets us show a real elapsed/total time from the byte count.
local BYTES_PER_SECOND = 6000
-- The speaker docs recommend submitting as many samples as possible to avoid
-- stuttering. 16 KiB of DFPWM is 128*1024 samples, the documented maximum.
local CHUNK_BYTES = 16 * 1024
-- 100% is the speaker's natural full volume; see setvolume.lua.
local MAX_VOLUME = 1.0
local VOLUME_STEP = MAX_VOLUME / 20 -- one bar segment
local REDRAW_INTERVAL = 0.2

local ROW_LABEL, ROW_NAME, ROW_BAR, ROW_TIME, ROW_VOL = 3, 4, 6, 7, 9

local speakers = { peripheral.find("speaker") }
if #speakers == 0 then
    ui.err("No speaker found.")
    ui.info("Place a speaker against the computer, or connect one with a modem.")
    return
end

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

local function isUrl(text)
    return text:match("^https?://") ~= nil
end

-- Header names are not case-normalised, so match case-insensitively.
local function headerValue(headers, name)
    if type(headers) ~= "table" then
        return nil
    end
    for key, value in pairs(headers) do
        if tostring(key):lower() == name then
            return value
        end
    end
    return nil
end

-- Check every drive, and ask each one where it is actually mounted rather
-- than assuming "disk/" -- that breaks with a second drive or a networked one.
local function songFromDisk()
    for _, drive in ipairs({ peripheral.find("drive") }) do
        if drive.isDiskPresent() then
            local mount = drive.getMountPath()
            if mount then
                local path = fs.combine(mount, "song.txt")
                if fs.exists(path) then
                    local uri = trim(readFile(path))
                    if uri ~= "" then
                        return { name = drive.getDiskLabel() or "Unlabelled disk", uri = uri }
                    end
                end
            end
        end
    end
    return nil
end

local function songFromLibrary()
    if not fs.isDir("songs") then
        return nil, "No disk in the drive, and no songs saved to this computer."
    end

    local files = fs.list("songs")
    if #files == 0 then
        return nil, "No disk in the drive, and your library is empty."
    end

    local names = {}
    for index, file in ipairs(files) do
        names[index] = (file:gsub("%.txt$", ""))
    end

    local choice = menu.pick({
        title = "LIBRARY",
        items = names,
        hint = "up/down move    enter play    q cancel",
    })
    if not choice then
        return nil, nil -- cancelled, not an error
    end

    local uri = trim(readFile(fs.combine("songs", files[choice])))
    if uri == "" then
        return nil, ("'%s' is empty -- save it again."):format(names[choice])
    end
    return { name = names[choice], uri = uri }
end

local song, problem = songFromDisk()
if not song then
    song, problem = songFromLibrary()
end

if not song then
    ui.reset()
    if problem then
        ui.err(problem)
        ui.info("Use 'save' for a floppy disk, or 'savetodevice' for this computer.")
    end
    return
end

if not isUrl(song.uri) then
    ui.reset()
    ui.err("That song's URL is not valid: " .. ui.fit(song.uri, 40))
    ui.info("It must start with http:// or https:// and point straight at the file.")
    return
end

local volume = math.min(math.max(settings.get("media_center.volume", 1.0), 0), MAX_VOLUME)
local looping = false
local finished = false
local bytesPlayed, totalBytes = 0, nil

local width, height = term.getSize()

local function drawFrame()
    ui.screen("MEDIA CENTER")
    ui.row(ROW_LABEL, " NOW PLAYING", ui.theme.dim)
    ui.row(ROW_NAME, " " .. song.name, ui.theme.accentAlt)
    ui.hint(height, "q stop    up/down volume    l loop")
end

local function drawStatus()
    local elapsed = bytesPlayed / BYTES_PER_SECOND
    local total = totalBytes and totalBytes / BYTES_PER_SECOND or nil
    local fraction = (total and total > 0) and (elapsed / total) or 0

    ui.header("MEDIA CENTER", ("vol %d%%"):format(math.floor(volume / MAX_VOLUME * 100 + 0.5)))
    ui.bar(2, ROW_BAR, width - 2, fraction, ui.theme.accent)

    ui.row(ROW_TIME, (" %s / %s"):format(ui.time(elapsed), ui.time(total)), ui.theme.dim)
    local state = looping and "loop on" or "loop off"
    ui.at(width - #state, ROW_TIME, state, looping and ui.theme.ok or ui.theme.dim)

    ui.row(ROW_VOL, " vol", ui.theme.dim)
    ui.bar(6, ROW_VOL, 20, volume / MAX_VOLUME, ui.theme.accentAlt)
end

-- Submit a buffer to every speaker at once. Only speakers that refused the
-- buffer are retried, so an accepted speaker never hears the same audio twice.
local function feed(buffer)
    local pending = {}
    for index, speaker in ipairs(speakers) do
        pending[index] = speaker
    end

    while #pending > 0 and not finished do
        local calls, refused = {}, {}
        for index, speaker in ipairs(pending) do
            calls[index] = function()
                refused[index] = not speaker.playAudio(buffer, volume)
            end
        end
        parallel.waitForAll(table.unpack(calls))

        local retry = {}
        for index, speaker in ipairs(pending) do
            if refused[index] then
                retry[#retry + 1] = speaker
            end
        end
        pending = retry

        if #pending > 0 then
            os.pullEvent("speaker_audio_empty")
        end
    end
end

local streamError = nil

local function stream()
    repeat
        local response, reason = http.get(song.uri, nil, true)
        if not response then
            streamError = tostring(reason or "request failed")
            finished = true
            return
        end

        totalBytes = tonumber(headerValue(response.getResponseHeaders(), "content-length"))
        bytesPlayed = 0

        -- A fresh decoder per pass; DFPWM decoding is stateful.
        local decoder = dfpwm.make_decoder()
        local chunk = response.read(CHUNK_BYTES)

        while chunk and not finished do
            feed(decoder(chunk))
            bytesPlayed = bytesPlayed + #chunk
            chunk = response.read(CHUNK_BYTES)
        end

        response.close()
    until finished or not looping

    finished = true
end

local function controls()
    while not finished do
        local _, key = os.pullEvent("key")
        if key == keys.q then
            finished = true
        elseif key == keys.up then
            volume = math.min(volume + VOLUME_STEP, MAX_VOLUME)
        elseif key == keys.down then
            volume = math.max(volume - VOLUME_STEP, 0)
        elseif key == keys.l then
            looping = not looping
        end
    end
end

local function ticker()
    while not finished do
        drawStatus()
        sleep(REDRAW_INTERVAL)
    end
end

drawFrame()
parallel.waitForAny(stream, controls, ticker)

for _, speaker in ipairs(speakers) do
    pcall(speaker.stop)
end

settings.set("media_center.volume", volume)
settings.save()

ui.reset()
term.clear()
term.setCursorPos(1, 1)

if streamError then
    ui.err("Could not fetch the song: " .. streamError)
    ui.info("Check the URL is a direct link and that the host is reachable.")
else
    ui.ok("Stopped '" .. song.name .. "'")
end
