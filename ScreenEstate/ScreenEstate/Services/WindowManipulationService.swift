import AppKit
import ApplicationServices

/// Protocol for window manipulation operations. Allows testing without real accessibility APIs.
protocol WindowManipulating {
    func getFocusedWindow() -> AXUIElement?
    func isWindowValid(_ window: AXUIElement) -> Bool
    func getWindowFrame(_ window: AXUIElement) -> CGRect?
    func isFullscreen(_ window: AXUIElement) -> Bool
    func exitFullscreen(_ window: AXUIElement) -> Bool
    func owningPID(_ window: AXUIElement) -> pid_t?
    @discardableResult func setWindowFrame(_ window: AXUIElement, frame: CGRect) -> Bool
    @discardableResult func raiseWindow(_ window: AXUIElement) -> Bool
    @discardableResult func activateOwningApp(_ window: AXUIElement) -> Bool
}

class WindowManipulationService: WindowManipulating {

    /// Check if accessibility is trusted, optionally prompting the user.
    static func checkAccessibility(prompt: Bool = false) -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": prompt
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Cap for synchronous AX calls so a hung target app can't beachball us
    /// for the default (multi-second) timeout.
    private static let axMessagingTimeout: Float = 0.5

    private func withTimeout(_ element: AXUIElement) -> AXUIElement {
        AXUIElementSetMessagingTimeout(element, Self.axMessagingTimeout)
        return element
    }

    /// Get the focused window of the frontmost app.
    func getFocusedWindow() -> AXUIElement? {
        // First try: AXUIElement system-wide approach
        let systemWide = withTimeout(AXUIElementCreateSystemWide())

        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        if appResult != .success {
            NSLog("Screen Estate [AX]: Failed to get focused app, error: \(appResult.rawValue) (\(describeAXError(appResult)))")
            // Fallback: use NSWorkspace to find frontmost app, then create AXUIElement from its PID
            return getFocusedWindowViaWorkspace()
        }

        guard let focusedApp else { return getFocusedWindowViaWorkspace() }
        // AXUIElement is a CFTypeRef alias — force cast is safe after nil check
        let app = focusedApp as! AXUIElement

        var focusedWindow: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        if windowResult != .success {
            NSLog("Screen Estate [AX]: Got app but failed to get focused window, error: \(windowResult.rawValue) (\(describeAXError(windowResult)))")
            // Try getting the first window from the windows list instead
            return getFirstWindow(of: app)
        }

        guard let focusedWindow else { return nil }
        return (focusedWindow as! AXUIElement)
    }

    /// Fallback: get focused window via NSWorkspace frontmost app PID
    private func getFocusedWindowViaWorkspace() -> AXUIElement? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            NSLog("Screen Estate [AX]: No frontmost application via NSWorkspace")
            return nil
        }

        #if DEBUG
        NSLog("Screen Estate [AX]: Trying via NSWorkspace, frontmost app: \(frontApp.localizedName ?? "unknown") (PID \(frontApp.processIdentifier))")
        #else
        NSLog("Screen Estate [AX]: Trying via NSWorkspace frontmost app")
        #endif

        let appElement = withTimeout(AXUIElementCreateApplication(frontApp.processIdentifier))

        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        if result != .success {
            NSLog("Screen Estate [AX]: Workspace fallback - failed to get focused window, error: \(result.rawValue) (\(describeAXError(result)))")
            return getFirstWindow(of: appElement)
        }

        guard let focusedWindow else { return nil }
        return (focusedWindow as! AXUIElement)
    }

    /// Last resort: get the first window from the app's window list
    private func getFirstWindow(of app: AXUIElement) -> AXUIElement? {
        var windowList: AnyObject?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowList)
        if result != .success {
            NSLog("Screen Estate [AX]: Failed to get windows list, error: \(result.rawValue) (\(describeAXError(result)))")
            return nil
        }

        guard let windows = windowList as? [AXUIElement], let first = windows.first else {
            NSLog("Screen Estate [AX]: Windows list is empty")
            return nil
        }

        NSLog("Screen Estate [AX]: Using first window from windows list (\(windows.count) windows)")
        return first
    }

    /// Get the current position of a window in Accessibility coordinates (top-left origin).
    func getWindowPosition(_ window: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value)
        guard result == .success, let value else { return nil }
        var point = CGPoint.zero
        // AXValue is a CFTypeRef alias — force cast is safe after nil check
        AXValueGetValue(value as! AXValue, .cgPoint, &point)
        return point
    }

    /// Get the current size of a window.
    func getWindowSize(_ window: AXUIElement) -> CGSize? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value)
        guard result == .success, let value else { return nil }
        var size = CGSize.zero
        AXValueGetValue(value as! AXValue, .cgSize, &size)
        return size
    }

    /// Check if a window reference is still valid by attempting to read an attribute.
    func isWindowValid(_ window: AXUIElement) -> Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value)
        return result == .success
    }

    /// Check if a window is in fullscreen mode.
    func isFullscreen(_ window: AXUIElement) -> Bool {
        var value: AnyObject?
        // Try the standard AXFullScreen attribute
        let result = AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value)
        if result == .success, let isFullscreen = value as? Bool {
            return isFullscreen
        }
        return false
    }

    /// Exit fullscreen mode for a window. Returns true if the window was fullscreen and we initiated exit.
    func exitFullscreen(_ window: AXUIElement) -> Bool {
        guard isFullscreen(window) else { return false }

        // Set AXFullScreen to false to exit fullscreen
        let result = AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, kCFBooleanFalse)
        if result == .success {
            NSLog("Screen Estate [AX]: Initiated fullscreen exit")
            return true
        } else {
            NSLog("Screen Estate [AX]: Failed to exit fullscreen: \(describeAXError(result))")
            return false
        }
    }

    /// Move and resize a window to the given frame in Accessibility coordinates (top-left origin).
    /// Returns `true` if both position and size were set successfully.
    @discardableResult
    func setWindowFrame(_ window: AXUIElement, frame: CGRect) -> Bool {
        // Pre-flight: verify accessibility is still enabled
        if !WindowManipulationService.checkAccessibility(prompt: false) {
            NSLog("Screen Estate [AX]: Accessibility permission not granted, cannot set window frame")
            return false
        }

        // Pre-flight: verify the window reference is still valid
        if !isWindowValid(window) {
            NSLog("Screen Estate [AX]: Window reference is no longer valid (window may have closed or lost focus)")
            return false
        }

        let success = applyFrame(window, frame: frame)

        if let actual = getWindowFrame(window),
           hypot(actual.origin.x - frame.origin.x, actual.origin.y - frame.origin.y) > 20
            || abs(actual.width - frame.width) > 20
            || abs(actual.height - frame.height) > 20 {
            return applyFrame(window, frame: frame)
        }

        return success
    }

    private func applyFrame(_ window: AXUIElement, frame: CGRect) -> Bool {
        var success = true
        var position = frame.origin

        if let posValue = AXValueCreate(.cgPoint, &position) {
            let posResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
            if posResult != .success {
                NSLog("Screen Estate [AX]: Failed to set window position: \(describeAXError(posResult))")
                success = false
            }
        } else {
            success = false
        }

        // Brief pause to let the target app process the position change.
        // Deliberately a sleep, not a run-loop spin: pumping the run loop here
        // would let queued hotkey/mouse handlers run mid-apply and mutate
        // snapping state while a frame is half-set.
        usleep(20_000)

        var size = frame.size
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            if sizeResult != .success {
                NSLog("Screen Estate [AX]: Failed to set window size: \(describeAXError(sizeResult))")
                success = false
            }
        } else {
            success = false
        }

        CFRunLoopRunInMode(.defaultMode, 0.02, false)

        if let posValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }

        return success
    }

    func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        guard let position = getWindowPosition(window), let size = getWindowSize(window) else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// Raise the window to the front of its app's window stack.
    @discardableResult
    func raiseWindow(_ window: AXUIElement) -> Bool {
        let result = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        if result != .success {
            NSLog("Screen Estate [AX]: Failed to raise window: \(describeAXError(result))")
            return false
        }
        return true
    }

    /// The process ID of the app that owns this window.
    func owningPID(_ window: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        let pidResult = AXUIElementGetPid(window, &pid)
        if pidResult != .success {
            NSLog("Screen Estate [AX]: Failed to get PID from window: \(describeAXError(pidResult))")
            return nil
        }
        return pid
    }

    /// Activate the app that owns this window, giving it keyboard focus.
    @discardableResult
    func activateOwningApp(_ window: AXUIElement) -> Bool {
        guard let pid = owningPID(window) else { return false }

        guard let app = NSRunningApplication(processIdentifier: pid) else {
            NSLog("Screen Estate [AX]: No running application for PID \(pid)")
            return false
        }

        let activated = app.activate()
        if !activated {
            #if DEBUG
            NSLog("Screen Estate [AX]: Failed to activate app \(app.localizedName ?? "unknown")")
            #else
            NSLog("Screen Estate [AX]: Failed to activate owning app")
            #endif
            return false
        }
        return true
    }

    private func describeAXError(_ error: AXError) -> String {
        switch error {
        case .success: "success"
        case .failure: "general failure"
        case .illegalArgument: "illegal argument"
        case .invalidUIElement: "invalid UI element"
        case .invalidUIElementObserver: "invalid observer"
        case .cannotComplete: "cannot complete (app not responding?)"
        case .attributeUnsupported: "attribute unsupported"
        case .actionUnsupported: "action unsupported"
        case .notificationUnsupported: "notification unsupported"
        case .notImplemented: "not implemented"
        case .notificationAlreadyRegistered: "notification already registered"
        case .notificationNotRegistered: "notification not registered"
        case .apiDisabled: "API disabled (accessibility permission not granted)"
        case .noValue: "no value"
        case .parameterizedAttributeUnsupported: "parameterized attribute unsupported"
        case .notEnoughPrecision: "not enough precision"
        @unknown default: "unknown error \(error.rawValue)"
        }
    }
}
