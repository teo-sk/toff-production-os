# TOFF Production OS

An open-source workflow framework for AI-assisted Unity game development.

Production OS gives Unity teams a portable process for working with AI coding agents: scoped tasks, human approval gates, honest validation evidence, and safe optional Unity Editor automation — without forcing a single game architecture.

**Version:** 0.3.1

## Features

- **AI agent onboarding** — clear `AGENTS.md` templates and Cursor rules for game repositories
- **Unity development workflow** — intake → spec → implement → validate → review
- **Approval gates** — humans retain creative, package, architecture, and release decisions
- **Unity CLI / MCP tooling abstraction** — capability-based backends (CLI Direct, CLI MCP, legacy MCP)
- **Safe editor mutations** — exact project identity, exclusive writers, serialized diff review
- **Testing and verification** — official Unity Test Framework evidence; PASS / FAIL / BLOCKED / UNVERIFIED
- **Portable project bootstrap** — non-destructive template install into any Unity game repo

## Quick Start

```bash
# Clone
git clone https://github.com/teo-sk/toff-production-os.git
cd toff-production-os

# Preview install into your Unity game (no writes)
./bootstrap/bootstrap.sh --dry-run /absolute/path/to/your-unity-game

# Install missing templates only (default: non-destructive)
./bootstrap/bootstrap.sh /absolute/path/to/your-unity-game

# Fill TODOs in generated AGENTS.md and docs, then review the diff
```

Optional readiness check (read-only; does not mutate the game):

```bash
./scripts/unity-capability-detect.sh /absolute/path/to/your-unity-game
```

Basic framework self-checks:

```bash
./templates/scripts/validate.sh --self-test   # script parsers only — not UTF evidence
./bootstrap/tests/run-tests.sh
./scripts/tests/run-capability-detect-tests.sh
```

Details: [bootstrap/README.md](bootstrap/README.md).

## How It Works

| Piece | Role |
|---|---|
| **This framework repository** | Process docs, templates, bootstrap, capability detector |
| **Your Unity game repository** | GDD, architecture, code, scenes, tests, game-specific rules |
| **AI coding agents** | Propose and implement within task scope |
| **Unity tooling (optional)** | Editor automation via verified CLI / MCP backends |
| **Tests and evidence** | Official UTF results, diffs, and honest verification labels |

Bootstrap installs templates into a game repo. It never installs Unity packages, rewrites MCP config, or requires Unity CLI.

## Requirements

| Tool | Required? |
|---|---|
| Git | Yes |
| Unity Editor | Yes for Unity games |
| Cursor (or compatible agent) | Recommended |
| Unity Test Framework | Recommended for Edit Mode evidence |
| Unity CLI + Pipeline | **Optional** |
| Unity CLI MCP / legacy AI Assistant MCP | **Optional** |
| CI | Optional |

## Documentation

| Doc | Purpose |
|---|---|
| [docs/philosophy.md](docs/philosophy.md) | Principles and verification honesty |
| [docs/production-pipeline.md](docs/production-pipeline.md) | Stage gates and Definition of Done |
| [docs/agent-architecture.md](docs/agent-architecture.md) | Agent roles and boundaries |
| [docs/tooling.md](docs/tooling.md) | Stack overview and mutation hygiene |
| [docs/unity-tooling.md](docs/unity-tooling.md) | Unity tooling contract, safety, evidence |
| [docs/validation-strategy.md](docs/validation-strategy.md) | PASS / FAIL / BLOCKED / UNVERIFIED + UTF routes |
| [docs/studio-vs-project.md](docs/studio-vs-project.md) | Framework vs game ownership |
| [docs/roadmap.md](docs/roadmap.md) | Deferred work |
| [AGENTS.md](AGENTS.md) | How agents maintain *this* framework repo |
| [CHANGELOG.md](CHANGELOG.md) | Release notes |

## Examples

| Example | Focus |
|---|---|
| [examples/legacy-mcp-workflow/](examples/legacy-mcp-workflow/) | Onboarding, code+UTF loop, controlled legacy MCP mutation |
| [examples/unity-cli-pipeline/](examples/unity-cli-pipeline/) | CLI/Pipeline capability detection, UTF via CLI, lifecycle limits |

Treat examples as **reference evidence**, not mandatory architecture.

## Compatibility and Limitations

- Unity CLI and Pipeline APIs used in pilots were **experimental**; re-verify per version.
- Batch `unity test` may require exclusive project lock — never auto-close the user’s Editor.
- Capability detection does not prove gameplay correctness or legacy MCP session reachability.
- Controlled Editor mutations still need **human approval** for design-altering changes.
- This repository is **not** a complete headless orchestrator.
- Successful tooling commands and screenshots do **not** prove gameplay feel or correctness.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security-sensitive reports: [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) — Copyright (c) 2026 Matej Žilák.

You may use this framework in commercial and closed-source Unity projects, subject to the MIT terms. Unity, Cursor, and other third-party products remain under their own licenses; this MIT grant covers only the contents of this repository.
