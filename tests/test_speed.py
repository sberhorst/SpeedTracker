"""
Behaviour tests for SpeedTracker's speed readout and slash commands.

The one that matters is section 3, the combat-taint guard.

GetUnitSpeed can hand back a protected value: it reads fine, but any
arithmetic on it raises. That is why UpdateSpeed does the division inside a
pcall and keeps lastKnownPct on failure. Without that, the readout would
either error every frame or reset to a wrong number in exactly the moments
you are watching it -- mid-combat, when a slow or a speed boost lands.

A test that only ever feeds a plain number cannot see any of this, which is
the whole reason the stub models a secret value rather than an int.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wow_stub import load_addon, Check  # noqa: E402

BASE_SPEED = 7.0


def boot(lua):
    """Fire ADDON_LOADED so the addon initialises its saved variables."""
    g = lua.globals()
    g.SpeedTrackerDB = lua.table()
    handler = g.T_initFrame.GetScript(g.T_initFrame, "OnEvent")
    handler(g.T_initFrame, "ADDON_LOADED", "SpeedTracker")
    return g


def fresh():
    lua = load_addon(
        ["SpeedTracker.lua"],
        exports=["UpdateSpeed", "initFrame", "tracker", "speedText", "DEFAULTS"],
    )
    return lua, boot(lua)


def main():
    c = Check("SpeedTracker :: speed readout and slash commands")

    lua, g = fresh()
    c.ok("addon initialised on ADDON_LOADED", g.SpeedTrackerDB is not None)

    c.section("1. Percentage readout")
    g.TEST.speed = BASE_SPEED
    g.T_UpdateSpeed()
    c.ok("base speed reads 100%", "100%" in g.T_speedText.GetText(g.T_speedText))

    g.TEST.speed = BASE_SPEED * 1.5
    g.T_UpdateSpeed()
    c.ok("+50% speed reads 150%", "150%" in g.T_speedText.GetText(g.T_speedText))

    g.TEST.speed = 0
    g.T_UpdateSpeed()
    c.ok("rooted reads 0%", "0%" in g.T_speedText.GetText(g.T_speedText))

    c.section("2. Colour coding")
    g.SpeedTrackerDB.colorize = True
    g.TEST.speed = BASE_SPEED * 1.5
    g.T_UpdateSpeed()
    c.ok("above base is green", "00ff88" in g.T_speedText.GetText(g.T_speedText))

    g.TEST.speed = BASE_SPEED * 0.5
    g.T_UpdateSpeed()
    c.ok("slowed is orange", "ff6644" in g.T_speedText.GetText(g.T_speedText))

    g.TEST.speed = BASE_SPEED
    g.T_UpdateSpeed()
    c.ok("at base is white", "ffffff" in g.T_speedText.GetText(g.T_speedText))

    g.SpeedTrackerDB.colorize = False
    g.TEST.speed = BASE_SPEED * 1.5
    g.T_UpdateSpeed()
    c.ok("colorize off stays white", "ffffff" in g.T_speedText.GetText(g.T_speedText))

    c.section("3. GUARD: protected combat value must not corrupt the readout")
    g.SpeedTrackerDB.colorize = True
    g.TEST.speedTaint = False
    g.TEST.speed = BASE_SPEED * 1.5
    g.T_UpdateSpeed()
    before = g.T_speedText.GetText(g.T_speedText)
    c.ok("pre-combat reads 150%", "150%" in before)

    g.TEST.speedTaint = True          # arithmetic on the speed now raises
    ok = True
    try:
        g.T_UpdateSpeed()
    except Exception as exc:  # noqa: BLE001
        ok = False
        print(f"        raised: {exc}")
    c.ok("UpdateSpeed survives a secret value without erroring", ok)
    c.ok(
        "readout holds its last known value instead of resetting",
        "150%" in g.T_speedText.GetText(g.T_speedText),
    )

    g.TEST.speedTaint = False
    g.TEST.speed = BASE_SPEED
    g.T_UpdateSpeed()
    c.ok("recovers once the value is readable again",
         "100%" in g.T_speedText.GetText(g.T_speedText))

    c.section("4. Slash commands")
    lua, g = fresh()
    slash = g.SlashCmdList["SPEEDTRACKER"]

    slash("lock")
    c.eq("/speed lock sets locked", g.SpeedTrackerDB.locked, True)
    slash("unlock")
    c.eq("/speed unlock clears locked", g.SpeedTrackerDB.locked, False)

    slash("toggle")
    c.eq("/speed toggle hides the frame", g.SpeedTrackerDB.visible, False)
    slash("toggle")
    c.eq("/speed toggle shows it again", g.SpeedTrackerDB.visible, True)

    g.SpeedTrackerDB.x, g.SpeedTrackerDB.y = 999, 999
    slash("reset")
    c.eq("/speed reset restores default x", g.SpeedTrackerDB.x, g.T_DEFAULTS.x)
    c.eq("/speed reset restores default y", g.SpeedTrackerDB.y, g.T_DEFAULTS.y)

    slash("")
    c.ok("bare /speed prints usage", any("/speed" in p for p in g.TEST.prints.values()))

    c.section("5. Defaults applied for a first-time user")
    lua2 = load_addon(["SpeedTracker.lua"], exports=["initFrame", "DEFAULTS"])
    g2 = boot(lua2)
    for key in ("x", "y", "locked", "scale", "visible", "showLabel", "colorize"):
        c.ok(f"default {key} populated", g2.SpeedTrackerDB[key] is not None)

    return c.summary()


if __name__ == "__main__":
    sys.exit(0 if main() else 1)
