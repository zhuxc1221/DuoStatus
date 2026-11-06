import AppKit
import IOKit.ps
import CoreWLAN
import ApplicationServices
import Carbon
import OSLog
import ServiceManagement

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

struct InputSource: Equatable {
    let label: String
    let name: String

    static func label(id: String, mode: String, language: String, ascii: Bool, name: String) -> String {
        if mode.lowercased().contains("roman") || id.contains("keylayout.ABC") { return "A" }
        if id.lowercased().contains("pinyin") || id.contains("ITABC") || mode.lowercased().contains("pinyin") { return "拼" }
        if language.hasPrefix("zh") { return "中" }
        if ascii { return "A" }
        return String(name.prefix(1))
    }
    static func read() -> InputSource {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return InputSource(label: "?", name: "输入法暂不可用") }
        func property(_ key: CFString) -> AnyObject? {
            guard let value = TISGetInputSourceProperty(source, key) else { return nil }
            return Unmanaged<AnyObject>.fromOpaque(value).takeUnretainedValue()
        }
        let id = property(kTISPropertyInputSourceID) as? String ?? ""
        let mode = property(kTISPropertyInputModeID) as? String ?? ""
        let language = (property(kTISPropertyInputSourceLanguages) as? [String])?.first ?? ""
        let name = property(kTISPropertyLocalizedName) as? String ?? "?"
        let ascii = property(kTISPropertyInputSourceIsASCIICapable) as? Bool ?? false
        return InputSource(label: label(id: id, mode: mode, language: language, ascii: ascii, name: name), name: name)
    }
}

struct HeaderLayout {
    static let font = NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .bold)
    let number: NSRect
    let bolt: NSRect?
    var bounds: NSRect { bolt.map { number.union($0) } ?? number }
    init(percent: Int, showsBolt: Bool, width: CGFloat) {
        let size = ("\(percent)" as NSString).size(withAttributes: [.font: Self.font])
        let groupWidth = size.width + (showsBolt ? 5.5 : 0)
        let x = (width - groupWidth) / 2
        number = NSRect(x: x, y: 0, width: size.width, height: size.height)
        bolt = showsBolt ? NSRect(x: x + size.width + 1, y: 1.2, width: 4.5, height: 7) : nil
    }
}

final class RingView: NSView {
    var battery = Battery(percent: 80, charging: false, onExternalPower: false) { didSet { needsDisplay = true } }
    var inputLabel = "拼" { didSet { needsDisplay = true } }
    var ink: NSColor = .white { didSet { needsDisplay = true } }
    var symbol = "wifi"
    var strength: Double = 1
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        let center = CGPoint(x: bounds.midX, y: 14.3)
        let radius: CGFloat = 13.2
        let header = HeaderLayout(percent: battery.percent, showsBolt: battery.showsBolt, width: bounds.width)
        cg.saveGState()
        cg.addRect(bounds)
        cg.addRect(header.bounds.insetBy(dx: -1, dy: -0.5))
        cg.clip(using: .evenOdd)
        func segment(_ end: Double, color: NSColor) {
            guard end > 135 else { return }
            cg.setStrokeColor(color.cgColor)
            cg.setLineWidth(1.7)
            cg.setLineCap(.round)
            cg.addArc(center: center, radius: radius, startAngle: 135 * .pi / 180, endAngle: end * .pi / 180, clockwise: false)
            cg.strokePath()
        }
        segment(405, color: ink.withAlphaComponent(0.28))
        segment(135 + Double(battery.percent) / 100 * 270, color: ink)
        cg.restoreGState()
        ("\(battery.percent)" as NSString).draw(at: header.number.origin, withAttributes: [.font: HeaderLayout.font, .foregroundColor: ink])
        if let rect = header.bolt, let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil) {
            let configuration = NSImage.SymbolConfiguration(pointSize: 8, weight: .bold).applying(.init(paletteColors: [ink]))
            (bolt.withSymbolConfiguration(configuration) ?? bolt).draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        let input = inputLabel as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 8, weight: .semibold), .foregroundColor: ink]
        let size = input.size(withAttributes: attributes)
        input.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: 19.5), withAttributes: attributes)
        if let wifi = NSImage(systemSymbolName: symbol, variableValue: strength, accessibilityDescription: nil) {
            let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold).applying(.init(paletteColors: [ink]))
            let image = wifi.withSymbolConfiguration(configuration) ?? wifi
            let h = 10.5
            let w = h * image.size.width / image.size.height
            image.draw(in: CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
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

func icon(battery: Battery, wifi: WiFi, inputLabel: String = "拼") -> NSImage {
    let view = RingView(frame: NSRect(x: 0, y: 0, width: 32, height: 30))
    view.ink = .black
    view.battery = battery
    view.inputLabel = inputLabel
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
    enum PanelState: String { case closed, overview, wifi, other }
    enum PanelAction: Equatable { case open, expand, wait, done, dismissed, unavailable, missingModule, expansionFailed }
    struct Transition {
        var opened = false
        var expanded = false
        var sawWindow = false
        mutating func next(_ state: PanelState, expired: Bool) -> PanelAction {
            if state == .wifi { return .done }
            if state == .closed && sawWindow { return .dismissed }
            if expired {
                if !sawWindow { return .unavailable }
                return expanded ? .expansionFailed : .missingModule
            }
            if state != .closed { sawWindow = true }
            if state == .overview && !expanded { expanded = true; return .expand }
            if state == .closed && !opened { opened = true; return .open }
            return .wait
        }
    }
    static func open() -> String? {
        guard AXIsProcessTrusted() else { return "需要在“设备控制和数据访问”中允许 DuoStatus。" }
        guard let button = controlCenterButton() else { return "未找到系统控制中心，请保持控制中心入口可用。" }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first else { return "系统控制中心暂不可用。" }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.25)
        func snapshot() -> (PanelState, AXUIElement?) {
            let windows = value(root, kAXWindowsAttribute) as? [AXUIElement] ?? []
            for window in windows {
                if find(in: window, identifier: "wifi-header") != nil { return (.wifi, nil) }
                if let module = find(in: window, identifier: "controlcenter-wifi") { return (.overview, module) }
            }
            return (windows.isEmpty ? .closed : .other, nil)
        }
        // An outside click dismisses the old panel before its mouse-up action arrives.
        Thread.sleep(forTimeInterval: 0.12)
        let deadline = ProcessInfo.processInfo.systemUptime + 2
        var transition = Transition()
        let log = Logger(subsystem: "io.github.zhuxc1221.DuoStatus", category: "NativeWiFi")
        while true {
            let (state, module) = snapshot()
            let action = transition.next(state, expired: ProcessInfo.processInfo.systemUptime >= deadline)
            log.debug("panel state: \(state.rawValue, privacy: .public), action: \(String(describing: action), privacy: .public)")
            switch action {
            case .done, .dismissed: return nil
            case .unavailable: return "系统面板未能打开，请再点一次。"
            case .missingModule: return "当前控制中心未显示 Wi‑Fi 控件，请检查控制中心布局后重试。"
            case .expansionFailed: return "Wi‑Fi 面板未能展开，请再点一次。"
            case .open:
                if let error = perform(kAXPressAction, on: button) { return error }
            case .expand:
                if let module, let error = showWiFiDetails(module) {
                    if snapshot().0 == .closed { return nil }
                    return error
                }
            case .wait: break
            }
            Thread.sleep(forTimeInterval: 0.03)
        }
    }
}

enum WindowInk {
    static let muted = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(calibratedWhite: 0.71, alpha: 1) : NSColor(calibratedWhite: 0.41, alpha: 1)
    }
    static let warning = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(calibratedRed: 0.92, green: 0.74, blue: 0.45, alpha: 1) : NSColor(calibratedRed: 0.55, green: 0.35, blue: 0, alpha: 1)
    }
    static let error = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(calibratedRed: 1, green: 0.56, blue: 0.56, alpha: 1) : NSColor(calibratedRed: 0.70, green: 0.14, blue: 0.09, alpha: 1)
    }
}

final class SettingsSurface: NSView {
    let panel: Bool
    init(frame: NSRect, panel: Bool = false) { self.panel = panel; super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        (panel ? NSColor.controlBackgroundColor : NSColor.windowBackgroundColor).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: panel ? 8 : 0, yRadius: panel ? 8 : 0).fill()
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
}

final class PrimaryButton: NSButton {
    override func draw(_ dirtyRect: NSRect) {
        (isHighlighted ? NSColor.secondaryLabelColor : NSColor.labelColor).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.windowBackgroundColor]
        let size = (title as NSString).size(withAttributes: attrs)
        (title as NSString).draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attrs)
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var item: NSStatusItem!
    var window: NSWindow!
    var status: NSTextField!
    var batteryValue: NSTextField!
    var batteryDetail: NSTextField!
    var wifiValue: NSTextField!
    var wifiDetail: NSTextField!
    var inputValue: NSTextField!
    var inputDetail: NSTextField!
    var permissionValue: NSTextField!
    var permissionButton: NSButton!
    var loginSwitch: NSSwitch!
    var loginDetail: NSTextField!
    var preview: RingView!
    var timer: Timer?
    var powerSource: CFRunLoopSource?
    var inputSource = InputSource(label: "?", name: "读取中")
    let timing = Logger(subsystem: "io.github.zhuxc1221.DuoStatus", category: "RefreshTiming")
    var reading = false
    var openingNative = false
    var repeatedNativeClick = false
    var nativeFinishedAt: TimeInterval = 0
    var nativeError: String?
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
        let context = Unmanaged.passUnretained(self).toOpaque()
        powerSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue().refreshPower()
        }, context)?.takeRetainedValue()
        if let powerSource { CFRunLoopAddSource(CFRunLoopGetMain(), powerSource, .commonModes) }
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(refreshInput), name: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil, suspensionBehavior: .deliverImmediately)
        refreshPower()
        refreshInput()
        refresh()
        timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer!, forMode: .common)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
        showWindow()
    }
    func makeWindow() {
        let size = NSSize(width: 420, height: 568)
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "DuoStatus"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        let content = SettingsSurface(frame: NSRect(origin: .zero, size: size))
        window.contentView = content
        func label(_ text: String, _ rect: NSRect, size: CGFloat = 13, weight: NSFont.Weight = .regular, secondary: Bool = false, align: NSTextAlignment = .left, in parent: NSView? = nil) -> NSTextField {
            let field = NSTextField(wrappingLabelWithString: text)
            field.frame = rect
            field.font = .systemFont(ofSize: size, weight: weight)
            field.textColor = secondary ? WindowInk.muted : .labelColor
            field.alignment = align
            (parent ?? content).addSubview(field)
            return field
        }
        func line(_ y: CGFloat, in parent: NSView, width: CGFloat) {
            let rule = NSBox(frame: NSRect(x: 16, y: y, width: width - 32, height: 1))
            rule.boxType = .separator
            parent.addSubview(rule)
        }
        let logo = NSImageView(frame: NSRect(x: 28, y: 29, width: 42, height: 42))
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") { logo.image = NSImage(contentsOf: url) }
        content.addSubview(logo)
        _ = label("DuoStatus", NSRect(x: 82, y: 27, width: 220, height: 27), size: 22, weight: .semibold)
        _ = label("电量 · Wi‑Fi · 输入法", NSRect(x: 83, y: 57, width: 220, height: 18), size: 12, secondary: true)
        preview = RingView(frame: NSRect(x: 350, y: 34, width: 32, height: 30))
        content.addSubview(preview)
        let panel = SettingsSurface(frame: NSRect(x: 28, y: 98, width: 364, height: 168), panel: true)
        content.addSubview(panel)
        let rows = [("电量", "读取电源状态…"), ("Wi‑Fi", "读取连接状态…"), ("输入法", "读取输入源…")]
        var values: [NSTextField] = [], details: [NSTextField] = []
        for (index, row) in rows.enumerated() {
            let top = CGFloat(index * 56)
            _ = label(row.0, NSRect(x: 16, y: top + 10, width: 100, height: 19), weight: .medium, in: panel)
            details.append(label(row.1, NSRect(x: 16, y: top + 31, width: 244, height: 18), size: 11, secondary: true, in: panel))
            values.append(label("—", NSRect(x: 254, y: top + 17, width: 94, height: 26), size: 20, weight: .medium, align: .right, in: panel))
            if index < 2 { line(top + 56, in: panel, width: 364) }
        }
        batteryValue = values[0]; wifiValue = values[1]; inputValue = values[2]
        batteryDetail = details[0]; wifiDetail = details[1]; inputDetail = details[2]
        _ = label("系统面板访问", NSRect(x: 28, y: 287, width: 120, height: 20), weight: .medium)
        permissionValue = label("检查中", NSRect(x: 168, y: 288, width: 126, height: 18), size: 12, secondary: true, align: .right)
        permissionButton = NSButton(title: "请求授权…", target: self, action: #selector(accessibilitySettings))
        permissionButton.isBordered = false
        permissionButton.font = .systemFont(ofSize: 12)
        permissionButton.frame = NSRect(x: 304, y: 281, width: 88, height: 28)
        content.addSubview(permissionButton)
        status = label("通过控制中心打开原生 Wi‑Fi 面板。", NSRect(x: 28, y: 315, width: 364, height: 36), size: 12, secondary: true)
        let native = PrimaryButton(title: "打开 Wi‑Fi 面板", target: self, action: #selector(openNativeWiFi))
        native.isBordered = false
        native.frame = NSRect(x: 27, y: 358, width: 366, height: 36)
        content.addSubview(native)
        for (index, row) in [("普通点击", "Wi‑Fi 面板"), ("⌥ + 点击", "连接详细信息"), ("右键点击", "设置与退出")].enumerated() {
            let y = CGFloat(410 + index * 22)
            _ = label(row.0, NSRect(x: 28, y: y, width: 140, height: 18), size: 12, secondary: true)
            _ = label(row.1, NSRect(x: 188, y: y, width: 204, height: 18), size: 12, align: .right)
        }
        _ = label("登录时启动", NSRect(x: 28, y: 495, width: 100, height: 20), weight: .medium)
        loginDetail = label("", NSRect(x: 130, y: 496, width: 210, height: 20), size: 11, secondary: true, align: .right)
        loginSwitch = NSSwitch(frame: NSRect(x: 352, y: 492, width: 40, height: 26))
        loginSwitch.setAccessibilityLabel("登录时启动")
        loginSwitch.target = self
        loginSwitch.action = #selector(toggleLaunchAtLogin(_:))
        content.addSubview(loginSwitch)
        updateLoginItem()
        let footerRule = NSBox(frame: NSRect(x: 28, y: 528, width: 364, height: 1))
        footerRule.boxType = .separator
        content.addSubview(footerRule)
        _ = label("关闭窗口后，仍在菜单栏运行", NSRect(x: 28, y: 542, width: 290, height: 17), size: 11, secondary: true)
        let quit = NSButton(title: "退出", target: self, action: #selector(quit))
        quit.isBordered = false
        quit.font = .systemFont(ofSize: 11)
        quit.frame = NSRect(x: 348, y: 536, width: 44, height: 28)
        content.addSubview(quit)
    }
    func updateWindow() {
        preview.ink = .labelColor
        preview.inputLabel = inputSource.label
        preview.battery = battery ?? Battery(percent: 0, charging: false, onExternalPower: false)
        preview.symbol = wifi.symbol
        preview.strength = wifi.strength
        preview.needsDisplay = true
        batteryValue.stringValue = battery.map { "\($0.percent)\($0.showsBolt ? " ⚡︎" : "")" } ?? "—"
        batteryValue.font = .monospacedDigitSystemFont(ofSize: 20, weight: .medium)
        batteryDetail.stringValue = battery?.powerLabel ?? "电量暂不可用"
        let parts = wifi.label.components(separatedBy: " · ")
        wifiValue.stringValue = parts.count > 1 ? parts[1] : (wifi.symbol == "wifi" ? "已连接" : "—")
        wifiValue.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        wifiDetail.stringValue = parts.first ?? wifi.label
        inputValue.stringValue = inputSource.label
        inputDetail.stringValue = inputSource.label == "拼" ? "简体拼音" : (inputSource.label == "A" ? "英文输入" : inputSource.name)
        let trusted = AXIsProcessTrusted()
        permissionButton.title = trusted ? "权限设置…" : "请求授权…"
        permissionValue.stringValue = trusted ? "已授权" : "需要授权"
        permissionValue.textColor = trusted ? WindowInk.muted : WindowInk.warning
        status.stringValue = nativeError ?? (trusted ? "可隐藏原生 Wi‑Fi、电池和文字输入图标。" : "点击「请求授权」，在 macOS 提示中选择。也可在「隐私与安全 → 设备控制和数据访问」中管理授权。")
        status.textColor = nativeError == nil ? WindowInk.muted : WindowInk.error
    }
    @objc func wake() { refreshPower(); refreshInput(); refresh() }
    @objc func refreshPower() {
        let start = ProcessInfo.processInfo.systemUptime
        battery = Battery.read()
        updateUI()
        let milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1000
        timing.debug("power notification → icon submission: \(milliseconds, format: .fixed(precision: 3)) ms")
    }
    @objc func refreshInput() {
        let start = ProcessInfo.processInfo.systemUptime
        inputSource = InputSource.read()
        updateUI()
        let milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1000
        timing.debug("input notification → icon submission: \(milliseconds, format: .fixed(precision: 3)) ms")
    }
    @objc func refresh() {
        guard !reading else { return }
        reading = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let wifi = WiFi.read()
            DispatchQueue.main.async {
                guard let self else { return }
                self.wifi = wifi
                self.reading = false
                self.updateUI()
            }
        }
    }
    func updateUI() {
        let value = battery ?? Battery(percent: 0, charging: false, onExternalPower: false)
        item.button?.image = icon(battery: value, wifi: wifi, inputLabel: inputSource.label)
        item.button?.toolTip = battery.map { "电量 \($0.percent) · \($0.powerLabel) · \(wifi.label)" } ?? "电量暂不可用 · \(wifi.label)"
        item.button?.toolTip = (item.button?.toolTip ?? "") + " · 输入法：\(inputSource.name)（\(inputSource.label)）"
        item.button?.setAccessibilityLabel(item.button?.toolTip)
        updateWindow()
        let batteryText = battery.map { "电量 \($0.percent) · \($0.powerLabel)" } ?? "电量暂不可用"
        guard !managementMenuOpen else { return }
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        for title in [batteryText, wifi.label, "输入法：\(inputSource.name)（\(inputSource.label)）"] {
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
            guard Self.acceptsNativeClick(eventTime: event.timestamp, finishedAt: nativeFinishedAt) else { return }
            openNativeWiFi()
        }
    }
    static func acceptsNativeClick(eventTime: TimeInterval, finishedAt: TimeInterval) -> Bool {
        finishedAt == 0 || eventTime > finishedAt + 0.25
    }
    func menuWillOpen(_ menu: NSMenu) { managementMenuOpen = true }
    func menuDidClose(_ menu: NSMenu) {
        managementMenuOpen = false
        item.menu = nil
    }
    @objc func openNativeWiFi() {
        guard !openingNative else { repeatedNativeClick = true; return }
        guard ProcessInfo.processInfo.systemUptime > nativeFinishedAt + 0.25 else { return }
        guard AXIsProcessTrusted() else {
            nativeError = nil
            updateUI()
            return
        }
        nativeError = nil
        repeatedNativeClick = false
        openingNative = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let error = NativeWiFiMenu.open()
            DispatchQueue.main.async {
                guard let self else { return }
                self.nativeFinishedAt = ProcessInfo.processInfo.systemUptime
                self.openingNative = false
                self.nativeError = self.repeatedNativeClick ? nil : error
                self.updateUI()
                if error != nil { self.timing.debug("native Wi-Fi request failed") }
            }
        }
    }
    @objc func accessibilitySettings() {
        guard AXIsProcessTrusted() else {
            _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
            return
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
    }
    func updateLoginItem() {
        let state = SMAppService.mainApp.status
        loginSwitch.state = state == .enabled || state == .requiresApproval ? .on : .off
        loginDetail.stringValue = state == .requiresApproval ? "请在系统登录项中允许" : ""
        loginDetail.toolTip = nil
    }
    @objc func toggleLaunchAtLogin(_ sender: NSSwitch) {
        let service = SMAppService.mainApp
        do {
            if sender.state == .on { try service.register() }
            else { try service.unregister() }
            updateLoginItem()
        } catch {
            updateLoginItem()
            loginDetail.stringValue = "更改失败，请检查系统登录项"
            loginDetail.toolTip = error.localizedDescription
        }
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        guard window != nil else { return }
        updateWindow()
        updateLoginItem()
    }
    @objc func wifiSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.wifi-settings-extension") { NSWorkspace.shared.open(url) }
    }
    @objc func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        if let powerSource { CFRunLoopSourceInvalidate(powerSource) }
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NSStatusBar.system.removeStatusItem(item)
    }
}

func selfTest() {
    func panelActions(_ states: [NativeWiFiMenu.PanelState]) -> [NativeWiFiMenu.PanelAction] {
        var transition = NativeWiFiMenu.Transition()
        return states.map { transition.next($0, expired: false) }
    }
    precondition(panelActions([.closed, .closed, .overview, .overview, .wifi]) == [.open, .wait, .expand, .wait, .done])
    precondition(panelActions([.overview, .closed]) == [.expand, .dismissed])
    precondition(panelActions([.closed, .overview, .closed]) == [.open, .expand, .dismissed])
    precondition(panelActions([.wifi]) == [.done])
    var missing = NativeWiFiMenu.Transition()
    precondition(missing.next(.other, expired: false) == .wait)
    precondition(missing.next(.other, expired: true) == .missingModule)
    var slow = NativeWiFiMenu.Transition()
    precondition(slow.next(.closed, expired: false) == .open)
    precondition(slow.next(.closed, expired: true) == .unavailable)
    precondition(!AppDelegate.acceptsNativeClick(eventTime: 9, finishedAt: 10))
    precondition(!AppDelegate.acceptsNativeClick(eventTime: 10.1, finishedAt: 10))
    precondition(AppDelegate.acceptsNativeClick(eventTime: 10.3, finishedAt: 10))
    precondition(AppDelegate.acceptsNativeClick(eventTime: 1, finishedAt: 0))
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
    for percent in [0, 8, 80, 100] {
        for bolt in [false, true] {
            let layout = HeaderLayout(percent: percent, showsBolt: bolt, width: 32)
            precondition(abs(layout.bounds.midX - 16) < 0.001)
            precondition(layout.bounds.minX >= 0 && layout.bounds.maxX <= 32)
        }
    }
    precondition(InputSource.label(id: "com.apple.inputmethod.SCIM.ITABC", mode: "", language: "zh-Hans", ascii: false, name: "拼音") == "拼")
    precondition(InputSource.label(id: "com.apple.keylayout.ABC", mode: "", language: "en", ascii: true, name: "ABC") == "A")
    precondition(InputSource.label(id: "com.apple.inputmethod.SCIM.ITABC", mode: "com.apple.inputmethod.SCIM.Roman", language: "zh-Hans", ascii: true, name: "拼音") == "A")
    precondition(icon(battery: paused, wifi: wifi, inputLabel: "拼").tiffRepresentation != icon(battery: paused, wifi: wifi, inputLabel: "A").tiffRepresentation)
    let screen = AppDelegate()
    screen.makeWindow()
    screen.updateWindow()
    precondition(screen.batteryValue.stringValue == "—")
    screen.battery = Battery(percent: 0, charging: false, onExternalPower: false)
    screen.nativeError = "测试错误提示"
    screen.updateWindow()
    precondition(screen.batteryValue.stringValue == "0" && screen.status.stringValue == "测试错误提示")
    let content = screen.window.contentView!
    for view in content.subviews {
        precondition(content.bounds.contains(view.frame), "Window content must not clip")
    }
    print("PASS: native panel open/dismiss/timeout transitions, centered charging/unplugged header, input source labels, window missing/zero/error states and bounds, battery values, Wi-Fi signal levels and menu-bar template image rendering, Control Center detail action (never Wi-Fi toggle), paused-charge bolt rendering")
}

func renderPreview(_ path: String) throws {
    let canvas = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 220))
    canvas.wantsLayer = true
    canvas.layer?.backgroundColor = NSColor(calibratedRed: 0.18, green: 0.23, blue: 0.31, alpha: 1).cgColor
    let fixtures = [Battery(percent: 80, charging: false, onExternalPower: false), Battery(percent: 80, charging: false, onExternalPower: true), Battery(percent: 80, charging: true, onExternalPower: true)]
    for (i, battery) in fixtures.enumerated() {
        let ring = RingView(frame: NSRect(x: 100 + CGFloat(i) * 220, y: 96, width: 32, height: 30))
        ring.battery = battery
        ring.inputLabel = i == 1 ? "A" : "拼"
        canvas.addSubview(ring)
        let caption = NSTextField(labelWithString: ["80 · 使用电池", "80 · 接电，暂停充电", "80 · 正在充电"][i])
        caption.textColor = .white
        caption.font = .systemFont(ofSize: 13)
        caption.frame = NSRect(x: 62 + CGFloat(i) * 220, y: 58, width: 140, height: 20)
        canvas.addSubview(caption)
    }
    let note = NSTextField(labelWithString: "数字叠加圆环 · 接电时显示闪电 · 底部显示当前输入法")
    note.font = .systemFont(ofSize: 12)
    note.textColor = NSColor.white.withAlphaComponent(0.7)
    note.frame = NSRect(x: 62, y: 160, width: 620, height: 20)
    canvas.addSubview(note)
    guard let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) else { throw NSError(domain: "DuoStatus", code: 1) }
    canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "DuoStatus", code: 2) }
    try png.write(to: URL(fileURLWithPath: path))
}

func renderWindowPreview(_ path: String, dark: Bool, error: Bool) throws {
    NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    let delegate = AppDelegate()
    delegate.makeWindow()
    delegate.battery = Battery(percent: 80, charging: false, onExternalPower: true)
    delegate.wifi = WiFi(symbol: "wifi", strength: 1, label: "Wi‑Fi 已连接 · -56 dBm")
    delegate.inputSource = InputSource(label: "拼", name: "简体拼音")
    if error { delegate.nativeError = "未找到控制中心中的 Wi‑Fi 模块，请在控制中心添加 Wi‑Fi 后重试。" }
    delegate.updateWindow()
    let content = delegate.window.contentView!
    content.layoutSubtreeIfNeeded()
    guard let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { throw NSError(domain: "DuoStatus", code: 3) }
    content.cacheDisplay(in: content.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "DuoStatus", code: 4) }
    try png.write(to: URL(fileURLWithPath: path))
}

let app = NSApplication.shared
if CommandLine.arguments.contains("--self-test") {
    selfTest()
} else if let index = CommandLine.arguments.firstIndex(of: "--render-window-preview"), CommandLine.arguments.count > index + 1 {
    try renderWindowPreview(CommandLine.arguments[index + 1], dark: CommandLine.arguments.contains("--dark"), error: CommandLine.arguments.contains("--error"))
} else if let index = CommandLine.arguments.firstIndex(of: "--render-preview"), CommandLine.arguments.count > index + 1 {
    try renderPreview(CommandLine.arguments[index + 1])
} else {
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
