import AppKit
import IOKit.ps
import CoreWLAN
import ApplicationServices

struct Battery: Equatable {
    let percent: Int
    let charging: Bool
    let onExternalPower: Bool

    var showsBolt: Bool { onExternalPower || charging }
    var powerLabel: String { charging ? "正在充电" : (onExternalPower ? "已接电源，未充电" : "使用电池") }

    static func percent(current: Double, maximum: Double) -> Int? {
        guard current.isFinite, maximum.isFinite, current >= 0, maximum > 0 else { return nil }
        return Int((min(current / maximum, 1) * 100).rounded())
    }

    static func parse(_ d: [String: Any]) -> Battery? {
        guard d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
              let current = d[kIOPSCurrentCapacityKey] as? NSNumber,
              let maximum = d[kIOPSMaxCapacityKey] as? NSNumber,
              let percent = percent(current: current.doubleValue, maximum: maximum.doubleValue) else { return nil }
        return Battery(percent: percent,
                       charging: d[kIOPSIsChargingKey] as? Bool ?? false,
                       onExternalPower: d[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue)
    }
    static func read() -> Battery? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            if let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
               let battery = parse(d) { return battery }
        }
        return nil
    }
}

final class RingView: NSView {
    var battery = Battery(percent: 80, charging: false, onExternalPower: false) { didSet { needsDisplay = true } }
    var ink: NSColor = .white { didSet { needsDisplay = true } }
    var symbol = "wifi"
    var strength: Double = 1
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY + 0.6)
        let radius = min(bounds.width / 2 - 1.6, bounds.height / 2 - 2)
        let stroke: CGFloat = 1.8
        let arcs: [(Double, Double)] = [(135, 220), (320, 405)]
        func segment(_ start: Double, _ end: Double, color: NSColor) {
            guard end > start else { return }
            cg.setStrokeColor(color.cgColor)
            cg.setLineWidth(stroke)
            cg.setLineCap(.round)
            cg.addArc(center: center, radius: radius, startAngle: start * .pi / 180, endAngle: end * .pi / 180, clockwise: false)
            cg.strokePath()
        }
        let active = ink
        var remaining = Double(battery.percent) / 100 * 170
        for (start, end) in arcs {
            segment(start, end, color: ink.withAlphaComponent(0.28))
            segment(start, min(end, start + remaining), color: active)
            remaining = max(0, remaining - (end - start))
        }
        let text = "\(battery.percent)" as NSString
        let font = NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: active]
        let size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: 0.3), withAttributes: attrs)
        if battery.showsBolt, let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil) {
            let configuration = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold).applying(.init(paletteColors: [ink]))
            (bolt.withSymbolConfiguration(configuration) ?? bolt).draw(in: CGRect(x: center.x - 3, y: bounds.height - 8, width: 6, height: 7), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        if let wifi = NSImage(systemSymbolName: symbol, variableValue: strength, accessibilityDescription: nil) {
            let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold).applying(.init(paletteColors: [ink]))
            let image = wifi.withSymbolConfiguration(configuration) ?? wifi
            let ratio = image.size.width / image.size.height
            let h = 12.0
            image.draw(in: CGRect(x: center.x - h * ratio / 2, y: center.y - h / 2, width: h * ratio, height: h), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
    }
}

struct WiFi {
    let symbol: String
    let strength: Double
    let label: String

    static func signal(_ rssi: Int) -> Double {
        if rssi >= -60 { return 1 }
        if rssi >= -75 { return 0.66 }
        return 0.33
    }
    static func read() -> WiFi {
        guard let interface = CWWiFiClient.shared().interface() else {
            return WiFi(symbol: "wifi.exclamationmark", strength: 1, label: "Wi‑Fi 状态不可用")
        }
        guard interface.powerOn() else { return WiFi(symbol: "wifi.slash", strength: 1, label: "Wi‑Fi 已关闭") }
        guard interface.interfaceMode() != .none else {
            return WiFi(symbol: "wifi.exclamationmark", strength: 1, label: "Wi‑Fi 未连接")
        }
        let rssi = interface.rssiValue()
        return WiFi(symbol: "wifi", strength: rssi < 0 ? signal(rssi) : 1, label: rssi < 0 ? "Wi‑Fi 已连接 · \(rssi) dBm" : "Wi‑Fi 已连接")
    }
}

func icon(battery: Battery, wifi: WiFi) -> NSImage {
    let view = RingView(frame: NSRect(x: 0, y: 0, width: 32, height: 30))
    view.ink = .black
    view.battery = battery
    view.symbol = wifi.symbol
    view.strength = wifi.strength
    let image = NSImage(size: view.bounds.size, flipped: true) { rect in
        view.draw(rect)
        return true
    }
    image.isTemplate = true
    return image
}

enum NativeWiFiMenu {
    static func detailsAction(in names: [String]) -> String? {
        names.first { $0.lowercased().contains("showdetails") }
    }
    static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }
    static func find(in element: AXUIElement, identifier: String, depth: Int = 0) -> AXUIElement? {
        guard depth <= 5 else { return nil }
        AXUIElementSetMessagingTimeout(element, 0.25)
        if let id = value(element, kAXIdentifierAttribute) as? String, id.lowercased() == identifier.lowercased() { return element }
        for child in value(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
            if let result = find(in: child, identifier: identifier, depth: depth + 1) { return result }
        }
        return nil
    }
    static func controlCenterButton() -> AXUIElement? {
        for bundle in ["com.apple.MenuBarAgent", "com.apple.controlcenter"] {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundle) {
                let root = AXUIElementCreateApplication(app.processIdentifier)
                AXUIElementSetMessagingTimeout(root, 0.25)
                var bars: [AXUIElement] = []
                for attribute in [kAXExtrasMenuBarAttribute, kAXMenuBarAttribute] {
                    if let bar = value(root, attribute), CFGetTypeID(bar) == AXUIElementGetTypeID() { bars.append(bar as! AXUIElement) }
                }
                if bars.isEmpty { bars = [root] }
                for bar in bars {
                    if let item = find(in: bar, identifier: "com.apple.menuextra.controlcenter") { return item }
                }
            }
        }
        return nil
    }
    static func perform(_ action: String, on element: AXUIElement) -> String? {
        AXUIElementSetMessagingTimeout(element, 2)
        let result = AXUIElementPerformAction(element, action as CFString)
        return result == .success || result == .cannotComplete ? nil : "系统界面未响应（\(result.rawValue)），请重试。"
    }
    static func showWiFiDetails(_ element: AXUIElement) -> String? {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return "无法读取系统 Wi‑Fi 详情入口。" }
        let actions = names as? [String] ?? []
        var action = detailsAction(in: actions)
        if action == nil {
            action = actions.first { name in
                var label: CFString?
                return AXUIElementCopyActionDescription(element, name as CFString, &label) == .success && ["显示详细信息", "Show Details"].contains(label as String? ?? "")
            }
        }
        // 只使用“显示详细信息”，不按 Wi-Fi 开关的 AXPress，避免改变网络状态。
        guard let action else { return "当前系统未提供 Wi‑Fi 详情动作（\(actions.joined(separator: ", "))）。" }
        return perform(action, on: element)
    }
    static func open() -> String? {
        guard AXIsProcessTrusted() else { return "需要在“设备控制和数据访问”中允许 DuoStatus。" }
        guard let button = controlCenterButton() else { return "未找到系统控制中心，请保持控制中心入口可用。" }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first else { return "系统控制中心暂不可用。" }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.25)
        func windows() -> [AXUIElement] { value(root, kAXWindowsAttribute) as? [AXUIElement] ?? [] }
        func module() -> AXUIElement? { windows().lazy.compactMap { find(in: $0, identifier: "controlcenter-wifi") }.first }
        if let wifi = module() { return showWiFiDetails(wifi) }
        if windows().contains(where: { find(in: $0, identifier: "wifi-header") != nil }) { return perform(kAXPressAction, on: button) }
        for _ in 0..<2 {
            if let error = perform(kAXPressAction, on: button) { return error }
            let deadline = Date().addingTimeInterval(1.2)
            repeat {
                if let wifi = module() { return showWiFiDetails(wifi) }
                Thread.sleep(forTimeInterval: 0.03)
            } while Date() < deadline
        }
        return "未找到控制中心中的 Wi‑Fi 模块，请先将 Wi‑Fi 控件加入控制中心。"
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var item: NSStatusItem!
    var window: NSWindow!
    var status: NSTextField!
    var preview: RingView!
    var timer: Timer?
    var reading = false
    var openingNative = false
    var managementMenu = NSMenu()
    var managementMenuOpen = false
    var battery: Battery?
    var wifi = WiFi(symbol: "wifi.exclamationmark", strength: 1, label: "读取中")

    func applicationDidFinishLaunching(_ notification: Notification) {
        makeWindow()
        item = NSStatusBar.system.statusItem(withLength: 34)
        item.autosaveName = "DuoStatusCombined"
        item.isVisible = true
        item.button?.imageScaling = .scaleNone
        item.button?.target = self
        item.button?.action = #selector(clicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateUI()
        refresh()
        timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer!, forMode: .common)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didWakeNotification, object: nil)
        showWindow()
    }
    func makeWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 390), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "DuoStatus"
        window.isReleasedWhenClosed = false
        window.center()
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 390))
        window.contentView = content
        func label(_ text: String, y: CGFloat, height: CGFloat, size: CGFloat = 13, bold: Bool = false) -> NSTextField {
            let field = NSTextField(wrappingLabelWithString: text)
            field.frame = NSRect(x: 28, y: y, width: 404, height: height)
            field.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
            content.addSubview(field)
            return field
        }
        _ = label("电量与 Wi‑Fi，合在一起", y: 340, height: 28, size: 23, bold: true)
        let tile = NSView(frame: NSRect(x: 28, y: 256, width: 404, height: 64))
        tile.wantsLayer = true
        tile.layer?.backgroundColor = NSColor(calibratedRed: 0.20, green: 0.25, blue: 0.33, alpha: 1).cgColor
        tile.layer?.cornerRadius = 12
        content.addSubview(tile)
        preview = RingView(frame: NSRect(x: 186, y: 17, width: 32, height: 30))
        tile.addSubview(preview)
        status = label("正在读取状态…", y: 207, height: 38)
        _ = label("左键：系统 Wi‑Fi 面板 · ⌥ 左键：系统详细信息\n右键：电量、设置和退出菜单。", y: 150, height: 46)
        _ = label("可关闭原生 Wi‑Fi 和电池菜单栏图标，仅保留本组合图标。通过控制中心打开系统 Wi‑Fi 面板，需要授权 DuoStatus 操作系统界面。", y: 66, height: 50, size: 11)
        let native = NSButton(title: "打开原生 Wi‑Fi 面板", target: self, action: #selector(openNativeWiFi))
        native.bezelStyle = .rounded
        native.frame = NSRect(x: 26, y: 114, width: 198, height: 30)
        content.addSubview(native)
        let permission = NSButton(title: "授权设置…", target: self, action: #selector(accessibilitySettings))
        permission.bezelStyle = .rounded
        permission.frame = NSRect(x: 230, y: 114, width: 125, height: 30)
        content.addSubview(permission)
        let quit = NSButton(title: "退出", target: self, action: #selector(quit))
        quit.bezelStyle = .rounded
        quit.frame = NSRect(x: 360, y: 8, width: 72, height: 30)
        content.addSubview(quit)
    }
    @objc func refresh() {
        guard !reading else { return }
        reading = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let battery = Battery.read()
            let wifi = WiFi.read()
            DispatchQueue.main.async {
                guard let self else { return }
                self.battery = battery
                self.wifi = wifi
                self.reading = false
                self.updateUI()
            }
        }
    }
    func updateUI() {
        let value = battery ?? Battery(percent: 0, charging: false, onExternalPower: false)
        item.button?.image = icon(battery: value, wifi: wifi)
        item.button?.toolTip = battery.map { "电量 \($0.percent) · \($0.powerLabel) · \(wifi.label)" } ?? "电量暂不可用 · \(wifi.label)"
        item.button?.setAccessibilityLabel(item.button?.toolTip)
        preview.battery = value
        preview.symbol = wifi.symbol
        preview.strength = wifi.strength
        preview.needsDisplay = true
        let batteryText = battery.map { "电量 \($0.percent) · \($0.powerLabel)" } ?? "电量暂不可用"
        status.stringValue = "\(batteryText)\n\(wifi.label)"
        guard !managementMenuOpen else { return }
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        for title in [batteryText, wifi.label] {
            let row = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            row.isEnabled = false
            menu.addItem(row)
        }
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Wi‑Fi 设置…", action: #selector(wifiSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        let show = NSMenuItem(title: "显示 DuoStatus 窗口", action: #selector(showWindow), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 DuoStatus", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        managementMenu = menu
    }
    @objc func clicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            NSApp.activate(ignoringOtherApps: true)
            item.menu = managementMenu
            sender.performClick(nil)
        } else {
            openNativeWiFi()
        }
    }
    func menuWillOpen(_ menu: NSMenu) { managementMenuOpen = true }
    func menuDidClose(_ menu: NSMenu) {
        managementMenuOpen = false
        item.menu = nil
    }
    @objc func openNativeWiFi() {
        guard !openingNative else { return }
        guard AXIsProcessTrusted() else {
            status.stringValue = "需要授权：请点击“授权设置”，允许 DuoStatus 打开系统 Wi‑Fi 面板。"
            showWindow()
            return
        }
        openingNative = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let error = NativeWiFiMenu.open()
            DispatchQueue.main.async {
                guard let self else { return }
                self.openingNative = false
                if let error { self.status.stringValue = error; self.showWindow() }
            }
        }
    }
    @objc func accessibilitySettings() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
    }
    @objc func wifiSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.wifi-settings-extension") { NSWorkspace.shared.open(url) }
    }
    @objc func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate(); NSStatusBar.system.removeStatusItem(item) }
}

func selfTest() {
    precondition(Battery.percent(current: 68, maximum: 100) == 68)
    precondition(Battery.percent(current: 4000, maximum: 5000) == 80)
    precondition(Battery.percent(current: 102, maximum: 100) == 100)
    precondition(Battery.percent(current: 0, maximum: 100) == 0)
    precondition(Battery.percent(current: 2, maximum: 0) == nil)
    precondition(Battery.percent(current: -1, maximum: 100) == nil)
    precondition(Battery.percent(current: .infinity, maximum: 100) == nil)
    var source: [String: Any] = [kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSCurrentCapacityKey: 80, kIOPSMaxCapacityKey: 100, kIOPSIsChargingKey: false, kIOPSPowerSourceStateKey: kIOPSACPowerValue]
    let paused = Battery.parse(source)!
    precondition(paused.percent == 80 && !paused.charging && paused.showsBolt)
    precondition(paused.powerLabel == "已接电源，未充电")
    source[kIOPSPowerSourceStateKey] = kIOPSBatteryPowerValue
    let unplugged = Battery.parse(source)!
    precondition(!unplugged.showsBolt)
    source[kIOPSPowerSourceStateKey] = kIOPSACPowerValue
    source[kIOPSIsChargingKey] = true
    precondition(Battery.parse(source)!.charging && Battery.parse(source)!.showsBolt)
    source[kIOPSMaxCapacityKey] = 0
    precondition(Battery.parse(source) == nil)
    let wifi = WiFi(symbol: "wifi", strength: 1, label: "")
    precondition(icon(battery: paused, wifi: wifi).tiffRepresentation != icon(battery: unplugged, wifi: wifi).tiffRepresentation)
    precondition(NativeWiFiMenu.detailsAction(in: ["AXPress", "AXShowDetails"]) == "AXShowDetails")
    precondition(NativeWiFiMenu.detailsAction(in: ["AXPress"]) == nil)
    precondition(WiFi.signal(-40) == 1 && WiFi.signal(-70) == 0.66 && WiFi.signal(-85) == 0.33)
    let image = icon(battery: Battery(percent: 100, charging: false, onExternalPower: false), wifi: WiFi(symbol: "wifi", strength: 1, label: ""))
    precondition(image.isTemplate && image.size == NSSize(width: 32, height: 30))
    precondition(image.tiffRepresentation != nil)
    print("PASS: battery values, Wi-Fi signal levels and menu-bar template image rendering, Control Center detail action (never Wi-Fi toggle), paused-charge bolt rendering")
}

func renderPreview(_ path: String) throws {
    let canvas = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 220))
    canvas.wantsLayer = true
    canvas.layer?.backgroundColor = NSColor(calibratedRed: 0.18, green: 0.23, blue: 0.31, alpha: 1).cgColor
    let fixtures = [Battery(percent: 80, charging: false, onExternalPower: false), Battery(percent: 80, charging: false, onExternalPower: true), Battery(percent: 80, charging: true, onExternalPower: true)]
    for (i, battery) in fixtures.enumerated() {
        let ring = RingView(frame: NSRect(x: 100 + CGFloat(i) * 220, y: 96, width: 32, height: 33))
        ring.battery = battery
        canvas.addSubview(ring)
        let caption = NSTextField(labelWithString: ["80 · 使用电池", "80 · 接电，暂停充电", "80 · 正在充电"][i])
        caption.textColor = .white
        caption.font = .systemFont(ofSize: 13)
        caption.frame = NSRect(x: 62 + CGFloat(i) * 220, y: 58, width: 140, height: 20)
        canvas.addSubview(caption)
    }
    let note = NSTextField(labelWithString: "数字电量 · 接电时显示闪电（含充电上限暂停状态）")
    note.font = .systemFont(ofSize: 12)
    note.textColor = NSColor.white.withAlphaComponent(0.7)
    note.frame = NSRect(x: 62, y: 160, width: 620, height: 20)
    canvas.addSubview(note)
    guard let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) else { throw NSError(domain: "DuoStatus", code: 1) }
    canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "DuoStatus", code: 2) }
    try png.write(to: URL(fileURLWithPath: path))
}

let app = NSApplication.shared
if CommandLine.arguments.contains("--self-test") {
    selfTest()
} else if let index = CommandLine.arguments.firstIndex(of: "--render-preview"), CommandLine.arguments.count > index + 1 {
    try renderPreview(CommandLine.arguments[index + 1])
} else {
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
