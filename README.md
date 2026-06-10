<div align="center">

# Zones

**FancyZones-style window snapping for macOS.**

Hold a modifier while dragging a window to overlay a zone layout on your screen, then drop the window to snap it into place — like Windows PowerToys FancyZones, built natively for the Mac.

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Build](https://img.shields.io/badge/build-Swift%20Package%20Manager-success)](Package.swift)

</div>

> [!NOTE]
> Zones is currently an **MVP vertical slice**: one active layout at a time, drag-to-snap on whichever display the cursor is over, an Accessibility permission flow, and a menu-bar toggle. See the [Roadmap](#roadmap) for what's next.

---


## Features

- 🪟 **Drag-to-snap** — hold ⇧ Shift while dragging any window to reveal zone overlays, then release to snap.
- ⌨️ **Keyboard moves** — hold **⌃⌥** and tap the arrow keys to walk the focused window between zones; the layout stays highlighted until you let the modifiers go.
- ✏️ **Visual zone editor** — build your own layouts by splitting cells left/right or top/bottom, dragging the dividers to resize, and merging neighbours back together. Saved layouts appear in the menu and persist across launches.
- 📐 **Resolution-independent layouts** — zones are stored as fractions of the display, so a layout behaves identically on a laptop panel or a 4K monitor.
- 🖥️ **Multi-monitor aware** — snapping targets whichever display your cursor is over.
- 🧭 **Menu-bar agent** — lightweight, no Dock icon; toggle snapping, pick a layout, or quit from the menu bar.
- ⚡ **Native & dependency-free** — pure Swift + AppKit, no third-party packages, no Electron.

## Requirements

| | |
|---|---|
| **macOS** | 14.0 (Sonoma) or later |
| **Toolchain** _(build from source only)_ | Swift 6.0+ (Xcode 16 or the matching Swift toolchain) |
| **Permissions** | Accessibility access (granted on first run — see [First run](#first-run)) |

## Installation

### Option A — Download a release _(coming soon)_

Prebuilt downloads aren't published yet — for now, [build from source](#option-b--build-from-source). When they land, the flow is:

1. Download `Zones-<version>.dmg` from the [**Releases**](../../releases) page, open it, and drag `Zones.app` into your `/Applications` folder.
2. **Get past Gatekeeper once.** Zones is **self-signed, not notarised by Apple** (it's built without a paid Apple Developer account), so the first launch is blocked as coming "from an unidentified developer." Clear it once:
   - **macOS 14 Sonoma:** right-click `Zones.app` → **Open**, then confirm in the dialog.
   - **macOS 15 Sequoia or later:** double-click it (it'll be blocked), then open **System Settings → Privacy & Security**, scroll to the Zones notice, click **Open Anyway**, and authenticate.
   - Or skip the dialogs entirely with the one-liner below.
3. That's the **only** time you'll see a warning. **Updates are automatic from then on:** Zones ships with [Sparkle](https://sparkle-project.org), checks for new versions in the background, and installs them in place — without re-triggering Gatekeeper.

> [!TIP]
> To bypass the Gatekeeper prompts, clear the quarantine flag after copying the app to `/Applications`:
> ```bash
> xattr -dr com.apple.quarantine /Applications/Zones.app
> ```

> [!NOTE]
> **Is self-signed safe?** The download is signed with a stable local certificate, and every auto-update is verified by Sparkle's own EdDSA signature before it installs — so updates can't be tampered with in transit. What's missing is Apple's *notarisation*, which is why macOS shows the one-time warning: it can't vouch for the developer the way it can for notarised apps.

### Option B — Build from source

Zones builds with the Swift Package Manager — no Xcode project required.

```bash
git clone https://github.com/<your-username>/zones.git
cd zones

swift test                 # run the ZonesCore unit tests
./Scripts/bundle.sh        # release build → build/Zones.app (signed)
open build/Zones.app       # launch the menu-bar agent
```

For day-to-day development:

```bash
swift build                # debug build
swift run ZonesApp         # build and launch directly
```

> [!NOTE]
> `Scripts/bundle.sh` assembles a proper `.app` bundle and code-signs it. It prefers a stable self-signed **"Zones Dev"** identity (created via `Scripts/create-signing-cert.sh`) and falls back to ad-hoc signing. A stable signature matters because it lets your **Accessibility grant survive rebuilds** instead of re-prompting every time.

## First run

1. On launch, macOS prompts for **Accessibility** permission — required to observe mouse drags and to move other apps' windows. Grant it in **System Settings → Privacy & Security → Accessibility**, then toggle Zones on.
2. A split-rectangle icon appears in the **menu bar**. Use it to toggle snapping, choose a layout, create or edit your own via **New Layout…**, **Check for Updates…**, or quit.
3. **Hold ⇧ Shift while dragging a window.** Zone overlays appear, the zone under your cursor highlights, and releasing snaps the window into it.
4. **Or hold ⌃⌥ and tap the arrow keys** to move the focused window between zones without the mouse. The zone overlay appears with the destination highlighted and stays up while you hold ⌃⌥, so you can keep tapping to walk the window across the layout; release the keys to dismiss it. A window that isn't in a zone yet lands in the nearest one.

### Building a custom layout

Pick **New Layout…** from the menu to open the editor. Click a cell to select it, then split it left/right or top/bottom, drag the dividers to resize, and merge a cell back into its neighbour. Name it and **Save** — it joins the menu and is remembered across launches.

## How it works

Zones is split into a pure, testable domain layer and a thin AppKit integration layer:

| Layer | Responsibility |
|-------|----------------|
| **`ZonesCore`** | Pure, unit-tested domain with no AppKit dependency: `Zone` / `ZoneLayout` (normalized 0–1 coordinates), `LayoutTemplate` (columns / grid / priority layouts), `ZoneGeometry` (normalized → pixels), `ZoneHitTester` (point → zone), and `ZoneNavigator` (directional zone-to-zone moves for the keyboard). The editor model — `EditableGrid`, a split/merge BSP tree that flattens to `[Zone]` — and persistence (`LayoutStore` / `FileLayoutStore` and the observable `LayoutLibrary`) live here too. |
| **`ZonesApp`** | AppKit menu-bar agent. `DragMonitor` (a `CGEventTap`) detects drags and `KeyboardMonitor` (another tap) detects the ⌃⌥+arrow hotkey; both feed `SnapController`, which orchestrates hit-testing, snapping, and keyboard moves (via `ZonesCore`'s `ZoneNavigator`). `OverlayWindowController` draws the zone overlays, `FocusedWindow` reads and resizes the target window via the Accessibility API, and `CoordinateSpace` handles the AppKit ↔ Quartz origin flip. The visual editor is `EditorWindowController` + `GridEditorView` + the AppKit-free `GridEditorViewModel`. |

```
Sources/
├── ZonesCore/   # pure domain logic (unit-tested)
└── ZonesApp/    # AppKit UI, event monitoring, system integration
Tests/
└── ZonesCoreTests/
Scripts/
├── bundle.sh              # release build + code-sign → build/Zones.app
├── create-signing-cert.sh # one-time: create a stable signing identity
└── make-gif.sh            # convert a screen recording → docs/demo.gif
```

## Roadmap

Current limitations and what's planned next:

- [x] Visual zone editor with persistent custom layouts.
- [x] Keyboard shortcuts to move windows between zones (⌃⌥ + arrow).
- [ ] Configurable snap modifier and move hotkey (currently fixed to ⇧ Shift / ⌃⌥).
- [ ] Arbitrary (non-guillotine) zone merges — the editor currently merges a cell only into a sibling cell.
- [ ] Per-app rules.
- [ ] Per-display layouts (multi-monitor currently uses the display under the cursor).

## Contributing

Contributions are welcome! To get started:

1. Fork the repo and create a feature branch.
2. Make your changes, keeping `ZonesCore` free of AppKit dependencies so it stays unit-testable.
3. Add or update tests under `Tests/ZonesCoreTests/` and make sure `swift test` passes.
4. Open a pull request describing the change and the motivation.

Please keep the domain/UI separation intact — pure logic in `ZonesCore`, system integration in `ZonesApp`.

## License

Zones is released under the [MIT License](LICENSE).
