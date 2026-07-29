-- Downloads every program. Runs on a bare computer, so it cannot require the
-- ui module -- that is one of the things it is fetching.

-- Change this if you fork the project. startup.lua has the same constant.
local REPO = "https://raw.githubusercontent.com/Metalloriff/cc-music-player/main/"

-- "ui" must come first: every other program requires it.
local FILES = { "ui", "menu", "startup", "play", "save", "savetodevice", "setvolume", "help" }
local SONGS = "songs"

local colour = term.isColour()

local function say(symbol, colour_, message)
    term.setTextColour(colour and colour_ or colors.white)
    write(symbol .. " ")
    term.setTextColour(colors.white)
    print(message)
end

local function fetch(url)
    local ok, response = pcall(http.get, url)
    if not ok or not response then
        return nil, type(response) == "string" and response or "request failed"
    end
    local body = response.readAll()
    response.close()
    return body
end

term.setBackgroundColour(colors.black)
term.clear()
term.setCursorPos(1, 1)
say("*", colors.magenta, "Installing the media center...")
print("")

local failed = {}

for _, name in ipairs(FILES) do
    local file = name .. ".lua"
    local body, reason = fetch(REPO .. file)

    if not body then
        say("x", colors.red, file .. " -- " .. tostring(reason))
        failed[#failed + 1] = file
    else
        local handle = fs.open(file, "w")
        if not handle then
            say("x", colors.red, file .. " -- could not write")
            failed[#failed + 1] = file
        else
            handle.write(body)
            -- The old installer never closed these, so writes could be lost.
            handle.close()
            say("+", colors.lime, file)
        end
    end
end

local version = fetch(REPO .. "version.txt")
if version then
    local handle = fs.open("version.txt", "w")
    if handle then
        handle.write(version)
        handle.close()
    end
end

-- 'savetodevice' and 'play' both expect this to exist.
if not fs.isDir(SONGS) then
    fs.makeDir(SONGS)
end

print("")
if #failed > 0 then
    say("x", colors.red, ("%d file(s) failed. Run 'install' again."):format(#failed))
    say("-", colors.lightGray, "If it keeps failing, check the HTTP API is enabled.")
else
    say("+", colors.lime, "Installation complete. Restart the computer.")
end

term.setTextColour(colors.white)
