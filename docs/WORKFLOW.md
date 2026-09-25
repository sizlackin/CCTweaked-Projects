# Actually Useful Turtles — local development workflow

This repo is the **source**. The Minecraft world is the **running installation**.
They are deliberately separate: the repo is never inside the world, and the
world is never a git repo.

| | |
|---|---|
| Source / git | `/home/cesar/Projects/CCTweaked-Projects` |
| Live controller (id 9) | `.../saves/The Fuckening/computercraft/computer/9` |
| Convenience symlink | `/home/cesar/Projects/ActuallyUsefulTurtles-LIVE` → computer/9 (inspection only, **not** git source) |
| Backups | `/home/cesar/Backups/ActuallyUsefulTurtles/` |
| Turtles | ids 12, 14, 15, 16 |

## Everyday loop

```fish
cd ~/Projects/CCTweaked-Projects
git pull
./tools/diff-controller          # what differs between source and live?
# edit files with Claude CLI / VS Code
./tools/deploy-controller --dry-run
./tools/deploy-controller
```

Then in game:

- **Reboot controller 9** if the deploy said controller reboot required.
- **Reboot turtles 12/14/15/16** only if it said turtle reboot required, and
  always *after* the controller.

Deploy tells you which of the two it needs; it works this out from the
directory each changed file lives in, not from guesswork.

## How a change actually reaches the running system

This is the part worth understanding, because it drives the whole design.

```
repo  ──deploy──►  computer/9/general|gui|host|storage|turtle/   (source dirs)
                             │
                   host/startup.lua, at boot, copies
                   general gui host storage ──► computer/9/runtime/   (flat)
                   …but only when the source file's mtime is NEWER.
                   If it copied anything, it reboots once more itself.
                             │
                   turtle/update.lua, on each turtle at boot, pulls
                   general turtle storage from the controller ──► turtle's runtime/
                   If anything changed, that turtle reboots itself.
```

Consequences:

- **Deploy writes source directories, never `runtime/`.** `runtime/` is the
  controller's own assembled copy, and `host/startup.lua` rebuilds it. Writing
  there by hand fights the boot process.
- **Deploy sets mtime to now** on every file it writes, so the boot-time
  newer-than test always fires.
- `general/` and `storage/` are shared: a change there needs **controller and
  turtle** reboots. `gui/` and `host/` are **controller only**. `turtle/` is
  **turtles only**.
- Until you reboot, the controller keeps running the old `runtime/` copy. A
  deploy on its own changes nothing that is executing. That makes deploys safe
  to stage and easy to undo.

`--with-runtime` additionally writes the `runtime/` twin, which is what the
old wget installers did to apply a change without a reboot. It is available but
not the default; a reboot is cleaner.

## Persistent state — never touched

Anything in this list is the controller's learned knowledge. No tool here
writes it; attempting to is a hard abort, not a warning.

```
runtime/map/**            learned block/ChunkyMap data (~319 files)
runtime/tunnelMap.txt     the tunnel graph  (~1.2 MB and growing)
runtime/stations.txt      stations
runtime/taskData.txt      task data
runtime/turtles.txt       known turtles
runtime/alerts.txt        alerts
log.txt
```

Rollback will not restore over them either, and it never deletes anything.

## The manifest

`tools/manifest.tsv` is an explicit `repo_path → live_path → origin` table, 80
entries, covering every code file in the controller's source directories. There
is no recursive directory copy anywhere in this tooling, and no file is written
unless it is listed.

`origin` records where a file comes from:

| origin | meaning |
|---|---|
| `patch` | custom patched file, in `ActuallyUsefulTurtles/patches/` |
| `tunnelnav` | shared tunnel navigation source, in `ActuallyUsefulTurtles/tunnelnav/` |
| `vendor` | upstream AUT file, in `ActuallyUsefulTurtles/controller/`, tracked so the whole install is comparable |

`patches/` and `tunnelnav/` keep their paths because the wget installers fetch
them by raw.githubusercontent URL — several pinned to commit SHAs, several to
`main`. **Do not move or rename those two directories** or you break the
installers.

## Tools

### `./tools/diff-controller`

Read-only comparison. Resolves three points — git HEAD, your working tree, and
live — so it can tell you *which side* moved:

| status | meaning |
|---|---|
| `identical` | repo and live agree |
| `modified-local` | you edited the repo, not deployed yet |
| `live-behind` | repo is ahead of live, and live's content matches an older commit in this repo — a normal, safe deploy |
| `live-drifted` | live holds content that appears nowhere in this repo's history — in-game work a deploy would destroy |
| `both-changed` | both moved; inspect before deploying |
| `missing-repo` / `missing-live` | mapped but one side is absent |

```fish
./tools/diff-controller                              # full table
./tools/diff-controller --only-changed
./tools/diff-controller --show gui/classMapDisplay.lua
./tools/diff-controller --installers                 # compare the wget scripts too
```

It also lists unmapped files on both sides, so nothing hides.

### `./tools/deploy-controller`

```fish
./tools/deploy-controller --dry-run                  # always worth doing first
./tools/deploy-controller                            # everything that differs
./tools/deploy-controller gui/classMapDisplay.lua turtle/classMiner.lua
./tools/deploy-controller --show                     # print diffs before writing
./tools/deploy-controller --with-runtime             # also refresh runtime/ twins
./tools/deploy-controller --allow-regress            # override the safety below
```

Before writing anything it:

1. verifies the target path really ends in `/computer/9`, has `computer` as its
   parent, contains nine expected controller files and six expected
   directories, and has no `.git`;
2. **refuses to deploy a file whose live version has drifted away from the
   repo's last commit** — that would discard in-game work. It points you at
   `import-live` instead;
3. backs up every live file it is about to modify into
   `Backups/ActuallyUsefulTurtles/deploy/<timestamp>/`, with a manifest;
4. shows you the exact file list, byte sizes, and who must reboot;
5. copies only manifest files, deletes nothing, and refuses any path under
   `runtime/` unless `--with-runtime`, and any persistent state path always.

### `./tools/backup-controller`

```fish
./tools/backup-controller                    # full snapshot, state included
./tools/backup-controller --code-only        # source dirs only
./tools/backup-controller --list
./tools/backup-controller --note "before X"
```

Plain directory copies under `Backups/ActuallyUsefulTurtles/full/`, so you can
grep and diff them normally. A full snapshot is ~4.5 MB, so taking one before
anything risky costs nothing. You do **not** need one per deploy — deploys back
up the files they touch automatically.

### `./tools/rollback-controller`

```fish
./tools/rollback-controller                                  # list deploys
./tools/rollback-controller 2026-09-25_00-42-46 --dry-run
./tools/rollback-controller 2026-09-25_00-42-46              # restore all of it
./tools/rollback-controller <stamp> general/classQueue.lua   # one file
./tools/rollback-controller --from-full <stamp> gui/classMapDisplay.lua
```

Restores only files that deploy recorded. It snapshots the current state first
(as `<stamp>_pre-rollback`) so a rollback is itself undoable, skips files
already matching, never deletes, and never writes persistent state. Files the
deploy newly created are reported rather than removed.

### `./tools/import-live`

The reverse direction, live → repo, for when the controller is ahead. Writes
only inside the repo.

```fish
./tools/import-live --dry-run
./tools/import-live                        # every differing mapped file
./tools/import-live --missing-only
./tools/import-live --installers           # also copy controller-only installers
./tools/import-live turtle/classMiner.lua
```

Use it whenever `diff-controller` reports `live-drifted`, then review with
`git diff` and commit. **Committing matters**: the guard decides whether live
is merely behind by searching this repo's history, so uncommitted work weakens
it.

You do not need it for `live-behind` — that just means the repo is ahead and a
normal deploy is what you want.

## Retiring the wget installers

The installers in `ActuallyUsefulTurtles/*.lua` are one-shot bootstrap scripts.
They are deliberately **not** deploy targets — `diff-controller --installers`
reports on them, but nothing deploys them.

For ordinary code edits you no longer need them: edit the file in the repo,
`./tools/deploy-controller`, reboot. Keep writing an installer only when you
want a change reproducible on a *fresh* controller, or shareable with someone
who has no clone.

## Working with Claude CLI on this repo

Run Claude from the repo, not from the world:

```fish
cd ~/Projects/CCTweaked-Projects
claude
```

What to tell it, and what it should do:

- **Edit source files only** — under `ActuallyUsefulTurtles/patches/`,
  `tunnelnav/`, or `controller/`. Never edit inside
  `ActuallyUsefulTurtles-LIVE` or the world directory.
- **Use `./tools/diff-controller` to orient** before changing anything; it
  shows whether live has drifted first.
- **Deploy through the tools**, never with `cp`, `rsync`, or by hand. `rsync
  --delete` into the controller would be catastrophic; the tools cannot delete.
- **Read `tools/manifest.tsv` to find where a live file comes from.** Given a
  live path like `gui/classMapDisplay.lua`, the manifest names the repo file to
  edit.
- **Adding a new file** means adding a manifest line too, otherwise deploy
  ignores it — which is the intended behaviour, not a bug.
- **Never `git init` in the world, never make the controller a git repo, never
  touch `runtime/` state.** These are the standing rules; the tools enforce
  them, but say so anyway.
- After deploying, Claude should tell you whether to reboot the controller, the
  turtles, or both — deploy prints exactly that.

## Custom work this install carries

Preserved as-is; none of it is upstream AUT. Do not let an upstream file
overwrite these:

shared tunnel navigation · cooperative multi-turtle mapping · tunnel graph
persistence · fast travel over mapped tunnels · strict no-dig tunnel navigation
· sophisticated storage support · 2-high tunnels · contained mining · clean
mining / backfill · lava tunnel maintenance · Philolite repair · floor-color
map display · four-turtle support · GPS integration · assorted
controller/turtle fixes

Marked in the source with `LABENHANCED_*` comments: `SMART_FRONTIER_SCORING`,
`SMART_TRAFFIC`, `BRANCH_RESCUE`, `HARD_STALE_RESET`, `TORCH_REROUTE`,
`STALE_CHECKPOINT_RECOVERY`, `MINING_ROUTE_BRIDGE`, `TUNNEL_NAV`,
`MULTI_MAPPER_CLAIMS`. Grep for `LABENHANCED` to find every custom hook.
