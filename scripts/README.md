# PHTV Scripts

Release automation is fully managed by GitHub Actions in:
- `.github/workflows/release.yml`
- `.github/workflows/ci.yml`

## Remaining local tools

### `tools/generate_dict_binary.swift`
Build-time utility to regenerate dictionary binary assets when dictionary source data changes.

## Notes

- Release, Homebrew sync, and local shell helpers were removed from `scripts/` because the logic now runs in GitHub Actions.
- Application runtime/source code remains Swift-first; this folder keeps only the dictionary generation tool.
