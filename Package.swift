// swift-tools-version:5.9
// Xcode 에서 열거나 `swift build` 로 확인할 때 사용 (설치는 install.sh 가 swiftc 로 직접 빌드)
import PackageDescription

let package = Package(
    name: "FloatingTodo",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "FloatingTodo", path: "Sources"),
    ]
)
