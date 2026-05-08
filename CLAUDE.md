# GifCat — Claude Code 컨텍스트

## 프로젝트 개요
macOS 메뉴바 앱. CPU/RAM 사용량에 따라 GIF 애니메이션 속도가 실시간으로 변함.
- 언어: Swift 5.9 / AppKit / macOS 13+
- 번들 ID: `com.gifmon.GifCat`
- 샌드박스: 비활성화 (mach API 필요)
- 코드 서명: ad-hoc (`CODE_SIGN_IDENTITY = "-"`)

## 현재 구현 상태
**모든 Step 완료 (Step 1~7), v1.0.0 태그 전 상태**

| Step | 내용 | 상태 |
|------|------|------|
| 1 | Xcode 프로젝트 세팅, 샌드박스 비활성화, .gitignore | ✅ |
| 2 | ResourceMonitor (CPU: host_processor_info, RAM: host_statistics64) | ✅ |
| 3 | GIFController (ImageIO 디코딩, DispatchSourceTimer 속도 제어) | ✅ |
| 4 | OverlayWindowController (투명 NSWindow, CALayer 렌더링, 드래그 이동) | ✅ |
| 5 | StatusBarController (메뉴바 아이콘, 실시간 수치, 전체 메뉴) | ✅ |
| 6 | OnboardingWindowController (첫 실행 패널, 드래그 앤 드롭) | ✅ |
| 7 | LaunchAtLogin (SMAppService), 에러 핸들링, 로그 정리 | ✅ |
| 8 | git tag v1.0.0 | ⏳ 테스트 완료 후 진행 |

## 미결 사항
- **메뉴바 아이콘 임시 변경됨**: `StatusBarController.swift` 의 `init()` 에서
  아이콘을 텍스트 `"GifCat"` 으로 바꿔둔 상태 (메뉴바 공간 부족 디버깅용).
  테스트 확인 후 원래 SF Symbol `cpu` 아이콘으로 복구 필요:
  ```swift
  // 현재 (임시)
  statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  btn.title = "GifCat"

  // 원래대로 복구해야 함
  statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  btn.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "GifCat")
  ```
  이 변경은 커밋/푸시되지 않은 로컬 수정 상태.

## 다음 할 일
1. 맥에서 빌드 & 테스트:
   - 메뉴바 아이콘 노출 확인
   - GIF 로드 → 오버레이 애니메이션 확인
   - CPU 부하 시 속도 변화 확인 (`yes > /dev/null`)
   - Activity Monitor와 CPU 수치 ±5% 비교
2. 테스트 통과 후 StatusBarController 아이콘 원복 + 커밋
3. `git tag v1.0.0 && git push origin v1.0.0`

## 아키텍처 요약
```
AppDelegate
├── ResourceMonitor      0.5s 주기 CPU/RAM 샘플링
│     CPUSampler         host_processor_info tick delta 래퍼
├── GIFController        ImageIO 프레임 디코딩, DispatchSourceTimer
├── OverlayWindowController  투명 NSWindow (.floating, .canJoinAllSpaces)
│     OverlayContentView     CALayer 렌더링, 드래그 이동, UserDefaults 위치 저장
├── StatusBarController  NSStatusItem, 메뉴 빌드, 실시간 레이블
└── OnboardingWindowController  NSPanel, DropZoneView (NSDraggingDestination)
```

## 주요 파일 경로
```
GifCat.xcodeproj/project.pbxproj
GifCat/App/AppDelegate.swift          ← 앱 진입점, 모든 컴포넌트 연결
GifCat/Core/ResourceMonitor.swift
GifCat/Core/GIFController.swift
GifCat/Controllers/StatusBarController.swift
GifCat/Controllers/OverlayWindowController.swift
GifCat/Controllers/OverlayContentView.swift
GifCat/Controllers/OnboardingWindowController.swift
GifCat/Utils/CPUSampler.swift
GifCat/Utils/UserDefaultsKeys.swift
GifCat/GifCat.entitlements             ← 샌드박스 OFF
```

## 속도 공식
```swift
frameInterval = 0.200 - usage × (0.200 - 0.033)
// usage 0.0 → 5fps,  usage 1.0 → 30fps
```

## UserDefaults 키
`gifFilePath`, `windowX`, `windowY`, `windowScale`, `monitorTarget`, `launchAtLogin`, `moveMode`
