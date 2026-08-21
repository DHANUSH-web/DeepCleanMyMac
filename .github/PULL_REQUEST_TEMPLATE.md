## Summary

<!-- FEAT or FIX. Target branch: **beta**. -->

## Kind

- [ ] FEAT
- [ ] FIX

## Tests

- [ ] `make test release` passes
- [ ] UI change: screenshot or short click-through notes

## Safety / HIG

- [ ] No auto-select except Smart Scan recommended groups
- [ ] Confirm dialogs still default to Cancel
- [ ] No engine logic copied into `.mm` files
- [ ] Native AppKit only (no custom chrome, no `sidebarWithViewController:`)

## Submodule

- [ ] `extras/dcmmlib` is GitHub `main` (`make init`) if this needs a new engine release
