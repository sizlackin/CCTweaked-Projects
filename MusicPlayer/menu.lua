-- Scrollable single-choice picker, driven by keys or the mouse.
--
-- The previous version appended a "[BACK]" entry on every redraw, which grew
-- the entry list without bound, and used error() to signal cancellation. This
-- one builds each frame from the item list without mutating it, scrolls when
-- the list is longer than the screen, and returns nil when the user backs out.

local ui = require("ui")

local menu = {}

local FIRST_ROW = 3

-- opts = { title = string, items = { string, ... }, hint = string }
-- Returns the chosen index, or nil if the user cancelled.
function menu.pick(opts)
    local items = opts.items or {}
    local title = opts.title or "SELECT"
    local hint = opts.hint or "up/down move    enter choose    q cancel"

    if #items == 0 then
        return nil
    end

    local w, h = term.getSize()
    local selected, scroll = 1, 0

    local function lastRow()
        return h - 2
    end

    local function perPage()
        return math.max(lastRow() - FIRST_ROW + 1, 1)
    end

    -- Keep the selection on screen, and never scroll past the end.
    local function clampScroll()
        local page = perPage()
        if selected < scroll + 1 then
            scroll = selected - 1
        elseif selected > scroll + page then
            scroll = selected - page
        end
        scroll = math.max(math.min(scroll, #items - page), 0)
    end

    local function render()
        clampScroll()
        local page = perPage()
        ui.screen(title, ("%d/%d"):format(selected, #items))

        for row = 0, page - 1 do
            local index = scroll + row + 1
            local y = FIRST_ROW + row
            if index > #items then
                ui.row(y, "")
            elseif index == selected then
                ui.band(y, " > " .. items[index])
            else
                ui.row(y, "   " .. items[index], ui.theme.text)
            end
        end

        -- Arrows only when there is more to see in that direction.
        if #items > page then
            ui.at(w, FIRST_ROW, scroll > 0 and "^" or " ", ui.theme.dim)
            ui.at(w, lastRow(), scroll + page < #items and "v" or " ", ui.theme.dim)
        end

        ui.hint(h, hint)
    end

    local function move(delta)
        selected = math.max(math.min(selected + delta, #items), 1)
    end

    while true do
        render()
        local event, a, b, c = os.pullEvent()

        if event == "key" then
            if a == keys.up then
                move(-1)
            elseif a == keys.down then
                move(1)
            elseif a == keys.pageUp then
                move(-perPage())
            elseif a == keys.pageDown then
                move(perPage())
            elseif a == keys.home then
                selected = 1
            elseif a == keys["end"] then
                selected = #items
            elseif a == keys.enter or a == keys.numPadEnter then
                ui.reset()
                return selected
            elseif a == keys.q or a == keys.backspace then
                ui.reset()
                return nil
            end
        elseif event == "mouse_click" then
            local y = c
            local index = scroll + (y - FIRST_ROW) + 1
            if y >= FIRST_ROW and y <= lastRow() and index <= #items then
                -- First click highlights; a second click on the same row picks it.
                if index == selected then
                    ui.reset()
                    return selected
                end
                selected = index
            end
        elseif event == "mouse_scroll" then
            move(a)
        elseif event == "term_resize" then
            w, h = term.getSize()
        end
    end
end

return menu
