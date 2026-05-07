import AppKit

class OverlayWindow: NSWindow {
    init(for screen: NSScreen) {
        super.init(
            contentRect: screen.visibleFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hasShadow = false
        self.setFrame(screen.visibleFrame, display: false)
    }
}
