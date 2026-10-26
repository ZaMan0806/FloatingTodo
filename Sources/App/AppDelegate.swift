// 앱 시작, 버튼·패널 창 관리, 메뉴

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store = TodoStore()
    let bubbleState = BubbleState()
    let settings = AppSettings()
    let updater = Updater()
    let updateItem = NSMenuItem(title: "업데이트 확인…", action: nil, keyEquivalent: "")
    var bubble: FloatingPanel!
    var popup: FloatingPanel!
    private var termSource: DispatchSourceSignal?

    let bubbleSize: CGFloat = 60
    var popupSize = NSSize(width: 300, height: 440)
    let minPopupSize = NSSize(width: 240, height: 200)
    let sizeKey = "popupSize"
    let grip = ResizeGripView(frame: NSRect(x: 0, y: 0, width: ResizeGripView.size, height: ResizeGripView.size))
    let gap: CGFloat = 6
    let originKey = "bubbleOrigin"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 색 고르기 창이 다른 앱을 쓰는 중에도 숨지 않고 위에 뜨도록
        NSColorPanel.shared.hidesOnDeactivate = false
        NSColorPanel.shared.level = .floating

        // 종료 신호(재시작/종료/stop.command)를 받으면 저장하고 끝내기
        signal(SIGTERM, SIG_IGN)
        let src = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        src.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.store.save() }
            exit(0)
        }
        src.resume()
        termSource = src
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.store.save() }
        }
        // 버튼
        bubble = FloatingPanel(rect: NSRect(origin: initialOrigin(),
                                            size: NSSize(width: bubbleSize, height: bubbleSize)))
        let view = BubbleView(frame: NSRect(x: 0, y: 0, width: bubbleSize, height: bubbleSize),
                              state: bubbleState, settings: settings, updater: updater)
        view.onClick = { [weak self] in self?.togglePopup() }
        view.onMove = { [weak self] in self?.positionPopup() }
        view.onDragEnd = { [weak self] in
            guard let self else { return }
            UserDefaults.standard.set(NSStringFromPoint(self.bubble.frame.origin), forKey: self.originKey)
        }
        let menu = NSMenu()
        let reload = NSMenuItem(title: "todos.json 다시 읽기", action: #selector(reloadTodos), keyEquivalent: "")
        reload.target = self
        menu.addItem(reload)
        let openFile = NSMenuItem(title: "todos.json 열기", action: #selector(openTodoFile), keyEquivalent: "")
        openFile.target = self
        menu.addItem(openFile)
        menu.addItem(.separator())
        updateItem.target = self
        menu.addItem(updateItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        menu.addItem(quit)
        menu.autoenablesItems = false
        menu.delegate = self   // 열 때마다 업데이트 항목을 상태에 맞게 바꾸기
        view.menu = menu
        bubble.allowsKey = false
        bubble.contentView = view
        bubble.orderFrontRegardless()

        // 할 일 패널
        if let s = UserDefaults.standard.string(forKey: sizeKey) {
            let saved = NSSizeFromString(s)
            if saved.width >= minPopupSize.width && saved.height >= minPopupSize.height { popupSize = saved }
        }
        popup = FloatingPanel(rect: NSRect(origin: .zero, size: popupSize))
        let container = NSView(frame: NSRect(origin: .zero, size: popupSize))
        let host = FirstMouseHostingView(rootView: TodoPanelView(store: store, settings: settings, updater: updater))
        if #available(macOS 13.0, *) { host.sizingOptions = [] }   // SwiftUI 가 창 크기를 고정하지 않도록
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        grip.onResize = { [weak self] size in self?.resizePopup(to: size) }
        grip.onResizeEnd = { [weak self] in
            guard let self else { return }
            UserDefaults.standard.set(NSStringFromSize(self.popupSize), forKey: self.sizeKey)
        }
        container.addSubview(grip)
        popup.contentView = container

        updater.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.save()
    }

    private func initialOrigin() -> NSPoint {
        if let s = UserDefaults.standard.string(forKey: originKey) {
            let p = NSPointFromString(s)
            if NSScreen.screens.contains(where: { $0.visibleFrame.insetBy(dx: -10, dy: -10).contains(p) }) {
                return p
            }
        }
        let f = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return NSPoint(x: f.minX + 24, y: f.midY)
    }

    func togglePopup() {
        if popup.isVisible {
            popup.makeFirstResponder(nil)   // 입력 중이던 글자(한글 조합 포함)를 확정한 뒤 저장
            store.save()
            popup.orderOut(nil)
            bubbleState.open = false
        } else {
            positionPopup()
            popup.orderFrontRegardless()
            bubbleState.open = true
            updater.checkIfStale()
        }
    }

    private var currentScreen: NSRect {
        (bubble.screen ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
    }

    func resizePopup(to size: NSSize) {
        let screen = currentScreen
        popupSize = NSSize(width: min(max(size.width, minPopupSize.width), screen.width - bubbleSize - gap),
                           height: min(max(size.height, minPopupSize.height), screen.height))
        positionPopup()
    }

    // 버튼 오른쪽에 붙이고, 오른쪽 공간이 없으면 왼쪽에 표시
    func positionPopup() {
        guard let popup else { return }
        let b = bubble.frame
        let screen = currentScreen
        var x = b.maxX + gap
        let onLeft = x + popupSize.width > screen.maxX
        if onLeft { x = b.minX - gap - popupSize.width }
        var y = b.maxY - popupSize.height
        y = min(max(y, screen.minY), screen.maxY - popupSize.height)
        popup.setFrame(NSRect(x: x, y: y, width: popupSize.width, height: popupSize.height), display: true)

        // 손잡이는 패널의 바깥쪽 아래 모서리에
        grip.isLeft = onLeft
        let g = ResizeGripView.size
        grip.frame = NSRect(x: onLeft ? 4 : popupSize.width - g - 4, y: 4, width: g, height: g)
    }

    @objc func reloadTodos() { store.load() }

    @objc func openTodoFile() {
        store.save()
        NSWorkspace.shared.open(store.fileURL)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateItem.isEnabled = true
        switch updater.status {
        case .available:
            updateItem.title = "업데이트 설치"
            updateItem.action = #selector(installUpdate)
        case .updating:
            updateItem.title = "업데이트 중…"
            updateItem.isEnabled = false
        case .idle, .failed:
            updateItem.title = "업데이트 확인…"
            updateItem.action = #selector(checkForUpdates)
        }
    }

    @objc func installUpdate() { updater.install() }

    @objc func checkForUpdates() {
        Task {
            let result = await updater.check()
            let alert = NSAlert()
            switch result {
            case .upToDate:
                alert.messageText = "최신 버전이에요."
            case .available:
                alert.messageText = "새 버전이 있어요."
                alert.informativeText = "업데이트하면 잠깐 꺼졌다가 다시 켜져요. 할 일은 그대로 남아 있어요."
                alert.addButton(withTitle: "업데이트")
                alert.addButton(withTitle: "나중에")
            case .unknownVersion:
                alert.messageText = "설치된 버전을 알 수 없어요."
                alert.informativeText = "설치 명령어(curl …)로 설치한 경우에만 업데이트를 확인할 수 있어요."
            case .failed:
                alert.messageText = "업데이트를 확인하지 못했어요."
                alert.informativeText = "인터넷 연결을 확인하고 잠시 뒤 다시 시도해 주세요."
            }
            if alert.buttons.isEmpty { alert.addButton(withTitle: "확인") }
            NSApp.activate(ignoringOtherApps: true)   // Dock 없는 앱이라 앞으로 가져와야 창이 보임
            if alert.runModal() == .alertFirstButtonReturn && result == .available {
                updater.install()
            }
        }
    }
}
