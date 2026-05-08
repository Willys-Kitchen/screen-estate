# Screen Estate

Screen Estate is an app to help you manage your screen real estate for free. It's a macOS window snapping utility app, similar to [FancyZones](https://learn.microsoft.com/en-us/windows/powertoys/fancyzones) on Windows.

Hold **Shift** while dragging a window and your defined zones appear on screen. Drag into one and the window resizes to fill it. Alternatively, press your designated modifier keys **+ 1–9** to snap the focused window directly to a numbered zone. Zones are configured globally and saved per mode, so you can have different layouts for different workflows.

## Features

- **Snap zones** — drag any window with Shift held to snap it to a defined zone
- **Keyboard shortcuts** — `Modifier + 1–9` snaps the focused window; `Modifier + 0` cycles modes
- **Preset layouts** — halves, thirds, two-thirds/one-third, quadrants (portrait-aware)
- **Custom grid editor** — merge and split cells to build your own layout
- **Multiple modes** — save different zone setups and switch between them
- **Multi-monitor** — configure zones across your whole set up
- **Customizable** — pick your modifier key (⌃⌥⇧⌘), accent color, and toggle drag-snap separately

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later (to build)
- Accessibility permission (prompted on first launch)

## Install

1. Clone the repo
   ```bash
   git clone https://github.com/Willys-Kitchen/screen-estate.git
   ```
2. Open `ScreenEstate/ScreenEstate.xcodeproj` in Xcode
3. Hit **Run** (⌘R), or build a release copy via **Product → Archive → Distribute App → Copy App**
4. Copy `ScreenEstate.app` to `/Applications`
5. **First launch:** right-click → **Open** (Gatekeeper will block a plain double-click on an unsigned app)
6. Grant **Accessibility** permission when prompted — the app needs this to move and resize windows

> If macOS still refuses to open it, run this once in Terminal:
> ```bash
> xattr -cr /Applications/ScreenEstate.app
> ```

## Usage

- **Open the editor** — click the menu bar icon → **Edit Zones…**
- **Presets tab** — click a preset to apply it to the current display/mode
- **Grid tab** — click cells to select, click a second cell to extend selection, then **Merge Cells**; double-click to split left/right, ⌃-click to split top/bottom
- **Snap a window** — hold **Shift** and drag any window to a zone highlight, or press `Modifier + 1–9` (default ⌃⌥) to snap the focused window
- **Cycle modes** — press `Modifier + 0`
- **Toggle snapping** — click the menu bar icon and use the **Enabled** toggle

## License

MIT
