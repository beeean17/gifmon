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
ResourceMonitor ──(cpu, ram)──▶ AppDelegate ──(usage)──▶ [GIFController...]
                                                               │
                                                          (CGImage frame)
                                                               ▼
                                [OverlayWindowController...] + StatusBarController
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

## How Speed Customization Works

The animation speed is controlled by `minFPS` and `maxFPS` properties on `GIFController`. The frame interval is calculated as:

```swift
// GifCat/Core/GIFController.swift
frameInterval = (1/minFPS) - usage × (1/minFPS - 1/maxFPS)
```

- `usage 0.0` (idle) → `minFPS`
- `usage 1.0` (full load) → `maxFPS`

The user selects values from the **속도** submenu in `StatusBarController`. Changes are applied immediately to every active `GIFController`, without waiting for the next `ResourceMonitor` tick. Settings persist via `UserDefaults` keys `speedMinFPS` and `speedMaxFPS`.

When **리소스 연동** is off, `fixedFPS` is used as the playback speed. When it is on, CPU/RAM usage maps between `minFPS` and `maxFPS`.

The menu bar icon can also be animated with its own `GIFController`. It shares the same speed settings as overlays, but renders frames through `StatusBarController.updateMenuBarFrame(_:)`.

The status item itself can be removed with **상단바에서 숨기기**. `StatusBarController.hideFromMenuBar()` removes the current `NSStatusItem`, and `AppDelegate.applicationShouldHandleReopen` restores it when the user launches the already-running app again.

To add more preset options, edit the `for fps in [...]` arrays in `StatusBarController.buildSpeedSubMenu()`.

---

## Planned Features (not yet implemented)

---

### 1. Multiple Characters (Multiple Overlay Windows)

**Status**: Basic support is implemented. Users can add several GIF/APNG overlays, replace all overlays, remove all overlays, and edit each overlay's frame.

**Current design**:
- `AppDelegate` owns an array of managed overlay records
- Each overlay instance owns its own `GIFController` and `OverlayWindowController`
- Overlay window frames are namespaced in `UserDefaults`
- The active overlay list is stored under `gifOverlays`
- All overlays share one `ResourceMonitor`

**Potential next step**:
- Add a per-GIF remove submenu that lists active overlays by filename

**Files to touch**:
- `GifCat/App/AppDelegate.swift` (main orchestration change)
- `GifCat/Controllers/OverlayWindowController.swift` (may need an `id` property)
- `GifCat/Utils/UserDefaultsKeys.swift` (new namespaced keys)
- `GifCat/Controllers/StatusBarController.swift` (add/remove character menu items)

---

## Other Ideas

| Feature | Difficulty | Files to touch |
|---------|-----------|----------------|
| Overlay opacity control | Easy | `OverlayContentView.swift`, `StatusBarController.swift` |
| CPU threshold alert / notification | Medium | `ResourceMonitor.swift`, `AppDelegate.swift` |
| Show usage % in menu bar icon | Medium | `StatusBarController.swift` |
| Different GIF per dark/light mode | Medium | `AppDelegate.swift`, `OverlayWindowController.swift` |
| WebP support | Easy | `OnboardingWindowController.swift`, `AppDelegate.swift` |

## License

By contributing you agree that your changes will be licensed under the [MIT License](LICENSE).
