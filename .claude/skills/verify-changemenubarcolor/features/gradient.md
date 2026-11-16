# Gradient strip

## Sub-features

- Two hex colors (start → end, left → right)
- Optional wallpaper path; `--all-displays`

## How to get to it (user POV)

Run `ChangeMenuBarColor Gradient "<start hex>" "<end hex>" ["<wallpaper path>"]`. The wallpaper's top strip becomes a horizontal gradient; the menu bar shows it.

## Driving it with the CLI + probe harness

```bash
.build/debug/ChangeMenuBarColor Gradient "#FF0000" "#00FF00" "/System/Library/CoreServices/DefaultDesktop.heic" 2>&1 | tee /tmp/verify-cmbc/evidence/gradient.log
JPG=$(ls -t ~/Library/Application\ Support/ChangeMenuBarColor/*.jpg | head -1)
H=$(grep -o "menu bar height [0-9.]*" /tmp/verify-cmbc/evidence/gradient.log | awk '{print int($4)}')
swift .claude/skills/verify-changemenubarcolor/helpers/probe_wallpaper.swift "$JPG" "$H" | tee /tmp/verify-cmbc/evidence/gradient-probe.txt
```

Proof: probe (dump mode, no expected color) shows the y=0 row at x=10% near (255,0,0) and at x=90% near (0,255,0), both staying inside rows 0..H-1, with row H+4 wallpaper at both columns. Judge the dump; the helper does not PASS/FAIL gradients itself. Cleanup per SKILL.md.

## Gotchas

- The gradient runs left→right only (start at x=0); both sampled columns must sit inside the strip rows.
- Same live-desktop and height-parsing caveats as solid-color.md.
