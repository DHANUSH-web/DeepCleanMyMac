# dcmm-desktop — agent instructions

Read this entire file before changing code. Do not ask the user to re-explain product, UI rules, or how this relates to dcmmlib.

## What this repo is

**dcmm-desktop** is **DeepCleanMyMac**, a **macOS-only** native AppKit GUI (Objective-C++).

- It is **not** a cross-platform GUI and must not be ported to Windows/Linux in this repo.
- A future Windows app will be a **separate project** that links **dcmmlib**.
- All scanning, hashing, path safety, and trashing go through **dcmmlib**. Do not reimplement engine logic in `.mm` files.

Typical workspace:

```
DeepCleanMyMac/
  dcmmlib/                 # engine (own git)
  dcmm-desktop/            # this app (own git)
    include/               # this app's headers only
    src/                   # AppKit .mm
    extras/dcmmlib/        # git submodule → ../dcmmlib
```

CMake prefers `extras/dcmmlib` if present, else sibling `../dcmmlib`. Do **not** clone the engine at the desktop repo root.

**If you change the engine**, edit the canonical `dcmmlib` repo and **sync** into `dcmm-desktop/extras/dcmmlib`. Otherwise the app builds stale code.

## Product

Free CleanMyMac-style utility: Smart Scan, System Junk, Large Files, Duplicates, Uninstaller, Privacy, Space Lens, Maintenance. Moves **checked** items to Trash after confirmation. No telemetry.

Bundle ID: `com.deepclean.DeepCleanMyMac`  
App name: DeepCleanMyMac  
Entry: `src/main.mm` → `AppDelegate` → `DCMainWindowController`

## Build (macOS)

CMake + **Ninja** + **Apple Clang**. OBJCXX + ARC. Deployment target 13.0.

```bash
make init                 # extras/dcmmlib submodule
make                      # debug
make build release
make test
make run                  # open the .app
make relaunch             # pkill + open after UI changes
```

CMake presets (equivalent):

```bash
git submodule update --init extras/dcmmlib
cmake --preset release
cmake --build --preset release
ctest --preset release
open build/release/DeepCleanMyMac.app
```

Debug: `--preset debug` (`build/debug`). Presets are in `CMakePresets.json` (Ninja + Clang). Do not commit `CMakeUserPresets.json`.

Equivalent without presets:

```bash
cmake -S . -B build -G Ninja \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_OBJCXX_COMPILER=clang++ \
  -DCMAKE_BUILD_TYPE=Release
cmake --build build
ctest --test-dir build --output-on-failure
open build/DeepCleanMyMac.app
```

Links: `dcmm`, Cocoa, AppKit, Foundation, QuartzCore, Collaboration.

## Source map

| File | Role |
|------|------|
| `include/Modules.h` | Sidebar modules (GUI-only enum; not in the engine) |
| `include/ui/Theme.h` + `src/ui/Widgets.mm` | Native AppKit helpers, confirm/inform dialogs |
| `src/ui/MainWindowController.mm` | Classic `NSSplitView`: frost sidebar + opaque content |
| `src/ui/SidebarView.mm` | Nav source list + user profile footer |
| `src/ui/DashboardView.mm` | Overview: compact storage card + tool rows |
| `src/ui/ResultsView.mm` | Smart Scan / System Junk / Privacy lists |
| `src/ui/LargeFilesView.mm` | Large files |
| `src/ui/DuplicatesView.mm` | SHA-256 duplicates |
| `src/ui/UninstallerView.mm` | Apps + leftovers |
| `src/ui/SpaceLensView.mm` | Home folder sizes |
| `src/ui/MaintenanceView.mm` | Housekeeping cards |
| `include/AppFeatures.hpp` | Desktop feature contracts (scan dispatch, roots, Select All) |
| `tests/` | Regression tests for every sidebar module (isolated `DCMM_HOME`) |

## UI design rules (hard-won — do not regress)

The user wants **Apple aesthetic** using **native AppKit**, not a custom theme and not a raw unstyled dump.

**Do**

- System colors (`labelColor`, `secondaryLabelColor`, `controlAccentColor`, `windowBackgroundColor`).
- System text styles / SF Pro weights; SF Symbols.
- Auto Layout + `NSStackView`; ~24–28 pt page margins; content hugging so headers stay at the **top** (use `DCFlexibleSpace` instead of stretching the first control).
- Grouped cards: `NSVisualEffectMaterialContentBackground`, corner radius ~10.
- Overview column ~480 pt: small disk **bar** (~220×8), not a full-window progress bar.
- Tools: **icon well + semibold title + caption description + chevron**. Not stretched gray push buttons.
- Maintenance: **2-column cards** with **Run at the bottom**, not a sparse title list and not one row stretched full height.
- Sidebar: **frosted, full-height column** with a **real divider**, desktop visible through the glass.

**Do not**

- Custom dark palettes, painted `NSView` chrome, custom `DCButton`/`DCRingView` (those were removed).
- **Tahoe liquid-glass floating sidebar.** Do **not** use `[NSSplitViewItem sidebarWithViewController:]`. That API puts a floating glass overlay on macOS 26. Use a classic `NSSplitView` plus `NSVisualEffectView` with `NSVisualEffectMaterialUnderWindowBackground` and `NSVisualEffectBlendingModeBehindWindow`. Content pane is **opaque** (`DCOpaquePane`). Window: `opaque = NO`, `backgroundColor = clearColor`, `FullSizeContentView` + transparent titlebar so frost can show wallpaper on the left only.
- Hover fill on the profile footer (click still works; no highlight).

## Sidebar profile

Footer shows: circular **account picture** (`Collaboration` / `CBIdentity`), **NSFullUserName**, **localized hostname** in caption color.

Click (no hover background) opens System Settings **Users & Groups**:

```
x-apple.systempreferences:com.apple.Users-Groups-Settings.extension
```

Fallbacks: `com.apple.preferences.users`, Apple ID settings, then System Settings app.

Disk usage is **Overview only**, not duplicated in the sidebar.

## Safety in the UI (engine still enforces)

Never skip these, even if the engine would also block:

1. **Opt-in for System Junk, Privacy, Large Files, Duplicates, Uninstaller.** Those lists start **unchecked**.
   **Smart Scan is the exception:** `scanSmart()` returns **recommended groups already selected**. The user still confirms before Trash. Do not list per-file rows on Smart Scan — one row per group (User Caches, Logs, Saved Application State). System Junk is the item-by-item picker (`scanJunk`).
2. **Confirm before any removal.** `DCConfirmMoveToTrash` / `DCConfirmDestructive`: **Cancel is the default (Return)**. Destructive button is second. List paths and size when moving to Trash.
3. **Preview first.** Maintenance: `previewMaintenance`. If `nothingToDo`, show **`DCInformNothingToClean`** — do not run Empty Trash (or Quick Look) on an empty set.
4. **Report outcome.** After a real clean: **`DCInformCleaned`** with **bytes freed** and item count. If zero items moved: Nothing to clean.
5. Empty Trash copy must say it is **permanent** and only affects user Trash.
6. DNS flush / Launch Services: they do **not** delete files; dialogs must say that (no fake byte counts).

Smart Scan **Select All** toggles to **Unselect All** when every listed item is checked (including after individual checkbox changes).

## Engine API the UI must use

```cpp
#include <dcmm/dcmm.hpp>
```

- `scanSmart` / `scanJunk` / `scanPrivacy`
- `trashPaths`
- `findLargeFiles` / `findDuplicates` / `spaceLens`
- `listApps` / `attachLeftovers`
- `disk` / `memory`
- `previewMaintenance` / `runMaintenance` / `maintenanceTasks`

Do not call `unlink`/`removeItem` from the GUI except through the engine. Do not weaken `isSafeToTrash`.

## How to work

- UI-only requests: headers in `include/` (`include/ui/`), implementations in `src/` (`src/ui/`). Do not “fix” catalogs unless asked.
- Third-party code and the engine submodule belong in `extras/`, never at the repo root.
- Behavior/safety/scan: change **dcmmlib**, then sync `extras/dcmmlib`, then wire UI if needed.
- After UI changes, `make relaunch` (or `pkill -x DeepCleanMyMac` then `open build/release/DeepCleanMyMac.app`).
- Match existing Objective-C++ style: ARC, helpers in `Theme.h`/`Widgets.mm`.

## Out of scope

- Making this app run on Windows or Linux
- Replacing AppKit with Qt/Flutter/SwiftUI unless the user explicitly asks
- Network services, accounts, licensing servers
- Permanent delete of user documents
