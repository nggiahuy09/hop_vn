import AppKit
import HopCore

/// Vietnamese typing in every app, in Telex or VNI.
///
/// A session `CGEventTap` reads each key as it is pressed and hands it to a
/// `VietnameseComposer`. A key that only types itself goes through untouched;
/// one that changes the word is swallowed, and the difference is sent as
/// backspaces and the corrected text. Nothing typed is recorded, and secure
/// input (password fields) never reaches a tap.
/// SPEC: docs/spec.md — "Vietnamese typing".
@MainActor
final class VietnameseTypingController: ObservableObject {
    enum Mode: String, CaseIterable {
        case off, telex, vni

        var method: VietnameseTypingMethod? {
            switch self {
            case .off: return nil
            case .telex: return .telex
            case .vni: return .vni
            }
        }
    }

    static let moduleID = "vietnamese"
    static let modeKey = "vietnameseTypingMode"
    static let lastMethodKey = "vietnameseTypingLastMethod"
    /// `true` writes hoà, khoẻ, thuỷ instead of hòa, khỏe, thủy.
    static let modernTonesKey = "vietnameseModernTones"

    @Published private(set) var mode: Mode
    /// Wanted on, and macOS will not let the tap run.
    @Published private(set) var isBlocked = false

    var isActive: Bool { mode != .off && !isBlocked }

    private let demo: Bool
    private var composer = VietnameseComposer(method: .telex)
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var observers: [NSObjectProtocol] = []
    /// Key codes whose press was swallowed, so their release is swallowed too.
    private var swallowedKeys: Set<Int64> = []

    /// Marks the events this controller posts, so its own tap lets them by.
    private static let marker: Int64 = 0x564E_5459
    private static let deleteKey: CGKeyCode = 51
    /// WORKAROUND: the text is carried by a key event whose code is only a
    /// carrier. The code of `a` is taken by the system's press-and-hold accent
    /// menu, which holds the character back; `x` has no accents.
    private static let carrierKey: CGKeyCode = 7

    /// A preview model stages the row and installs nothing.
    init(demo: Bool = false) {
        self.demo = demo
        if demo {
            mode = .telex
        } else {
            mode = Mode(rawValue: UserDefaults.standard.string(forKey: Self.modeKey) ?? "") ?? .off
        }
    }

    /// Begin following the module's switch and the frontmost app.
    func start() {
        guard !demo, !Snapshot.active, observers.isEmpty else { return }
        observers.append(NotificationCenter.default.addObserver(
            forName: ModuleActivation.didChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.reconcile() }
        })
        // The word belongs to the field it was typed in.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.composer.reset() }
        })
        reconcile()
    }

    /// Choosing a method IS switching on, and "off" is the other chip: the row
    /// has no separate switch.
    func select(_ new: Mode) {
        guard !demo else {
            mode = new
            return
        }
        if new != .off, !AXIsProcessTrusted() {
            refuse(askSystem: true)
            return
        }
        store(new)
        if !reconcile() { refuse(askSystem: false) }
    }

    /// The hotkey: Vietnamese on and off. On is the method used last;
    /// changing between Telex and VNI is the panel's chips.
    func toggle() {
        let wasOn = mode != .off
        select(wasOn ? .off : lastMethod)
        // One sound per change, a different one each way; a blocked tap
        // changed nothing, so it stays silent.
        if wasOn {
            if mode == .off { Sounds.typingToggle(on: false) }
        } else if isActive {
            Sounds.typingToggle(on: true)
        }
    }

    private var lastMethod: Mode {
        Mode(rawValue: UserDefaults.standard.string(forKey: Self.lastMethodKey) ?? "") == .vni ? .vni : .telex
    }

    private func store(_ new: Mode) {
        mode = new
        let defaults = UserDefaults.standard
        defaults.set(new.rawValue, forKey: Self.modeKey)
        if new != .off { defaults.set(new.rawValue, forKey: Self.lastMethodKey) }
        composer.reset()
    }

    /// No typing happened, and macOS does the asking.
    private func refuse(askSystem: Bool) {
        AccessibilityWatch.shared.reportBlocked()
        if askSystem { PermissionRepair.askAgain(.accessibility) }
    }

    /// Brings the tap in line with what is wanted; `false` when it is wanted
    /// and cannot run. A module switched off is switched off everywhere, so
    /// putting it back starts from "off".
    @discardableResult
    private func reconcile() -> Bool {
        guard !demo, !Snapshot.active else { return true }
        if !ModuleActivation.isOn(Self.moduleID), mode != .off { store(.off) }
        guard let method = mode.method else {
            removeTap()
            isBlocked = false
            return true
        }
        composer.method = method
        if let tap {
            if !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
            isBlocked = false
            return true
        }
        let installed = AXIsProcessTrusted() && installTap()
        isBlocked = !installed
        return installed
    }

    // MARK: - The tap

    private func installTap() -> Bool {
        let types: [CGEventType] = [.keyDown, .keyUp, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<VietnameseTypingController>
                .fromOpaque(userInfo).takeUnretainedValue()
            let swallow = MainActor.assumeIsolated { controller.handle(type, event, proxy) }
            return swallow ? nil : Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source
        return true
    }

    private func removeTap() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        swallowedKeys = []
        composer.reset()
    }

    /// `true` swallows the event.
    private func handle(_ type: CGEventType, _ event: CGEvent, _ proxy: CGEventTapProxy) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // WORKAROUND: macOS switches a tap off when a callback is slow; a
            // typing method that quietly stops is worse than one that re-arms.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            composer.reset()
            return false
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            composer.reset()
            return false
        case .keyUp:
            return swallowedKeys.remove(event.getIntegerValueField(.keyboardEventKeycode)) != nil
        case .keyDown:
            return handleKeyDown(event, proxy)
        default:
            return false
        }
    }

    private func handleKeyDown(_ event: CGEvent, _ proxy: CGEventTapProxy) -> Bool {
        guard event.getIntegerValueField(.eventSourceUserData) != Self.marker else { return false }
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            composer.reset()
            return false
        }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        if code == Int64(Self.deleteKey) {
            composer.backspace()
            return false
        }
        var length = 0
        var units = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: units.count,
                                       actualStringLength: &length, unicodeString: &units)
        guard length == 1, let scalar = Unicode.Scalar(units[0]) else {
            composer.reset()
            return false
        }
        composer.modernTonePlacement =
            UserDefaults.standard.object(forKey: Self.modernTonesKey) as? Bool ?? false
        switch composer.push(Character(scalar)) {
        case .pass, .boundary:
            return false
        case .replace(let delete, let insert):
            swallowedKeys.insert(code)
            send(delete: delete, insert: insert, proxy: proxy)
            return true
        case .fix(let delete, let insert):
            // the word is put back, and the key that ended it types itself after
            send(delete: delete, insert: insert, proxy: proxy)
            return false
        }
    }

    // MARK: - Typing back

    private func send(delete: Int, insert: String, proxy: CGEventTapProxy) {
        let source = CGEventSource(stateID: .privateState)
        for _ in 0..<delete { post(source, proxy, key: Self.deleteKey, text: nil) }
        if !insert.isEmpty { post(source, proxy, key: Self.carrierKey, text: insert) }
    }

    private func post(_ source: CGEventSource?, _ proxy: CGEventTapProxy, key: CGKeyCode, text: String?) {
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)
            else { continue }
            event.flags = []
            event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
            if let text {
                let units = Array(text.utf16)
                units.withUnsafeBufferPointer {
                    event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: $0.baseAddress)
                }
            }
            // SPEC: docs/spec.md — "Vietnamese typing": entered at this tap, so
            // it never sees its own output.
            event.tapPostEvent(proxy)
        }
    }
}
