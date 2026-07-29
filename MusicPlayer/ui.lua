-- Shared look and feel for the media center. Every command draws through
-- this module so colours, headers and bars stay consistent.
--
-- Bars are drawn as space characters tinted by their *background* colour,
-- which gives a solid block instead of an ASCII [###---] approximation.

local ui = {}

local colour = term.isColour()

-- On a standard (monochrome) computer every accent collapses to white, so
-- the layout still reads even though the colours are gone.
local function pick(bright, plain)
    return colour and bright or plain
end

ui.theme = {
    accent = pick(colors.magenta, colors.white),
    accentAlt = pick(colors.lightBlue, colors.white),
    text = colors.white,
    dim = pick(colors.lightGray, colors.white),
    track = pick(colors.gray, colors.black),
    ok = pick(colors.lime, colors.white),
    warn = pick(colors.yellow, colors.white),
    err = pick(colors.red, colors.white),
    headerFg = colors.black,
    headerBg = pick(colors.magenta, colors.white),
    selectFg = colors.black,
    selectBg = pick(colors.magenta, colors.white),
    bg = colors.black,
}

function ui.isColour()
    return colour
end

-- Truncate with a visible marker so a clipped name is obviously clipped.
function ui.fit(text, width)
    text = tostring(text)
    if width <= 0 then
        return ""
    end
    if #text <= width then
        return text
    end
    if width <= 2 then
        return text:sub(1, width)
    end
    return text:sub(1, width - 2) .. ".."
end

function ui.pad(text, width)
    text = ui.fit(text, width)
    return text .. (" "):rep(width - #text)
end

-- mm:ss, or --:-- when the length is unknown.
function ui.time(seconds)
    if not seconds then
        return "--:--"
    end
    seconds = math.max(math.floor(seconds), 0)
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- Full-width title bar. `right` is flush against the right edge.
function ui.header(title, right)
    local w = term.getSize()
    right = right and (tostring(right) .. " ") or ""
    local text = ui.pad(" " .. tostring(title), math.max(w - #right, 0)) .. right
    text = ui.pad(text, w)

    term.setCursorPos(1, 1)
    term.blit(text,
        colors.toBlit(ui.theme.headerFg):rep(w),
        colors.toBlit(ui.theme.headerBg):rep(w))
end

-- Clear to a fresh screen with a header, ready to draw from row 3.
function ui.screen(title, right)
    term.setBackgroundColour(ui.theme.bg)
    term.setTextColour(ui.theme.text)
    term.clear()
    ui.header(title, right)
    term.setCursorPos(1, 3)
end

function ui.at(x, y, text, colour_)
    term.setCursorPos(x, y)
    term.setTextColour(colour_ or ui.theme.text)
    term.write(tostring(text))
end

-- Overwrite a whole row, so redraws do not leave stale characters behind.
function ui.row(y, text, colour_)
    local w = term.getSize()
    term.setCursorPos(1, y)
    term.setTextColour(colour_ or ui.theme.text)
    term.setBackgroundColour(ui.theme.bg)
    term.write(ui.pad(text, w))
end

-- A row rendered as a solid colour band, e.g. the selected list entry.
function ui.band(y, text, fg, bg)
    local w = term.getSize()
    term.setCursorPos(1, y)
    term.blit(ui.pad(text, w),
        colors.toBlit(fg or ui.theme.selectFg):rep(w),
        colors.toBlit(bg or ui.theme.selectBg):rep(w))
end

-- Solid left-to-right progress bar.
function ui.bar(x, y, width, fraction, colour_)
    if width <= 0 then
        return
    end
    colour_ = colour_ or ui.theme.accent
    local filled = math.floor(width * math.min(math.max(fraction or 0, 0), 1) + 0.5)
    term.setCursorPos(x, y)
    term.blit((" "):rep(width),
        colors.toBlit(colour_):rep(width),
        colors.toBlit(colour_):rep(filled) .. colors.toBlit(ui.theme.track):rep(width - filled))
end

-- Dim keybinding hints, pinned to a row.
function ui.hint(y, text)
    ui.row(y, " " .. text, ui.theme.dim)
end

-- Inline tagged lines, for short commands that print into the shell rather
-- than taking over the screen.
local function tagged(symbol, colour_, message)
    term.setTextColour(colour_)
    write(symbol .. " ")
    term.setTextColour(ui.theme.text)
    print(tostring(message))
end

function ui.ok(message)
    tagged("+", ui.theme.ok, message)
end

function ui.warn(message)
    tagged("!", ui.theme.warn, message)
end

function ui.err(message)
    tagged("x", ui.theme.err, message)
end

function ui.info(message)
    tagged("-", ui.theme.dim, message)
end

-- One-line highlighted heading that does not clear the screen.
function ui.banner(text)
    term.setTextColour(ui.theme.headerFg)
    term.setBackgroundColour(ui.theme.headerBg)
    write(" " .. tostring(text) .. " ")
    term.setBackgroundColour(ui.theme.bg)
    term.setTextColour(ui.theme.text)
    print("")
end

-- Bar drawn at the cursor, for inline output.
function ui.barInline(width, fraction, colour_)
    local x, y = term.getCursorPos()
    ui.bar(x, y, width, fraction, colour_)
    term.setCursorPos(x + width, y)
    term.setBackgroundColour(ui.theme.bg)
    term.setTextColour(ui.theme.text)
end

-- Leave the terminal in a sane state so the shell prompt is not tinted.
function ui.reset()
    term.setBackgroundColour(colors.black)
    term.setTextColour(colors.white)
end

return ui
