# Contributing to GifCat

GifCat is a small, hackable macOS menu bar app. PRs are welcome — here's everything you need to get started.

## Development Setup

**Requirements**
- macOS 13 Ventura or later
- Xcode 15 or later

**Clone & Run**
```bash
git clone https://github.com/Joseng8908/gifmon.git
cd gifmon
open GifCat.xcodeproj
```

Press **⌘R** to build and run. The app launches as a menu bar icon — no Dock entry.

## Project Structure

```
GifCat/
├── App/
│   ├── AppDelegate.swift          ← wires all components together
│   └── GifCatApp.swift            ← @main entry point
├── Core/
│   ├── ResourceMonitor.swift      ← 0.5s CPU/RAM polling loop
│   └── GIFController.swift        ← ImageIO decode + frame timer
├── Controllers/
│   ├── StatusBarController.swift  ← menu bar icon & menu
│   ├── OverlayWindowController.swift
│   ├── OverlayContentView.swift   ← CALayer rendering, drag-to-move
│   └── OnboardingWindowController.swift
└── Utils/
    ├── CPUSampler.swift
    └── UserDefaultsKeys.swift
```

**Data flow**

```
ResourceMonitor ──(cpu, ram)──▶ AppDelegate ──(usage)──▶ GIFController
                                                               │
                                                          (CGImage frame)
                                                               ▼
                                                     OverlayWindowController
```

## How to Add a Feature

### Example: add a new menu item

1. Add a stored `NSMenuItem?` in `StatusBarController`
2. Wire it in `buildMenu()` with an `@objc` action
3. Expose a callback (`var onMyFeature: (() -> Void)?`) so `AppDelegate` handles the logic
4. Implement the logic in `AppDelegate`

Keep `StatusBarController` as a pure UI layer — no business logic there.

### Example: support a new file format

ImageIO already decodes most animated formats. To expose a new extension:
1. Add it to the `allowedContentTypes` array in `OnboardingWindowController.openFilePicker()`
2. Add it to the `gifURL(from:)` extension filter in `DropZoneView`
3. Add it to `AppDelegate.openGIFPanel()`

### Example: add a new UserDefaults key

1. Add the key constant to `UserDefaultsKeys.swift`
2. Read/write via `UserDefaults.standard` in `AppDelegate`
3. Document it in the `README.md` persistence table

## macOS-Specific Gotchas

**Entry point** — The app uses `@main` + manual `NSApplication.shared` / delegate wiring in `GifCatApp.swift`. Do **not** add `@NSApplicationMain` back; it breaks on macOS 26.

**Sandbox is OFF** — Required for `host_processor_info` (mach API). Don't enable it.

**NSStatusItem images** — Always set `isTemplate = true` on images used in the menu bar button, otherwise they may be invisible in certain appearance modes.

**CPU sampling** — Uses `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` tick deltas, same method as Activity Monitor. See `CPUSampler.swift`.

## Submitting a PR

1. Fork the repo and create a branch: `git checkout -b feat/my-feature`
2. Keep changes focused — one feature or fix per PR
3. Test on a real Mac (menu bar apps need real hardware)
4. Open a PR against `main` with a short description of what and why

## Feature Ideas

Looking for something to build? Here are some ideas:

| Feature | Difficulty | Files to touch |
|---------|-----------|----------------|
| Configurable fps range (beyond 5–30) | Easy | `GIFController.swift`, `StatusBarController.swift` |
| Multiple GIFs with random rotation | Medium | `GIFController.swift`, `AppDelegate.swift` |
| Overlay opacity control | Easy | `OverlayContentView.swift`, `StatusBarController.swift` |
| CPU threshold alert / notification | Medium | `ResourceMonitor.swift`, `AppDelegate.swift` |
| Show usage % in menu bar icon | Medium | `StatusBarController.swift` |
| Different GIF per dark/light mode | Medium | `AppDelegate.swift`, `OverlayWindowController.swift` |
| WebP support | Easy | `OnboardingWindowController.swift`, `AppDelegate.swift` |

## License

By contributing you agree that your changes will be licensed under the [MIT License](LICENSE).
