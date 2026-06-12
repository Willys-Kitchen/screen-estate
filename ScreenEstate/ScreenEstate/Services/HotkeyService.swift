import AppKit
import Carbon.HIToolbox

/// Registers the modifier+digit chords as Carbon system hotkeys.
///
/// `RegisterEventHotKey` delivers a matched chord to us *instead of* the
/// frontmost app, so e.g. a user who records ⌘ never has ⌘1 both switch the
/// browser tab and snap the window — a passive `NSEvent` global monitor cannot
/// suppress delivery. Carbon hotkeys also work without Accessibility, so the
/// chords come alive immediately; only the snap itself needs the permission.
@MainActor
class HotkeyService {
    private var appState: AppState
    private var snappingEngine: SnappingEngine
    private var overlayManager: OverlayManager

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?

    /// Registers one system hotkey and returns its token (or nil on failure).
    /// Injectable so tests can exercise the lifecycle without registering real
    /// system hotkeys.
    var registerHotKey: (_ keyCode: UInt32, _ carbonModifiers: UInt32, _ id: UInt32) -> EventHotKeyRef?

    /// Unregisters a token previously returned by `registerHotKey`.
    var unregisterHotKey: (EventHotKeyRef) -> Void

    /// Identifies our hotkeys in the Carbon dispatch callback ("SEst").
    nonisolated static let signature: OSType = 0x53457374

    /// Hotkey id (the digit itself) → virtual key code on the number row.
    private static let digitKeyCodes: [UInt32: UInt32] = [
        0: UInt32(kVK_ANSI_0), 1: UInt32(kVK_ANSI_1), 2: UInt32(kVK_ANSI_2),
        3: UInt32(kVK_ANSI_3), 4: UInt32(kVK_ANSI_4), 5: UInt32(kVK_ANSI_5),
        6: UInt32(kVK_ANSI_6), 7: UInt32(kVK_ANSI_7), 8: UInt32(kVK_ANSI_8),
        9: UInt32(kVK_ANSI_9),
    ]

    init(appState: AppState, snappingEngine: SnappingEngine, overlayManager: OverlayManager) {
        self.appState = appState
        self.snappingEngine = snappingEngine
        self.overlayManager = overlayManager
        self.registerHotKey = { keyCode, carbonModifiers, id in
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: HotkeyService.signature, id: id)
            let status = RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
            guard status == noErr, let ref else {
                NSLog("Screen Estate: Failed to register hotkey \(id) (status \(status), chord may be taken by another app)")
                return nil
            }
            return ref
        }
        self.unregisterHotKey = { UnregisterEventHotKey($0) }
        observeModifierKey()
    }

    /// Whether any system hotkeys are currently registered.
    var isMonitoring: Bool { !hotKeyRefs.isEmpty }

    func start() {
        installDispatchHandlerIfNeeded()
        registerAllHotkeys()
    }

    func stop() {
        unregisterAllHotkeys()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func registerAllHotkeys() {
        unregisterAllHotkeys()
        let modifiers = appState.modifierKey.carbonFlags
        for (id, keyCode) in Self.digitKeyCodes.sorted(by: { $0.key < $1.key }) {
            if let ref = registerHotKey(keyCode, modifiers, id) {
                hotKeyRefs.append(ref)
            }
        }
        NSLog("Screen Estate: Registered \(hotKeyRefs.count) hotkeys for \(appState.modifierKey.displayString)+0-9")
    }

    private func unregisterAllHotkeys() {
        hotKeyRefs.forEach(unregisterHotKey)
        hotKeyRefs.removeAll()
    }

    /// Follow the user's recorded modifier: re-register live chords with the
    /// new flags whenever the setting changes.
    private func observeModifierKey() {
        withObservationTracking {
            _ = appState.settings.modifierKey
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.isMonitoring {
                    self.registerAllHotkeys()
                }
                self.observeModifierKey()
            }
        }
    }

    private func installDispatchHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr, hotKeyID.signature == HotkeyService.signature else { return noErr }
            // Carbon dispatches hotkey events on the main thread.
            MainActor.assumeIsolated {
                Unmanaged<HotkeyService>.fromOpaque(userData)
                    .takeUnretainedValue()
                    .handleHotKeyPressed(id: hotKeyID.id)
            }
            return noErr
        }, 1, &eventType, userData, &eventHandlerRef)
        if status != noErr {
            NSLog("Screen Estate: Failed to install hotkey dispatch handler (status \(status))")
        }
    }

    func handleHotKeyPressed(id: UInt32) {
        switch id {
        case 1...9:
            snappingEngine.snapFocusedWindowToZone(number: Int(id))
        case 0:
            appState.cycleMode()
            if let screen = NSScreen.main {
                overlayManager.flashModeName(appState.activeMode?.name ?? "", on: screen)
            }
        default:
            break
        }
    }
}
