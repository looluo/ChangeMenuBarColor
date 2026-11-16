# Original wallpaper memory (anti-stacking)

## Sub-features

- First no-argument run: remembers the current desktop's file path in `original-wallpaper-<displayID>.txt`
- Later no-argument runs: if the current desktop is a file this tool generated, builds on the remembered original instead
- Passing a wallpaper argument re-marks that file as the original
- Cleanup keeps `.txt` markers, deletes only old `.jpg` outputs

## How to get to it (user POV)

Run twice with different colors and no wallpaper argument: `ChangeMenuBarColor SolidColor "#111111"` then `... "#EEEEEE"`. The second result must be the original wallpaper plus one strip — not a strip over the first run's strip.

## Driving it with the CLI + probe harness

```bash
# seed a known original, then stack two runs
.build/debug/ChangeMenuBarColor SolidColor "#111111" "/System/Library/CoreServices/DefaultDesktop.heic"   # marks DefaultDesktop as original
.build/debug/ChangeMenuBarColor SolidColor "#EEEEEE" 2>&1 | tee /tmp/verify-cmbc/evidence/memory.log      # no-arg: must rebuild from DefaultDesktop
JPG=$(ls -t ~/Library/Application\ Support/ChangeMenuBarColor/*.jpg | head -1)
H=$(grep -o "menu bar height [0-9.]*" /tmp/verify-cmbc/evidence/memory.log | awk '{print int($4)}')
swift .claude/skills/verify-changemenubarcolor/helpers/probe_wallpaper.swift "$JPG" "$H" 238 238 238 | tee /tmp/verify-cmbc/evidence/memory-probe.txt
```

Proof: memory.log contains `using the remembered original wallpaper .../DefaultDesktop.heic` (not the previous run's jpg); probe `PASS` shows the full strip is (238,238,238) with no dark `#111111` band inside it. Cleanup per SKILL.md (restore uses the same marker).

## Gotchas

- If the marker is missing while the desktop is a generated file, the tool errors on purpose ("original wallpaper ... is not remembered") and must not stack — that error is correct behavior, not a bug.
- Markers are per display (`NSScreenNumber`); an unplugged/replugged screen may get a new marker only when a non-tool wallpaper is current.
- Two runs in this journey set the desktop twice; one restore at the end is enough.
