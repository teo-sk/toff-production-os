# AGENTS.md — {{GAME_NAME}}

Portable onboarding for any coding agent. Prefer this file + linked docs over conversation memory.

> Generated from TOFF Games Production OS {{OS_VERSION}}. Fill every `{{…}}` / `TODO` before relying on agents.

## Identity

- **Game:** {{GAME_NAME}} — {{GAME_ONE_LINER}}
- **Phase / status:** See [docs/00-status.md](docs/00-status.md).
- **Unity:** pin from `ProjectSettings/ProjectVersion.txt` (currently `{{UNITY_VERSION}}`). Do not upgrade Unity or packages unless a human task explicitly requires it.
- **Primary gameplay scene:** `{{PRIMARY_SCENE}}` (TODO if unknown).

## Document ownership

| Doc | Authority |
|---|---|
| [docs/GDD.md](docs/GDD.md) (or `docs/02-gdd.md`) | Approved gameplay / product design intent |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (or `docs/04-technical-design.md`) | Approved technical architecture |
| [docs/features/](docs/features/) | Per-task scope and acceptance criteria |
| [docs/decisions/](docs/decisions/) | Durable ADRs |
| [docs/00-status.md](docs/00-status.md) | Current implementation status |

Agents **may** update factual status after verified changes.  
Agents **must not** silently change approved gameplay, visual direction, or acceptance criteria to fit code. On conflict: escalate with options.

## Layout

```
{{PROJECT_LAYOUT}}
```

Namespaces / assemblies: `{{NAMESPACES_OR_TODO}}`

## Hard constraints

1. Stay inside the task’s allowed paths; report before expanding.  
2. Default forbidden: `Packages/manifest.json`, silent `ProjectSettings/**`, secrets, store publish, bulk scene rewrites.  
3. Do not add speculative packages unless the task and a human approve.  
4. {{ARCHITECTURE_CONSTRAINTS_OR_TODO}}  
5. Follow Production OS Unity MCP identity rules before any Editor mutation (see below).

## Task lifecycle

1. **Understand** — player outcome, linked spec, allowed/forbidden paths.  
2. **Plan** — real files impacted; risks; do not invent project facts.  
3. **Implement** — focused feature-branch diff.  
4. **Validate** — `./scripts/validate.sh` when safe; otherwise report blocked + in-Editor alternative. Never claim tests passed without execution. (`--self-test` checks the script only.)  
5. **Review** — evidence, risks, rollback; human approval for core feel, packages, architecture, release.

## Unity MCP — project identity

MCP is **optional**. If disconnected or identity unverifiable: continue with C# / docs / tests; report MCP unavailable and identity **unverified**.

Before **any** Unity MCP mutation:

1. Canonicalize this repository’s absolute Git root.  
2. Canonicalize MCP project root (`GetProjectRoot` or equivalent).  
3. Require **exact string equality**; refuse mutations otherwise.  
4. Do not use folder-name heuristics or hardcoded home paths.  
5. Confirm active scene / target asset matches the task (default: `{{PRIMARY_SCENE}}`).  
6. Prefer clean git checkpoint or document pre-existing dirty state.  
7. One writable Editor session — do not race another agent on the same scene/prefab.

After mutation: console check; property readback; **full serialized Git diff** for incidental YAML; report succeeded / failed / **not Play Mode–verified**. Never claim correct gameplay from MCP success alone.

## Task completion report

- Summary of changes (paths)  
- Acceptance: met / not met / deferred  
- Validation: command, result (PASS/FAIL/BLOCKED/UNVERIFIED), evidence path — distinguish `--self-test` from UTF  
- MCP: used? roots compared? mutations? console clean?  
- Risks / follow-ups  
- Human approvals still needed  
