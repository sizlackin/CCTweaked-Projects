"""Shared plumbing for the Actually Useful Turtles deploy tooling.

Nothing in here writes to the live controller. Writes live in deploy-controller
and rollback-controller only, and both go through assert_safe_target() first.
"""

import hashlib
import os
import subprocess
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Locations
# ---------------------------------------------------------------------------

REPO = Path(__file__).resolve().parent.parent
AUT = REPO / "ActuallyUsefulTurtles"
MANIFEST = REPO / "tools" / "manifest.tsv"

CONTROLLER_ID = "9"

SAVE = Path(
    "/home/cesar/.local/share/PrismLauncher/instances/Delightful Machinations"
    "/minecraft/saves/The Fuckening"
)
CC_ROOT = SAVE / "computercraft" / "computer"
LIVE = CC_ROOT / CONTROLLER_ID

BACKUPS = Path("/home/cesar/Backups/ActuallyUsefulTurtles")
FULL_BACKUPS = BACKUPS / "full"
DEPLOY_BACKUPS = BACKUPS / "deploy"

TURTLE_IDS = ["12", "14", "15", "16"]

# ---------------------------------------------------------------------------
# What the controller boot process does with each directory.
#
#   host/startup.lua  copies  general gui host storage  ->  runtime/   (flat)
#   turtle/update.lua pulls   general turtle storage     from the host
#
# So a file's directory decides who has to reboot to pick the change up.
# ---------------------------------------------------------------------------

CONTROLLER_DIRS = {"general", "gui", "host", "storage"}
TURTLE_DIRS = {"general", "turtle", "storage"}

# ---------------------------------------------------------------------------
# Persistent state. These are the learned map, the tunnel graph, stations,
# queues, tasks and alerts. A deploy or rollback that touches any of these is
# a bug, so the check is a hard abort rather than a warning.
# ---------------------------------------------------------------------------

PROTECTED_EXACT = {
    "runtime/tunnelMap.txt",
    "runtime/stations.txt",
    "runtime/taskData.txt",
    "runtime/turtles.txt",
    "runtime/alerts.txt",
    "log.txt",
}
PROTECTED_PREFIXES = ("runtime/map/",)


def is_protected(rel: str) -> bool:
    rel = rel.replace(os.sep, "/")
    return rel in PROTECTED_EXACT or rel.startswith(PROTECTED_PREFIXES)


# Files that live under the controller but are generated or bootstrap-only.
# They are deliberately not deploy targets.
GENERATED_OR_BOOTSTRAP = {
    "startup.lua",      # copied from host/startup.lua by the boot process
    "setup.lua",        # one-shot upstream installer
    "rawterm.lua",      # standalone utility, fetched separately
    "log.txt",
}

# Sentinels that prove we are looking at a real AUT controller.
EXPECTED_LIVE_FILES = [
    "host/startup.lua",
    "host/main.lua",
    "host/classTaskManager.lua",
    "general/utils.lua",
    "general/killRednet.lua",
    "gui/classHostDisplay.lua",
    "storage/classRemoteStorage.lua",
    "turtle/classMiner.lua",
    "startup.lua",
]
EXPECTED_LIVE_DIRS = ["general", "gui", "host", "storage", "turtle", "runtime"]


# ---------------------------------------------------------------------------
# Terminal helpers
# ---------------------------------------------------------------------------

_TTY = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None


def c(text: str, code: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _TTY else text


def red(t):
    return c(t, "31")


def green(t):
    return c(t, "32")


def yellow(t):
    return c(t, "33")


def blue(t):
    return c(t, "36")


def bold(t):
    return c(t, "1")


def die(msg: str, code: int = 1):
    print(f"\n{red('ABORT:')} {msg}\n", file=sys.stderr)
    sys.exit(code)


# ---------------------------------------------------------------------------
# Guards
# ---------------------------------------------------------------------------

def verify_live_root():
    """Refuse to continue unless LIVE really is controller 9's directory."""
    if LIVE.name != CONTROLLER_ID:
        die(f"live path does not end in /{CONTROLLER_ID}: {LIVE}")
    if LIVE.parent.name != "computer":
        die(f"live path parent is not 'computer': {LIVE}")
    if not LIVE.is_dir():
        die(f"live controller directory does not exist: {LIVE}")
    if (LIVE / ".git").exists():
        die("the live controller directory contains .git - it must never be a repo")

    missing = [p for p in EXPECTED_LIVE_FILES if not (LIVE / p).is_file()]
    missing += [d + "/" for d in EXPECTED_LIVE_DIRS if not (LIVE / d).is_dir()]
    if missing:
        die(
            "live path does not look like the AUT controller; missing:\n  "
            + "\n  ".join(missing)
        )

    # Not fatal, but worth shouting about: this is the learned tunnel graph.
    if not (LIVE / "runtime" / "tunnelMap.txt").is_file():
        print(
            yellow("WARNING: runtime/tunnelMap.txt is absent - is this the right world?"),
            file=sys.stderr,
        )


def assert_safe_target(rel: str, allow_runtime: bool = False):
    """Last line of defence before any write into the live tree."""
    rel = rel.replace(os.sep, "/")
    if rel.startswith("/") or ".." in rel.split("/"):
        die(f"refusing suspicious relative path: {rel}")
    if is_protected(rel):
        die(f"refusing to write persistent runtime state: {rel}")
    if rel.startswith("runtime/") and not allow_runtime:
        die(f"refusing to write into runtime/ without --with-runtime: {rel}")
    target = (LIVE / rel).resolve()
    if not str(target).startswith(str(LIVE.resolve()) + os.sep):
        die(f"path escapes the controller directory: {rel}")


# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

class Entry:
    __slots__ = ("repo_rel", "live_rel", "origin")

    def __init__(self, repo_rel, live_rel, origin):
        self.repo_rel = repo_rel      # relative to repo root
        self.live_rel = live_rel      # relative to computer/9
        self.origin = origin          # 'patch' | 'tunnelnav' | 'vendor'

    @property
    def repo_path(self) -> Path:
        return REPO / self.repo_rel

    @property
    def live_path(self) -> Path:
        return LIVE / self.live_rel

    @property
    def live_dir(self) -> str:
        return self.live_rel.split("/")[0]

    @property
    def needs_controller_reboot(self) -> bool:
        return self.live_dir in CONTROLLER_DIRS

    @property
    def needs_turtle_reboot(self) -> bool:
        return self.live_dir in TURTLE_DIRS


def load_manifest():
    if not MANIFEST.is_file():
        die(f"manifest not found: {MANIFEST}")
    entries = []
    seen_live, seen_repo = {}, {}
    for lineno, raw in enumerate(MANIFEST.read_text().splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        parts = [p for p in parts if p != ""]
        if len(parts) != 3:
            die(f"{MANIFEST}:{lineno}: expected 3 tab-separated fields, got {len(parts)}")
        repo_rel, live_rel, origin = parts
        if live_rel in seen_live:
            die(f"{MANIFEST}:{lineno}: live path mapped twice: {live_rel} "
                f"(also line {seen_live[live_rel]})")
        if repo_rel in seen_repo:
            die(f"{MANIFEST}:{lineno}: repo path mapped twice: {repo_rel} "
                f"(also line {seen_repo[repo_rel]})")
        if is_protected(live_rel):
            die(f"{MANIFEST}:{lineno}: manifest targets persistent state: {live_rel}")
        seen_live[live_rel] = lineno
        seen_repo[repo_rel] = lineno
        entries.append(Entry(repo_rel, live_rel, origin))
    return entries


# ---------------------------------------------------------------------------
# Comparison
# ---------------------------------------------------------------------------

def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(131072), b""):
            h.update(chunk)
    return h.hexdigest()


SAME, DIFFER, NO_REPO, NO_LIVE = "same", "differ", "no-repo", "no-live"


def compare(e: Entry) -> str:
    rp, lp = e.repo_path, e.live_path
    if not rp.is_file():
        return NO_REPO
    if not lp.is_file():
        return NO_LIVE
    if rp.stat().st_size != lp.stat().st_size:
        return DIFFER
    return SAME if sha(rp) == sha(lp) else DIFFER


def unified_diff(e: Entry, context: int = 3) -> str:
    """Repo (source) as 'a', live as 'b'. Uses the system diff for speed."""
    if not e.repo_path.is_file() or not e.live_path.is_file():
        return ""
    r = subprocess.run(
        ["diff", "-u", f"-U{context}",
         "--label", f"a/{e.repo_rel} (source)",
         "--label", f"b/{e.live_rel} (live)",
         str(e.repo_path), str(e.live_path)],
        capture_output=True, text=True,
    )
    return r.stdout


def git_blob_sha(path: Path):
    """The git blob id this file's content would have."""
    r = subprocess.run(["git", "-C", str(REPO), "hash-object", "-t", "blob", "--", str(path)],
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def find_in_history(repo_rel: str, blob: str, limit: int = 400):
    """Return the commit where repo_rel last held this exact blob, else None.

    This is what separates 'live is simply behind a commit we know about' from
    'live holds content this repo has never seen'. The first is a normal deploy;
    the second is in-game work that a deploy would destroy.
    """
    if not blob:
        return None
    if subprocess.run(["git", "-C", str(REPO), "cat-file", "-e", blob],
                      capture_output=True).returncode != 0:
        return None  # object not in this repo at all
    r = subprocess.run(
        ["git", "-C", str(REPO), "log", "--all", f"-n{limit}", "--format=%H", "--", repo_rel],
        capture_output=True, text=True,
    )
    for commit in r.stdout.split():
        got = subprocess.run(
            ["git", "-C", str(REPO), "rev-parse", f"{commit}:{repo_rel}"],
            capture_output=True, text=True,
        )
        if got.returncode == 0 and got.stdout.strip() == blob:
            return commit
    return None


def live_is_known(e) -> bool:
    """True when the live file's content exists somewhere in this repo's history."""
    return find_in_history(e.repo_rel, git_blob_sha(e.live_path)) is not None


def live_source_files():
    """Every code file under the controller's source directories."""
    out = []
    for d in sorted(CONTROLLER_DIRS | TURTLE_DIRS):
        base = LIVE / d
        if not base.is_dir():
            continue
        for p in sorted(base.rglob("*")):
            if p.is_file():
                out.append(str(p.relative_to(LIVE)))
    return out


def timestamp() -> str:
    from datetime import datetime
    return datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
