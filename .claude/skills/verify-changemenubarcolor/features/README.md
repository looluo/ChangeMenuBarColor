# ChangeMenuBarColor feature map

Index of user-facing features for verification. Each file says how a user reaches the feature, how to drive it with the CLI+probe harness, and what observable end state proves it works. A proof that skips a listed feature is incomplete.

| Feature | File | One-shot safe? |
|---|---|---|
| Solid color strip (`SolidColor`) | [solid-color.md](solid-color.md) | Changes desktop; restore after |
| Gradient strip (`Gradient`) | [gradient.md](gradient.md) | Changes desktop; restore after |
| Original wallpaper memory (anti-stacking) | [original-wallpaper-memory.md](original-wallpaper-memory.md) | Changes desktop; restore after |
| Menu bar height detection (notch vs classic) | [menubar-height.md](menubar-height.md) | Read log + probe; restore after |

Shared preconditions: built binary (see SKILL.md Launch), a GUI session (NSScreen needs a logged-in display), `/System/Library/CoreServices/DefaultDesktop.heic` present.
