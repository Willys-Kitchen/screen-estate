# Screen Estate

A macOS window manager that lets you snap windows into customisable zones by holding **Shift** and dragging.

## Features

- **Snap zones** — drag any window with Shift held to snap it to a defined zone
- **Preset layouts** — halves, thirds, two-thirds/one-third, quadrants
- **Custom grid editor** — merge and split cells to build your own layout
- **Multiple modes** — save different zone setups and switch between them
- **Multi-monitor** — configure zones per display independently

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

- **Open the editor** — click the menu bar icon → **Open Editor**
- **Presets tab** — click a preset to apply it to the current display/mode
- **Grid tab** — click cells to select, click a second cell to extend selection, then **Merge Cells**; double-click to split left/right, ⌃-click to split top/bottom
- **Snap a window** — hold **Shift**, start dragging any window, hover over a zone highlight, release

## License

MIT
