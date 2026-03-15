# PHTV Scripts

Release automation is fully managed by GitHub Actions in:
- `.github/workflows/release.yml`
- `.github/workflows/ci.yml`

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
