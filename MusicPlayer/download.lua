-- Bootstrap: fetches install.lua, which then fetches everything else.
-- This is the file that goes on pastebin.
--
-- It runs on a bare computer, so it cannot use the ui module -- that is one of
-- the things install.lua has yet to download.

-- If you fork this, point REPO at your own copy. It must be the
-- raw.githubusercontent.com URL, not the github.com page, or you will
-- download a web page instead of code.
local REPO = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/MusicPlayer/"

local colour = term.isColour()

local function say(symbol, colour_, message)
    term.setTextColour(colour and colour_ or colors.white)
    write(symbol .. " ")
    term.setTextColour(colors.white)
    print(message)
end

local function fail(message, hint)
    say("x", colors.red, message)
    if hint then
        say("-", colors.lightGray, hint)
    end
    term.setTextColour(colors.white)
end

term.setBackgroundColour(colors.black)
term.clear()
-- clear() leaves the cursor where it was, so without this the text below can
-- start halfway down the screen.
term.setCursorPos(1, 1)

if not http then
    fail("The HTTP API is disabled on this server.",
        "Ask the server owner to enable it in the CC: Tweaked config.")
    return
end

say("*", colors.magenta, "Downloading the installer...")
print("")

local ok, response = pcall(http.get, REPO .. "install.lua")

-- http.get returns nil plus a reason on failure; the old version indexed it
-- straight away and crashed with "attempt to index nil".
if not ok or not response then
    fail("Could not reach " .. REPO,
        "Check the URL and your connection, then try again.")
    return
end

local status = response.getResponseCode and response.getResponseCode() or 200
local body = response.readAll()
response.close()

if status ~= 200 then
    fail(("The server answered %d, not 200."):format(status),
        "Check install.lua really exists at that path.")
    return
end

if not body or body == "" then
    fail("The installer came back empty.", "Check the URL points straight at install.lua.")
    return
end

-- A github.com page URL (rather than raw) returns HTML, which would be written
-- out as a .lua file and fail confusingly later.
if body:find("^%s*<") then
    fail("That URL returned a web page, not code.",
        "Use the raw.githubusercontent.com link.")
    return
end

local file = fs.open("install.lua", "w")
if not file then
    fail("Could not write install.lua.", "Is the computer's disk full?")
    return
end

file.write(body)
file.close()

say("+", colors.lime, "Installer downloaded.")
print("")
say("!", colors.yellow, "Run 'install' next.")
say("-", colors.lightGray, "It overwrites any files with the same names and")
say("-", colors.lightGray, "cannot be undone. Use a fresh computer if you have")
say("-", colors.lightGray, "anything on this one you want to keep.")

term.setTextColour(colors.white)
