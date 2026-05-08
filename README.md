# GifCat

> A macOS menu bar app that plays your GIF / APNG at a speed driven by CPU / RAM usage.

Inspired by [RunCat](https://github.com/takayoshiotake/RunCat_for_macOS) — load **any** GIF or APNG you want, and the animation accelerates as your system gets busier.

---

## Download

**[⬇ Download GifCat v1.0.0](https://github.com/Joseng8908/gifmon/releases/latest)**

1. Download `GifCat.zip` from the link above and unzip it.
2. Move `GifCat.app` to your **Applications** folder.
3. Because the binary is ad-hoc signed (not notarized), macOS Gatekeeper will block it on first launch. Run this once in Terminal:
   ```bash
   xattr -d com.apple.quarantine /Applications/GifCat.app
   ```
4. Double-click `GifCat.app` — done.

> **macOS 13 Ventura or later** required (tested on macOS 26).

---

## Features

- **Adaptive speed** — frame rate scales live with CPU / RAM usage (5 fps → 30 fps)
- **GIF & APNG support** — works with `.gif`, `.png`, and `.apng` files
- **Transparent overlay** — always-on-top, click-through window that follows you across every Space
- **Bring your own GIF** — no bundled images; drop any GIF/APNG onto the onboarding screen
- **Configurable monitoring** — track CPU, RAM, or `max(CPU, RAM)`
- **Resizable overlay** — three sizes: 75 × 75 / 150 × 150 / 225 × 225 px
- **Drag to reposition** — enable Move Mode from the menu, then drag the overlay anywhere
- **Launch at login** — optional auto-start on macOS login

---

## Usage

1. **First launch** — an onboarding panel appears in the center of the screen.
2. **Load a file** — drag a `.gif` or `.apng` file onto the panel, or click **GIF 선택하기**.
3. The animation appears as a transparent overlay on your desktop.
4. Animation **speeds up / slows down** automatically as your CPU or RAM usage changes.
5. All settings are accessible from the **menu bar icon** (click the `cpu` symbol).

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
GIF 교체...                  ← swap the current GIF/APNG
위치 초기화                  ← reset overlay to default position
────────────────────
이동 모드             ☐      ← enable to drag the overlay
로그인 시 자동 실행   ☐
────────────────────
종료
```

---

## Build from Source

```bash
git clone https://github.com/Joseng8908/gifmon.git
cd gifmon
open GifCat.xcodeproj
```

Press **⌘R** in Xcode to build and run.

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

## Requirements

| | |
|---|---|
| **Platform** | macOS 13 Ventura or later |
| **Sandbox** | Disabled (required for `host_processor_info` mach API) |
| **Code signing** | Ad-hoc |

---

## License

MIT — see [LICENSE](LICENSE).
