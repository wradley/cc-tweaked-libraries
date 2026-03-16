# cc-tweaked-programs
Backup for CC:Tweaked programs

## IDE Setup
VS Code with [lauls](https://luals.github.io/) for language support. They also have [addons](https://luals.github.io/wiki/addons/) for CC:Tweaked.

## Organization
Reusable libraries live under `lib/<name>/`.

Recommended library layout:

- `README.md`: library-specific docs
- `src/`: runtime source to vendor into program repos
- `tst/`: library-local tests

Single-file libraries should use `src/<name>.lua`.
Multi-file libraries should use `src/<module>/init.lua` plus supporting modules.

## Tests

- Run all shared-library tests from `tst/run.lua`.
- Each library may also keep its own local runner under `lib/<name>/tst/run.lua`.
