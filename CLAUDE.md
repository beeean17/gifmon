# GifCat — Claude Code 컨텍스트

## 프로젝트 개요
macOS 메뉴바 앱. CPU/RAM 사용량에 따라 GIF/APNG 애니메이션 속도가 실시간으로 변함.
- 언어: Swift 5.9 / AppKit / macOS 13+
- 번들 ID: `com.gifmon.GifCat`
- 샌드박스: 비활성화 (mach API 필요)
- 코드 서명: ad-hoc (`CODE_SIGN_IDENTITY = "-"`)
- 릴리즈: v1.0.0 태그 완료, GitHub Releases에 바이너리 배포 중

## 구현 완료 상태
**v1.0.0 출시 완료**

| Step | 내용 | 상태 |
|------|------|------|
| 1 | Xcode 프로젝트 세팅, 샌드박스 비활성화, .gitignore | ✅ |
| 2 | ResourceMonitor (CPU: host_processor_info, RAM: host_statistics64) | ✅ |
| 3 | GIFController (ImageIO 디코딩, DispatchSourceTimer 속도 제어) | ✅ |
| 4 | OverlayWindowController (투명 NSWindow, CALayer 렌더링, 드래그 이동) | ✅ |
| 5 | StatusBarController (메뉴바 아이콘, 실시간 수치, 전체 메뉴) | ✅ |
| 6 | OnboardingWindowController (첫 실행 패널, 드래그 앤 드롭) | ✅ |
| 7 | LaunchAtLogin (SMAppService), 에러 핸들링, 로그 정리 | ✅ |
| 8 | git tag v1.0.0, GitHub Release 배포 | ✅ |

## 알려진 macOS 플랫폼 이슈

### macOS 26 호환성 (@NSApplicationMain 제거)
`@NSApplicationMain` 어트리뷰트가 macOS 26에서 `applicationDidFinishLaunching`을 호출하지 않는 문제가 있었음.
`GifCatApp.swift`에서 `@main` + 명시적 delegate 연결로 교체해 해결:

```swift
// GifCat/App/GifCatApp.swift
@main
struct GifCatApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
```

`AppDelegate`에는 `@NSApplicationMain` 없음. 향후 macOS 신버전 대응 시 이 패턴 유지할 것.

### NSStatusItem 렌더링
`NSImage(systemSymbolName:)` 결과에 `isTemplate = true` 설정 필요. 미설정 시 다크/라이트 모드 전환 때 아이콘이 안 보일 수 있음.

## 아키텍처 요약
```
AppDelegate                  ← 앱 진입점, 모든 컴포넌트 연결
├── ResourceMonitor          0.5s 주기 CPU/RAM 샘플링
│     CPUSampler             host_processor_info tick delta 래퍼
├── GIFController            ImageIO 프레임 디코딩, DispatchSourceTimer
├── OverlayWindowController  투명 NSWindow (.floating, .canJoinAllSpaces)
│     OverlayContentView     CALayer 렌더링, 드래그 이동, UserDefaults 위치 저장
├── StatusBarController      NSStatusItem, 메뉴 빌드, 실시간 레이블
└── OnboardingWindowController  NSPanel, DropZoneView (NSDraggingDestination)
```

## 주요 파일 경로
```
GifCat.xcodeproj/project.pbxproj
GifCat/App/AppDelegate.swift                ← 앱 진입점, 모든 컴포넌트 연결
GifCat/App/GifCatApp.swift                  ← @main 진입점 (delegate 수동 연결)
GifCat/Core/ResourceMonitor.swift
GifCat/Core/GIFController.swift             ← ImageIO 기반, GIF·APNG 모두 지원
GifCat/Controllers/StatusBarController.swift
GifCat/Controllers/OverlayWindowController.swift
GifCat/Controllers/OverlayContentView.swift
GifCat/Controllers/OnboardingWindowController.swift
GifCat/Utils/CPUSampler.swift
GifCat/Utils/UserDefaultsKeys.swift
GifCat/GifCat.entitlements                  ← 샌드박스 OFF
```

## 속도 공식
```swift
frameInterval = 0.200 - usage × (0.200 - 0.033)
// usage 0.0 → 5fps,  usage 1.0 → 30fps
```

## UserDefaults 키
`gifFilePath`, `windowX`, `windowY`, `windowScale`, `monitorTarget`, `launchAtLogin`, `moveMode`

## 지원 파일 형식
ImageIO(`CGImageSourceCreateWithURL`) 기반이므로 GIF, APNG, PNG 모두 디코딩 가능.
UI 레이어 확장자 허용 목록: `["gif", "png", "apng"]`
- `OnboardingWindowController.swift` — 파일 피커 + 드래그 드롭
- `AppDelegate.swift` — GIF 교체 메뉴

## 기여 아이디어 (미구현 기능)
기여를 환영합니다. 아래는 좋은 시작점입니다:

| 아이디어 | 난이도 | 관련 파일 |
|---------|--------|-----------|
| 커스텀 fps 범위 설정 (5~30 외) | 하 | `GIFController.swift`, `StatusBarController.swift` |
| 여러 GIF 등록 후 랜덤 재생 | 중 | `GIFController.swift`, `AppDelegate.swift` |
| 오버레이 투명도 조절 | 하 | `OverlayContentView.swift`, `StatusBarController.swift` |
| CPU 임계값 도달 시 알림 | 중 | `ResourceMonitor.swift`, `AppDelegate.swift` |
| 메뉴바 아이콘에 현재 사용률 숫자 표시 | 중 | `StatusBarController.swift` |
| 다크/라이트 모드별 다른 GIF 사용 | 중 | `AppDelegate.swift`, `OverlayWindowController.swift` |
| WebP 지원 | 하 | `OnboardingWindowController.swift`, `AppDelegate.swift` |

## 빌드 & 배포
```bash
# 개발 빌드 (Xcode)
open GifCat.xcodeproj  # ⌘R

# 릴리즈 빌드 (CLI)
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project GifCat.xcodeproj \
  -scheme GifCat \
  -configuration Release \
  -derivedDataPath /tmp/gifcat-build \
  build

# /Applications에 설치
cp -R /tmp/gifcat-build/Build/Products/Release/GifCat.app /Applications/
```
