-- Set the playback volume, as a percentage.

local ui = require("ui")

-- 100% is the speaker's natural full volume. The peripheral technically
-- accepts up to 3.0, but that is amplification and it distorts, so the scale
-- stops at 1.0 -- add more speakers if you want it louder.
local MAX_VOLUME = 1.0

local args = { ... }
local percent = tonumber(args[1])

if not percent then
    ui.err("Please give a number between 0 and 100.")
    ui.info("Example: setvolume 60")
    ui.reset()
    return
end

-- The old version accepted anything, so 'setvolume 500' produced a volume of
-- 15 and the speaker rejected it.
if percent < 0 or percent > 100 then
    ui.err(("Volume must be between 0 and 100 (you gave %s)."):format(args[1]))
    ui.reset()
    return
end

settings.set("media_center.volume", percent / 100 * MAX_VOLUME)
-- settings.set only changes memory; without this the volume resets on reboot.
settings.save()

ui.banner("VOLUME")
write("  ")
ui.barInline(20, percent / 100, ui.theme.accentAlt)
print((" %d%%"):format(percent))
ui.reset()
