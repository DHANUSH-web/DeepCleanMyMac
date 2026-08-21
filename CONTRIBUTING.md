# Contributing to DeepCleanMyMac

Thanks for helping. This repo is the **macOS-only** AppKit app. Scanning, safety, and trashing live in **[dcmmlib](https://github.com/DHANUSH-web/dcmmlib)** (`extras/dcmmlib`).

Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and [SECURITY.md](SECURITY.md). Engine-only changes belong in dcmmlib, not here.

## Branches

| Branch | Role |
|--------|------|
| `beta` | Default for PRs and new work |
| `main` | Stable releases — do not open feature PRs against `main` |

The engine uses `dev` / `main` at https://github.com/DHANUSH-web/dcmmlib.git (this is the submodule URL). After an engine change, update the submodule:

```bash
git -C extras/dcmmlib fetch origin
git -C extras/dcmmlib checkout <dcmmlib-dev-commit>
```

## Setup

macOS 13+, CMake 3.21+, Ninja, Apple Clang, Xcode Command Line Tools.

```bash
git clone --recurse-submodules https://github.com/DHANUSH-web/DeepCleanMyMac.git
cd DeepCleanMyMac
git checkout beta
make init                 # if the submodule is missing
make build release
make test release
make run release
```

If `extras/dcmmlib` is empty: `git submodule update --init extras/dcmmlib`.

## Pull requests

1. Fork and branch from **`beta`**.
2. One feature or one fix per PR.
3. Run `make test release`.
4. UI changes: screenshot or a short note of what you clicked.
5. Open the PR **against `beta`**.

Commit subjects: `FEAT: …` or `FIX: …`.

## Rules

- Native AppKit / Human Interface Guidelines. No custom dark palettes or painted chrome.
- Do not use `sidebarWithViewController:` (Tahoe liquid-glass sidebar).
- Do not reimplement scan/trash logic in `.mm` files — call `dcmmlib`.
- Deletes stay opt-in, with Cancel as the default confirm. Report bytes freed.
- Headers in `include/`, implementations in `src/`, third-party and the engine in `extras/`.
