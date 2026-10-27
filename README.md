# TOFF Games Production OS

**Version:** 0.3.0  
**Status:** Extracted pilot framework with Unity tooling abstraction — usable foundation, not a mature autonomous production platform or orchestrator.

Studio-wide playbook for AI-native Unity game development at TOFF Games. One standard process; many independent game repositories.

## What this is

Production OS standardizes **how** TOFF Games builds games with humans + AI agents:

- Task intake, scope, approval boundaries, and Definition of Done
- Documentation ownership (design intent vs implementation status)
- Safe Unity Editor automation policy (CLI Direct, CLI MCP, legacy MCP)
- Capability-based backend selection and read-only capability detection
- Portable validation strategy for official Unity Test Framework Edit Mode
- Bootstrap templates for new or existing Unity game repos

It does **not** replace a game’s GDD, architecture, art direction, or Unity project layout.  
It does **not** include the future headless Game Development Orchestrator (policy foundation only in 0.3).

## What it standardizes

| Layer | Owned by Production OS |
|---|---|
| Process | Lifecycle, DoD, evidence honesty, human gates |
| Agent instructions (studio) | How to maintain *this* repository |
| Agent templates (games) | Portable `AGENTS.md` + Cursor rules with placeholders |
| Tooling contract | Capability names, permission levels, backend selection rules |
| Tooling patterns | Identity checks, validate.sh contract, capability detect, bootstrap |
| Docs templates | Status, GDD, architecture, QA, ADR, feature specs, tooling reports |

## What remains game-specific

| Concern | Owned by each game repo |
|---|---|
| Game name, fantasy, rules, feel | GDD / art direction |
| Unity version, packages, platforms | `ProjectSettings`, manifests |
| Folder layout, namespaces, assemblies | Architecture + ADRs |
| Scenes, prefabs, assets | Game assets |
| Test assemblies and filters | Game `scripts/validate.config.sh` |
| Whether CLI / Pipeline / MCP are installed | Local Editor + developer machine |

## Provenance

| Pilot | Contribution |
|---|---|
| **Nehokej** | Onboarding, code+UTF loop, legacy MCP scene mutation — [examples/nehokej/](examples/nehokej/) |
| **WheelDraw** | Production OS v0.2 adoption, bootstrap portability, in-Editor UTF |
| **SOWA** | Unity CLI Direct + Pipeline + legacy MCP coexistence — [examples/sowa-game/](examples/sowa-game/) |

Treat pilots as **reference evidence**, not mandatory architecture.

## Quick start

### Bootstrap a game repository

```bash
# Dry-run (no writes)
./bootstrap/bootstrap.sh --dry-run /path/to/your-unity-game

# Install missing templates only (default: non-destructive)
./bootstrap/bootstrap.sh /path/to/your-unity-game

# Overwrite existing managed files (explicit)
./bootstrap/bootstrap.sh --force /path/to/your-unity-game
```

Details: [bootstrap/README.md](bootstrap/README.md).

Bootstrap **never** installs Unity packages, rewrites MCP config, or requires Unity CLI.

### Check Unity tooling readiness (optional, read-only)

```bash
./scripts/unity-capability-detect.sh /absolute/path/to/your-unity-game
```

Agents should use this (or equivalent checks) before claiming a backend can mutate a project. See [docs/unity-tooling.md](docs/unity-tooling.md).

### Adopt in an existing game

1. Run bootstrap with `--dry-run` and review the report.  
2. Install without `--force`; fill `TODO` placeholders in generated files.  
3. Pin Unity version in docs; configure `scripts/validate.config.sh` if needed.  
4. Keep game-specific architecture rules in the game repo — do not force Nehokej’s domain layout.  
5. **v0.2 → v0.3:** no mandatory migration. Optionally refresh tooling safety rules / completion-report template after review.

### Maintain templates

- Edit files under `templates/` in this repo.  
- Bump `VERSION` (semver) and update `CHANGELOG.md`.  
- Re-run bootstrap with care on consumer games; prefer additive upgrades.

## Required vs optional tools

| Tool | Role | Required? |
|---|---|---|
| Git | Durable source of truth | Yes |
| Cursor (or compatible agent) | Implementation | Recommended |
| Unity Editor | Game development | Yes for Unity games |
| Unity Test Framework | Edit Mode evidence | Recommended |
| Unity CLI + Pipeline | Preferred Editor automation when verified | **Optional** |
| Unity CLI MCP | Optional MCP transport | **Optional** |
| Legacy Unity AI Assistant MCP | Live Editor assist | **Optional** |
| CI | Headless validate/build | Optional (roadmap) |

## Capability-based backends

| Backend | Role |
|---|---|
| Unity CLI Direct | Preferred when the needed capability is verified for the exact project |
| Unity CLI MCP | Optional supported backend when configured |
| Legacy AI Assistant MCP | Compatibility backend |

Do **not** select CLI only because `unity` is on `PATH`.  
Do **not** silently fall back across backends for mutations.  
Report `UNAVAILABLE` / `UNKNOWN` / `BLOCKED` honestly.

## What v0.3 does and does **not** automate

| Does | Does not |
|---|---|
| Document the Unity Tooling Contract | Build the headless orchestrator |
| Detect capabilities read-only | Auto-install Pipeline / packages |
| Standardize validation + evidence policy | Auto-close Editors or rewrite MCP config |
| Remain usable without CLI/MCP | Guarantee CLI stability across versions |
| Stay backward compatible with v0.2 projects | Force Nehokej/WheelDraw/SOWA migrations |

## Framework vs game vs tooling

| Concept | Meaning |
|---|---|
| **Framework version** | This repo’s `VERSION` (e.g. `0.3.0`) |
| **Game implementation** | A game’s code, scenes, and docs |
| **Runtime tooling** | Unity Editor, optional CLI/Pipeline/MCP, CI runners |
| **Agent instructions** | `AGENTS.md` + `.cursor/rules` in a repo |
| **Workflow validation** | Specs, tests, Play Mode notes, diff review |

## Documentation map

| Doc | Purpose |
|---|---|
| [docs/philosophy.md](docs/philosophy.md) | Principles and honesty about verification |
| [docs/production-pipeline.md](docs/production-pipeline.md) | Stage gates and lifecycle |
| [docs/agent-architecture.md](docs/agent-architecture.md) | Roles, boundaries, handoffs |
| [docs/tooling.md](docs/tooling.md) | Studio stack overview |
| [docs/unity-tooling.md](docs/unity-tooling.md) | **Unity tooling contract, safety, evidence** |
| [docs/validation-strategy.md](docs/validation-strategy.md) | PASS / FAIL / BLOCKED / UNVERIFIED + UTF routes |
| [docs/studio-vs-project.md](docs/studio-vs-project.md) | What lives where |
| [docs/roadmap.md](docs/roadmap.md) | Deferred work |
| [AGENTS.md](AGENTS.md) | How agents maintain *this* OS repo |
| [CHANGELOG.md](CHANGELOG.md) | Release notes |

## Honesty bar

Do not claim production readiness from static checks alone.  
Do not treat CLI/MCP tool success as gameplay proof.  
Do not describe conditional pilot results as fully proven studio-wide capabilities.  
A tooling smoke test is not gameplay regression coverage.

## License / ownership

Internal TOFF Games studio framework. Not published as a product.
