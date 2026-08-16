"""
Smoke test: the .toc is well-formed and every Lua file it lists loads.

Catches syntax errors, nil globals introduced by a refactor, and load-time
calls into APIs Blizzard has removed -- the failures that stop the addon
dead at login.

SpeedTracker has no ADDON_VERSION constant; its version lives in string
literals (the login message and the options subtitle). So instead of
comparing a variable, this asserts the TOC version actually appears in the
Lua. Without that, bumping the TOC leaves the addon announcing a stale
version to the user forever, and nothing complains.
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wow_stub import load_addon, Check, ADDON_ROOT  # noqa: E402

ADDON = "SpeedTracker"
TOC = os.path.join(ADDON_ROOT, f"{ADDON}.toc")


def parse_toc(path):
    directives, files = {}, []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            if line.startswith("##"):
                key, _, value = line[2:].partition(":")
                directives[key.strip()] = value.strip()
            elif not line.startswith("#"):
                files.append(line)
    return directives, files


def main():
    c = Check(f"{ADDON} :: smoke")

    c.section("TOC")
    directives, files = parse_toc(TOC)

    interface = directives.get("Interface", "")
    c.ok("Interface is a 6-digit build number", re.fullmatch(r"\d{6}", interface))
    print(f"        Interface: {interface}")

    version = directives.get("Version", "")
    c.ok("Version present", version)
    c.ok("Title present", directives.get("Title"))
    c.ok("SavedVariables declared", directives.get("SavedVariables"))

    c.ok("declares at least one Lua file", files)
    for f in files:
        c.ok(f"{f} exists on disk", os.path.exists(os.path.join(ADDON_ROOT, f)))

    c.section("Lua loads")
    try:
        load_addon(files)
        c.ok("all TOC Lua files loaded under the stub", True)
    except Exception as exc:  # noqa: BLE001
        c.ok(f"all TOC Lua files loaded under the stub -- {exc}", False)
        return c.summary()

    c.section("Version consistency")
    source = "".join(
        open(os.path.join(ADDON_ROOT, f), encoding="utf-8").read() for f in files
    )
    c.ok(
        f"TOC version {version!r} appears in the Lua source",
        version and version in source,
    )

    return c.summary()


if __name__ == "__main__":
    sys.exit(0 if main() else 1)
