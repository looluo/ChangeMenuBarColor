# Solid color strip

## Sub-features

- Hex color parsing (`#RRGGBB`, `#RGB`, `#AARRGGBB`; invalid hex → error message, no wallpaper change)
- Optional wallpaper path argument; omitted → current desktop as base (see original-wallpaper-memory.md)
- `--all-displays` flag for multi-screen setups

## How to get to it (user POV)

Run `ChangeMenuBarColor SolidColor "<hex>" ["<wallpaper path>"]`. A new wallpaper identical to the base but with a solid strip of the given color across the top becomes the desktop picture.

## Driving it with the CLI + probe harness

```bash
.build/debug/ChangeMenuBarColor SolidColor "#1A2B3C" "/System/Library/CoreServices/DefaultDesktop.heic" 2>&1 | tee /tmp/verify-cmbc/evidence/solid.log
JPG=$(ls -t ~/Library/Application\ Support/ChangeMenuBarColor/*.jpg | head -1)
H=$(grep -o "menu bar height [0-9.]*" /tmp/verify-cmbc/evidence/solid.log | awk '{print int($4)}')
swift .claude/skills/verify-changemenubarcolor/helpers/probe_wallpaper.swift "$JPG" "$H" 26 43 60 | tee /tmp/verify-cmbc/evidence/solid-probe.txt
```

Proof: log shows `Wallpaper set`; probe prints `PASS` (rows 0..H-1 are 26,43,60 ±12 at both sampled columns; row H+4 is wallpaper, not strip color). Cleanup per SKILL.md (restore + rm this jpg).

## Gotchas

- The run **sets the live desktop** — always restore (see SKILL.md Cleanup).
- Strip height comes from the machine's display: 76px on this notched MacBook; 48px on classic 2x displays. Never hardcode; parse it from the log.
- Do not use the upstream GitHub Release binary — it clamps the strip to 24pt and stacks on previous output.
- An invalid hex (e.g. `#12`) prints an error and must NOT change the desktop; assert no new jpg appeared.
