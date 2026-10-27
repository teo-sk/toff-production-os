# Studio vs project

## Ownership matrix

| Concern | Production OS (`toff-production-os`) | Game repository |
|---|---|---|
| Process / DoD / approval gates | Defaults | May tighten; do not silently weaken safety |
| MCP identity & mutation safety | Mandatory pattern | Fill scene/path placeholders |
| Architecture style | Optional recommendations | Authoritative for that game |
| Unity version | Discovery/pin pattern | Actual pin in `ProjectSettings` |
| GDD / art / product | Templates only | Authoritative content |
| Feature specs | Template | Real specs + acceptance |
| Validation script | Portable template | Installed + optional config |
| Bootstrap | Ships here | Consumer of bootstrap |
| Pilot findings | `examples/` reference | May diverge |

## Upgrade path

1. Note framework `VERSION` used when bootstrapping (record in game `docs/00-status.md`).  
2. Diff new templates against installed copies.  
3. Apply with bootstrap `--dry-run`, then selective install; use `--force` only with review.  
4. Keep game-specific sections when merging rule updates.

## Anti-patterns

- Copying an entire Unity project into Production OS  
- Symlinking or submodule-coupling game Assets into the OS repo  
- Forcing every game onto one folder layout (`Assets/_Game` vs `Assets/Domains`, etc.)  
- Hardcoding absolute developer machine paths in templates  
- Treating Nehokej pilot quirks as studio law  
