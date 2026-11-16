---
name: verify-changemenubarcolor
description: "Drive the ChangeMenuBarColor CLI the way a user does — run SolidColor/Gradient against a real wallpaper, prove the generated strip and desktop side effects, then restore the desktop. Use when a change to this repo needs behavioral proof, or when anything about strip generation, wallpaper setting, or original-wallpaper memory looks broken."
---

# Verify ChangeMenuBarColor

macOS CLI (SwiftPM executable) that generates a wallpaper with a colored top strip and sets it as the desktop picture. Surface: the `ChangeMenuBarColor` binary with `SolidColor` / `Gradient` subcommands. Every real run mutates the **user's live desktop wallpaper** — the restore helper below is mandatory, not optional.

Helpers live in this skill's `helpers/` directory and are invoked as `swift <skill-dir>/helpers/<script>.swift <args>`.

## Launch

No server. Build once, then each drive is a fresh process:

```bash
swift build          # from repo root; binary at .build/debug/ChangeMenuBarColor
```

Ready = `swift build` prints `Build complete!` and `.build/debug/ChangeMenuBarColor --help` exits 0.

**Never use a binary from anywhere else.** The GitHub Release artifact of the upstream repo is stale code (48px clamp bug, no notch support) and has caused real misdiagnosis on this machine. Use `.build/debug/ChangeMenuBarColor` or `./build.sh` output only.

## Doctor

Read-only, run first whenever anything looks off:

```bash
.build/debug/ChangeMenuBarColor --help        # exits 0, lists SolidColor and Gradient
ls ~/Library/Application\ Support/ChangeMenuBarColor/   # generated jpgs + original-wallpaper-<displayID>.txt markers
```

Also note the current display's menu bar height source: on a notched MacBook the run log says `Using menu bar height 76.0 from auxiliary area (notched display)`; a classic display says `Using calculated menu bar height: <px>` (typically 48 at 2x). The expected strip height below depends on this.

## Drive

Always pass an explicit wallpaper (deterministic, does not depend on the user's current desktop):

```bash
.build/debug/ChangeMenuBarColor SolidColor "#1A2B3C" "/System/Library/CoreServices/DefaultDesktop.heic"
.build/debug/ChangeMenuBarColor Gradient "#FF0000" "#00FF00" "/System/Library/CoreServices/DefaultDesktop.heic"
```

A successful run prints, in order: `Starting up` → `Loaded <path>` → `Generating <color> ... image` → a menu bar height line → `Created new wallpaper for the main screen in <url>` → `Wallpaper set` → `All done!`. The generated file is the newest `wallpaper-screen-adjusted-<UUID>.jpg` in `~/Library/Application Support/ChangeMenuBarColor/`; capture its UUID for probe and cleanup.

Probe the strip (solid case checks PASS/FAIL itself; gradient uses the dumped columns):

```bash
swift <skill-dir>/helpers/probe_wallpaper.swift <generated.jpg> <stripHeightPx> <r> <g> <b>
# e.g. for "#1A2B3C" on a notched display: ... wallpaper-...jpg 76 26 43 60
```

## Evidence

Proof artifacts go to `/tmp/verify-cmbc/evidence/` (survives cleanup; recreate the dir if missing):

- the full run log (stdout+stderr),
- the probe output (rows 0..strip+4 with per-row OK/FAIL and final PASS/FAIL),
- `ls -la` of the Application Support folder after the run.

Standards: the strip must cover rows 0..strip-1 across the width at the requested color (±12 per channel after JPEG), row strip+4 must be wallpaper (DefaultDesktop's sky is ~(166,136,126)/(85,94,125) at x=mid — never the strip color); the side effect (desktop picture now the generated jpg) is verified from the run's own `Wallpaper set` + the file's presence, not by screenshots. Screenshot capture is blocked (no Screen Recording permission) — the pixel probe of the generated jpg is the evidence, do not attempt `screencapture`.

## Cleanup

Restore the desktop, then remove only what this run created:

```bash
swift <skill-dir>/helpers/restore_wallpaper.swift     # re-sets each screen from its marker file; prints "restored N screen(s)"
rm ~/Library/Application\ Support/ChangeMenuBarColor/wallpaper-screen-adjusted-<UUID>.jpg   # the file THIS run made
```

Never delete `original-wallpaper-*.txt` markers; never delete jpgs from earlier runs (the tool owns those). Kill nothing — drives are one-shot processes that have already exited.

## Helpers

- `helpers/probe_wallpaper.swift <jpg> <stripHeightPx> [r g b]` — dumps rows 0..strip+4 at x=10% and x=90%; with r g b, exits non-zero if any strip row drifts >12/channel or row strip+4 still matches the strip color.
- `helpers/restore_wallpaper.swift` — restores every screen's desktop picture from its marker; exits non-zero if nothing restored.
