-- Built-in help. The old version printed the "4-step tutorial" preamble and
-- then a single step, so you never saw the whole thing at once.

local ui = require("ui")

local args = { ... }
local topic = (args[1] or ""):lower()

local function heading(text)
    print("")
    ui.banner(text)
end

local function step(number, text)
    term.setTextColour(ui.theme.accent)
    write(("  %d. "):format(number))
    term.setTextColour(ui.theme.text)
    print(text)
end

local function detail(text)
    term.setTextColour(ui.theme.dim)
    print("     " .. text)
    term.setTextColour(ui.theme.text)
end

local function command(name, description)
    term.setTextColour(ui.theme.accentAlt)
    write("  " .. name)
    term.setTextColour(ui.theme.dim)
    print(" -- " .. description)
    term.setTextColour(ui.theme.text)
end

if topic == "saving" then
    heading("SAVING A SONG")
    step(1, "Convert your audio to DFPWM.")
    detail("Open https://music.madefor.cc/ and drag the file onto the box,")
    detail("then download the result.")
    step(2, "Upload it somewhere with direct links.")
    detail("https://catbox.moe/ works. Copy the file URL when it finishes.")
    detail("The link must end at the file itself, not a preview page.")
    step(3, "Save it, wrapping both parts in quotes.")
    detail('save "Tobu Candyland" "https://files.catbox.moe/swtak2.dfpwm"')
    detail("Needs a disk drive with a floppy disk in it.")
    detail('Or: savetodevice "Tobu Candyland" "https://..." for no disk.')
    step(4, "Run 'play'.")
    detail("A disk plays straight away; otherwise pick from your library.")

elseif topic == "commands" then
    heading("COMMANDS")
    command("play", "play a disk, or pick from the library")
    command("save", 'save to a floppy disk:  save "name" "url"')
    command("savetodevice", 'save to this computer:  savetodevice "name" "url"')
    command("setvolume", "set volume 0-100:  setvolume 60")
    command("help saving", "how to convert and save a song")
    command("help playback", "controls while a song is playing")

elseif topic == "playback" or topic == "volume" then
    heading("PLAYBACK CONTROLS")
    command("up / down", "volume up and down, saved when you stop")
    command("l", "toggle looping")
    command("q", "stop and return to the shell")
    print("")
    ui.info("The bar shows elapsed and total time, worked out from the")
    ui.info("file size (DFPWM runs at a constant 6 KB per second).")

else
    heading("MEDIA CENTER")
    if topic ~= "" then
        ui.warn("No help topic called '" .. topic .. "'.")
        print("")
    end
    ui.info("Streams DFPWM audio from the web to your speakers.")
    print("")
    command("help commands", "every command")
    command("help saving", "get a song onto the computer")
    command("help playback", "controls while playing")
end

print("")
ui.reset()
