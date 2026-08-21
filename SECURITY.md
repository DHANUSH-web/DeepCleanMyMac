# Security policy

DeepCleanMyMac moves user-selected files to Trash through dcmmlib. Bugs can destroy data.

## Please report privately

**Do not** open a public issue for allowlist bypasses, surprise deletes, or symlink escapes.

- App / UI: [GitHub Security Advisories](https://github.com/DHANUSH-web/DeepCleanMyMac/security/advisories/new)
- Engine: [dcmmlib advisories](https://github.com/DHANUSH-web/dcmmlib/security/advisories/new)

## In scope

- UI that auto-selects junk or skips the confirm dialog
- Calling `unlink` / `removeItem` instead of `Engine::trashPaths`
- Bundling a stale submodule that lacks a safety fix

## Out of scope

- User confirmed Move to Trash and the files are in Trash
- Empty Trash after the user confirmed (permanent, by design)
