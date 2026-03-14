# PHTV Scripts

Release automation is fully managed by GitHub Actions in:
- `.github/workflows/release.yml`
- `.github/workflows/ci.yml`

## Remaining local tools

### `tools/generate_dict_binary.swift`
Build-time utility to regenerate dictionary binary assets when dictionary source data changes.

Canonical dictionary sources live in:
- `docs/dictionary/en_words.txt` and `docs/dictionary/vi_words.txt`
- `docs/dictionary/en_words.d/*.txt` for categorized English additions that should always be preserved in `en_dict.bin`

## Notes

- Release, Homebrew sync, and local shell helpers were removed from `scripts/` because the logic now runs in GitHub Actions.
- Application runtime/source code remains Swift-first; this folder keeps only the dictionary generation tool.
