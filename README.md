# GifCat

> A macOS menu bar app that plays your GIF at a speed driven by CPU / RAM usage.

Inspired by [RunCat](https://github.com/takayoshiotake/RunCat_for_macOS) — load **any** GIF you want, and the animation accelerates as your system gets busier.

---

## Features

- **Adaptive speed** — frame rate scales live with CPU / RAM usage (5 fps → 30 fps)
- **Transparent overlay** — always-on-top, click-through window that follows you across every Space
- **Bring your own GIF** — no bundled images; drop any GIF onto the onboarding screen
- **Drag-and-drop loading** — drag a `.gif` file directly onto the welcome panel
- **Configurable monitoring** — track CPU, RAM, or `max(CPU, RAM)`
- **Resizable overlay** — three sizes: 75 × 75 / 150 × 150 / 225 × 225 px
- **Drag to reposition** — enable Move Mode from the menu, then drag the overlay anywhere

---

## Requirements

| | |
|---|---|
| **Platform** | macOS 13 Ventura or later |
| **Language** | Swift 5.9 |
| **Build tool** | Xcode 15+ |
| **Sandbox** | Disabled (required for `host_processor_info` mach API) |
| **Code signing** | Ad-hoc (no Apple Developer account needed) |

---

## Build & Run

```bash
git clone git@github.com:Joseng8908/gifmon.git
cd gifmon
open GifCat.xcodeproj
```

Then press **⌘R** in Xcode to build and run.

> On first launch macOS may show a security prompt — go to  
> **System Settings → Privacy & Security → Open Anyway**.

---

## Usage

1. **First launch** — an onboarding panel appears in the center of the screen.
2. **Load a GIF** — drag a `.gif` file onto the panel, or click **GIF 선택하기**.
3. The GIF appears as a transparent overlay on your desktop.
4. Animation **speeds up / slows down** automatically as your CPU or RAM usage changes.
5. All settings are accessible from the **menu bar icon** (⌘-click the `cpu` symbol).

### Menu reference

```
CPU: 45% | RAM: 62%          ← live stats (read-only)
────────────────────
모니터링 대상
  ● CPU
  ○ RAM
  ○ CPU + RAM (max)
────────────────────
크기
  ○ 작게  (0.5×)
  ● 보통  (1×)
  ○ 크게  (1.5×)
────────────────────
GIF 교체...                  ← swap the current GIF
위치 초기화                  ← reset overlay to default position
────────────────────
이동 모드             ☐      ← enable to drag the overlay
로그인 시 자동 실행   ☐
────────────────────
종료
```

---

## Architecture

```
AppDelegate
├── ResourceMonitor          CPU & RAM sampling every 0.5 s (mach API)
│     CPUSampler             host_processor_info tick-delta wrapper
├── GIFController            ImageIO frame decode · DispatchSourceTimer
├── OverlayWindowController  transparent floating NSWindow · CALayer rendering
│     OverlayContentView     drag-to-move · position persistence
├── StatusBarController      NSStatusItem · live label · all menu actions
└── OnboardingWindowController  first-run panel · NSDraggingDestination
```

### Speed mapping

```swift
// usage: 0.0 (idle) → 1.0 (full load)
frameInterval = 0.200 - usage × (0.200 - 0.033)
//              5 fps at 0%           30 fps at 100%
```

### CPU sampling

Uses `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` to read per-core tick counters, then computes `(Δuser + Δsys) / Δtotal` across all cores — the same method Activity Monitor uses.

### RAM sampling

Uses `host_statistics64(HOST_VM_INFO64)`.  
Reported usage = `(total − free − inactive) / total` (inactive pages treated as available by default).

---

## Persistence (UserDefaults)

| Key | Type | Default |
|-----|------|---------|
| `gifFilePath` | String? | nil |
| `windowX` | Double | bottom-right − 50 |
| `windowY` | Double | 100 |
| `windowScale` | Double | 1.0 |
| `monitorTarget` | Int | 0 (CPU) |
| `launchAtLogin` | Bool | false |
| `moveMode` | Bool | false |

---

## License

MIT — see [LICENSE](LICENSE).
