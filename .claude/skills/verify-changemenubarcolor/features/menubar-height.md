# Menu bar height detection

## Sub-features

- Notched displays (macOS 12+): `auxiliaryTopRightArea`/`LeftArea` height × backing scale (38pt → 76px here)
- Classic displays: `(frame - visibleFrame - origin.y) × scale`, sanity-clamped in points (≤50pt), else 24pt fallback
- Fallback triggers log `using standard height`; successful paths log the value used

## How to get to it (user POV)

Invisible plumbing: every generated wallpaper's strip height must exactly match the menu bar the user sees, or the menu bar is part colored / part wallpaper (the "half-height black" symptom).

## Driving it with the CLI + probe harness

```bash
cat > /tmp/mb_height.swift <<'EOF'
import Cocoa
let s = NSScreen.main!
if #available(macOS 12.0, *), let a = s.auxiliaryTopRightArea ?? s.auxiliaryTopLeftArea {
    print("notched: \(a.height * s.backingScaleFactor)")
} else {
    let c = (s.frame.height - s.visibleFrame.height - s.visibleFrame.origin.y) * s.backingScaleFactor
    print(c / s.backingScaleFactor <= 50 ? "classic: \(c)" : "fallback: \(24 * s.backingScaleFactor)")
}
EOF
swift /tmp/mb_height.swift
.build/debug/ChangeMenuBarColor SolidColor "#1A2B3C" "/System/Library/CoreServices/DefaultDesktop.heic" 2>&1 | grep "menu bar height"
```

Proof: the swift probe's value equals the tool's logged `menu bar height N` (76.0 on this notched MacBook), and the generated jpg's strip measures exactly N px via `probe_wallpaper.swift "$JPG" "$N" 26 43 60`. On a notched display a log line ending `using standard height` while the swift probe says `notched:` is a FAIL.

## Gotchas

- Requires the screen the run targets — run inside the GUI session, not over headless SSH.
- The formula path can legitimately report one point more than the auxiliary area on scaled resolutions; treat ±2px as equal.
- `screencapture` is unavailable (no Screen Recording permission); never make screenshots part of this proof.
