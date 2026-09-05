# DeepCleanMyMac

[![CI](https://github.com/DHANUSH-web/DeepCleanMyMac/actions/workflows/ci.yml/badge.svg)](https://github.com/DHANUSH-web/DeepCleanMyMac/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Native **macOS** cleaner (AppKit, Objective-C++). All scanning, hashing, safety checks, and trashing go through **[dcmmlib](https://github.com/DHANUSH-web/dcmmlib)** as a Git submodule (`extras/dcmmlib`) — no engine logic lives here.

## Layout

```
dcmm-desktop/
  include/           App headers (AppDelegate, Modules, ui/)
  src/               AppKit implementations
  extras/dcmmlib/    git submodule (engine)
  tests/             GoogleTest (engine link + module titles)
```

You do **not** need a separate dcmmlib clone. The engine lives only at `extras/dcmmlib`, pulled from [GitHub `main`](https://github.com/DHANUSH-web/dcmmlib).

```bash
git clone --recurse-submodules https://github.com/DHANUSH-web/DeepCleanMyMac.git
cd DeepCleanMyMac
make init                 # extras/dcmmlib from GitHub main (also if you cloned without --recurse-submodules)
```

## Build (LLVM + Clang + Ninja)

```bash
make init                 # extras/dcmmlib from GitHub main
make                      # debug (default)
make build release
make test
make run                  # open DeepCleanMyMac.app
make clean
```

`make help` lists presets (`debug` / `release` / `all`), `relaunch`, and `test release`.

Equivalent with CMake presets:

```bash
make init   # or: git submodule update --init extras/dcmmlib && git -C extras/dcmmlib checkout main
cmake --preset release
cmake --build build/release
ctest --preset release
open build/release/DeepCleanMyMac.app
```

Debug: `--preset debug` (output in `build/debug`).

Equivalent without presets:

```bash
# For debug
cmake -S . -B build/debug -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=cmake/llvm-clang.cmake \
  -DCMAKE_BUILD_TYPE=Debug
cmake --build build/debug
ctest --test-dir build/debug --output-on-failure
open build/debug/DeepCleanMyMac.app

# For release
cmake -S . -B build/release -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=cmake/llvm-clang.cmake \
  -DCMAKE_BUILD_TYPE=Release
cmake --build build/release
ctest --test-dir build/release --output-on-failure
open build/release/DeepCleanMyMac.app
```

## What the app does

- Smart Scan — recommended groups only (`~/Library/Caches`, logs, saved state)
- Deep Scan — every cache and leftover, item by item (review first; not all are safe to remove)
- Large files and SHA-256 duplicates
- App uninstaller + leftover files
- Privacy (browser caches)
- Space Lens (home-folder usage)
- Maintenance (empty Trash, flush DNS, rebuild Launch Services)

Selected items are **moved to Trash** by `dcmmlib`. Protected paths are rejected by the engine.

## Contributing

Development happens on **`beta`**. `main` is stable. See [CONTRIBUTING.md](CONTRIBUTING.md). Please follow the [code of conduct](CODE_OF_CONDUCT.md). Security issues: [SECURITY.md](SECURITY.md).

Engine PRs go to [dcmmlib](https://github.com/DHANUSH-web/dcmmlib) on **`dev`**.

## License

[MIT](LICENSE).
