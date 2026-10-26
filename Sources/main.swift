// FloatingTodo — 화면 위에 떠 있는 버튼 + 할 일 패널
// 빌드: install.sh (Sources 아래 .swift 파일을 swiftc 로 한 번에 컴파일)

import AppKit

// 최상위 코드는 메인 스레드에서 돌지만 컴파일러가 모르므로 명시해 줌
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)   // Dock 아이콘 없이 실행
    app.run()                             // 여기서 계속 실행되므로 delegate 도 유지됨
}
