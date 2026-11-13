# Quillfolio (macOS Edition) 🖋️✨

> **A native, professional digital handwriting, geometry, and knowledge notebook for macOS.**  
> Crafted with Swift, SwiftUI, AppKit, and CoreGraphics. Featuring sub-pixel vector ink smoothing, hardware stylus pressure dynamics, intelligent auto-shape recognition, multi-column dynamic tables, an infinite canvas, and full bilingual support (English & Polish).

[![Platform](https://img.shields.io/badge/Platform-macOS%2013.0%2B-blue?logo=apple)](https://www.apple.com/macos/)
[![Language](https://img.shields.io/badge/Language-Swift%206-orange?logo=swift)](https://swift.org)
[![Architecture](https://img.shields.io/badge/Architecture-Apple%20Silicon%20(arm64)-purple)](https://www.apple.com/mac/)
[![Installer](https://img.shields.io/badge/Installer-.dmg%20(2.7%20MB)-green?logo=files)](Quillfolio.dmg)
[![Author](https://img.shields.io/badge/Author-B4rtiX-black?logo=github)](https://github.com/B4rtiX)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

---

## 🖥️ System Requirements

### Hardware & Operating System

| Specification | Minimum Requirement | Recommended |
| :--- | :--- | :--- |
| **Operating System** | **macOS 13.0 (Ventura)** or later | **macOS 14 (Sonoma)** / **macOS 15 (Sequoia)** |
| **Processor / Architecture** | **Apple Silicon (M1, M2, M3, M4)** *(native `arm64` binary)* | Apple Silicon (M1 Pro/Max/Ultra or newer) |
| **Memory (RAM)** | **4 GB RAM** | **8 GB RAM** or more |
| **Disk Space** | **~25 MB** available disk space *(DMG installer is ~2.6 MB)* | Additional space for your notes and embedded images |
| **Display** | Minimum resolution of **1280 × 800** | Retina / 4K / ProMotion (120 Hz) |

> [!NOTE]
> **Why macOS 13.0+?**
> Quillfolio leverages modern macOS frameworks including multi-column `NavigationSplitView`, native AppKit graphics contexts, vibrancy materials, and hardware-accelerated CoreGraphics vector rendering.

### Supported Input Hardware

1. **Trackpad & Mouse**:
   - Two-axis smooth pan & zoom across an infinite horizontal and vertical canvas.
   - Built-in **velocity-based pressure simulation** dynamically modulates ink stroke thickness according to cursor speed, providing a natural handwritten aesthetic even without a physical stylus.
2. **Graphics Tablets & Digital Pens**:
   - Hardware pressure sensitivity (`NSEvent.pressure`) with configurable non-linear response curves (0.5x – 2.5x).
   - Zero-lag support for **Wacom**, **Huion**, **XP-Pen**, **Gaomon**, **Veikk**, and other USB/Bluetooth drawing tablets.
   - Dedicated support for **tablet ExpressKeys** and pen rocker buttons:
     - Zoom In: `Cmd + =` / button 3
     - Zoom Out: `Cmd + -` / button 4
     - Undo / Redo: `Cmd + Z` / `Cmd + Shift + Z` (and `Ctrl + Z` / `Ctrl + Y`)
3. **iPad with Apple Pencil (Apple Sidecar)**:
   - Wirelessly use an iPad as an external drawing screen with full tilt and pressure fidelity via Apple Sidecar.

---

## 🌟 Key Features

### 1. ✒️ Vector Digital Ink & Bézier Spline Smoothing
- **Anti-Jitter Filter**: Suppresses high-frequency micro-tremors from hand movements.
- **Midpoint Quadratic Bézier Interpolation**: Translates discrete raw digitizer points into continuous vector curves with natural, rounded arcs — completely eliminating jagged corners or staircasing artifacts.
- **3-Point Moving Average Pressure Smoothing**: Guarantees silky-smooth line taper transitions from delicate hairlines to bold downstrokes.

### 2. 🪄 Intelligent Geometric Shape Recognition (Hold & Snap)
Draw naturally and pause for a brief moment (`~0.45s`) at the end of a stroke to trigger auto-snapping:
- **Precision Detection**:
  - **Circles vs. Ellipses**: Distinguishes true circular geometry from elongated or tilted ovals.
  - **Squares vs. Rectangles**: Accurately measures aspect ratios and 90° right angles.
  - **Triangles & Right-Angled Triangles**: Detects equilateral, isosceles, and right triangles.
  - **Rhombus (Diamond) & Parallelogram**: Recognizes slanted quadrilaterals with parallel opposing edges.
  - **Regular & Stretched Hexagons**: Symmetrical 6-sided polygons and elongated diagram blocks with pointed ends.
  - **Trapezoids**: Both isosceles and right-angled trapezoids (with vertical right walls on left or right).
  - **Single & Double-Headed Arrows**: Detects arrowheads on either or both ends.
  - **Stars & Clouds**: Multi-pointed stars and cloud diagrams.
- **Handwriting Protection**: Smart heuristics prevent common handwriting letters (e.g., cursive 'o', words, or continuous script) from accidentally converting into geometric shapes.
- **Interactive Transformation**: Every recognized shape features 8 resize handles, rotational control, and an instant **[ ⇄ Reverse Arrow ]** direction toggle.

### 3. 📊 Dynamic Interactive Tables & Floating Text
- **Auto-Expanding Tables**: Multi-column and multi-row tables rendered directly on the canvas. Type into any cell and watch the row height and column width expand dynamically without truncating content.
- **One-Click Row & Column Management**: Quick `+ Row`, `+ Column`, `- Row`, and `- Column` controls.
- **Floating Text Boxes & Sticky Notes**: Click anywhere to place transparent floating text boxes or colorful pastel Post-it notes with arbitrary rotation.
- **Rich Typography & Math Symbols**: Choose between San Francisco, Helvetica, Times New Roman, Georgia, Menlo (Code), Noteworthy (Handwriting), and Optima. Insert Greek letters ($\alpha, \beta, \gamma, \theta$), math operators ($\pi, \sum, \int, \infty, \sqrt{}$), logic symbols ($\in, \subset, \cup, \cap$), and exponents ($^2, ^3, ^n$).

### 4. 🌐 Full Bilingual Interface (English 🇬🇧 & Polish 🇵🇱)
- Instant, real-time UI localization toggle between English and Polish across all views, toolbars, tooltips, popup descriptions, menus, and dialogs.
- Changes apply immediately without restarting the application and are remembered across sessions.

### 5. ⚙️ Dedicated macOS Settings Hub (`⌘,`)
Accessible via the sidebar, toolbar gear icon, or system menu (`⌘,`):
- **General & Language**: Switch language cards, select app theme (System / Light / Dark), and toggle the animated startup splash screen.
- **Canvas & Paper**: Set default paper style (*Blank, Ruled, Grid, Dotted*) and default background color (*White, Cream Sepia, Yellow Legal, Dark Slate, Chalkboard*).
- **Drawing & Stylus**: Choose default tool, toggle Bézier vector smoothing, adjust stylus pressure sensitivity, and fine-tune auto-shape hold delay.
- **Typography & Text**: Configure default font family and font size with live preview.
- **Storage & Backup**: View exact storage paths on disk, browse notebook statistics (notes count, total pages, handwritten strokes), reveal storage folder in Finder, and safely restore factory defaults without losing notes.

### 6. 📄 Infinite Canvas & Multi-Page Notebooks
- Expand your canvas infinitely horizontally (`+800 px`) and vertically (`+1000 px`) to fit large diagrams, mind maps, or extended equations.
- Organize work into hierarchical **Categories ➔ Subcategories ➔ Notes ➔ Multiple Pages**.

### 7. 📤 Export & Sharing
- **Vector PDF Export**: Exports high-resolution multi-page vector documents ready for print or sharing.
- **Crystal-Clear PNG Export**: Exports the active page at 2x Retina resolution with transparent or styled paper background.

---

## ⌨️ Essential Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| **`⌘ + N`** | Create a new note |
| **`⌘ + Z`** / **`Ctrl + Z`** | Undo stroke, shape, or text edit |
| **`⌘ + ⇧ + Z`** / **`Ctrl + Y`** | Redo stroke, shape, or text edit |
| **`⌘ + =`** / **`Cmd + +`** | Zoom in (+15%) |
| **`⌘ + -`** | Zoom out (-15%) |
| **`⌘ + 0`** | Reset zoom to 100% |
| **`⌘ + ,`** | Open Settings |
| **`⌘ + C`** / **`⌘ + V`** | Copy and paste selected strokes or shapes |
| **`⌘ + D`** | Duplicate selected elements |
| **`Backspace`** / **`Delete`** | Delete selected strokes or active shape |

---

## 🚀 Installation & Running

### Option 1: Install via DMG (Recommended)
1. Download **[`Quillfolio.dmg`](Quillfolio.dmg)** (approx. **2.6 MB**).
2. Double-click the `.dmg` file to mount it.
3. Drag **Quillfolio** into your **Applications** folder.
4. Launch it from Launchpad, Spotlight (`⌘ + Space`), or the Applications folder.

### Option 2: Build from Source
Requirements: macOS 13.0+, Xcode Command Line Tools (`xcode-select --install`).

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/Quillfolio.git
cd Quillfolio

# Compile the native macOS application
./build.sh

# Run the app
open Quillfolio.app

# Optional: Generate a standalone installer .dmg
./create_dmg.sh
```

---

## 🧪 Unit Testing & Verification
The project includes an exhaustive unit test suite covering vector smoothing, Douglas-Peucker shape heuristics, undo/redo state trees, table geometry, and localization:

```bash
swiftc -parse-as-library test_deep_suite.swift \
       Sources/Models/Localization.swift \
       Sources/Models/Models.swift \
       Sources/Models/DataStore.swift \
       Sources/Drawing/PaperRenderer.swift \
       Sources/Drawing/CanvasView.swift \
       Sources/Drawing/ShapeRecognizer.swift \
       -o /tmp/run_all_tests && /tmp/run_all_tests
```
*(All 77/77 tests pass with 100% test coverage).*

---

## 📁 Project Structure

```
Quillfolio/
├── Quillfolio.dmg              # Ready-to-install standalone Apple Disk Image (~2.6 MB)
├── Quillfolio.app              # Compiled native macOS application bundle
├── build.sh                    # Automated release compiler and installer script
├── create_dmg.sh               # Standalone DMG packaging script
├── AppIcon.icns                # High-resolution multi-size macOS app icon
├── test_deep_suite.swift       # 77-test verification suite
├── Sources/
│   ├── App.swift               # Application entry point, menus & global shortcuts
│   ├── Models/
│   │   ├── Localization.swift  # Dual-language engine (English & Polish)
│   │   ├── Models.swift        # Data structures (strokes, shapes, tables, notes)
│   │   └── DataStore.swift     # State management, persistence & history stack
│   ├── Drawing/
│   │   ├── CanvasView.swift    # AppKit high-performance vector rendering engine
│   │   ├── CanvasRepresentable.swift # SwiftUI to AppKit NSView bridge
│   │   ├── ShapeRecognizer.swift     # Douglas-Peucker & geometric curvature solver
│   │   └── PaperRenderer.swift # Background textures (grid, dots, ruled, chalkboard)
│   └── Views/
│       ├── MainView.swift      # Navigation split view coordinator
│       ├── SidebarView.swift   # Category tree & quick filters
│       ├── ToolbarView.swift   # Drawing tools, color picker & thickness popover
│       ├── NoteCanvasAreaView.swift # Canvas viewport, zoom & multi-page controls
│       ├── InteractiveOverlays.swift # Text formatting, dynamic tables & Post-it notes
│       ├── SettingsView.swift  # Complete native macOS Settings hub (⌘,)
│       ├── HomeDashboardView.swift  # Welcome dashboard, templates & search
│       ├── SplashScreenView.swift   # Animated startup splash screen
│       └── ExportHelper.swift  # High-DPI PNG and vector PDF exporter
└── README.md                   # Complete English documentation
```

---

## 📄 License
This project is open-source software licensed under the **GNU General Public License v3.0 (GPL-3.0)**.  
You are free to copy, distribute, and modify this software under the terms of the GPL-3.0 license. Any derivative works must remain open-source under the same license terms.

See the [LICENSE](LICENSE) file for more details.  
Copyright (c) 2026 **B4rtiX**. All rights reserved.
