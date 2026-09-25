# CCTweaked-Projects — working rules

This repo is the **source** for a ComputerCraft: Tweaked install that is
**running right now** in a Minecraft world. The world holds irreplaceable
learned state. Read `docs/WORKFLOW.md` before doing anything structural.

## Hard rules

- **Never `git init` in the Minecraft world**, and never make the live
  ComputerCraft directory a git repo or a submodule.
- **Never `cp`, `rsync`, or hand-edit into the live controller.** Especially
  never `rsync --delete`. All writes go through `./tools/deploy-controller`,
  which cannot delete and refuses unmapped paths.
- **Never write the controller's persistent state.** `runtime/map/**`,
  `runtime/tunnelMap.txt`, `runtime/stations.txt`, `runtime/taskData.txt`,
  `runtime/turtles.txt`, `runtime/alerts.txt`, `log.txt`. This is the learned
  map, tunnel graph, stations, queues and tasks. The tools hard-abort on these.
- **Never write `runtime/*.lua` directly.** `runtime/` is the controller's own
  assembled copy; `host/startup.lua` rebuilds it from the source dirs at boot.
  Deploy targets source dirs only.
- **Never edit through `ActuallyUsefulTurtles-LIVE`** (a symlink to the live
  controller). It is for inspection.
- **Never move or rename `ActuallyUsefulTurtles/patches/` or
  `ActuallyUsefulTurtles/tunnelnav/`.** The wget installers fetch those paths
  by raw.githubusercontent URL, some pinned to `main`.
- **Never replace a patched file with an upstream Actually Useful Turtles
  version.** This install carries heavy custom work (see WORKFLOW.md).
- **Do not modify turtles 12/14/15/16 directly.** They pull from the controller
  themselves via `turtle/update.lua` at boot.

## Layout

| Path | Role |
|---|---|
| `ActuallyUsefulTurtles/patches/` | custom patched source; also served to installers |
| `ActuallyUsefulTurtles/tunnelnav/` | shared tunnel navigation source; also served to installers |
| `ActuallyUsefulTurtles/controller/` | upstream AUT files, tracked so the install is comparable |
| `ActuallyUsefulTurtles/*.lua` | one-shot wget installers — **not** deploy targets |
| `tools/manifest.tsv` | the only source → live mapping that exists |
| `docs/WORKFLOW.md` | full explanation |

Live controller (id 9):
`/home/cesar/.local/share/PrismLauncher/instances/Delightful Machinations/minecraft/saves/The Fuckening/computercraft/computer/9`

## Normal task shape

```fish
./tools/diff-controller                 # orient: has live drifted?
# edit the repo file named by tools/manifest.tsv
./tools/deploy-controller --dry-run
./tools/deploy-controller
```

To find which repo file backs a live path, look it up in `tools/manifest.tsv`.
Adding a new file requires a new manifest line, or deploy will ignore it.

## If diff-controller says `live-behind`

The repo is ahead of live and live matches an older commit. This is the normal
case after `git pull`. Just deploy.

## If diff-controller says `live-drifted`

Live holds content that appears nowhere in this repo's history — in-game work.
**Do not deploy over it.** Deploy will refuse anyway. Capture it instead:

```fish
./tools/import-live --dry-run
./tools/import-live
git diff            # review
```

Then commit, so the regression guard stays accurate.

## After deploying

Report which reboots are needed — `deploy-controller` prints this:

- files in `general/` or `storage/` → controller **and** turtles
- files in `gui/` or `host/` → controller only
- files in `turtle/` → turtles only

Controller first, then turtles. Until a reboot happens, the controller is still
running the old `runtime/` copy, so a deploy alone changes nothing executing.

## Shell

The user's interactive shell is **fish**. Tools are Python 3 with shebangs and
are executable, so `./tools/...` works directly. Do not emit bash-only syntax
(`export X=y`, `$(...)` heredoc assumptions, `&&` chains relying on bash
builtins) in commands intended for the user to paste.
