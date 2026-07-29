# Furnace Stats

A furnace monitor for ComputerCraft / CC:Tweaked. Shows what's in your furnace on a
monitor, with colored bars for how full each slot is. Long item names scroll sideways
so they always fit.

Works two ways:

- **Local** — monitor sitting next to the computer.
- **Wireless** — furnace in one place, monitor somewhere else entirely.

Requires CC:Tweaked. Optionally uses Advanced Peripherals for a smelting-progress bar.

---

## 1. Install

On the computer, type:

```
wget https://raw.githubusercontent.com/YOURNAME/YOURREPO/main/furnacestats.lua furnacestats.lua
```

Replace `YOURNAME/YOURREPO` with your repo. **Use the `raw.githubusercontent.com`
link**, not the normal `github.com` page link — that one downloads the web page
instead of the code.

To check it worked:

```
ls
```

You should see `furnacestats.lua`.

---

## 2. Pick your setup

### Setup A — monitor next to the computer (easiest)

1. Place the **computer**.
2. Place a **furnace** touching the computer's **front** (the side with the screen).
3. Place a **monitor** touching any other side of the computer.
4. Run it:

```
furnacestats
```

Done. That's the whole thing.

### Setup B — monitor far away (wireless)

You need **two** computers. A wireless modem can send messages but cannot show
things on a distant monitor, so the far monitor needs its own computer.

**Computer A — at the furnace:**

1. Place the **computer**.
2. Place a **furnace** touching its **front**.
3. Place a **Wireless Modem** on any other side. Don't right-click it.
4. Install the script (step 1 above).
5. Run:

```
furnacestats host
```

Leave it running. Computer A needs no monitor at all.

**Computer B — at the monitor:**

1. Place a **computer**.
2. Place a **monitor** touching it.
3. Place a **Wireless Modem** on another side.
4. Install the script (step 1 above).
5. Run:

```
furnacestats client
```

Stats appear within a couple of seconds.

Keep the two computers within **64 blocks**. Further apart, use **Ender Modems** on
both — same commands, unlimited range.

### Setup C — monitor far away, but cabled

If you'd rather run cable than use a second computer:

1. **Wired Modem** on the computer, **Wired Modem** stuck on the monitor.
2. **Networking Cable** between them.
3. **Right-click both wired modems.** The ring turns red. Skip this and it won't work.
4. Run `furnacestats`.

---

## 3. Commands

| Command | What it does |
|---|---|
| `furnacestats` | Draw to a monitor this computer can reach (touching it, or over cable) |
| `furnacestats host` | Same, plus broadcast over a wireless modem. Works with no monitor. |
| `furnacestats client` | Draw stats received wirelessly from a host |

Hold **Ctrl+T** to stop it.

### Start automatically on world load

```
edit startup.lua
```

Type one line:

```lua
shell.run("furnacestats")
```

Then **Ctrl** → **Save** → **Exit**. Use `"furnacestats host"` or
`"furnacestats client"` instead if that's the mode you want.

---

## 4. Reading the display

```
    FURNACE          <- header
In Cobblesto  64     <- input item and how many
############---      <- how full that slot is
Fuel Coal     61
###########----
Out Stone     23
#####----------
```

- **In** (blue) — what's being smelted
- **Fuel** (orange) — what's burning
- **Out** (green) — finished items. **A full green bar means the furnace is jammed**
  and needs emptying.

Each bar shows how full that slot is out of a full stack. Item names too long for
the screen scroll sideways, pausing briefly at the start so you can read them.

---

## 5. Configuration

Open the file with `edit furnacestats.lua`. Settings are all at the top.
**You don't need to change anything for a single furnace.**

### Furnace not on the front?

Run `peripherals` to see what's attached and which side it's on, then change:

```lua
{ title = "FURNACE", furnace = "front", monitor = nil, reader = nil, scale = 0.5 },
```

`furnace` can be a side (`"top"`, `"left"`, `"back"`…) or a wired network name
(`"minecraft:furnace_0"`).

### Other settings

| Setting | Meaning |
|---|---|
| `title` | Name shown in the header |
| `monitor` | Monitor to use. `nil` = find one automatically. `false` = don't draw, broadcast only |
| `reader` | Advanced Peripherals Block Reader, for the smelting progress bar. `nil` = off |
| `scale` | Text size. `0.5` is smallest and fits the most |
| `CLIENT_WATCH` | On a client: which furnace's `title` to show. `nil` = the first one it hears |
| `SCROLL_INTERVAL` | Seconds per scroll step. Lower = faster |

### Several furnaces

Give each host a different `title`:

```lua
{ title = "IRON", furnace = "front" },
```

Then on each client, set which one that screen shows:

```lua
local CLIENT_WATCH = "IRON"
```

If several furnaces are cable-reachable from one computer, list them all instead —
each needs its own monitor name:

```lua
local DISPLAYS = {
    { title = "IRON", furnace = "minecraft:furnace_0", monitor = "monitor_0" },
    { title = "GOLD", furnace = "minecraft:furnace_1", monitor = "monitor_1" },
}
```

### Smelting progress bar (optional)

Needs **Advanced Peripherals**. Put a **Block Reader** facing the furnace, connect it,
and add its name:

```lua
{ title = "FURNACE", furnace = "front", reader = "blockReader_0" },
```

A fourth **Cook** bar appears, orange while burning and gray when idle.

---

## 6. If something's wrong

**`No display could be set up`**
No monitor found. Run `peripherals` — if there's no `(monitor)` line, the monitor
isn't touching the computer and isn't on the cable network. On a cabled setup,
right-click both wired modems until their rings are red.

**`No wireless modem attached`**
You have a wired modem, not a wireless one. Run `peripherals`: a wireless modem shows
as `(modem)`, a wired one as `(modem, peripheral_hub)`.

**`NO SIGNAL` on the client**
Computer A isn't running `furnacestats host`, or the two are more than 64 blocks
apart. Use Ender Modems for longer distances.

**Nothing happens after `wget`**
Check the URL is the `raw.githubusercontent.com` one. Run `ls` to confirm the file
downloaded.

**Item names are cut off**
They scroll automatically. If a name never scrolls it already fits. For more room,
use a bigger monitor or set `scale = 0.5`.
