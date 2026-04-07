import AppKit
import ApplicationServices

class WindowManipulationService {

    /// Check if accessibility is trusted, optionally prompting the user.
    static func checkAccessibility(prompt: Bool = false) -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": prompt
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Get the focused window of the frontmost app.
    func getFocusedWindow() -> AXUIElement? {
        // First try: AXUIElement system-wide approach
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        if appResult != .success {
            NSLog("Screen Estate [AX]: Failed to get focused app, error: \(appResult.rawValue) (\(describeAXError(appResult)))")
            // Fallback: use NSWorkspace to find frontmost app, then create AXUIElement from its PID
            return getFocusedWindowViaWorkspace()
        }

        let app = focusedApp as! AXUIElement

        var focusedWindow: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        if windowResult != .success {
            NSLog("Screen Estate [AX]: Got app but failed to get focused window, error: \(windowResult.rawValue) (\(describeAXError(windowResult)))")
            // Try getting the first window from the windows list instead
            return getFirstWindow(of: app)
        }

        return (focusedWindow as! AXUIElement)
    }

    /// Fallback: get focused window via NSWorkspace frontmost app PID
    private func getFocusedWindowViaWorkspace() -> AXUIElement? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            NSLog("Screen Estate [AX]: No frontmost application via NSWorkspace")
            return nil
        }

        NSLog("Screen Estate [AX]: Trying via NSWorkspace, frontmost app: \(frontApp.localizedName ?? "unknown") (PID \(frontApp.processIdentifier))")

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        if result != .success {
            NSLog("Screen Estate [AX]: Workspace fallback - failed to get focused window, error: \(result.rawValue) (\(describeAXError(result)))")
            return getFirstWindow(of: appElement)
        }

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
        guard result == .success, let axValue = value else { return nil }
        var point = CGPoint.zero
        AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
        return point
    }

    /// Get the current size of a window.
    func getWindowSize(_ window: AXUIElement) -> CGSize? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value)
        guard result == .success, let axValue = value else { return nil }
        var size = CGSize.zero
        AXValueGetValue(axValue as! AXValue, .cgSize, &size)
        return size
    }

    /// Move and resize a window to the given frame in Accessibility coordinates (top-left origin).
    /// Returns `true` if both position and size were set successfully.
    @discardableResult
    func setWindowFrame(_ window: AXUIElement, frame: CGRect) -> Bool {
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

        return success
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
