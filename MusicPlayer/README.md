# Music Streaming Player for ComputerCraft / CC: Tweaked

Streams DFPWM audio from the web to your speakers, with a live progress bar,
a scrollable library, and volume that sticks between sessions.

## Requirements

* **CC: Tweaked** with the HTTP API enabled (it is, by default).
* At least one **Speaker**. Any number works, connected directly or by modem.
* An **Advanced Computer** is recommended for colour. It runs on a normal
  computer too, just in greyscale.
* A **Disk Drive** is optional — songs can live on the computer instead.

## Install

On a fresh computer:

```
pastebin get 98zM0gh1 download
download
install
```

Then restart the computer.

## Getting a song on there

1. Convert your audio to DFPWM at [music.madefor.cc](https://music.madefor.cc/).
2. Upload it somewhere that gives direct links — [catbox](https://catbox.moe/)
   works. The URL has to point at the file itself, not a preview page.
3. Save it, with both parts in quotes:

   ```
   save "Tobu Candyland" "https://files.catbox.moe/swtak2.dfpwm"
   ```

   That writes to the floppy disk in your drive. For no disk at all:

   ```
   savetodevice "Tobu Candyland" "https://files.catbox.moe/swtak2.dfpwm"
   ```

4. Run `play`.

A disk in the drive plays straight away. Otherwise you get your library to
pick from.

## Commands

| Command | What it does |
|---|---|
| `play` | Play the disk in the drive, or pick from the library |
| `save "name" "url"` | Save a song to a floppy disk |
| `savetodevice "name" "url"` | Save a song to this computer |
| `setvolume 0-100` | Set the volume, remembered across reboots |
| `help` | Help topics |
| `help saving` | Full walkthrough of converting and saving |
| `help commands` | Every command |
| `help playback` | Controls while a song is playing |

## While a song is playing

| Key | Action |
|---|---|
| `up` / `down` | Volume, saved when you stop |
| `l` | Toggle looping |
| `q` | Stop |

The bar shows elapsed and total time. DFPWM runs at a constant 6 KB per
second, so the length is worked out from the file size — no metadata needed.

In the library list: arrow keys or the mouse wheel to move, `enter` or a
second click to play, `q` to back out. It scrolls if you have more songs than
fit on screen.

## Forking

If you fork this, change the `REPO` constant at the top of **both**
`install.lua` and `startup.lua` so the installer and the update check point at
your copy.

## Notes

* Any number of speakers works. A buffer is only re-sent to speakers that
  refused it, so they stay in sync instead of echoing.
* Songs saved with `savetodevice` live in `songs/`. Names are sanitised into
  safe filenames, so `AC/DC` becomes `AC_DC`.
* Volume tops out at the speaker's natural level. The peripheral technically
  accepts triple that, but it distorts — add more speakers instead.

## Changelog

### 0.2.0

Bug fixes:

* `play` crashed with "attempt to index nil" when playing a song from the
  computer rather than a disk — it read the label off a drive it had already
  established was absent.
* The in-play command parser never advanced its word index, so every word was
  treated as the command name and arguments were always empty. An unknown
  command then crashed trying to print a nil argument.
* The boot update check crashed whenever the request failed, and only ran at
  all if a speaker happened to be connected.
* `setvolume` never called `settings.save()`, so the volume reset on every
  reboot, and `startup` never called `settings.load()` to read it back.
* `setvolume` accepted any number despite promising 0–100; `setvolume 500`
  produced a volume the speaker rejected.
* The menu appended a `[BACK]` entry on every single redraw, growing the list
  without bound, and signalled cancellation by throwing an error.
* Nothing ever created the `songs/` directory that `savetodevice` writes to
  and `play` lists.
* `peripheral.find` results were used without nil checks; no speakers meant
  `parallel.waitForAll()` was called with no arguments, which errors.
* Disk paths were hardcoded to `disk/`, which breaks with a second drive or
  one connected over a modem. Now asks the drive where it is mounted.
* Written files were left unclosed in the installer and the update check.
* A buffer refused by one speaker was re-sent to all of them, so accepted
  speakers heard it twice.

Changes:

* Shared `ui` module so every command has consistent colours, headers and bars.
* `play` shows a live progress bar with elapsed/total time, and is driven by
  single keypresses — the old version called `read()` while a background loop
  printed to the same screen, and the two fought over the cursor.
* The library list scrolls and accepts the mouse.
* Audio is submitted in 16 KiB chunks instead of 4 KiB, the documented maximum
  per call, which reduces stuttering.
* `help` shows a whole topic at once instead of one step at a time.
* Every command explains what to do next when something is missing.
