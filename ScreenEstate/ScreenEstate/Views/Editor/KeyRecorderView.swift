import SwiftUI
import AppKit

@MainActor
final class KeyRecorderModel: ObservableObject {
    @Published var isRecording = false
    @Published var liveFlags: NSEvent.ModifierFlags = []
    // Written and read on main thread by both monitors — safe without actor isolation
    nonisolated(unsafe) private var capturedFlags: NSEvent.ModifierFlags = []
    private var flagsMonitor: Any?
    private var keyMonitor: Any?

    func startRecording(onSave: @escaping @MainActor (CustomModifierKey) -> Void) {
        isRecording = true
        liveFlags = []
        capturedFlags = []

        // Global monitor: fires regardless of whether the app is "active"
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let newFlags = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .subtracting([.capsLock, .numericPad, .function, .help])
            self?.capturedFlags = newFlags
            Task { @MainActor [weak self] in
                self?.liveFlags = newFlags
            }
        }

        // Local monitor: consume Return/Escape/trigger key while recording
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let keyCode = event.keyCode
            let chars = event.charactersIgnoringModifiers
            let flags = self.capturedFlags

            if keyCode == 53 { // Escape — cancel
                Task { @MainActor [weak self] in self?.stop() }
                return nil
            }
            if (keyCode == 36 || keyCode == 76) && !flags.isEmpty { // Return — save modifiers only
                let key = CustomModifierKey(flags: flags.rawValue)
                Task { @MainActor [weak self] in
                    onSave(key)
                    self?.stop()
                }
                return nil
            }
            if !flags.isEmpty, let char = chars, !char.isEmpty { // Any key — save modifiers+key
                let key = CustomModifierKey(flags: flags.rawValue)
                Task { @MainActor [weak self] in
                    onSave(key)
                    self?.stop()
                }
                return nil
            }
            Task { @MainActor [weak self] in self?.stop() }
            return nil
        }
    }

    func stop() {
        if let m = flagsMonitor { NSEvent.removeMonitor(m); flagsMonitor = nil }
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        isRecording = false
        liveFlags = []
        capturedFlags = []
    }
}

struct KeyRecorderView: View {
    @Binding var modifierKey: CustomModifierKey
    @StateObject private var model = KeyRecorderModel()

    private var recordingLabel: String {
        if model.liveFlags.isEmpty {
            return "Hold modifiers, then press a key (or ↩ for mod-only)…"
        }
        return "\(model.liveFlags.modifierDisplayString) + press a key (or ↩ to save)"
    }

    var body: some View {
        Button {
            if model.isRecording {
                model.stop()
            } else {
                model.startRecording { key in
                    modifierKey = key
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(model.isRecording ? recordingLabel : modifierKey.displayString)
                    .foregroundColor(model.isRecording ? .accentColor : .primary)
                    .frame(minWidth: 80, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(model.isRecording
                          ? Color.accentColor.opacity(0.08)
                          : Color(nsColor: .controlBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(model.isRecording ? Color.accentColor : Color(nsColor: .separatorColor),
                                lineWidth: model.isRecording ? 1.5 : 1))
            )
        }
        .buttonStyle(.plain)
    }
}

extension NSEvent.ModifierFlags {
    var modifierDisplayString: String {
        var parts: [String] = []
        if contains(.control) { parts.append("⌃") }
        if contains(.option)  { parts.append("⌥") }
        if contains(.shift)   { parts.append("⇧") }
        if contains(.command) { parts.append("⌘") }
        return parts.isEmpty ? "—" : parts.joined()
    }
}
