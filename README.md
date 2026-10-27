# TOFF Games Production OS

**Version:** 0.2.0  
**Status:** Extracted pilot framework — usable foundation, not a mature autonomous production platform.

Studio-wide playbook for AI-native Unity game development at TOFF Games. One standard process; many independent game repositories.

## What this is

Production OS standardizes **how** TOFF Games builds games with humans + AI agents:

- Task intake, scope, approval boundaries, and Definition of Done
- Documentation ownership (design intent vs implementation status)
- Safe Unity Editor / MCP mutation practices
- Portable validation strategy for Edit Mode tests
- Bootstrap templates for new or existing Unity game repos

It does **not** replace a game’s GDD, architecture, art direction, or Unity project layout.

## What it standardizes

| Layer | Owned by Production OS |
|---|---|
| Process | Lifecycle, DoD, evidence honesty, human gates |
| Agent instructions (studio) | How to maintain *this* repository |
| Agent templates (games) | Portable `AGENTS.md` + Cursor rules with placeholders |
| Tooling patterns | MCP identity checks, validate.sh contract, bootstrap |
| Docs templates | Status, GDD, architecture, QA, ADR, feature specs |

## What remains game-specific

| Concern | Owned by each game repo |
|---|---|
| Game name, fantasy, rules, feel | GDD / art direction |
| Unity version, packages, platforms | `ProjectSettings`, manifests |
| Folder layout, namespaces, assemblies | Architecture + ADRs |
| Scenes, prefabs, assets | Game assets |
| Test assemblies and filters | Game `scripts/validate.config.sh` |
| MCP server choice and availability | Local Editor + developer machine |

## Provenance

Extracted from the **Nehokej (Paper Football)** pilot after:

1. Fresh agent onboarding via `AGENTS.md` + Cursor rules  
2. Feature implementation loop (GAME-E2E-001 — code + Edit Mode tests)  
3. Unity MCP scene mutation loop (GAME-E2E-002 — identity, approval, serialized diff hygiene)

See [examples/nehokej/](examples/nehokej/) for pilot findings. Treat Nehokej as a **reference**, not a mandatory architecture.

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

### Adopt in an existing game

1. Run bootstrap with `--dry-run` and review the report.  
2. Install without `--force`; fill `TODO` placeholders in generated files.  
3. Pin Unity version in docs; configure `scripts/validate.config.sh` if needed.  
4. Keep game-specific architecture rules in the game repo — do not force Nehokej’s domain layout.

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
| Unity MCP | Live Editor assist | **Optional** |
| CI | Headless validate/build | Optional (roadmap) |

## Framework vs game vs tooling

| Concept | Meaning |
|---|---|
| **Framework version** | This repo’s `VERSION` (e.g. `0.2.0`) |
| **Game implementation** | A game’s code, scenes, and docs |
| **Runtime tooling** | Unity, MCP server, CI runners |
| **Agent instructions** | `AGENTS.md` + `.cursor/rules` in a repo |
| **Workflow validation** | Specs, tests, Play Mode notes, diff review |

## Documentation map

| Doc | Purpose |
|---|---|
| [docs/philosophy.md](docs/philosophy.md) | Principles and honesty about verification |
| [docs/production-pipeline.md](docs/production-pipeline.md) | Stage gates and lifecycle |
| [docs/agent-architecture.md](docs/agent-architecture.md) | Roles, boundaries, handoffs |
| [docs/tooling.md](docs/tooling.md) | ChatGPT, Cursor, Unity, MCP, Git |
| [docs/validation-strategy.md](docs/validation-strategy.md) | PASS / FAIL / BLOCKED / UNVERIFIED |
| [docs/studio-vs-project.md](docs/studio-vs-project.md) | What lives where |
| [docs/roadmap.md](docs/roadmap.md) | Deferred work |
| [AGENTS.md](AGENTS.md) | How agents maintain *this* OS repo |
| [CHANGELOG.md](CHANGELOG.md) | Release notes |

## Honesty bar

Do not claim production readiness from static checks alone.  
Do not treat MCP tool success as gameplay proof.  
Do not describe conditional pilot results as fully proven studio-wide capabilities.

## License / ownership

Internal TOFF Games studio framework. Not published as a product.
