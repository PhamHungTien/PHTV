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

The English dictionary now builds fully offline from checked-in sources.
The Vietnamese dictionary merges `docs/dictionary/vi_words.txt` with a pinned upstream seed snapshot in `scripts/vendor/viet74k_seed.txt`.

Source files may include blank lines and comment lines prefixed with `#`.

Useful maintenance modes:
- `swift scripts/tools/generate_dict_binary.swift --check-sources`
- `swift scripts/tools/generate_dict_binary.swift --strict-check-sources`
- `swift scripts/tools/generate_dict_binary.swift --normalize-sources`
- `swift scripts/tools/generate_dict_binary.swift --refresh-vietnamese-seed`

`--strict-check-sources` is intended for CI and fails if local sources still contain duplicates or invalid entries.
`--normalize-sources` removes duplicates/invalid lines while preserving the first-seen order of words.
Default Vietnamese builds require the pinned seed snapshot; use `--refresh-vietnamese-seed` to update it, and `--allow-local-only-vietnamese` only when you intentionally accept reduced coverage.

## Notes

- Release, Homebrew sync, and local shell helpers were removed from `scripts/` because the logic now runs in GitHub Actions.
- Application runtime/source code remains Swift-first; this folder keeps only the dictionary generation tool.
