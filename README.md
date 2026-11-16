# ChangeMenuBarColor

A macOS menu bar app that makes the menu bar black, plus a CLI that composites any solid color or gradient strip onto the wallpaper. The menu bar samples the wallpaper, so the tool writes a colored strip at the top of a copy of your wallpaper and sets it as the desktop picture.

## Menu bar app

```bash
./build.sh
open build/ChangeMenuBarColor.app
```

A status icon appears in the menu bar. The menu holds one switch and an Exit item.

- **Notch** on turns the menu bar black on every display. Off restores the original wallpaper.
- Change the wallpaper in System Settings at any time. The strip re-applies to the new wallpaper within about two seconds.
- **Exit** quits the app and leaves the wallpaper exactly as it is.
- On first launch the app registers itself as a login item, on by default (macOS 13 or later). Remove it in System Settings under General, Login Items.

## CLI

The same binary works as a CLI. Pass a subcommand and it skips the GUI.

```bash
swift build
.build/debug/ChangeMenuBarColor SolidColor "#CCCCCC" "/path/to/wallpaper.jpg"
.build/debug/ChangeMenuBarColor Gradient "#FF0000" "#00FF00" --all-displays
```

Omit the wallpaper path to use the currently set wallpaper. `--all-displays` generates one wallpaper per screen.

## How it works

The tool composites a strip the exact height of the menu bar onto a copy of the wallpaper, in sRGB, so the color you ask for is the color you see. It detects notched displays (macOS 12 or later) and uses the taller menu bar height they have. The original wallpaper is remembered per display in `~/Library/Application Support/ChangeMenuBarColor`, so repeated runs and color changes never stack strips on top of each other.

Known limits. Dynamic wallpapers are converted to a static jpg. Enabling "Automatically hide and show the menu bar" breaks menu bar height detection.

## Requirements

macOS 10.15 or later. The login item needs macOS 13 or later.

## Author

- **Igor Kulman** - initial work - igor@kulman.sk
- Fork maintained by looluo

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
