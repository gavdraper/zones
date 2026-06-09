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

Prebuilt `Zones.app` downloads aren't available yet. For now, [build from source](#option-b--build-from-source).

When releases are published:

1. Grab the latest `Zones.app` from the [**Releases**](../../releases) page.
2. Move it to your `/Applications` folder.
3. Because the app is self-signed, macOS Gatekeeper may block the first launch. Right-click `Zones.app` → **Open**, then confirm in the dialog. (You only need to do this once.)

> [!TIP]
> If macOS still refuses to open it, run `xattr -dr com.apple.quarantine /Applications/Zones.app` to clear the quarantine flag.

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
2. A split-rectangle icon appears in the **menu bar**. Use it to toggle snapping, choose a layout, or quit.
3. **Hold ⇧ Shift while dragging a window.** Zone overlays appear, the zone under your cursor highlights, and releasing snaps the window into it.

## How it works

Zones is split into a pure, testable domain layer and a thin AppKit integration layer:

| Layer | Responsibility |
|-------|----------------|
| **`ZonesCore`** | Pure, unit-tested domain with no AppKit dependency: `Zone` / `ZoneLayout` (normalized 0–1 coordinates), `LayoutTemplate` (columns / grid / priority layouts), `ZoneGeometry` (normalized → pixels), and `ZoneHitTester` (point → zone). |
| **`ZonesApp`** | AppKit menu-bar agent. `DragMonitor` (a `CGEventTap`) detects drags, `SnapController` orchestrates hit-testing and snapping, `OverlayWindowController` draws the zone overlays, `FocusedWindow` resizes the target window via the Accessibility API, and `CoordinateSpace` handles the AppKit ↔ Quartz origin flip. |

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

- [ ] Configurable snap modifier (currently fixed to ⇧ Shift).
- [ ] Visual zone editor (built-in layouts only for now).
- [ ] Keyboard shortcuts to move windows between zones.
- [ ] Per-app rules and layout persistence.
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
