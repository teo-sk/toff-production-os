# Framework vs project

## Ownership matrix

| Concern | Production OS (`toff-production-os`) | Game repository |
|---|---|---|
| Process / DoD / approval gates | Defaults | May tighten; do not silently weaken safety |
| Unity tooling identity & mutation safety | Mandatory pattern (CLI/MCP optional) | Fill scene/path placeholders; optional capability detect |
| Architecture style | Optional recommendations | Authoritative for that game |
| Unity version | Discovery/pin pattern | Actual pin in `ProjectSettings` |
| GDD / art / product | Templates only | Authoritative content |
| Feature specs | Template | Real specs + acceptance |
| Validation script | Portable template | Installed + optional config |
| Bootstrap | Ships here | Consumer of bootstrap |
| Reference findings | `examples/` | May diverge |

## Upgrade path

1. Note framework `VERSION` used when bootstrapping (record in game `docs/00-status.md`).  
2. Diff new templates against installed copies.  
3. Apply with bootstrap `--dry-run`, then selective install; use `--force` only with review.  
4. Keep game-specific sections when merging rule updates.  
5. **v0.2 → v0.3:** no mandatory migration. CLI/Pipeline remain optional. Manually adopt updated `unity-mcp-safety` wording and tooling completion report if desired. No automatic three-way merge in 0.3.

## Anti-patterns

- Copying an entire Unity project into Production OS  
- Symlinking or submodule-coupling game Assets into the OS repo  
- Forcing every game onto one folder layout (`Assets/_Game` vs `Assets/Domains`, etc.)  
- Hardcoding absolute developer machine paths in templates  
- Treating a single pilot’s quirks as framework law  
