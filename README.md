# dcmm-desktop

Native **DeepCleanMyMac** macOS app. The UI is AppKit (Objective-C++). All scanning, hashing, safety checks, and trashing go through **[dcmmlib](https://github.com)** as a Git submodule — no engine logic lives here.

## Layout

```
dcmm-desktop/
  src/           AppKit GUI
  tests/         GoogleTest (engine link + module titles)
  dcmmlib/       git submodule (after `git submodule update --init`)
```

If the submodule is missing, CMake will also accept a sibling `../dcmmlib` checkout.

## Build (LLVM + Clang + Ninja)

```bash
git submodule update --init --recursive
cmake --preset release
cmake --build --preset release
ctest --preset release
open build/release/DeepCleanMyMac.app
```

Debug: `--preset debug` (output in `build/debug`).

Equivalent without presets:

```bash
cmake -S . -B build -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=cmake/llvm-clang.cmake \
  -DCMAKE_BUILD_TYPE=Release
cmake --build build
ctest --test-dir build --output-on-failure
open build/DeepCleanMyMac.app
```

## What the app does

- Smart Scan — recommended groups only (`~/Library/Caches`, logs, saved state)
- System Junk — every cache and leftover, item by item (npm, Cargo, Xcode, Darwin tmp, …)
- Large files and SHA-256 duplicates
- App uninstaller + leftover files
- Privacy (browser caches)
- Space Lens (home-folder usage)
- Maintenance (empty Trash, flush DNS, rebuild Launch Services)

Selected items are **moved to Trash** by `dcmmlib`. Protected paths are rejected by the engine.
