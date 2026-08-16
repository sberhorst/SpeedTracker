# Tests

Runs SpeedTracker's actual Lua against a stubbed WoW API, outside the game.

```bash
pip install lupa
python tests/run_all.py
```

Exits `0` if everything passes, `1` if anything fails. `lupa` embeds a real
Lua interpreter in Python, so these tests execute the addon's real source
rather than reasoning about it. No other dependencies.

## Why this exists

Nothing here breaks because a Lua function is wrong internally. It breaks at
the seam with Blizzard's API, and that seam moves every patch.

For SpeedTracker the sharp edge is `GetUnitSpeed`. In protected combat states
it hands back a value that *reads* fine but raises on any arithmetic — the
error fires when you use the number, not when you fetch it. `UpdateSpeed`
therefore does the division inside a `pcall` and keeps `lastKnownPct` when it
fails. Remove that and the readout either errors every frame or snaps to a
wrong number in exactly the moment you are watching it: mid-fight, when a
slow or a speed boost lands.

`test_speed.py` section 3 is the guard. The stub models a real secret value —
a table whose arithmetic metamethods raise — because a test that only ever
feeds a plain number cannot see any of this.

## Layout

| File | What it covers |
|---|---|
| `wow_stub.py` | The fake Blizzard API, `load_addon()`, and a small assert helper |
| `test_smoke.py` | The `.toc` parses, every Lua file it lists loads, and the TOC version actually appears in the source |
| `test_speed.py` | Percentage readout, colour coding, the combat-taint guard, slash commands, first-run defaults |
| `test_api_contract.py` | Fails if the addon calls anything removed or renamed in the current patch |
| `run_all.py` | Runs every `test_*.py` here |

## Writing a test

`load_addon()` takes the Lua files in TOC order and a list of addon **locals**
to re-expose, since Lua locals are otherwise unreachable from outside the file.
Each file is loaded as its own chunk and called with `(addonName, addon)`,
exactly as WoW does.

```python
from wow_stub import load_addon, Check

lua = load_addon(["SpeedTracker.lua"], exports=["UpdateSpeed", "speedText"])
g = lua.globals()

g.TEST.speed = 10.5          # 150% of base run speed
g.T_UpdateSpeed()
assert "150%" in g.T_speedText.GetText(g.T_speedText)

g.TEST.speedTaint = True     # now arithmetic on the speed raises
g.T_UpdateSpeed()            # must not error, must hold 150%
```

`g.TEST` is the control surface: `speed`, `speedTaint`, `auras`, `restricted`,
`spellNames`, and `prints` (everything the addon sent to chat).

## Two rules that make this worth running

1. **Model the new API behaviour in the stub, not the old one.** The stub is
   only useful if it lies the way the current patch lies.
2. **Prove the test can fail.** Re-introduce the bug, watch the suite go red,
   then restore. A guard that has never gone red is decoration — this suite
   was checked that way: deleting the `pcall` in `UpdateSpeed` turns section 3
   red and `run_all.py` exits 1.

## After a patch

Update the tables at the top of `test_api_contract.py` with what the patch
removed, renamed, or restricted. That edit is the point of the file: it turns
"read the patch notes and hope" into a check that runs.

This harness is shared with AdventureKit and Socialite. `wow_stub.py` is
addon-agnostic — `ADDON_ROOT` resolves to the repo containing `tests/` — so
improvements are worth copying across all three.
