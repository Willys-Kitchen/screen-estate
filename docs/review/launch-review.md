# Launch Readiness Review — 2026-06-10

Adversarial pre-launch review of ScreenEstate. Five lenses; findings appended as each lens completes.

## Scoreboard

| Lens | Status | Critical | Major | Minor |
|------|--------|----------|-------|-------|
| 1. Hostile environment (AX/TCC/displays) | done | 0 | 5 | 2 |
| 2. Concurrency & lifecycle | done | 0 | 2 | 3 |
| 3. State & persistence integrity | done | 0 | 2 | 2 |
| 4. Security & privacy posture | done | 1 | 0 | 1 |
| 5. Operational readiness | done | 0 | 0 | 2 |

Severity: **Critical** = can crash, corrupt state, or render core feature unusable in plausible conditions (incl. distribution blockers). **Major** = wrong behavior or degraded UX in realistic edge cases. **Minor** = polish, hygiene, latent risk.

Finding status: `open` / `fixed` / `accepted-risk`.

## Lens 1 — Hostile environment

### F-01 [Major] No AX messaging timeout — a hung app beachballs ScreenEstate
- Where: `ScreenEstate/ScreenEstate/Services/WindowManipulationService.swift` (all AX calls)
- What: `AXUIElementSetMessagingTimeout` is never called. Every `AXUIElementCopyAttributeValue`/`SetAttributeValue` runs synchronously on the main thread with the default (multi-second) timeout.
- Why it matters: Press a hotkey while the frontmost app is hung (spinning beachball) and ScreenEstate's entire UI freezes for the duration — repeated calls in `setWindowFrame` (preflight + apply + verify) multiply the stall.
- Suggested fix: Call `AXUIElementSetMessagingTimeout(element, 0.5)` on the system-wide and per-app elements after creation.
- Status: open

### F-02 [Major] Fullscreen snap can grab and snap the wrong window
- Where: `ScreenEstate/ScreenEstate/Services/SnappingEngine.swift:306-314`
- What: After initiating fullscreen exit, the code waits 0.8 s then calls `getFocusedWindow()` and snaps whatever is focused. Focus can legitimately move during that window (user clicks elsewhere; fullscreen exit shifts focus to another app's window).
- Why it matters: A different app's window gets resized/moved — surprising and destructive to the user's layout.
- Suggested fix: Capture the original window's PID (`AXUIElementGetPid`) before exiting fullscreen; after re-fetch, verify the fresh window's PID matches and bail (fade curtain, no snap) if not.
- Status: open

### F-03 [Major] Every snap failure is blamed on Accessibility permission
- Where: `ScreenEstate/ScreenEstate/App/AppDelegate.swift:89-111`
- What: `onSnapFailed` always shows the "Accessibility Permission Required" alert, but `setWindowFrame` also fails for non-permission reasons: window closed mid-drag, non-resizable window, hung app, AX size constraints.
- Why it matters: A user with permission granted who snaps a stubborn window gets told to grant a permission they already have — confusing, erodes trust, and the real cause is hidden.
- Suggested fix: In `handleSnapFailed`, check `WindowManipulationService.checkAccessibility()`. Only show the permission alert when it returns false; otherwise show nothing or a transient "couldn't move that window" notice.
- Status: open

### F-04 [Major] Display-change observer is wired to a no-op
- Where: `ScreenEstate/ScreenEstate/App/AppServiceController.swift:32` (`displayService.startMonitoring { }`)
- What: The display-change callback is an empty closure. Nothing reacts to monitors being added/removed: overlays stay on stale frames, an in-flight drag keeps its `cachedGlobalZones`, overlay windows for a disconnected display aren't torn down.
- Why it matters: Unplugging a monitor mid-drag (or while the keyboard-snap overlay is up) leaves stale/orphaned overlays and zone numbers that no longer match what `updateHitTest` computes from fresh display data.
- Suggested fix: On change, cancel any active tracking and hide overlays (expose a method on `SnappingEngine`); recompute caches lazily next use.
- Status: open

### F-05 [Major] Display identifiers unstable across reconnects — layouts orphan, users must reconfigure
- Where: `ScreenEstate/ScreenEstate/Services/DisplayService.swift:19-27`
- What: The identifier embeds `CGDisplaySerialNumber`, but some monitors (confirmed: Dell U3423WE, U2518D) report *different non-zero serials* for the same physical display across reconnects — the value can derive from connection-dependent EDID data, especially through docks. The serial==0 → `CGDirectDisplayID` fallback has the same instability. Confirmed in a real `modes.json`: the same Dell monitor appears under two serials (`s810043212` vs `s809645644`), and orphaned layouts accumulate (8 layouts in one mode).
- Why it matters: This is the reported "no memory of monitor configuration" bug — switching between home/work setups (or just replugging a dock) makes saved zones silently stop applying, and every reconfiguration appends another orphan layout.
- Suggested fix: When a connected display's exact identifier has no layout, fuzzy re-match against saved layouts by vendor+model (disambiguating multiples of the same model by relative position), and migrate the matched layout to the new identifier. Consider garbage-collecting duplicate vendor+model layouts on load.
- Status: open

### F-06 [Minor] Frame verification checks position only, never size
- Where: `ScreenEstate/ScreenEstate/Services/WindowManipulationService.swift:165-172`
- What: The post-apply check compares only origin (20 pt tolerance). Windows with min/max size constraints (Terminal grid sizing, some Electron apps) land at the right origin with the wrong size and report success.
- Why it matters: Silent partial snaps; user thinks the zone "didn't take".
- Suggested fix: Compare size too; optionally report partial success distinctly (don't trigger the failure alert for a constrained resize).
- Status: open

### F-07 [Minor] Arbitrary 1080 fallback for primary screen height
- Where: `ScreenEstate/ScreenEstate/Services/SnappingEngine.swift:341`
- What: `resolveGlobalZone` uses `NSScreen.screens.first?.frame.height ?? 1080`. If the screens list is momentarily empty (display sleep/reconfigure), coordinate conversion produces garbage frames.
- Why it matters: Window teleports to a nonsense position instead of the snap failing cleanly.
- Suggested fix: `guard let` the primary screen and abort the snap when absent.
- Status: open

## Lens 2 — Concurrency & lifecycle

### F-08 [Major] Run-loop spin inside frame apply allows re-entrancy mid-snap
- Where: `ScreenEstate/ScreenEstate/Services/WindowManipulationService.swift:190,203`
- What: `applyFrame` calls `CFRunLoopRunInMode(.defaultMode, 0.02, false)` twice, pumping the main run loop mid-snap. Queued main-actor tasks — hotkey handlers, mouse-up handlers, `cancelTracking` — can execute while `setWindowFrame` is half-applied.
- Why it matters: A second hotkey press or mouse-up landing inside the spin mutates `SnappingEngine` state mid-operation; symptoms would be rare, unreproducible mis-snaps.
- Suggested fix: Make the apply path `async` and use `Task.sleep` between position/size writes, or set both attributes without pumping the run loop and rely on the existing delayed verify pass.
- Status: open

### F-09 [Major] Hotkey chords are not consumed — frontmost app also receives them
- Where: `ScreenEstate/ScreenEstate/Services/HotkeyService.swift:32-35`
- What: `NSEvent.addGlobalMonitorForEvents` observes events but cannot swallow them. The modifier+digit chord is also delivered to the focused app.
- Why it matters: Default ⌃⌥+digit is mostly safe, but the modifier is user-configurable (`KeyRecorderView`): pick ⌘ and ⌘1 will switch the Safari tab *and* snap the window — every time.
- Suggested fix: Either consume via a `CGEventTap` (listen+suppress) / Carbon `RegisterEventHotKey`, or restrict the recorder to modifier combos that don't collide with common app shortcuts and document the pass-through.
- Status: open

### F-10 [Minor] No in-flight guard on the fullscreen snap sequence
- Where: `ScreenEstate/ScreenEstate/Services/SnappingEngine.swift:298-322`
- What: Pressing the hotkey again during the 0.8 s fullscreen-exit wait starts a second exit/curtain/snap sequence; the two interleave.
- Suggested fix: Track an `isFullscreenSnapInFlight` flag and ignore (or queue) re-entrant requests.
- Status: open

### F-11 [Minor] Observation re-arm gap can miss rapid isEnabled toggles
- Where: `ScreenEstate/ScreenEstate/App/AppDelegate.swift:49-64`
- What: `withObservationTracking`'s onChange re-arms inside an async `Task`. A second toggle landing before the re-arm executes is unobserved.
- Why it matters: Services can end up out of sync with the toggle (e.g. left running while disabled) until the next toggle.
- Suggested fix: Read the current `isEnabled` and reconcile (idempotent start/stop) rather than acting on the assumption of one change per fire — current code mostly does this; just re-arm *before* acting, or accept-risk.
- Status: open

### F-12 [Minor] Two independent OverlayManager instances
- Where: `ScreenEstate/ScreenEstate/App/AppServiceController.swift:21-25`
- What: `SnappingEngine` gets its own default `OverlayManager()` while `HotkeyService` is handed a second instance for `flashModeName`. Neither knows what the other is displaying.
- Why it matters: Mode-name flash and zone overlays can stack/fight; hide calls on one don't affect the other.
- Suggested fix: Create one `OverlayManager` in the controller and inject it into both.
- Status: open

## Lens 3 — State & persistence integrity

### F-13 [Major] Debounced auto-save loses edits made just before quit
- Where: `ScreenEstate/ScreenEstate/App/ScreenEstateApp.swift:28-37` (`AutoSaveController.scheduleSave`)
- What: Saves are debounced 1 s via `DispatchQueue.main.asyncAfter`; there is no `applicationWillTerminate` flush. Edit a zone, quit within a second → edit silently lost.
- Why it matters: Classic "my layout didn't stick" bug report; users edit then immediately quit the editor/app.
- Suggested fix: Add `applicationWillTerminate` in `AppDelegate` that synchronously flushes the pending save (expose `flush()` on `AutoSaveController`).
- Status: open

### F-14 [Major] Corrupt modes.json is immediately overwritten with defaults
- Where: `ScreenEstate/ScreenEstate/App/ScreenEstateApp.swift:96-113`
- What: Any load failure (corrupt file, transient read error, future schema change) falls into the defaults path, which then *saves* the defaults over the user's file.
- Why it matters: One bad read irrecoverably destroys the user's entire zone configuration. Recovery is impossible because the original is gone.
- Suggested fix: Before saving defaults, rename the unreadable file to `modes.json.corrupt-<date>` so the data is recoverable.
- Status: open

### F-15 [Minor] No schema version; settings decode is all-or-nothing on legacy fields
- Where: `ScreenEstate/ScreenEstate/Models/AppSettings.swift:100-109`; `modes.json` / `settings.json` have no version field
- What: Five fields are hard-required in `init(from:)`; any future rename/removal throws and resets *all* settings. `CustomModifierKey` already needed ad-hoc legacy decoding — evidence this will recur.
- Why it matters: Post-launch schema evolution becomes risky; a v2 that can't read v1 wipes user prefs.
- Suggested fix: Add `"version": 1` to both files now (decode-if-present), and make remaining settings fields `decodeIfPresent` with defaults.
- Status: open

### F-16 [Minor] Login-item registration failure is swallowed
- Where: `ScreenEstate/ScreenEstate/App/ScreenEstateApp.swift:124-126`
- What: `try? SMAppService.mainApp.register()` — if registration fails (e.g. app translocation, unsigned build), the setting shows enabled while the login item doesn't exist.
- Suggested fix: Log the error and reconcile the toggle with `SMAppService.mainApp.status` when the settings UI opens.
- Status: open

## Lens 4 — Security & privacy posture

(Subagent scan: entitlements/signing, logging, input-monitoring scope, Info.plist, dependencies, network, file writes. Items not listed below passed: input monitors are correctly scoped to recording/drag contexts; `LSUIElement` set; zero third-party dependencies; no network calls; persistence is atomic writes to `~/Library/Application Support/ScreenEstate/`.)

### F-17 [Critical] No hardened runtime, ad-hoc manual signing — distribution blocker
- Where: `ScreenEstate/ScreenEstate.xcodeproj/project.pbxproj` (`CODE_SIGN_IDENTITY = "-"`, `CODE_SIGN_STYLE = Manual`, no `ENABLE_HARDENED_RUNTIME`)
- What: The app is ad-hoc signed with hardened runtime unset. Sandbox is correctly off (required for AX); entitlements file is empty (fine).
- Why it matters: Cannot notarize → Gatekeeper blocks the download for end users. Ad-hoc signing is also the root cause of the known TCC grant reset on every rebuild (see memory note). This is *the* launch blocker.
- Suggested fix: Sign with a Developer ID Application certificate, enable hardened runtime, notarize the distributed build.
- Status: open

### F-18 [Minor] App names + PIDs logged on AX error paths
- Where: `ScreenEstate/ScreenEstate/Services/WindowManipulationService.swift:62,245`
- What: `NSLog` includes frontmost app name and PID. Window titles/content are never logged (good).
- Why it matters: Unified log entries reveal which apps the user focuses; low risk but easy to tighten.
- Suggested fix: Gate behind `#if DEBUG` or drop the app name from the message.
- Status: open

## Lens 5 — Operational readiness

(Subagent scan: error swallowing, force unwraps, resource lifecycle, overlay lifecycle, diagnostics, threading, launch-at-login/updates. Passed cleanly: all NSEvent monitors, timers, and notification observers have matching teardown with weak captures; overlay windows are reused per display and ordered out correctly; no force-unwraps/`try!`/`fatalError` — the four `as!` casts in `WindowManipulationService` are guarded and documented; all AX/UI work stays on the main thread. The silent `try? SMAppService.register()` finding duplicates F-16.)

### F-19 [Minor] No diagnostics affordance — app is a black box for support
- Where: app-wide; `MenuBarView`, Info.plist (`CFBundleShortVersionString` 1.0)
- What: No user-facing version display, no "copy debug info", and logging is unstructured `NSLog` (~50 statements) rather than `os.Logger` with a subsystem.
- Why it matters: The first launch bug report will be "hotkeys don't work" — almost always the Accessibility/TCC issue. Without a visible trust status + version, every report becomes a back-and-forth.
- Suggested fix: Add an About/debug menu item showing version, Accessibility trust state, and display layout; optionally migrate to `os.Logger` so `log show --predicate 'subsystem == ...'` works.
- Status: open

### F-20 [Minor] No update mechanism — decide before first distribution
- Where: project-wide (no Sparkle, no update check)
- What: Once builds are in users' hands there is no way to push fixes.
- Why it matters: Affects signing/notarization setup (F-17) — adding Sparkle later means re-doing distribution plumbing. A deliberate "manual downloads only for v1" decision is fine; it just should be a decision.
- Suggested fix: Either integrate Sparkle 2 before launch or document manual-update policy.
- Status: open

## Verdict

**20 findings: 1 Critical, 8 Major, 11 Minor. The codebase is in good shape structurally** — clean resource lifecycle, tested geometry/zone logic, properly scoped input monitoring, zero dependencies, no network. The launch risk is concentrated in:

1. **F-17 (signing/notarization)** — the only hard blocker; nothing ships without it.
2. **Data-loss pair F-13 + F-14** — auto-save flush on quit and corrupt-file backup are both small fixes that prevent the worst-case user experience (lost configuration).
3. **Trust-eroding UX pair F-03 + F-09** — wrong permission alert and non-consumed hotkey chords are the two most likely "this app is broken" first impressions.

Suggested fix order: F-17 → F-13/F-14 → F-03 → F-02 → F-09 → F-01/F-04 → remainder as polish.
