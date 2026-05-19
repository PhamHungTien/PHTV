# PHTV Scripts

Release automation is fully managed by GitHub Actions in:
- `.github/workflows/release.yml`
- `.github/workflows/ci.yml`

## Local development entrypoint

Use `scripts/dev.swift` for local build/test commands. It pins command-line builds to
`/Applications/Xcode.app/Contents/Developer` by default, so the project still builds
when the system `xcode-select` path points at Command Line Tools.

Useful commands:
- `scripts/dev.swift env-check`
- `scripts/dev.swift build`
- `scripts/dev.swift test`
- `scripts/dev.swift engine-test`
- `scripts/dev.swift hotkey-test`
- `scripts/dev.swift dict-check`
- `scripts/dev.swift clean`

Override Xcode or DerivedData paths when needed:

```bash
DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer scripts/dev.swift build
DERIVED_DATA_PATH=/tmp/phtv-derived-data scripts/dev.swift test
```

## Remaining local tools

### `tools/generate_dict_binary.swift`
Build-time utility to regenerate dictionary binary assets when dictionary source data changes.

Canonical dictionary sources live in:
- `docs/dictionary/en_words.txt`
- `docs/dictionary/vi_words.txt`

Both English and Vietnamese dictionaries now build fully offline from those two checked-in source files only.

Source files may include blank lines and comment lines prefixed with `#`.

Useful maintenance modes:
- `swift scripts/tools/generate_dict_binary.swift --check-sources`
- `swift scripts/tools/generate_dict_binary.swift --strict-check-sources`
- `swift scripts/tools/generate_dict_binary.swift --normalize-sources`

`--strict-check-sources` is intended for CI and fails if local sources still contain duplicates or invalid entries.
`--normalize-sources` removes duplicates/invalid lines while preserving the first-seen order of words.

## Notes

- Release, Homebrew sync, and local shell helpers were removed from `scripts/` because the logic now runs in GitHub Actions.
- Application runtime/source code remains Swift-first; this folder keeps only the dictionary generation tool.
